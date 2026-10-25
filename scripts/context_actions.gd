extends RefCounted

## Explicit timed actions, separate from instincts and movement execution.
var active: Dictionary = {}
var prepare_ticks := 6
var cooldown_ticks := 60

func reset() -> void:
	active.clear()

func interrupt(id: int, sim) -> void:
	if active.has(id):
		active.erase(id)
		sim.events.append({"type": "special_cancelled", "unit_id": id})

func ensure_exit(id: int, sim) -> void:
	var unit: Dictionary = sim.get_unit(id)
	if not unit.is_empty() and unit.get("sheltered", false) and not active.has(id):
		active[id] = {"kind": "leave", "cell": unit["cell"], "start_tick": sim.tick_count, "end_tick": sim.tick_count + maxi(1, prepare_ticks), "target_id": -1}
		sim.events.append({"type": "special_started", "unit_id": id, "kind": "leave", "cell": unit["cell"]})

func can_start(unit: Dictionary, kind: String, sim, target_id: int = -1) -> bool:
	if unit.is_empty() or sim.finished or sim.movement.active.has(unit["id"]) or active.has(unit["id"]):
		return false
	if kind not in ["enter", "leave"] and sim.tick_count < int(unit.get("special_ready_tick", 0)):
		return false
	var ground: String = sim.terrain.cells.get(unit["cell"], "")
	var wounded := int(unit["hp"]) < int(sim.CARD_STATS[unit["kind"]]["hp"])
	if kind == "leave":
		return unit.get("sheltered", false)
	if unit.get("sheltered", false):
		return false
	match kind:
		"enter":
			return ground == "cave"
		"roll":
			return unit["kind"] == "pig" and ground == "mud" and wounded
		"forage":
			return unit["kind"] == "horse" and ground == "cornfield" and wounded
		"charge":
			return unit["kind"] == "boar" and not unit.get("charged", false)
		"demolish":
			var target: Dictionary = sim.cards.get_building(target_id)
			return unit["kind"] == "golem" and not target.is_empty() and sim._can_attack(unit, target)
	return false

func ingest(commands: Array, sim) -> void:
	var groups := {}
	for command in commands:
		if command["type"] != "special":
			continue
		var id: int = command["unit_id"]
		var unit: Dictionary = sim.get_unit(id)
		if unit.is_empty() or unit["owner"] != command["player"]:
			continue
		if not groups.has(id):
			groups[id] = []
		var choice := {"kind": command["kind"], "target_id": command.get("target_id", -1)}
		if choice not in groups[id]:
			groups[id].append(choice)
	var ids := groups.keys()
	ids.sort()
	for id in ids:
		var unit: Dictionary = sim.get_unit(id)
		if groups[id].size() != 1 or not can_start(unit, str(groups[id][0]["kind"]), sim, int(groups[id][0]["target_id"])):
			sim.events.append({"type": "special_rejected", "unit_id": id})
			continue
		var kind: String = groups[id][0]["kind"]
		sim.orders.active.erase(id)
		if kind not in ["enter", "leave"]:
			unit["special_ready_tick"] = sim.tick_count + maxi(1, cooldown_ticks)
		active[id] = {"kind": kind, "cell": unit["cell"], "start_tick": sim.tick_count, "end_tick": sim.tick_count + maxi(1, prepare_ticks), "target_id": groups[id][0]["target_id"]}
		sim.events.append({"type": "special_started", "unit_id": id, "kind": kind, "cell": unit["cell"]})

func produce_damage(sim) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids := active.keys()
	ids.sort()
	for id in ids:
		var action: Dictionary = active[id]
		if action["kind"] == "demolish" and sim.tick_count >= int(action["end_tick"]):
			result.append({"type": "attack", "attacker": id, "defender": action["target_id"], "demolition": true})
	return result

func advance(sim) -> void:
	var ids := active.keys()
	ids.sort()
	for id in ids:
		var unit: Dictionary = sim.get_unit(id)
		if unit.is_empty():
			active.erase(id)
			continue
		var action: Dictionary = active[id]
		if action["kind"] == "demolish" and sim.cards.get_building(int(action["target_id"])).is_empty() and not action.get("impact_accepted", false):
			interrupt(id, sim)
			continue
		if sim.tick_count < int(action["end_tick"]):
			continue
		active.erase(id)
		var ground: String = sim.terrain.cells.get(unit["cell"], "")
		var previous_hp: int = unit["hp"]
		var kind: String = action["kind"]
		if kind == "enter" and ground == "cave":
			unit["sheltered"] = true
		elif kind == "leave":
			unit["sheltered"] = false
		elif kind == "demolish":
			if not action.get("impact_accepted", false):
				sim.events.append({"type": "special_cancelled", "unit_id": id})
				continue
		elif kind == "charge":
			unit["charged"] = true
		elif kind == "roll" and ground == "mud":
			unit["hp"] = mini(int(sim.CARD_STATS[unit["kind"]]["hp"]), int(unit["hp"]) + 1)
		elif kind == "forage" and ground == "cornfield":
			unit["hp"] = mini(int(sim.CARD_STATS[unit["kind"]]["hp"]), int(unit["hp"]) + 2)
			sim.terrain.cells.erase(unit["cell"])
		else:
			sim.events.append({"type": "special_cancelled", "unit_id": id})
			continue
		sim.events.append({"type": "special_completed", "unit_id": id, "kind": kind, "cell": unit["cell"], "amount": int(unit["hp"]) - previous_hp})
