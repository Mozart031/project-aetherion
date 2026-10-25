extends SceneTree

var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_messages()
	_test_building_kind()
	_test_end_queue()
	_test_fixed_rival()
	if failures == 0:
		print("PASS: scoped navigation errors, real construction kind, finished command guards and unchanged fixed rival/restart")
	quit(0 if failures == 0 else 1)

func _scene():
	var view = load("res://scenes/battle_stacks_demo.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view.board.set_process(false)
	view.board._process(0.05)
	return view

func _test_messages() -> void:
	var view = _scene()
	view._begin("creature")
	view._confirm_at(view.board._center(Vector2i(7, 0)))
	_check(view.placement.message == "own_territory_required", "Invalid placement creates a current draft error")
	view._cycle("terrain")
	_check(view.placement.message == "own_territory_required" and view.placement.draft.get("card") == "pig", "Independent stack navigation preserves a live placement error")
	view._cycle("creature")
	_check(view.placement.message.is_empty() and view.placement.draft.is_empty(), "Changing draft's own top cancels and clears its obsolete error")
	view._begin("creature") # Boar costs three of the existing four essence.
	view._confirm_at(view.board._center(Vector2i(0, 0)))
	var pending: Dictionary = view.stacks.snapshot()
	view._cycle("terrain")
	_check(view.placement.busy() and view.stacks.snapshot() == pending, "Navigation cannot discard an in-flight acknowledgement")
	view.board._process(0.05)
	_check(view.stacks.top("creature") == "horse", "Accepted card still rotates automatically exactly once")
	view._begin("creature")
	_check(view.placement.message == "unavailable" and view.placement.draft.is_empty(), "Unaffordable card produces no active draft")
	var before: int = view.board.sim.players[0]["essence"]
	view._cycle("creature")
	_check(view.placement.message.is_empty() and not view.panel.status.text.contains("Falta esencia o disponibilidad") and view.board.sim.players[0]["essence"] == before, "Browsing clears stale error without changing essence")
	view.placement.message = "match_finished" # Global-status fixture, not a card error.
	view._cycle("terrain")
	_check(view.placement.message == "match_finished", "Navigation retains global match-end status")
	view.free()

func _test_building_kind() -> void:
	var sim := AetherionSimulation.new()
	sim.tick_count = 10
	# Synthetic second kind only tests identity propagation, never equips a new card.
	sim.cards.buildings = [{"id": 1000000, "kind": "fence", "owner": 0, "cell": Vector2i(1, 1), "hp": 1}, {"id": 1000001, "kind": "fixture_structure", "owner": 1, "cell": Vector2i(5, 1), "hp": 1}]
	sim.cards.apply_damage({1000000: 1, 1000001: 1}, sim)
	_check(sim.cards.buildings.is_empty() and sim.players[0]["recovering"][1000000]["kind"] == "fence" and sim.players[1]["recovering"][1000001]["kind"] == "fixture_structure", "Each destroyed construction recovers its actual kind for its owner")
	_check(sim.players[0]["recovering"][1000000]["ready_tick"] == 130 and sim.players[1]["recovering"][1000001]["ready_tick"] == 130, "Identity fix preserves the existing 120-tick recovery")
	_check(not sim.loadouts[0].contains("fixture_structure"), "Identity fixture introduces no playable construction")

func _test_end_queue() -> void:
	var sim := AetherionSimulation.new()
	sim.tick_count = sim.MATCH_LIMIT_TICKS - 1
	sim.step()
	_check(sim.finished and sim.queued_commands.is_empty(), "Fixture reaches the real timeout")
	var snapshots := [sim.get_player_view(0), sim.get_player_view(1)]
	var raw_events := sim.events.duplicate(true)
	sim.queue_summon(0, "pig", Vector2i(1, 1))
	sim.queue_attack(1, 2)
	sim.queue_core_attack(1, 1)
	sim.queue_move(0, 1, Vector2i(2, 1))
	sim.queue_destination(0, 1, Vector2i(3, 1))
	sim.queue_target(0, 1, 2)
	sim.queue_stop(0, 1)
	sim.queue_hold(0, 1)
	sim.queue_act_at(0, 1, "roll", Vector2i(1, 1))
	sim.queue_ecology(0, 1, false)
	sim.queue_special(0, 1, "roll")
	sim.queue_play_card(0, "pig", Vector2i(1, 1), -1, 100)
	sim.step()
	_check(sim.queued_commands.is_empty() and snapshots == [sim.get_player_view(0), sim.get_player_view(1)] and sim.events == raw_events, "All public queue APIs ignore post-match input without state/event/queue growth")
	sim.reset()
	sim.queue_summon(0, "pig", Vector2i(1, 1))
	sim.step()
	_check(sim.units.size() == 1 and sim.players[0]["essence"] == 2, "Finished guards do not disable a restarted match")

func _test_fixed_rival() -> void:
	var view = _scene()
	while view.board.sim.tick_count < 302:
		view.board._process(0.05)
	var sim: AetherionSimulation = view.board.sim
	_check(sim.units.size() == 2 and sim.get_unit(1)["kind"] == "pig" and sim.get_unit(1)["cell"] == Vector2i(4, 0), "Demo retains its initial pig and fixed flank destination")
	_check(sim.get_unit(2).get("kind") == "boar" and sim.get_unit(2)["cell"] == Vector2i(4, 1) and sim.cards.buildings[0]["cell"] == Vector2i(5, 1), "Demo retains the paid fence and boar reinforcement schedule")
	_check(sim.players[1]["essence"] == 2 and sim.natural.enabled and sim.natural_defense.enabled, "Fixed rival still pays the same economy and keeps ecology/defense")
	view.board._start_battle()
	view.board._process(0.05)
	_check(sim.units.size() == 1 and sim.get_unit(1)["kind"] == "pig" and not view.board.scheduled_boar and not view.board.scheduled_fence, "Demo restart resets the existing fixed scenario")
	view.free()
