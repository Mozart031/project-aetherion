extends RefCounted
class_name AetherionSimulation

## Deterministic rules scaffold. One step equals 1/20 second.
## Local deterministic prototype; explicit orders and optional adjacent defense.
const Movement = preload("res://scripts/movement.gd")
const TacticalOrders = preload("res://scripts/tactical_orders.gd")
const NaturalDefense = preload("res://scripts/natural_defense.gd")
const TerrainEffects = preload("res://scripts/terrain_effects.gd")
const ContextActions = preload("res://scripts/context_actions.gd")
const BattleCards = preload("res://scripts/battle_cards.gd")
const NaturalIntents = preload("res://scripts/natural_intents.gd")
const MatchLoadout = preload("res://scripts/match_loadout.gd")
const WIDTH := 8
const HEIGHT := 4
const TICK_RATE := 20
const TICK_SECONDS := 1.0 / 20.0
const MAX_ESSENCE := 8
const ESSENCE_REGEN_TICKS := 60
const CORE_MAX_HP := 12
const MATCH_LIMIT_TICKS := 12000
const CARD_STATS := {
	"pig": {"hp": 4, "atk": 1, "armor": 0, "interval": 40, "cost": 2, "recovery": 240},
	"horse": {"hp": 4, "atk": 2, "armor": 0, "interval": 40, "cost": 3, "recovery": 240},
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
var natural_defense := NaturalDefense.new()
var terrain := TerrainEffects.new()
var actions := ContextActions.new()
var cards := BattleCards.new()
var natural := NaturalIntents.new()
var loadouts := [MatchLoadout.new(), MatchLoadout.new()]

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
	terrain.reset()
	actions.reset()
	natural.reset()
	players = [
		{"essence": 4, "core_hp": CORE_MAX_HP, "core_cell": Vector2i(1, 1), "core_known_to": [true, false], "recovering": {}},
		{"essence": 4, "core_hp": CORE_MAX_HP, "core_cell": Vector2i(6, 2), "core_known_to": [false, true], "recovering": {}}
	]
	cards.reset(CARD_STATS.keys())

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

func place_terrain(cell: Vector2i, kind: String) -> bool:
	return tick_count == 0 and terrain.place(cell, kind)

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

func queue_hold(player: int, unit_id: int) -> void:
	_queue_order(player, unit_id, {"kind": "hold"})

func queue_act_at(player: int, unit_id: int, action: String, cell: Vector2i, target_id: int = -1) -> void:
	_queue_order(player, unit_id, {"kind": "act_at", "action": action, "cell": cell, "target_id": target_id})

func queue_ecology(player: int, unit_id: int, value: bool) -> void:
	if not finished:
		queued_commands.append({"type": "ecology", "player": player, "unit_id": unit_id, "enabled": value})

func get_context_actions(player: int, unit_id: int, cell: Vector2i, target_id: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var unit := get_unit(unit_id)
	if unit.is_empty() or unit["owner"] != player:
		return result
	var labels := {"roll": "Ir a revolcarse", "forage": "Ir a comer", "enter": "Ir al refugio", "leave": "Salir del refugio", "charge": "Preparar embestida", "demolish": "Ir a demoler"}
	var species_action: String = {"pig": "roll", "horse": "forage", "boar": "charge", "golem": "demolish"}.get(unit["kind"], "")
	var choices: Array = [species_action, "leave" if unit.get("sheltered", false) and cell == unit["cell"] else "enter"]
	for kind in choices:
		if kind.is_empty():
			continue
		var option := actions.plan(unit, kind, cell, target_id, self)
		option["label"] = labels[kind]
		option["immediate"] = option["enabled"] and actions.can_start(unit, kind, self, target_id) and (cell == unit["cell"] or kind == "demolish")
		result.append(option)
	return result

func queue_special(player: int, unit_id: int, kind: String, target_id: int = -1) -> void:
	if not finished:
		queued_commands.append({"type": "special", "player": player, "unit_id": unit_id, "kind": kind, "target_id": target_id})

func configure_loadout(player: int, equipped: Dictionary) -> bool:
	return tick_count == 0 and player in [0, 1] and loadouts[player].configure(equipped)

func get_card_placement(player: int, card: String, cell: Vector2i, target_id: int = -1) -> Dictionary:
	return cards.validate_play({"player": player, "card": card, "cell": cell, "target_id": target_id}, self, queued_commands)

func queue_play_card(player: int, card: String, cell: Vector2i, target_id: int = -1, request_id: int = -1) -> void:
	if not finished:
		var command := {"type": "play_card", "player": player, "card": card, "cell": cell, "target_id": target_id}
		if request_id >= 0:
			command["request_id"] = request_id
		queued_commands.append(command)

func occupied_cells() -> Dictionary:
	var result := movement.occupied_cells(units)
	for building in cards.buildings:
		result[building["cell"]] = building["id"]
	return result

func get_target(id: int) -> Dictionary:
	var unit := get_unit(id)
	return cards.get_building(id) if unit.is_empty() else unit

func cell_under_attack(cell: Vector2i, commands: Array) -> bool:
	var targets: Array[Dictionary] = []
	for unit in units:
		if unit["cell"] == cell:
			targets.append(unit)
	var building := cards.building_at(cell)
	if not building.is_empty():
		targets.append(building)
	for target in targets:
		for attacker in units:
			var preparation: Dictionary = actions.active.get(attacker["id"], {})
			if preparation.get("kind") == "demolish" and int(preparation["end_tick"]) <= tick_count and preparation["target_id"] == target["id"] and _can_attack(attacker, target, true):
				return true
			if not _can_attack(attacker, target):
				continue
			var goal: Dictionary = orders.active.get(attacker["id"], {}).get("goal", {})
			if goal.get("kind") == "attack_target" and goal.get("target_id") == target["id"]:
				return true
			if goal.get("kind") == "hold" and not movement.active.has(attacker["id"]) and natural_defense.target_for(attacker, self, false) == target["id"]:
				return true
			for reaction in natural_defense.produce(self, commands):
				if reaction["attacker"] == attacker["id"] and reaction["defender"] == target["id"]:
					return true
			for command in commands:
				if command["type"] == "attack" and command["attacker"] == attacker["id"] and command["defender"] == target["id"]:
					return true
				if command["type"] == "order" and command["player"] == attacker["owner"] and command["unit_id"] == attacker["id"] and command["goal"].get("target_id") == target["id"]:
					return true
				if command["type"] == "order" and command["player"] == attacker["owner"] and command["unit_id"] == attacker["id"] and command["goal"].get("kind") == "hold" and not movement.active.has(attacker["id"]) and natural_defense.target_for(attacker, self, false) == target["id"]:
					return true
	return false

func _queue_order(player: int, unit_id: int, goal: Dictionary) -> void:
	if not finished:
		queued_commands.append({"type": "order", "player": player, "unit_id": unit_id, "goal": goal})

func can_move(player: int, unit_id: int, destination: Vector2i) -> bool:
	return not finished and not actions.active.has(unit_id) and not get_unit(unit_id).get("sheltered", false) and movement.can_move(get_unit(unit_id), player, destination, occupied_cells(), movement.active)

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
	var card_states := {}
	for kind in BattleCards.Catalog.CARDS:
		card_states[kind] = cards.state(observer, kind, self)
	var observed_events := events.filter(func(event): return event["type"] != "card_result" or event["player"] == observer)
	return {"tick": tick_count, "players": visible_players, "units": units.duplicate(true), "buildings": cards.buildings.duplicate(true), "cards": card_states, "loadout": loadouts[observer].snapshot(), "motions": movement.active.duplicate(true), "actions": actions.active.duplicate(true), "orders": orders.view_for(observer, units), "natural": natural.view_for(observer, units), "terrain": terrain.cells.duplicate(true), "events": observed_events.duplicate(true), "finished": finished, "winner": winner}

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
	for player_id in range(players.size()):
		var player: Dictionary = players[player_id]
		var recovering: Dictionary = player["recovering"]
		for id in recovering.keys():
			if tick_count >= int(recovering[id]["ready_tick"]):
				events.append({"type": "card_recovered", "kind": recovering[id]["kind"], "unit_id": id, "player": player_id})
				recovering.erase(id)

	# First accept summons, then evaluate attacks against the same pre-damage state.
	var commands := queued_commands.duplicate(true)
	queued_commands.clear()
	for command in commands:
		if command["type"] == "summon":
			_apply_summon(command)
		elif command["type"] == "play_card":
			cards.play(command, self, commands)
	commands = _filter_mixed_orders(commands)
	natural.ingest(commands, self)
	orders.ingest(commands, self)
	actions.ingest(commands, self)
	commands.append_array(orders.produce(self))
	commands.append_array(natural.produce(self))
	commands.append_array(natural_defense.produce(self, commands))
	commands.append_array(actions.produce_damage(self))
	# Snapshot before damage/arrivals: no swaps, chains or arrival-tick redirection.
	var occupied := occupied_cells()
	var busy := movement.active.duplicate(true)
	for id in actions.active:
		busy[id] = true
	for unit in units:
		if unit.get("sheltered", false):
			busy[unit["id"]] = true

	var unit_damage: Dictionary = {}
	var core_damage := [0, 0]
	for command in commands:
		match command["type"]:
			"attack":
				var attacker := get_unit(int(command["attacker"]))
				var defender := get_target(int(command["defender"]))
				if _can_attack(attacker, defender, command.get("demolition", false)):
					var atk: int = int(CARD_STATS[attacker["kind"]]["atk"])
					if attacker.get("charged", false):
						atk += 1
						attacker.erase("charged")
						events.append({"type": "charge_hit", "unit_id": attacker["id"], "cell": defender["cell"]})
					if command.get("demolition", false):
						atk += 2
						if actions.active.has(attacker["id"]):
							actions.active[attacker["id"]]["impact_accepted"] = true
					var armor: int = int(CARD_STATS.get(defender["kind"], {"armor": 0})["armor"])
					var protection := 1 if defender.get("sheltered", false) else 0
					var amount := maxi(1, atk - armor - protection)
					unit_damage[defender["id"]] = int(unit_damage.get(defender["id"], 0)) + amount
					natural.record_hit(int(attacker["id"]), int(defender["id"]), tick_count)
					events.append({"type": "attack_accepted", "unit_id": attacker["id"], "target_id": defender["id"], "kind": attacker["kind"], "from_cell": attacker["cell"], "cell": defender["cell"], "amount": amount, "source": command.get("source", "explicit"), "action": "demolish" if command.get("demolition", false) else "attack"})
					attacker["ready_tick"] = tick_count + int(CARD_STATS[attacker["kind"]]["interval"])
			"core_attack":
				var attacker := get_unit(int(command["attacker"]))
				var defending_player: int = int(command["defender"])
				if not attacker.is_empty() and defending_player in [0, 1]:
					# Reject hidden-core attacks before any coordinate-dependent check.
					if not players[defending_player]["core_known_to"][int(attacker["owner"])]:
						continue
					if attacker.get("sheltered", false) or actions.active.has(attacker["id"]):
						continue
					if attacker["owner"] != defending_player and attacker["cell"] == players[defending_player]["core_cell"] and tick_count >= int(attacker["ready_tick"]):
						var atk: int = int(CARD_STATS[attacker["kind"]]["atk"])
						if atk > 0:
							core_damage[defending_player] += atk
							attacker["ready_tick"] = tick_count + int(CARD_STATS[attacker["kind"]]["interval"])

	for unit in units:
		var damage: int = int(unit_damage.get(unit["id"], 0))
		unit["hp"] = int(unit["hp"]) - damage
		if damage > 0:
			events.append({"type": "damaged", "unit_id": unit["id"], "amount": damage, "cell": unit["cell"]})
	for i in range(2):
		players[i]["core_hp"] = maxi(0, int(players[i]["core_hp"]) - core_damage[i])
	cards.apply_damage(unit_damage, self)

	var survivors: Array[Dictionary] = []
	for unit in units:
		if int(unit["hp"]) <= 0:
			var owner: int = int(unit["owner"])
			var kind: String = str(unit["kind"])
			var ready := tick_count + int(CARD_STATS[kind]["recovery"])
			players[owner]["recovering"][unit["id"]] = {"kind": kind, "copy_id": unit.get("copy_id", -1), "ready_tick": ready}
			cards.defeated(unit, ready)
			events.append({"type": "defeated", "unit_id": unit["id"], "kind": kind, "cell": unit["cell"]})
		else:
			survivors.append(unit)
	units = survivors
	actions.advance(self)
	orders.cleanup(self)
	natural.cleanup(self)
	# Accepted attacks use the origin and apply damage before any arrival.
	events.append_array(movement.advance(units, tick_count))
	_check_end()
	if finished:
		movement.reset()
		orders.reset()
		actions.reset()
		natural.reset()
	else:
		var movement_events := movement.resolve(commands, units, tick_count, move_duration_ticks, occupied, busy, terrain.durations(move_duration_ticks))
		events.append_array(movement_events)
		orders.observe_movement(self, movement_events)
		natural.planner.observe_movement(self, movement_events)

func _apply_summon(command: Dictionary) -> void:
	var player: int = int(command["player"])
	var kind: String = str(command["kind"])
	var cell: Vector2i = command["cell"]
	if player not in [0, 1] or not CARD_STATS.has(kind) or not owns_cell(player, cell):
		return
	var stats: Dictionary = CARD_STATS[kind]
	var copy_id := cards.free_copy(player, kind, tick_count)
	if int(players[player]["essence"]) < int(stats["cost"]) or copy_id == -1:
		return
	if occupied_cells().has(cell):
		return
	for unit in units:
		if unit["cell"] == cell:
			return
	players[player]["essence"] -= int(stats["cost"])
	units.append({"id": next_unit_id, "copy_id": copy_id, "owner": player, "kind": kind, "cell": cell, "hp": stats["hp"], "ready_tick": tick_count, "ecology_enabled": true})
	cards.copies[player][kind][copy_id]["unit_id"] = next_unit_id
	events.append({"type": "summoned", "unit_id": next_unit_id, "kind": kind, "owner": player})
	next_unit_id += 1

func _filter_mixed_orders(commands: Array) -> Array:
	var intent_types := {}
	for command in commands:
		if command["type"] not in ["order", "special"]:
			continue
		var id: int = command["unit_id"]
		var unit := get_unit(id)
		if unit.is_empty() or unit["owner"] != command["player"]:
			continue
		if not intent_types.has(id):
			intent_types[id] = {}
		intent_types[id][command["type"]] = true
	var conflicted := {}
	var ids := intent_types.keys()
	ids.sort()
	for id in ids:
		if intent_types[id].size() > 1:
			conflicted[id] = true
			events.append({"type": "order_rejected", "unit_id": id, "reason": "contradictory_actions"})
	return commands.filter(func(command): return command["type"] not in ["order", "special"] or not conflicted.has(command["unit_id"]))

func _can_attack(attacker: Dictionary, defender: Dictionary, demolition: bool = false) -> bool:
	if attacker.is_empty() or defender.is_empty() or attacker["owner"] == defender["owner"]:
		return false
	if attacker.get("sheltered", false) or (actions.active.has(attacker["id"]) and not demolition):
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
