extends SceneTree

var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _fight() -> AetherionSimulation:
	var sim := AetherionSimulation.new()
	sim.queue_summon(0, "pig", Vector2i(3, 1))
	sim.queue_summon(1, "turtle", Vector2i(4, 1))
	sim.place_terrain(Vector2i(3, 1), "cornfield")
	sim.step()
	sim.players[0]["essence"] = 8 # Funds fixture isolates exchange validation.
	return sim

func _attempt(sim: AetherionSimulation, cell: Vector2i, allowed: bool) -> void:
	var owner := 0 if cell.x < 4 else 1
	var before: int = sim.players[owner]["essence"]
	var preview := sim.get_card_placement(owner, "mud", cell)
	_check(preview["valid"] == allowed, "Preview uses the approved attack lock")
	sim.queue_play_card(owner, "mud", cell, -1, sim.tick_count)
	sim.step()
	var result: Dictionary = sim.events.filter(func(event): return event["type"] == "card_result")[0]
	_check(result["accepted"] == allowed, "Next-tick execution agrees with unchanged preview context")
	if not allowed:
		_check(sim.terrain.cells[cell] == "cornfield" and sim.players[owner]["essence"] == before, "Blocked exchange preserves terrain and essence")

func _initialize() -> void:
	_test_cooldown()
	_test_preparation()
	_test_release()
	_test_boundary()
	_test_pending_orders()
	if failures == 0:
		print("PASS: directed cooldown lock, full demolition preparation, pursuit/release, pure preview and exact next-tick boundary")
	quit(0 if failures == 0 else 1)

func _test_cooldown() -> void:
	var sim := _fight()
	sim.queue_target(1, 2, 1)
	sim.step()
	var ready: int = sim.get_unit(2)["ready_tick"]
	var hit_hp: int = sim.get_unit(1)["hp"]
	while sim.tick_count < ready - 1:
		_attempt(sim, Vector2i(3, 1), false)
		_check(sim.get_unit(2)["ready_tick"] == ready and sim.get_unit(1)["hp"] == hit_hp, "Lock neither advances cooldown nor adds damage")
	_attempt(sim, Vector2i(3, 1), false)
	_check(sim.get_unit(1)["hp"] == hit_hp - 1, "Existing directed attack lands at the original cooldown boundary")
	_check(sim.can_move(0, 1, Vector2i(2, 1)), "Exchange lock does not prohibit displacement")
	var before := sim.get_player_view(0)
	for index in range(3):
		sim.get_card_placement(0, "mud", Vector2i(3, 1))
	_check(before == sim.get_player_view(0), "Lock queries remain pure")

func _test_preparation() -> void:
	for natural in [false, true]:
		var sim := AetherionSimulation.new()
		sim.place_terrain(Vector2i(4, 1), "cornfield")
		sim.queue_play_card(1, "fence", Vector2i(4, 1))
		sim.queue_play_card(0, "golem", Vector2i(3, 1))
		sim.step()
		sim.players[1]["essence"] = 8
		var target: int = sim.cards.buildings[0]["id"]
		if natural:
			sim.natural.enabled = true
		else:
			sim.queue_special(0, 1, "demolish", target)
		sim.step()
		_check(sim.actions.active.get(1, {}).get("kind") == "demolish", "Fixture begins accepted manual or natural demolition")
		var deadline: int = sim.actions.active[1]["end_tick"]
		while sim.tick_count < deadline:
			_attempt(sim, Vector2i(4, 1), false)
		_check(sim.cards.buildings.is_empty(), "Lock does not postpone accepted demolition damage")
		_attempt(sim, Vector2i(4, 1), true)

func _test_release() -> void:
	for cause in ["stop", "replace", "attacker_dead", "target_gone", "out_of_range"]:
		var sim := _fight()
		sim.queue_target(1, 2, 1)
		sim.step()
		match cause:
			"stop": sim.queue_stop(1, 2)
			"replace": sim.queue_hold(1, 2)
			"attacker_dead": sim.get_unit(2)["hp"] = 0 # Defeat cleanup fixture.
			"target_gone": sim.get_unit(1)["hp"] = 0
			"out_of_range": sim.get_unit(2)["cell"] = Vector2i(6, 1) # Range-only fixture.
		sim.step()
		_attempt(sim, Vector2i(3, 1), true)
	var chase := _fight()
	chase.get_unit(2)["cell"] = Vector2i(6, 1)
	chase.queue_target(1, 2, 1)
	_attempt(chase, Vector2i(3, 1), true)
	var cancel := AetherionSimulation.new()
	cancel.queue_play_card(0, "golem", Vector2i(3, 1))
	cancel.queue_play_card(1, "fence", Vector2i(4, 1))
	cancel.place_terrain(Vector2i(4, 1), "cornfield")
	cancel.step()
	cancel.players[1]["essence"] = 8
	cancel.queue_special(0, 1, "demolish", cancel.cards.buildings[0]["id"])
	cancel.step()
	cancel.queue_stop(0, 1)
	cancel.step()
	_attempt(cancel, Vector2i(4, 1), true)

func _test_boundary() -> void:
	for offset in [0, 1, 2]:
		var sim := _fight()
		sim.get_unit(2)["ready_tick"] = sim.tick_count + offset # Instant attack readiness fixture.
		sim.queue_attack(2, 1)
		_attempt(sim, Vector2i(3, 1), offset > 1)
	var defense := _fight()
	defense.natural_defense.enabled = true
	defense.get_unit(1)["ready_tick"] = 20
	defense.get_unit(2)["ready_tick"] = defense.tick_count + 1
	_attempt(defense, Vector2i(3, 1), false)

func _test_pending_orders() -> void:
	for conflict in ["contradictory", "mixed", "invalid_action", "foreign"]:
		var sim := _fight()
		match conflict:
			"contradictory":
				sim.queue_target(1, 2, 1)
				sim.queue_stop(1, 2)
			"mixed":
				sim.queue_target(1, 2, 1)
				sim.queue_special(1, 2, "enter")
			"invalid_action": sim.queue_act_at(1, 2, "forage", Vector2i(3, 1), 1)
			"foreign": sim.queue_target(0, 2, 1)
		_attempt(sim, Vector2i(3, 1), true)
		_check(sim.get_unit(1)["hp"] == 4, "Rejected/foreign intents cannot create damage or a persistent exchange lock")
