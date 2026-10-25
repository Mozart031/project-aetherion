extends RefCounted

const Catalog = preload("res://scripts/battle_catalog.gd")
var copies_per_species := 3
var construction_recovery_ticks := 120
var copies: Array[Dictionary] = []
var terrain_owners: Dictionary = {}
var buildings: Array[Dictionary] = []
var next_building_id := 1000000

func reset(kinds: Array) -> void:
	copies = [{}, {}]
	for player in range(2):
		for kind in kinds:
			copies[player][kind] = []
			for index in range(maxi(1, copies_per_species)):
				copies[player][kind].append({"copy_id": index, "unit_id": -1, "ready_tick": 0})
	terrain_owners.clear()
	buildings.clear()
	next_building_id = 1000000

func free_copy(player: int, kind: String, tick: int) -> int:
	for copy in copies[player].get(kind, []):
		if int(copy["unit_id"]) == -1 and tick >= int(copy["ready_tick"]):
			return int(copy["copy_id"])
	return -1

func defeated(unit: Dictionary, ready_tick: int) -> void:
	var copy_id: int = unit.get("copy_id", -1)
	if copy_id >= 0:
		var copy: Dictionary = copies[int(unit["owner"])][unit["kind"]][copy_id]
		copy["unit_id"] = -1
		copy["ready_tick"] = ready_tick

func get_building(id: int) -> Dictionary:
	for building in buildings:
		if int(building["id"]) == id:
			return building
	return {}

func building_at(cell: Vector2i) -> Dictionary:
	for building in buildings:
		if building["cell"] == cell:
			return building
	return {}

func state(player: int, kind: String, sim) -> Dictionary:
	if player not in [0, 1] or not Catalog.CARDS.has(kind):
		return {"available": 0, "active": 0, "recovering": 0, "ready_tick": 0}
	var result := {"available": 0, "active": 0, "recovering": 0, "ready_tick": 0}
	var category: String = Catalog.CARDS[kind]["category"]
	if category == "creature":
		for copy in copies[player][kind]:
			if int(copy["unit_id"]) != -1:
				result["active"] += 1
			elif int(copy["ready_tick"]) > sim.tick_count:
				result["recovering"] += 1
				if result["ready_tick"] == 0 or int(copy["ready_tick"]) < int(result["ready_tick"]):
					result["ready_tick"] = copy["ready_tick"]
			else:
				result["available"] += 1
	elif category == "terrain":
		for cell in terrain_owners:
			if terrain_owners[cell] == player and sim.terrain.cells.get(cell, "") == kind:
				result["active"] += 1
		result["available"] = 1 if result["active"] == 0 else 0
	elif category == "construction":
		for building in buildings:
			if building["owner"] == player:
				result["active"] += 1
		for recovery in sim.players[player]["recovering"].values():
			if recovery["kind"] == "fence":
				result["recovering"] += 1
				result["ready_tick"] = recovery["ready_tick"]
		result["available"] = 1 if result["active"] == 0 and result["recovering"] == 0 else 0
	else:
		result["available"] = 1 # Reusable by paying essence, not combat recovery.
	return result

func _reject(sim, command: Dictionary, reason: String) -> void:
	sim.events.append({"type": "card_rejected", "player": command["player"], "card": command["card"], "reason": reason})

func play(command: Dictionary, sim, commands: Array) -> void:
	var player: int = command["player"]
	var kind: String = command["card"]
	var cell: Vector2i = command["cell"]
	if player not in [0, 1] or not Catalog.CARDS.has(kind):
		_reject(sim, command, "invalid_card")
		return
	var data: Dictionary = Catalog.CARDS[kind]
	if sim.players[player]["essence"] < data["cost"] or state(player, kind, sim)["available"] == 0:
		_reject(sim, command, "unavailable")
		return
	var category: String = data["category"]
	if category == "trick":
		var target: Dictionary = sim.get_unit(int(command["target_id"]))
		if target.is_empty() or target["owner"] != player or target["hp"] >= sim.CARD_STATS[target["kind"]]["hp"]:
			_reject(sim, command, "invalid_target")
			return
		var previous_hp: int = target["hp"]
		target["hp"] = mini(int(sim.CARD_STATS[target["kind"]]["hp"]), int(target["hp"]) + 2)
		sim.players[player]["essence"] -= int(data["cost"])
		sim.events.append({"type": "healed", "unit_id": target["id"], "cell": target["cell"], "amount": int(target["hp"]) - previous_hp})
	elif not sim.owns_cell(player, cell):
		_reject(sim, command, "own_territory_required")
		return
	elif category == "creature":
		var before: int = sim.next_unit_id
		sim._apply_summon({"player": player, "kind": kind, "cell": cell})
		if sim.next_unit_id == before:
			_reject(sim, command, "occupied")
			return
	elif category == "terrain":
		for unit in sim.units:
			if unit["cell"] == cell and unit.get("sheltered", false):
				_reject(sim, command, "refuge_occupied")
				return
		if sim.terrain.cells.get(cell, "") == kind or (sim.terrain.cells.has(cell) and sim.cell_under_attack(cell, commands)):
			_reject(sim, command, "terrain_locked_or_same")
			return
		# Normal replacement returns the previous terrain card immediately.
		sim.terrain.cells[cell] = kind
		terrain_owners[cell] = player
		sim.players[player]["essence"] -= int(data["cost"])
	elif category == "construction":
		if sim.occupied_cells().has(cell):
			_reject(sim, command, "occupied")
			return
		buildings.append({"id": next_building_id, "kind": "fence", "owner": player, "cell": cell, "hp": 4, "max_hp": 4})
		next_building_id += 1
		sim.players[player]["essence"] -= int(data["cost"])
	sim.events.append({"type": "card_played", "player": player, "card": kind, "cell": cell})

func apply_damage(damage: Dictionary, sim) -> void:
	var survivors: Array[Dictionary] = []
	for building in buildings:
		var amount: int = damage.get(building["id"], 0)
		building["hp"] -= amount
		if amount > 0:
			sim.events.append({"type": "building_damaged", "unit_id": building["id"], "amount": amount, "cell": building["cell"]})
		if building["hp"] <= 0:
			sim.players[int(building["owner"])]["recovering"][building["id"]] = {"kind": "fence", "ready_tick": sim.tick_count + maxi(1, construction_recovery_ticks)}
			sim.events.append({"type": "building_defeated", "unit_id": building["id"], "cell": building["cell"]})
		else:
			survivors.append(building)
	buildings = survivors
