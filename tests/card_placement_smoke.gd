extends SceneTree

const Placement = preload("res://scripts/card_placement_controller.gd")
var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_test_draft_and_commit()
	_test_race_and_replay()
	_test_queries_and_privacy()
	if failures == 0:
		print("PASS: pure placement, cancel, revalidation, exact payment, request replay, stale responses, availability and hidden-core privacy")
	quit(0 if failures == 0 else 1)

func _test_draft_and_commit() -> void:
	var sim := AetherionSimulation.new()
	var placement := Placement.new()
	var before := sim.get_player_view(0)
	_check(placement.begin(0, "creature", "pig", sim), "Available top card can start a local draft")
	_check(not placement.preview(sim, Vector2i(4, 0))["valid"] and placement.preview(sim, Vector2i(1, 1))["valid"], "Placement queries use authoritative territorial rules")
	_check(before == sim.get_player_view(0) and sim.queued_commands.is_empty(), "Starting and highlighting do not spend, allocate copies or queue commands")
	placement.cancel()
	_check(placement.draft.is_empty() and before == sim.get_player_view(0), "Cancel is entirely local")
	placement.begin(0, "creature", "pig", sim)
	_check(not placement.confirm(sim, Vector2i(4, 0)) and sim.queued_commands.is_empty(), "Invalid local confirmation never sends a command")
	_check(placement.confirm(sim, Vector2i(1, 1)) and not placement.confirm(sim, Vector2i(2, 1)), "Only one confirmation can be pending")
	_check(sim.players[0]["essence"] == 4 and sim.units.is_empty() and not placement.cancel(), "Pending transaction waits for tick and cannot be undone as a local draft")
	sim.step()
	placement.consume(sim.get_player_view(0))
	_check(sim.players[0]["essence"] == 2 and sim.units.size() == 1 and placement.draft.is_empty(), "Accepted command pays exactly once and closes matching draft")
	_check(sim.cards.state(0, "pig", sim)["available"] == 2, "Deployment allocates an individual copy")

func _test_race_and_replay() -> void:
	var sim := AetherionSimulation.new()
	var placement := Placement.new()
	placement.begin(0, "creature", "pig", sim)
	sim.queue_play_card(0, "pig", Vector2i(1, 1)) # Earlier same-tick placement wins occupancy.
	placement.confirm(sim, Vector2i(1, 1))
	sim.step()
	placement.consume(sim.get_player_view(0))
	_check(sim.units.size() == 1 and sim.players[0]["essence"] == 2 and placement.message == "occupied" and not placement.busy(), "Changed destination rejects at commit without charging the rejected draft")
	_check(placement.confirm(sim, Vector2i(2, 2)), "Rejected draft can select a new valid destination")
	placement.consume({"finished": false, "events": [{"type": "card_result", "player": 0, "request_id": 1, "accepted": true}]})
	_check(placement.busy() and placement.draft["request_id"] == 2, "An old acknowledgement cannot close a newer pending placement")
	var command: Dictionary = sim.queued_commands[-1].duplicate(true)
	sim.queued_commands.append(command.duplicate(true))
	sim.step()
	placement.consume(sim.get_player_view(0))
	_check(sim.units.size() == 2 and sim.players[0]["essence"] == 0 and placement.draft.is_empty(), "Duplicate request confirms one deployment and one payment")
	sim.queued_commands.append(command)
	sim.step()
	_check(sim.units.size() == 2 and sim.players[0]["essence"] == 0, "Late retransmission returns cached result without replaying a card")
	_check(not placement.begin(0, "creature", "pig", sim), "Insufficient essence cannot start a new draft")
	sim = AetherionSimulation.new()
	sim.queue_play_card(0, "pig", Vector2i(1, 1))
	sim.step()
	sim.get_unit(1)["hp"] = 1 # Wounded fixture to detect duplicate healing.
	sim.queue_play_card(0, "heal", Vector2i(1, 1), 1, 7)
	sim.queue_play_card(0, "heal", Vector2i(1, 1), 1, 7)
	sim.step()
	_check(sim.get_unit(1)["hp"] == 3 and sim.players[0]["essence"] == 0, "Reusable trick cannot apply twice with the same request ID")
	sim.queue_play_card(0, "heal", Vector2i(1, 1), 1, 6)
	sim.step()
	_check(sim.get_unit(1)["hp"] == 3 and sim.events[-1]["reason"] == "stale_request", "Older requests cannot replay after a newer request")
	_check(sim.get_player_view(1)["events"].all(func(event): return event["type"] != "card_result"), "Request acknowledgements are private to the requesting observer")
	# Essence can change after preview but before the tick: no partial deployment.
	sim = AetherionSimulation.new()
	sim.queue_play_card(0, "golem", Vector2i(0, 0))
	placement.reset()
	placement.begin(0, "creature", "pig", sim)
	placement.confirm(sim, Vector2i(1, 1))
	sim.step()
	placement.consume(sim.get_player_view(0))
	_check(sim.units.size() == 1 and sim.units[0]["kind"] == "golem" and placement.message == "unavailable", "Commit rechecks essence after earlier commands without creating a free creature")

func _test_queries_and_privacy() -> void:
	var pair: Array[AetherionSimulation] = []
	for core in [Vector2i(4, 0), Vector2i(7, 3)]:
		var sim := AetherionSimulation.new()
		sim.place_core(1, core)
		pair.append(sim)
	var before := pair[0].get_player_view(0)
	for id in AetherionSimulation.BattleCards.Catalog.CARDS:
		for x in range(8):
			for y in range(4):
				_check(pair[0].get_card_placement(0, id, Vector2i(x, y)) == pair[1].get_card_placement(0, id, Vector2i(x, y)), "Highlights cannot depend on hidden-core location")
	_check(before == pair[0].get_player_view(0), "All-card all-cell queries are pure")
	var sim := pair[0]
	sim.queue_play_card(0, "pig", Vector2i(1, 1))
	sim.step()
	_check(not sim.get_card_placement(0, "pig", Vector2i(1, 1))["valid"], "Occupied origin rejects deployment")
	sim.queue_move(0, 1, Vector2i(2, 1))
	sim.step()
	_check(not sim.get_card_placement(0, "pig", Vector2i(2, 1))["valid"], "Reserved destination rejects deployment")
	_check(not sim.get_card_placement(0, "heal", Vector2i(1, 1), 1)["valid"], "Heal preview rejects a healthy target")
	sim.get_unit(1)["hp"] = 3
	_check(sim.get_card_placement(0, "heal", Vector2i(1, 1), 1)["valid"], "Heal preview accepts a wounded own target without applying it")
