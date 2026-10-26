extends RefCounted

## Explicit timed actions, separate from instincts and movement execution.
var active: Dictionary = {}
var prepare_ticks := 6
var cooldown_ticks := 60
var outcomes: Dictionary = {}

func reset() -> void:
	active.clear()
	outcomes.clear()

func interrupt(id: int, sim) -> void:
	if active.has(id):
		outcomes[id] = {"kind": active[id]["kind"], "tick": sim.tick_count, "completed": false, "source": active[id].get("source", "explicit")}
		active.erase(id)
		sim.events.append({"type": "special_cancelled", "unit_id": id})

func ensure_exit(id: int, sim) -> void:
	var unit: Dictionary = sim.get_unit(id)
	if not unit.is_empty() and unit.get("sheltered", false) and not active.has(id):
		active[id] = {"kind": "leave", "cell": unit["cell"], "start_tick": sim.tick_count, "end_tick": sim.tick_count + maxi(1, prepare_ticks), "target_id": -1}
		sim.events.append({"type": "special_started", "unit_id": id, "kind": "leave", "cell": unit["cell"]})

func can_start(unit: Dictionary, kind: String, sim, target_id: int = -1) -> bool:
	if unit.is_empty() or sim.finished or sim.is_preparation_phase() or sim.movement.active.has(unit["id"]) or active.has(unit["id"]):
		return false
	if kind not in ["enter", "leave", "conquer"] and sim.tick_count < int(unit.get("special_ready_tick", 0)):
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
			return unit["kind"] == "horse" and ground == "cornfield" and wounded and not sim.is_section_protected_against(unit["cell"], int(unit["owner"]))
		"charge":
			return unit["kind"] == "boar" and not unit.get("charged", false)
		"demolish":
			var target: Dictionary = sim.cards.get_building(target_id)
			return unit["kind"] == "golem" and not target.is_empty() and sim._can_attack(unit, target)
		"conquer":
			return sim.can_unit_conquer(unit) and sim.get_section_controller(unit["cell"]) != int(unit["owner"]) and not sim.is_section_protected_against(unit["cell"], int(unit["owner"]))
	return false

func plan(unit: Dictionary, kind: String, cell: Vector2i, target_id: int, sim) -> Dictionary:
	var result := {"kind": kind, "cell": cell, "target_id": target_id, "enabled": false, "reason": "Acción incompatible", "ready_in": 0}
	if unit.is_empty() or sim.finished or cell.x < 0 or cell.x >= 8 or cell.y < 0 or cell.y >= 4:
		return result
	var ground: String = sim.terrain.cells.get(cell, "")
	var missing: int = int(sim.CARD_STATS[unit["kind"]]["hp"]) - int(unit["hp"])
	match kind:
		"roll":
			result["enabled"] = unit["kind"] == "pig" and ground == "mud" and missing > 0
			result["reason"] = "Necesita barro y vida perdida"
		"forage":
			result["enabled"] = unit["kind"] == "horse" and ground == "cornfield" and missing > 0 and not sim.is_section_protected_against(cell, int(unit["owner"]))
			result["reason"] = "Necesita maizal y vida perdida"
		"enter":
			result["enabled"] = ground == "cave" and not (cell == unit["cell"] and unit.get("sheltered", false))
			result["reason"] = "Necesita una cueva para entrar"
		"leave":
			result["enabled"] = unit.get("sheltered", false) and cell == unit["cell"]
			result["reason"] = "La criatura no está refugiada"
		"charge":
			result["enabled"] = unit["kind"] == "boar" and cell == unit["cell"] and not unit.get("charged", false)
			result["reason"] = "Embestida ya preparada o especie incompatible"
		"demolish":
			var target: Dictionary = sim.cards.get_building(target_id)
			result["enabled"] = unit["kind"] == "golem" and not target.is_empty() and target["owner"] != unit["owner"]
			result["reason"] = "Elige una construcción rival"
			if not target.is_empty():
				result["cell"] = target["cell"]
		"conquer":
			if sim.is_preparation_phase():
				result["enabled"] = false
				result["reason"] = "No disponible durante la preparación"
			elif not sim.can_unit_conquer(unit):
				result["enabled"] = false
				result["reason"] = "La criatura no puede conquistar"
			elif sim.get_section_controller(cell) == int(unit["owner"]):
				result["enabled"] = false
				result["reason"] = "La sección ya está bajo tu control"
			elif sim.is_section_protected_against(cell, int(unit["owner"])):
				result["enabled"] = false
				result["reason"] = "Sección protegida por defensas activas"
			else:
				result["enabled"] = true
	if kind not in ["enter", "leave", "conquer"]:
		result["ready_in"] = maxi(0, int(unit.get("special_ready_tick", 0)) - sim.tick_count)
	if result["enabled"]:
		result["reason"] = "Disponible" if result["ready_in"] == 0 else "Esperará el cooldown al llegar"
	return result

func start(unit: Dictionary, kind: String, sim, target_id: int = -1, source: String = "explicit", keep_order: bool = false) -> bool:
	if not can_start(unit, kind, sim, target_id):
		return false
	var id: int = unit["id"]
	if not keep_order:
		sim.orders.active.erase(id)
	if kind not in ["enter", "leave", "conquer"]:
		unit["special_ready_tick"] = sim.tick_count + maxi(1, cooldown_ticks)
	outcomes.erase(id)
	var duration: int = maxi(1, sim.territory.conquest_ticks) if kind == "conquer" else maxi(1, prepare_ticks)
	active[id] = {"kind": kind, "cell": unit["cell"], "start_tick": sim.tick_count, "end_tick": sim.tick_count + duration, "target_id": target_id, "source": source}
	sim.events.append({"type": "special_started", "unit_id": id, "kind": kind, "cell": unit["cell"], "source": source, "end_tick": active[id]["end_tick"]})
	return true

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
			sim.events.append({"type": "special_rejected", "unit_id": id, "player": unit["owner"]})
			continue
		var kind: String = groups[id][0]["kind"]
		start(unit, kind, sim, int(groups[id][0]["target_id"]))

func produce_damage(sim) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids := active.keys()
	ids.sort()
	for id in ids:
		var action: Dictionary = active[id]
		if action["kind"] == "demolish" and sim.tick_count >= int(action["end_tick"]):
			result.append({"type": "attack", "attacker": id, "defender": action["target_id"], "demolition": true, "source": action.get("source", "explicit")})
	return result

func advance(sim) -> void:
	var ids := active.keys()
	ids.sort()
	for id in ids:
		var unit: Dictionary = sim.get_unit(id)
		if unit.is_empty():
			active.erase(id)
			outcomes.erase(id)
			continue
		var action: Dictionary = active[id]
		if action["kind"] == "demolish" and sim.cards.get_building(int(action["target_id"])).is_empty() and not action.get("impact_accepted", false):
			interrupt(id, sim)
			continue
		if action["kind"] == "conquer":
			if sim.is_preparation_phase() or sim.movement.active.has(id) or unit["cell"] != action["cell"] or unit.get("sheltered", false) or not sim.can_unit_conquer(unit) or sim.get_section_controller(action["cell"]) == int(unit["owner"]) or sim.is_section_protected_against(action["cell"], int(unit["owner"])):
				interrupt(id, sim)
				continue
		if action["kind"] == "forage" and sim.is_section_protected_against(action["cell"], int(unit["owner"])):
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
				outcomes[id] = {"kind": kind, "tick": sim.tick_count, "completed": false}
				sim.events.append({"type": "special_cancelled", "unit_id": id})
				continue
		elif kind == "charge":
			unit["charged"] = true
		elif kind == "roll" and ground == "mud":
			unit["hp"] = mini(int(sim.CARD_STATS[unit["kind"]]["hp"]), int(unit["hp"]) + 1)
		elif kind == "forage" and ground == "cornfield":
			unit["hp"] = mini(int(sim.CARD_STATS[unit["kind"]]["hp"]), int(unit["hp"]) + 2)
			sim.terrain.cells.erase(unit["cell"])
		elif kind == "conquer":
			var transfer: Dictionary = sim.set_section_controller(unit["cell"], int(unit["owner"]))
			if not transfer["changed"]:
				outcomes[id] = {"kind": kind, "tick": sim.tick_count, "completed": false}
				sim.events.append({"type": "special_cancelled", "unit_id": id})
				continue
			sim.events.append({"type": "section_conquered", "unit_id": id, "player": int(unit["owner"]), "previous_owner": int(transfer["previous_owner"]), "cell": unit["cell"], "footprint_id": int(transfer["footprint_id"])})
		else:
			outcomes[id] = {"kind": kind, "tick": sim.tick_count, "completed": false}
			sim.events.append({"type": "special_cancelled", "unit_id": id})
			continue
		outcomes[id] = {"kind": kind, "tick": sim.tick_count, "completed": true, "source": action.get("source", "explicit")}
		sim.events.append({"type": "special_completed", "unit_id": id, "kind": kind, "cell": unit["cell"], "amount": int(unit["hp"]) - previous_hp, "source": action.get("source", "explicit")})
	for id in outcomes.keys():
		if sim.get_unit(id).is_empty():
			outcomes.erase(id)
