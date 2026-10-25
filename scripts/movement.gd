extends RefCounted

## Deterministic execution of single-step intents, not behavior or path planning.
var active: Dictionary = {}
var reservations: Dictionary = {}

func reset() -> void:
	active.clear()
	reservations.clear()

func occupied_cells(units: Array[Dictionary]) -> Dictionary:
	var occupied := reservations.duplicate()
	for unit in units:
		occupied[unit["cell"]] = unit["id"]
	return occupied

func can_move(unit: Dictionary, player: int, destination: Vector2i, occupied: Dictionary, busy: Dictionary) -> bool:
	if unit.is_empty() or player not in [0, 1] or unit["owner"] != player:
		return false
	if destination.x < 0 or destination.x >= 8 or destination.y < 0 or destination.y >= 4:
		return false
	var origin: Vector2i = unit["cell"]
	return not busy.has(unit["id"]) and not occupied.has(destination) and absi(origin.x - destination.x) + absi(origin.y - destination.y) == 1

func advance(units: Array[Dictionary], tick: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var live := {}
	for unit in units:
		live[unit["id"]] = unit
	var ids := active.keys()
	ids.sort()
	for id in ids:
		var motion: Dictionary = active[id]
		if not live.has(id) or tick >= int(motion["end_tick"]):
			reservations.erase(motion["to"])
			active.erase(id)
			if live.has(id):
				live[id]["cell"] = motion["to"]
				result.append({"type": "move_arrived", "unit_id": id})
	return result

func resolve(commands: Array, units: Array[Dictionary], tick: int, duration: int, occupied: Dictionary, busy: Dictionary, durations: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var live := {}
	for unit in units:
		live[unit["id"]] = unit
	var intents := {}
	for command in commands:
		if command["type"] != "move":
			continue
		var id: int = command["unit_id"]
		# Foreign or stale commands cannot poison the owner's valid intention.
		if not live.has(id) or live[id]["owner"] != command["player"]:
			continue
		if not intents.has(id):
			intents[id] = {}
		intents[id][command["cell"]] = true
	var candidates := {}
	var destination_counts := {}
	var ids := intents.keys()
	ids.sort()
	for id in ids:
		if intents[id].size() != 1:
			continue
		var destination: Vector2i = intents[id].keys()[0]
		if can_move(live[id], int(live[id]["owner"]), destination, occupied, busy):
			candidates[id] = destination
			destination_counts[destination] = int(destination_counts.get(destination, 0)) + 1
	for id in ids:
		if candidates.has(id) and destination_counts[candidates[id]] == 1:
			var destination: Vector2i = candidates[id]
			active[id] = {"from": live[id]["cell"], "to": destination, "start_tick": tick, "end_tick": tick + maxi(1, int(durations.get(destination, duration)))}
			reservations[destination] = id
			result.append({"type": "move_started", "unit_id": id})
		else:
			result.append({"type": "move_rejected", "unit_id": id})
	return result
