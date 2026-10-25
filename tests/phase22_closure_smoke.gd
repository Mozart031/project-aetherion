extends SceneTree

var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _ticks(sim: AetherionSimulation, count: int) -> void:
	for index in range(count):
		sim.step()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_instance_controls()
	_test_manual_attack_priority()
	_test_context_arrival()
	_test_copy_deadline()
	_test_pig_counterplay()
	_test_match_results()
	var expected := _frame_replay(20.0)
	_check(expected == _frame_replay(30.0) and expected == _frame_replay(120.0), "Actual scene accumulator preserves per-tick states/events at 20, 30 and 120 FPS")
	if failures == 0:
		print("PASS: Phase 22 closure: player authority, per-instance ecology, contextual arrival, exact copy recovery, pig counterplay, match outcomes and actual frame replay")
	quit(0 if failures == 0 else 1)

func _test_instance_controls() -> void:
	var sim := AetherionSimulation.new()
	sim.place_terrain(Vector2i(1, 1), "mud")
	sim.place_terrain(Vector2i(2, 2), "mud")
	sim.queue_play_card(0, "pig", Vector2i(1, 1))
	sim.queue_play_card(0, "pig", Vector2i(2, 2))
	sim.step()
	# Wounds fixture isolates two copies' independent controls.
	sim.get_unit(1)["hp"] = 3
	sim.get_unit(2)["hp"] = 3
	sim.natural.enabled = true
	sim.queue_ecology(0, 1, false)
	_ticks(sim, 8)
	_check(sim.get_unit(1)["hp"] == 3 and sim.get_unit(2)["hp"] == 4, "Disabling one copy does not disable another copy's natural recovery")
	sim.queue_ecology(0, 1, true)
	sim.queue_destination(0, 2, Vector2i(3, 2))
	_ticks(sim, 12) # Up to four decision ticks plus the six-tick preparation.
	_check(sim.get_unit(1)["hp"] == 4 and sim.get_unit(2)["cell"] == Vector2i(3, 2), "Enabling ecology on one copy preserves another copy's explicit movement")
	sim.queue_hold(0, 2)
	_ticks(sim, 100)
	_check(sim.get_unit(2)["cell"] == Vector2i(3, 2) and sim.orders.active[2]["goal"]["kind"] == "hold", "Hold persists without autonomous movement")

func _test_manual_attack_priority() -> void:
	var sim := AetherionSimulation.new()
	sim.place_terrain(Vector2i(1, 1), "mud")
	sim.queue_play_card(0, "pig", Vector2i(3, 1))
	sim.queue_play_card(1, "pig", Vector2i(4, 3))
	sim.step()
	sim.get_unit(1)["hp"] = 2 # Wound fixture; combat remains real afterwards.
	sim.natural.enabled = true
	sim.natural_defense.enabled = true
	sim.step()
	var committed: Vector2i = sim.get_motion(1)["to"]
	sim.queue_target(0, 1, 2)
	sim.step()
	_check(sim.natural.claims.is_empty() and sim.orders.active[1]["goal"]["kind"] == "attack_target", "Directed attack immediately supersedes a natural resource intention")
	_check(sim.get_motion(1)["to"] == committed, "Manual priority never erases an accepted natural step")
	var healed := false
	var attacked := false
	for tick in range(35):
		sim.step()
		for event in sim.events:
			if event["type"] == "special_completed" and event["unit_id"] == 1:
				healed = true
			if event["type"] == "attack_accepted" and event["unit_id"] == 1 and event["target_id"] == 2:
				attacked = true
	_check(attacked and not healed, "Manual attack approaches and hits its target instead of resuming a recovery trip")

func _test_context_arrival() -> void:
	for kind in ["pig", "horse"]:
		var sim := AetherionSimulation.new()
		var ground := "mud" if kind == "pig" else "cornfield"
		var action := "roll" if kind == "pig" else "forage"
		sim.place_terrain(Vector2i(3, 1), ground)
		sim.queue_play_card(0, kind, Vector2i(1, 1))
		sim.step()
		sim.get_unit(1)["hp"] = 2
		sim.get_unit(1)["special_ready_tick"] = 21 # Existing cooldown fixture.
		sim.natural.enabled = true
		sim.queue_act_at(0, 1, action, Vector2i(3, 1))
		var starts := 0
		var completions := 0
		for tick in range(40):
			sim.step()
			for event in sim.events:
				if event["type"] == "special_started" and event["unit_id"] == 1:
					starts += 1
					_check(event["kind"] == action and sim.tick_count >= 21 and sim.get_unit(1)["cell"] == Vector2i(3, 1), "Contextual action starts only after arrival and cooldown")
				if event["type"] == "special_completed" and event["unit_id"] == 1:
					completions += 1
		_check(starts == 1 and completions == 1 and sim.orders.active.is_empty(), "Go-and-act executes the appropriate contextual action once")
		_check(sim.get_unit(1)["hp"] == (3 if kind == "pig" else 4), "Arrival preserves species healing amounts")
		_check(sim.terrain.cells.has(Vector2i(3, 1)) == (kind == "pig"), "Forage consumes its ration; rolling preserves mud")

func _test_copy_deadline() -> void:
	var sim := AetherionSimulation.new()
	sim.queue_play_card(0, "pig", Vector2i(3, 1))
	sim.queue_play_card(1, "golem", Vector2i(4, 1))
	sim.step()
	var lost_copy: int = sim.get_unit(1)["copy_id"]
	sim.queue_attack(2, 1)
	sim.step()
	var ready: int = sim.players[0]["recovering"][1]["ready_tick"]
	sim.queue_play_card(0, "pig", Vector2i(1, 1))
	sim.step()
	_check(sim.get_unit(3)["copy_id"] != lost_copy and sim.cards.state(0, "pig", sim)["recovering"] == 1, "A free copy deploys while the defeated copy remains individually recovering")
	while sim.tick_count < 120:
		sim.step()
	sim.queue_play_card(0, "pig", Vector2i(0, 0))
	sim.step()
	_check(sim.get_unit(4)["copy_id"] != lost_copy, "Third active instance uses its own copy, not the defeated one")
	while sim.tick_count < ready - 2:
		sim.step()
	var essence: int = sim.players[0]["essence"]
	sim.queue_play_card(0, "pig", Vector2i(2, 0))
	sim.step()
	_check(sim.tick_count == ready - 1 and sim.get_unit(5).is_empty() and sim.players[0]["essence"] == essence, "Recovering copy cannot deploy one tick early and rejection spends no essence")
	sim.queue_play_card(0, "pig", Vector2i(2, 0))
	sim.step()
	_check(sim.tick_count == ready and sim.get_unit(5).get("copy_id") == lost_copy and not sim.players[0]["recovering"].has(1), "Exact recovery deadline releases only that copy for a new paid deployment")
	_check(sim.get_unit(3).get("copy_id") == 1 and sim.get_unit(4).get("copy_id") == 2, "Other same-species copies remain active throughout recovery")
	print("CHECK: defeated pig copy unavailable through tick %s; reusable at tick %s" % [ready - 1, ready])

func _test_pig_counterplay() -> void:
	var sim := AetherionSimulation.new()
	sim.place_terrain(Vector2i(6, 1), "mud")
	sim.natural.enabled = true
	sim.natural_defense.enabled = true
	sim.queue_play_card(0, "boar", Vector2i(3, 1))
	sim.queue_play_card(1, "pig", Vector2i(4, 1))
	sim.queue_target(0, 1, 2)
	var heals := 0
	var moves := 0
	var death_tick := -1
	for tick in range(180):
		sim.step()
		for event in sim.events:
			if event["type"] == "move_started" and event["unit_id"] == 2:
				moves += 1
			if event["type"] == "special_completed" and event["kind"] == "roll" and event["unit_id"] == 2:
				heals += int(event["amount"])
			if event["type"] == "defeated" and event["unit_id"] == 2:
				death_tick = sim.tick_count
	_check(moves == 2 and heals == 1 and death_tick > 0 and death_tick <= 60, "A directed fresh boar pursues and defeats a mud-seeking pig despite its natural heal")
	_check(sim.get_unit(1).get("hp", 0) > 0 and sim.get_unit(2).is_empty(), "Mud recovery grants neither endless evasion nor invulnerability against pursuit")
	print("CHECK: pursuing boar defeats pig at tick %s after %s natural steps and %s HP healed" % [death_tick, moves, heals])
	# A wounded pig on mud can heal repeatedly, but only at its approved bounded rate.
	sim = AetherionSimulation.new()
	sim.place_terrain(Vector2i(1, 1), "mud")
	sim.queue_play_card(0, "pig", Vector2i(1, 1))
	sim.step()
	sim.get_unit(1)["hp"] = 1
	sim.natural.enabled = true
	var last_start := -100
	var count := 0
	for tick in range(240):
		sim.step()
		for event in sim.events:
			if event["type"] == "special_started":
				_check(sim.tick_count - last_start >= sim.actions.cooldown_ticks, "Consecutive natural heals respect the 60-tick special cooldown")
				last_start = sim.tick_count
			if event["type"] == "special_completed":
				_check(event["amount"] == 1, "Each natural roll heals exactly one HP")
				count += 1
		_check(sim.get_unit(1)["hp"] <= 4, "Repeated healing never exceeds maximum HP")
	_check(count == 3 and sim.actions.active.is_empty() and sim.natural.planner.active.is_empty(), "Pig stops recovering once healthy instead of entering an endless action loop")

func _test_match_results() -> void:
	for health in [[0, 0], [12, 0], [0, 12], [12, 12], [9, 10]]:
		var sim := AetherionSimulation.new()
		# Boundary fixtures characterize existing results; do not discover/damage a hidden core.
		sim.players[0]["core_hp"] = health[0]
		sim.players[1]["core_hp"] = health[1]
		if health[0] > 0 and health[1] > 0:
			sim.tick_count = sim.MATCH_LIMIT_TICKS - 2
			sim.step()
			_check(not sim.finished, "Timeout does not end the match one tick early")
		sim.step()
		var expected := 0 if health[0] > health[1] else (1 if health[1] > health[0] else -1)
		_check(sim.finished and sim.winner == expected, "Existing core-HP result is deterministic for defeat, mutual defeat and timeout")
		var ended := sim.get_player_view(0)
		_ticks(sim, 5)
		_check(ended == sim.get_player_view(0), "Finished simulation does not advance ticks, regenerate or repeat damage")
	_check(AetherionSimulation.TICK_SECONDS == 0.05 and AetherionSimulation.MATCH_LIMIT_TICKS * AetherionSimulation.TICK_SECONDS == 600, "20 Hz and 12000-tick timeout represent ten simulated minutes")

func _frame_replay(fps: float) -> Array:
	var view = load("res://scenes/battle_depth_demo.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	var history := []
	var supplied := -1
	while view.sim.tick_count < 180:
		if supplied != view.sim.tick_count:
			supplied = view.sim.tick_count
			match supplied:
				0: view.sim.queue_play_card(0, "pig", Vector2i(3, 0))
				20: view.sim.queue_hold(0, 3)
				40: view.sim.queue_stop(0, 3)
				60: view.sim.queue_ecology(0, 3, false)
				80: view.sim.queue_ecology(0, 3, true)
		var before: int = view.sim.tick_count
		view._process(1.0 / fps)
		if before != view.sim.tick_count:
			history.append(view.sim.get_player_view(0))
	var before_stall: int = view.sim.tick_count
	view._process(1.0)
	_check(view.sim.tick_count - before_stall == 5, "Existing one-second frame clamp processes five fixed ticks, not a variable simulation step")
	view.free()
	return history
