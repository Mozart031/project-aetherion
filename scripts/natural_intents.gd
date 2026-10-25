extends RefCounted

## Bounded, situational species profiles. No core coordinates or economy queries.
const Planner = preload("res://scripts/tactical_orders.gd")
var enabled := false
var radius := 2
var decision_interval := 4
var threat_ticks := 40
var blocked_retry_ticks := 20
var planner := Planner.new()
var claims: Dictionary = {}
var explanations: Dictionary = {}
var threats: Dictionary = {}
var waiting_since: Dictionary = {}
var retry_at: Dictionary = {}
var explicit_this_tick: Dictionary = {}
var previous_world: Dictionary = {}

func _init() -> void:
	planner.source = "natural"

func reset() -> void:
	planner.reset()
	claims.clear()
	explanations.clear()
	threats.clear()
	waiting_since.clear()
	retry_at.clear()
	explicit_this_tick.clear()
	previous_world.clear()

func has_goal(id: int) -> bool:
	return enabled and planner.active.has(id)

func _release(id: int) -> void:
	for cell in claims.keys():
		if claims[cell]["unit_id"] == id:
			claims.erase(cell)

func cancel(id: int, sim, interrupt_action: bool = true) -> void:
	planner.active.erase(id)
	_release(id)
	waiting_since.erase(id)
	retry_at.erase(id)
	if interrupt_action and sim.actions.active.get(id, {}).get("source") == "natural":
		sim.actions.interrupt(id, sim)

func _explain(id: int, reason: String, sim) -> void:
	if explanations.get(id, "") != reason:
		explanations[id] = reason
		sim.events.append({"type": "natural_state", "unit_id": id, "reason": reason})

func ingest(commands: Array, sim) -> void:
	explicit_this_tick.clear()
	var controls := {}
	for command in commands:
		if command["type"] == "ecology":
			var id: int = command["unit_id"]
			var unit: Dictionary = sim.get_unit(id)
			if unit.is_empty() or unit["owner"] != command["player"]:
				continue
			if not controls.has(id):
				controls[id] = {}
			controls[id][command["enabled"]] = true
		elif command["type"] in ["order", "special", "move"]:
			var unit: Dictionary = sim.get_unit(int(command["unit_id"]))
			if not unit.is_empty() and unit["owner"] == command["player"]:
				explicit_this_tick[unit["id"]] = true
		elif command["type"] in ["attack", "core_attack"] and command.get("source", "explicit") == "explicit":
			explicit_this_tick[command["attacker"]] = true
	var ids := controls.keys()
	ids.sort()
	for id in ids:
		if controls[id].size() == 1:
			var value: bool = controls[id].keys()[0]
			sim.get_unit(id)["ecology_enabled"] = value
			explicit_this_tick[id] = true
			sim.events.append({"type": "ecology_changed", "unit_id": id, "enabled": value})
		else:
			sim.events.append({"type": "ecology_rejected", "unit_id": id})
	for id in explicit_this_tick:
		cancel(id, sim)

func record_hit(attacker_id: int, target_id: int, tick: int) -> void:
	if not enabled:
		return
	var old: Dictionary = threats.get(target_id, {})
	if old.is_empty() or int(old["tick"]) < tick or (old["tick"] == tick and attacker_id < int(old["attacker"])):
		threats[target_id] = {"attacker": attacker_id, "tick": tick}

func preferred_target(unit: Dictionary, adjacent: Array[int], tick: int) -> int:
	if enabled and unit.get("ecology_enabled", true) and unit["kind"] == "boar":
		var recent: Dictionary = threats.get(unit["id"], {})
		if not recent.is_empty() and tick - int(recent["tick"]) <= threat_ticks and recent["attacker"] in adjacent:
			return int(recent["attacker"])
	adjacent.sort()
	return adjacent[0] if not adjacent.is_empty() else -1

func _goal(id: int, action: String, cell: Vector2i, target_id: int, sim) -> void:
	planner.active[id] = {"goal": {"kind": "act_at", "action": action, "cell": cell, "target_id": target_id, "territory_half": 0 if sim.get_unit(id)["cell"].x < 4 else 1}, "status": "pending", "path": []}
	_explain(id, {"roll": "Busca barro para recuperarse", "forage": "Busca maíz para recuperarse", "charge": "Prepara embestida ante un rival cercano", "demolish": "Demuele una valla rival cercana"}[action], sim)

func _resource(unit: Dictionary, kind: String, sim) -> Vector2i:
	var origin: Vector2i = unit["cell"]
	var occupied: Dictionary = sim.occupied_cells()
	var half := 0 if origin.x < 4 else 1
	for x in range(8):
		if (0 if x < 4 else 1) != half:
			for y in range(4):
				occupied[Vector2i(x, y)] = -1
	var cells: Array = sim.terrain.cells.keys()
	cells.sort_custom(func(a, b): return a.x < b.x if a.x != b.x else a.y < b.y)
	var best := Vector2i(-1, -1)
	var best_distance := radius + 1
	for cell in cells:
		if sim.terrain.cells[cell] != kind or (0 if cell.x < 4 else 1) != half:
			continue
		if kind == "cornfield" and sim.cards.terrain_owners.get(cell, -1) not in [-1, unit["owner"]]:
			continue
		if claims.has(cell) and claims[cell]["unit_id"] != unit["id"]:
			continue
		if cell != origin and occupied.has(cell):
			continue
		var path: Array[Vector2i] = planner.find_path(origin, [cell], occupied)
		if cell != origin and path.is_empty():
			continue
		if path.size() <= radius and path.size() < best_distance:
			best = cell
			best_distance = path.size()
	return best

func _choose(unit: Dictionary, sim) -> void:
	var id: int = unit["id"]
	var missing: int = int(sim.CARD_STATS[unit["kind"]]["hp"]) - int(unit["hp"])
	var ready: bool = sim.tick_count >= int(unit.get("special_ready_tick", 0))
	if unit["kind"] in ["pig", "horse"] and missing >= (2 if unit["kind"] == "horse" else 1) and ready:
		var resource: String = "mud" if unit["kind"] == "pig" else "cornfield"
		var cell := _resource(unit, resource, sim)
		if cell != Vector2i(-1, -1):
			claims[cell] = {"unit_id": id, "requested_tick": waiting_since.get(id, sim.tick_count)}
			_goal(id, "roll" if resource == "mud" else "forage", cell, -1, sim)
		else:
			_explain(id, "Sin recurso cercano libre; mantiene la posición", sim)
		return
	var adjacent: int = sim.natural_defense.target_for(unit, sim)
	if unit["kind"] == "boar" and adjacent != -1 and sim.actions.can_start(unit, "charge", sim):
		_goal(id, "charge", unit["cell"], -1, sim)
	elif unit["kind"] == "golem" and adjacent == -1:
		var ids: Array[int] = []
		for building in sim.cards.buildings:
			if sim.actions.can_start(unit, "demolish", sim, int(building["id"])):
				ids.append(int(building["id"]))
		ids.sort()
		if not ids.is_empty():
			_goal(id, "demolish", sim.cards.get_building(ids[0])["cell"], ids[0], sim)
		else:
			_explain(id, "Defiende su posición", sim)
	else:
		_explain(id, "Defiende su posición" if adjacent != -1 else "Descansa; no hay motivo para desplazarse", sim)

func produce(sim) -> Array[Dictionary]:
	if not enabled:
		for id in planner.active.keys():
			cancel(id, sim)
		return []
	cleanup(sim)
	# Public ecology state only: deliberately excludes players, cores and private card data.
	var world := {"units": sim.units.duplicate(true), "terrain": sim.terrain.cells.duplicate(true), "buildings": sim.cards.buildings.duplicate(true)}
	var changed := world != previous_world
	previous_world = world
	var ids: Array[int] = []
	for unit in sim.units:
		var id: int = unit["id"]
		if explicit_this_tick.has(id) or sim.orders.active.has(id) or unit.get("sheltered", false) or not unit.get("ecology_enabled", true):
			cancel(id, sim)
			var reason := "Ecología desactivada"
			if sim.orders.active.has(id):
				reason = "Orden del jugador"
			elif unit.get("sheltered", false):
				reason = "Refugio del jugador"
			elif explicit_this_tick.has(id):
				reason = "Intervención del jugador"
			_explain(id, reason, sim)
			continue
		if planner.active.has(id):
			var goal: Dictionary = planner.active[id]["goal"]
			var lost: bool = not sim.actions.plan(unit, goal["action"], goal["cell"], goal.get("target_id", -1), sim)["enabled"]
			if not planner.active[id].get("action_started", false) and lost:
				cancel(id, sim, false)
				_explain(id, "Oportunidad perdida; termina el paso comprometido", sim)
			elif planner.active[id]["status"] == "blocked" and not sim.movement.active.has(id):
				cancel(id, sim, false)
				retry_at[id] = sim.tick_count + maxi(1, blocked_retry_ticks)
				_explain(id, "Recurso ocupado; espera sin insistir", sim)
			continue
		if sim.actions.active.has(id) or sim.movement.active.has(id):
			continue
		if sim.tick_count < int(retry_at.get(id, 0)):
			continue
		if changed or sim.tick_count % maxi(1, decision_interval) == 0:
			var missing: int = int(sim.CARD_STATS[unit["kind"]]["hp"]) - int(unit["hp"])
			var requests_resource: bool = (unit["kind"] == "pig" and missing >= 1) or (unit["kind"] == "horse" and missing >= 2)
			if not requests_resource:
				waiting_since.erase(id)
			elif not waiting_since.has(id):
				waiting_since[id] = sim.tick_count
			ids.append(id)
	ids.sort_custom(func(a, b): return waiting_since.get(a, sim.tick_count) < waiting_since.get(b, sim.tick_count) if waiting_since.get(a, sim.tick_count) != waiting_since.get(b, sim.tick_count) else a < b)
	for id in ids:
		_choose(sim.get_unit(id), sim)
	var result := planner.produce(sim)
	for cell in claims.keys():
		if not planner.active.has(claims[cell]["unit_id"]):
			claims.erase(cell)
	return result

func cleanup(sim) -> void:
	planner.cleanup(sim)
	var live := {}
	for unit in sim.units:
		live[unit["id"]] = true
	for cell in claims.keys():
		if not live.has(claims[cell]["unit_id"]) or not planner.active.has(claims[cell]["unit_id"]):
			claims.erase(cell)
	for dictionary in [explanations, threats, waiting_since, retry_at]:
		for id in dictionary.keys():
			if not live.has(id):
				dictionary.erase(id)

func view_for(player: int, units: Array[Dictionary]) -> Dictionary:
	var result := {}
	if enabled:
		for unit in units:
			if unit["owner"] == player:
				result[unit["id"]] = {"enabled": unit.get("ecology_enabled", true), "reason": explanations.get(unit["id"], "Observa el entorno"), "goal": planner.active.get(unit["id"], {}).duplicate(true)}
	return result
