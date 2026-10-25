extends RefCounted

## Provisional adjacent defense, separate from explicit goals and species skills.
var enabled := false

func produce(sim, commands: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not enabled:
		return result
	var explicit_units := {}
	for command in commands:
		if command["type"] in ["order", "move"]:
			var unit: Dictionary = sim.get_unit(int(command["unit_id"]))
			if not unit.is_empty() and unit["owner"] == command["player"]:
				explicit_units[command["unit_id"]] = true
		elif command["type"] in ["attack", "core_attack"]:
			explicit_units[command["attacker"]] = true
	for unit in sim.units:
		var id: int = unit["id"]
		if sim.orders.active.has(id) or sim.movement.active.has(id) or explicit_units.has(id):
			continue
		if int(sim.CARD_STATS[unit["kind"]]["atk"]) <= 0:
			continue
		var target_id := -1
		for other in sim.units:
			var delta: Vector2i = other["cell"] - unit["cell"]
			if other["owner"] != unit["owner"] and absi(delta.x) + absi(delta.y) == 1:
				if target_id == -1 or int(other["id"]) < target_id:
					target_id = int(other["id"])
		if target_id != -1:
			result.append({"type": "attack", "attacker": id, "defender": target_id})
	return result
