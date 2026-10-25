extends RefCounted
class_name AetherionSimulation

## Deterministic rules scaffold. One step equals 1/20 second.
## No networking, autonomous AI or terrain effects yet.
const Movement = preload("res://scripts/movement.gd")
const TacticalOrders = preload("res://scripts/tactical_orders.gd")
const WIDTH := 8
const HEIGHT := 4
const TICK_RATE := 20
const TICK_SECONDS := 1.0 / 20.0
const MAX_ESSENCE := 8
const ESSENCE_REGEN_TICKS := 60
const CORE_MAX_HP := 12
const MATCH_LIMIT_TICKS := 12000
const CARD_STATS := {
	"boar": {"hp": 3, "atk": 3, "armor": 1, "interval": 36, "cost": 3, "recovery": 240},
	"turtle": {"hp": 5, "atk": 1, "armor": 2, "interval": 44, "cost": 3, "recovery": 240},
	"beaver": {"hp": 4, "atk": 1, "armor": 1, "interval": 40, "cost": 2, "recovery": 160},
	"golem": {"hp": 6, "atk": 4, "armor": 2, "interval": 56, "cost": 4, "recovery": 320},
	"rhino": {"hp": 6, "atk": 3, "armor": 1, "interval": 48, "cost": 5, "recovery": 320},
	"pigeon": {"hp": 2, "atk": 0, "armor": 0, "interval": 40, "cost": 1, "recovery": 160}
}

var tick_count := 0
var players: Array[Dictionary] = []
var units: Array[Dictionary] = []
var queued_commands: Array[Dictionary] = []
var events: Array[Dictionary] = []
var next_unit_id := 1
var finished := false
var winner := -1
var movement := Movement.new()
var move_duration_ticks := 6
var orders := TacticalOrders.new()

func _init() -> void:
	reset()

func reset() -> void:
	tick_count = 0
	next_unit_id = 1
	finished = false
	winner = -1
	units.clear()
	queued_commands.clear()
	events.clear()
	movement.reset()
	orders.reset()
	players = [
		{"essence": 4, "core_hp": CORE_MAX_HP, "core_cell": Vector2i(1, 1), "core_known_to": [true, false], "recovering": {}},
		{"essence": 4, "core_hp": CORE_MAX_HP, "core_cell": Vector2i(6, 2), "core_known_to": [false, true], "recovering": {}}
	]

func owns_cell(player: int, cell: Vector2i) -> bool:
	if player < 0 or player > 1 or cell.y < 0 or cell.y >= HEIGHT:
		return false
	return cell.x >= player * 4 and cell.x < player * 4 + 4

func place_core(player: int, cell: Vector2i) -> bool:
	if tick_count != 0 or not owns_cell(player, cell):
		return false
	players[player]["core_cell"] = cell
	return true

func queue_summon(player: int, kind: String, cell: Vector2i) -> void:
	queued_commands.append({"type": "summon", "player": player, "kind": kind, "cell": cell})

func queue_attack(attacker_id: int, defender_id: int) -> void:
	queued_commands.append({"type": "attack", "attacker": attacker_id, "defender": defender_id})

func queue_move(player: int, unit_id: int, destination: Vector2i) -> void:
	if not finished:
		queued_commands.append({"type": "move", "player": player, "unit_id": unit_id, "cell": destination})

func queue_destination(player: int, unit_id: int, destination: Vector2i) -> void:
	_queue_order(player, unit_id, {"kind": "move_to", "cell": destination})

func queue_target(player: int, unit_id: int, target_id: int) -> void:
	_queue_order(player, unit_id, {"kind": "attack_target", "target_id": target_id})

func queue_stop(player: int, unit_id: int) -> void:
	_queue_order(player, unit_id, {"kind": "stop"})

func _queue_order(player: int, unit_id: int, goal: Dictionary) -> void:
	if not finished:
		queued_commands.append({"type": "order", "player": player, "unit_id": unit_id, "goal": goal})

func can_move(player: int, unit_id: int, destination: Vector2i) -> bool:
	return not finished and movement.can_move(get_unit(unit_id), player, destination, movement.occupied_cells(units), movement.active)

func get_motion(unit_id: int) -> Dictionary:
	return movement.active.get(unit_id, {}).duplicate(true)

func get_player_view(observer: int) -> Dictionary:
	if observer not in [0, 1]:
		return {}
	var visible_players := players.duplicate(true)
	for player in visible_players:
		if not player["core_known_to"][observer]:
			player.erase("core_cell")
		player.erase("core_known_to")
	return {"tick": tick_count, "players": visible_players, "units": units.duplicate(true), "motions": movement.active.duplicate(true), "orders": orders.view_for(observer, units), "events": events.duplicate(true), "finished": finished, "winner": winner}

func queue_core_attack(attacker_id: int, defending_player: int) -> void:
	queued_commands.append({"type": "core_attack", "attacker": attacker_id, "defender": defending_player})

func get_unit(unit_id: int) -> Dictionary:
	for unit in units:
		if unit["id"] == unit_id:
			return unit
	return {}

func step() -> void:
	if finished:
		return
	tick_count += 1
	events.clear()
	if tick_count % ESSENCE_REGEN_TICKS == 0:
		for player in players:
			player["essence"] = mini(MAX_ESSENCE, int(player["essence"]) + 1)
	for player in players:
		var recovering: Dictionary = player["recovering"]
		for kind in recovering.keys():
			if tick_count >= int(recovering[kind]):
				recovering.erase(kind)

	# First accept summons, then evaluate attacks against the same pre-damage state.
	var commands := queued_commands.duplicate(true)
	queued_commands.clear()
	for command in commands:
		if command["type"] == "summon":
			_apply_summon(command)
	orders.ingest(commands, self)
	commands.append_array(orders.produce(self))
	# Snapshot before damage/arrivals: no swaps, chains or arrival-tick redirection.
	var occupied := movement.occupied_cells(units)
	var busy := movement.active.duplicate(true)

	var unit_damage: Dictionary = {}
	var core_damage := [0, 0]
	for command in commands:
		match command["type"]:
			"attack":
				var attacker := get_unit(int(command["attacker"]))
				var defender := get_unit(int(command["defender"]))
				if _can_attack(attacker, defender):
					var atk: int = int(CARD_STATS[attacker["kind"]]["atk"])
					var armor: int = int(CARD_STATS[defender["kind"]]["armor"])
					unit_damage[defender["id"]] = int(unit_damage.get(defender["id"], 0)) + maxi(1, atk - armor)
					attacker["ready_tick"] = tick_count + int(CARD_STATS[attacker["kind"]]["interval"])
			"core_attack":
				var attacker := get_unit(int(command["attacker"]))
				var defending_player: int = int(command["defender"])
				if not attacker.is_empty() and defending_player in [0, 1]:
					# Reject hidden-core attacks before any coordinate-dependent check.
					if not players[defending_player]["core_known_to"][int(attacker["owner"])]:
						continue
					if attacker["owner"] != defending_player and attacker["cell"] == players[defending_player]["core_cell"] and tick_count >= int(attacker["ready_tick"]):
						var atk: int = int(CARD_STATS[attacker["kind"]]["atk"])
						if atk > 0:
							core_damage[defending_player] += atk
							attacker["ready_tick"] = tick_count + int(CARD_STATS[attacker["kind"]]["interval"])

	for unit in units:
		unit["hp"] = int(unit["hp"]) - int(unit_damage.get(unit["id"], 0))
	for i in range(2):
		players[i]["core_hp"] = maxi(0, int(players[i]["core_hp"]) - core_damage[i])

	var survivors: Array[Dictionary] = []
	for unit in units:
		if int(unit["hp"]) <= 0:
			var owner: int = int(unit["owner"])
			var kind: String = str(unit["kind"])
			players[owner]["recovering"][kind] = tick_count + int(CARD_STATS[kind]["recovery"])
			events.append({"type": "defeated", "unit_id": unit["id"], "kind": kind})
		else:
			survivors.append(unit)
	units = survivors
	orders.cleanup(self)
	# Accepted attacks use the origin and apply damage before any arrival.
	events.append_array(movement.advance(units, tick_count))
	_check_end()
	if finished:
		movement.reset()
		orders.reset()
	else:
		events.append_array(movement.resolve(commands, units, tick_count, move_duration_ticks, occupied, busy))

func _apply_summon(command: Dictionary) -> void:
	var player: int = int(command["player"])
	var kind: String = str(command["kind"])
	var cell: Vector2i = command["cell"]
	if player not in [0, 1] or not CARD_STATS.has(kind) or not owns_cell(player, cell):
		return
	var stats: Dictionary = CARD_STATS[kind]
	if int(players[player]["essence"]) < int(stats["cost"]) or players[player]["recovering"].has(kind):
		return
	if movement.reservations.has(cell):
		return
	for unit in units:
		if unit["cell"] == cell:
			return
	players[player]["essence"] -= int(stats["cost"])
	units.append({"id": next_unit_id, "owner": player, "kind": kind, "cell": cell, "hp": stats["hp"], "ready_tick": tick_count})
	events.append({"type": "summoned", "unit_id": next_unit_id, "kind": kind, "owner": player})
	next_unit_id += 1

func _can_attack(attacker: Dictionary, defender: Dictionary) -> bool:
	if attacker.is_empty() or defender.is_empty() or attacker["owner"] == defender["owner"]:
		return false
	if tick_count < int(attacker["ready_tick"]) or int(CARD_STATS[attacker["kind"]]["atk"]) <= 0:
		return false
	var a: Vector2i = attacker["cell"]
	var b: Vector2i = defender["cell"]
	return absi(a.x - b.x) + absi(a.y - b.y) == 1

func _check_end() -> void:
	var a: int = int(players[0]["core_hp"])
	var b: int = int(players[1]["core_hp"])
	if a == 0 or b == 0 or tick_count >= MATCH_LIMIT_TICKS:
		finished = true
		winner = 0 if a > b else (1 if b > a else -1)
		events.append({"type": "match_end", "winner": winner})
