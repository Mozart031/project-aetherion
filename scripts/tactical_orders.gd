extends RefCounted

## Explicit goals and deterministic orthogonal routing; no autonomous behavior.
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
var active: Dictionary = {}
var source := "explicit"

func reset() -> void:
	active.clear()

func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func find_path(origin: Vector2i, goals: Array, occupied: Dictionary) -> Array[Vector2i]:
	var frontier: Array[Vector2i] = [origin]
	var previous := {origin: origin}
	var cursor := 0
	while cursor < frontier.size():
		var cell := frontier[cursor]
		cursor += 1
		if cell in goals:
			var path: Array[Vector2i] = []
			while cell != origin:
				path.push_front(cell)
				cell = previous[cell]
			return path
		for direction in DIRECTIONS:
			var next: Vector2i = cell + direction
			if next.x < 0 or next.x >= 8 or next.y < 0 or next.y >= 4 or previous.has(next) or occupied.has(next):
				continue
			previous[next] = cell
			frontier.append(next)
	return []

func ingest(commands: Array, sim) -> void:
	var groups := {}
	for command in commands:
		if command["type"] != "order":
			continue
		var id: int = command["unit_id"]
		var unit: Dictionary = sim.get_unit(id)
		if unit.is_empty() or unit["owner"] != command["player"]:
			continue
		if not groups.has(id):
			groups[id] = []
		var goal: Dictionary = command["goal"]
		if goal not in groups[id]:
			groups[id].append(goal)
	var ids := groups.keys()
	ids.sort()
	for id in ids:
		if groups[id].size() != 1:
			sim.events.append({"type": "order_rejected", "unit_id": id, "player": sim.get_unit(id)["owner"], "reason": "contradictory"})
			continue
		var goal: Dictionary = groups[id][0].duplicate(true)
		var unit: Dictionary = sim.get_unit(id)
		var valid := true
		match goal["kind"]:
			"hold":
				pass
			"act_at":
				var option: Dictionary = sim.actions.plan(unit, str(goal["action"]), goal["cell"], int(goal.get("target_id", -1)), sim)
				valid = option["enabled"]
			"move_to":
				var cell: Vector2i = goal["cell"]
				valid = cell.x >= 0 and cell.x < 8 and cell.y >= 0 and cell.y < 4
			"attack_target":
				var target: Dictionary = sim.get_target(int(goal["target_id"]))
				valid = not target.is_empty() and target["owner"] != unit["owner"] and int(sim.CARD_STATS[unit["kind"]]["atk"]) > 0
			"stop":
				sim.natural.cancel(id, sim)
				sim.actions.interrupt(id, sim)
				active.erase(id)
				sim.events.append({"type": "order_stopped", "unit_id": id, "player": unit["owner"]})
				continue
			_:
				valid = false
		if not valid:
			sim.events.append({"type": "order_rejected", "unit_id": id, "player": unit["owner"], "reason": "invalid_goal"})
			continue
		if active.has(id) and active[id]["goal"] == goal:
			continue
		sim.actions.interrupt(id, sim)
		sim.natural.cancel(id, sim)
		if goal["kind"] != "hold" and not (goal["kind"] == "act_at" and goal["action"] == "leave"):
			sim.actions.ensure_exit(id, sim)
		active[id] = {"goal": goal, "status": "pending", "path": []}
		sim.events.append({"type": "order_accepted", "unit_id": id, "player": unit["owner"]})

func _status(sim, id: int, value: String, path: Array = []) -> void:
	if active[id]["status"] != value:
		sim.events.append({"type": "order_status", "unit_id": id, "player": sim.get_unit(id)["owner"], "status": value, "source": source})
	active[id]["status"] = value
	active[id]["path"] = path

func produce(sim) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids := active.keys()
	ids.sort()
	var occupied: Dictionary = sim.occupied_cells()
	for id in ids:
		var unit: Dictionary = sim.get_unit(id)
		if unit.is_empty():
			active.erase(id)
			continue
		if sim.actions.active.has(id):
			continue
		var goal: Dictionary = active[id]["goal"]
		var goals: Array = []
		if goal["kind"] == "hold":
			_status(sim, id, "holding")
			if sim.movement.active.has(id):
				continue
			var target_id: int = sim.natural_defense.target_for(unit, sim, false)
			if target_id != -1:
				result.append({"type": "attack", "attacker": id, "defender": target_id, "source": "hold"})
			continue
		if goal["kind"] == "act_at":
			if active[id].get("action_started", false):
				var outcome: Dictionary = sim.actions.outcomes.get(id, {})
				active.erase(id)
				sim.events.append({"type": "order_completed", "unit_id": id, "player": unit["owner"], "reason": "action_finished" if outcome.get("completed", false) else "action_cancelled", "source": source})
				continue
			var option: Dictionary = sim.actions.plan(unit, str(goal["action"]), goal["cell"], int(goal.get("target_id", -1)), sim)
			if not option["enabled"]:
				active.erase(id)
				sim.events.append({"type": "order_completed", "unit_id": id, "player": unit["owner"], "reason": "resource_lost", "source": source})
				continue
			var reached: bool = _distance(unit["cell"], option["cell"]) == 1 if goal["action"] == "demolish" else unit["cell"] == option["cell"]
			if reached and not sim.movement.active.has(id):
				_status(sim, id, "waiting_special")
				if sim.actions.start(unit, str(goal["action"]), sim, int(goal.get("target_id", -1)), source, true):
					active[id]["action_started"] = true
					_status(sim, id, "acting")
				continue
			if goal["action"] == "demolish":
				for direction in DIRECTIONS:
					goals.append(option["cell"] + direction)
			else:
				goals.append(option["cell"])
		elif goal["kind"] == "attack_target":
			var target: Dictionary = sim.get_target(int(goal["target_id"]))
			if target.is_empty():
				active.erase(id)
				sim.events.append({"type": "order_completed", "unit_id": id, "player": unit["owner"], "reason": "target_defeated"})
				continue
			if _distance(unit["cell"], target["cell"]) == 1:
				_status(sim, id, "attacking")
				result.append({"type": "attack", "attacker": id, "defender": target["id"], "source": source})
				continue
			for direction in DIRECTIONS:
				goals.append(target["cell"] + direction)
		else:
			goals.append(goal["cell"])
			if unit["cell"] == goal["cell"] and not sim.movement.active.has(id):
				active.erase(id)
				sim.events.append({"type": "order_completed", "unit_id": id, "player": unit["owner"], "reason": "destination_reached"})
				continue
		if sim.movement.active.has(id):
			_status(sim, id, "moving", active[id]["path"])
			continue
		var route_occupied := occupied
		if source == "natural":
			route_occupied = occupied.duplicate()
			for x in range(8):
				if (0 if x < 4 else 1) != goal["territory_half"]:
					for y in range(4):
						route_occupied[Vector2i(x, y)] = -1
		var path := find_path(unit["cell"], goals, route_occupied)
		if path.is_empty():
			_status(sim, id, "blocked")
			continue
		active[id]["path"] = path
		result.append({"type": "move", "player": unit["owner"], "unit_id": id, "cell": path[0], "source": source})
	return result

func observe_movement(sim, movement_events: Array[Dictionary]) -> void:
	for event in movement_events:
		var id: int = event["unit_id"]
		if active.has(id):
			if event["type"] == "move_rejected":
				_status(sim, id, "blocked", active[id]["path"])
			elif event["type"] == "move_started":
				_status(sim, id, "moving", active[id]["path"])

func cleanup(sim) -> void:
	for id in active.keys():
		if sim.get_unit(id).is_empty():
			active.erase(id)
		elif active[id]["goal"]["kind"] == "attack_target" and sim.get_target(int(active[id]["goal"]["target_id"])).is_empty():
			active.erase(id)
			sim.events.append({"type": "order_completed", "unit_id": id, "player": sim.get_unit(id)["owner"], "reason": "target_defeated"})

func view_for(player: int, units: Array[Dictionary]) -> Dictionary:
	var result := {}
	for unit in units:
		if unit["owner"] == player and active.has(unit["id"]):
			result[unit["id"]] = active[unit["id"]].duplicate(true)
	return result
