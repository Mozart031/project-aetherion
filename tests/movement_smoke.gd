extends SceneTree

var failures := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _pair(a := Vector2i(3, 1), b := Vector2i(4, 1), second_kind := "turtle") -> AetherionSimulation:
	var sim := AetherionSimulation.new()
	sim.queue_summon(0, "boar", a)
	sim.queue_summon(1, second_kind, b)
	sim.step()
	_check(sim.units.size() == 2, "Fixture summons both creatures")
	return sim

func _until(sim: AetherionSimulation, tick: int) -> void:
	for index in range(maxi(0, tick - sim.tick_count)):
		sim.step()

func _initialize() -> void:
	_test_step_and_validation()
	_test_conflicts()
	_test_damage_and_death()
	_test_reservations_reset_and_end()
	_test_hidden_core()
	if failures == 0:
		print("PASS: movement timing, validation, conflicts, damage, death, reservations, reset and hidden cores")
	quit(0 if failures == 0 else 1)

func _test_step_and_validation() -> void:
	var sim := _pair(Vector2i(3, 1), Vector2i(7, 3))
	var before := sim.get_player_view(0)
	_check(sim.can_move(0, 1, Vector2i(4, 1)), "Enemy territory is allowed")
	for destination in [Vector2i(-1, 1), Vector2i(8, 1), Vector2i(3, -1), Vector2i(3, 4), Vector2i(4, 2), Vector2i(5, 1), Vector2i(3, 1)]:
		_check(not sim.can_move(0, 1, destination), "Reject bounds, diagonals, long steps and same cell")
		for player in [-1, 0, 1, 2]:
			sim.queue_move(player, 999, destination)
	_check(not sim.can_move(1, 1, Vector2i(4, 1)), "Foreign unit rejected")
	_check(not sim.can_move(0, 999, Vector2i(4, 1)), "Missing unit rejected")
	_check(sim.get_player_view(0) == before, "Queries do not mutate state")
	sim.queue_move(1, 1, Vector2i(3, 0))
	sim.queue_move(0, 1, Vector2i(4, 1))
	sim.step()
	_check(sim.get_motion(1).get("end_tick") == 8, "Six ticks after acceptance at tick 2")
	_check(sim.get_unit(1)["cell"] == Vector2i(3, 1), "Origin remains occupied")
	_check(sim.movement.reservations.get(Vector2i(4, 1)) == 1, "Destination reserved")
	_check(sim.players[0]["essence"] == 1 and sim.get_unit(1)["ready_tick"] == 1, "Move consumes neither essence nor attack cooldown")
	var snapshot := sim.get_motion(1)
	snapshot["to"] = Vector2i.ZERO
	_check(sim.get_motion(1)["to"] == Vector2i(4, 1), "Motion query returns a detached snapshot")
	sim.queue_move(0, 1, Vector2i(3, 0))
	sim.step()
	_check(sim.get_motion(1)["to"] == Vector2i(4, 1), "No redirection while moving")
	_until(sim, 7)
	_check(sim.get_unit(1)["cell"] == Vector2i(3, 1), "No early arrival")
	sim.queue_move(0, 1, Vector2i(5, 1))
	sim.step()
	_check(sim.get_unit(1)["cell"] == Vector2i(4, 1), "Arrive exactly at tick 8")
	_check(sim.get_motion(1).is_empty() and sim.movement.reservations.is_empty(), "Release destination; arrival-tick order rejected")
	sim.move_duration_ticks = 3
	sim.queue_move(0, 1, Vector2i(5, 1))
	sim.step()
	_check(sim.get_motion(1).get("end_tick") == 12, "Configurable step duration")
	_until(sim, 12)
	_check(sim.get_unit(1)["cell"] == Vector2i(5, 1), "Configured duration is honored")

func _test_conflicts() -> void:
	var reference := {}
	for reverse_order in [false, true]:
		var sim := _pair(Vector2i(3, 1), Vector2i(4, 2))
		var commands := [[0, 1], [1, 2]]
		if reverse_order:
			commands.reverse()
		for command in commands:
			sim.queue_move(command[0], command[1], Vector2i(4, 1))
		sim.step()
		_check(sim.movement.active.is_empty() and sim.movement.reservations.is_empty(), "All contenders for shared destination rejected")
		if reverse_order:
			_check(sim.get_player_view(0) == reference, "Conflict results and events independent of input order")
		else:
			reference = sim.get_player_view(0)
	for reverse_order in [false, true]:
		var sim := _pair()
		var commands := [[0, 1, Vector2i(4, 1)], [1, 2, Vector2i(3, 1)]]
		if reverse_order:
			commands.reverse()
		for command in commands:
			sim.queue_move(command[0], command[1], command[2])
		sim.step()
		_check(sim.movement.active.is_empty(), "Swaps into occupied cells rejected")
	var chain := _pair()
	chain.queue_move(0, 1, Vector2i(4, 1))
	chain.queue_move(1, 2, Vector2i(5, 1))
	chain.step()
	_check(chain.get_motion(1).is_empty() and not chain.get_motion(2).is_empty(), "No following into an occupied origin")
	for reverse_order in [false, true]:
		var sim := _pair()
		var destinations := [Vector2i(3, 0), Vector2i(3, 2)]
		if reverse_order:
			destinations.reverse()
		for destination in destinations:
			sim.queue_move(0, 1, destination)
		sim.step()
		_check(sim.get_motion(1).is_empty(), "Contradictory destinations rejected in both orders")
	var duplicates := _pair()
	for repeat in range(3):
		duplicates.queue_move(0, 1, Vector2i(3, 0))
	duplicates.step()
	_check(duplicates.movement.active.size() == 1 and duplicates.events.size() == 1, "Identical duplicates start exactly one step")
	_until(duplicates, 20)
	_check(duplicates.get_unit(1)["cell"] == Vector2i(3, 0) and duplicates.get_motion(1).is_empty(), "No deferred duplicate movement")

func _test_damage_and_death() -> void:
	var mutual := _pair(Vector2i(3, 1), Vector2i(4, 1), "boar")
	mutual.get_unit(1)["hp"] = 2
	mutual.get_unit(2)["hp"] = 2
	mutual.queue_move(0, 1, Vector2i(3, 0))
	mutual.queue_move(1, 2, Vector2i(4, 0))
	mutual.step()
	mutual.queue_attack(1, 2)
	mutual.queue_attack(2, 1)
	mutual.step()
	_check(mutual.units.is_empty() and mutual.movement.active.is_empty() and mutual.movement.reservations.is_empty(), "Mutual lethal attacks in transit stay simultaneous and release both reservations")
	for reverse_order in [false, true]:
		var sim := _pair()
		if reverse_order:
			sim.queue_move(0, 1, Vector2i(3, 0))
		sim.queue_attack(1, 2)
		sim.queue_attack(2, 1)
		if not reverse_order:
			sim.queue_move(0, 1, Vector2i(3, 0))
		sim.step()
		_check(sim.get_unit(1)["hp"] == 2 and sim.get_unit(2)["hp"] == 4, "Movement order never cancels accepted simultaneous damage")
		_check(sim.get_unit(1)["ready_tick"] == 38 and sim.get_unit(2)["ready_tick"] == 46, "Original attack cooldowns preserved")
		_check(not sim.get_motion(1).is_empty(), "Movement is independent of cooldown")
	var moving := _pair()
	moving.queue_move(0, 1, Vector2i(3, 0))
	moving.step()
	_until(moving, 4)
	moving.queue_attack(2, 1)
	moving.step()
	_check(moving.get_unit(1)["hp"] == 2, "Receive damage mid-transit at logical origin")
	_check(moving.get_motion(1).get("end_tick") == 8, "Damage does not pause or prolong movement")
	for lethal in [false, true]:
		var sim := _pair()
		if lethal:
			sim.get_unit(1)["hp"] = 1 # Low-health fixture, not a gameplay API.
		sim.queue_move(0, 1, Vector2i(3, 0))
		sim.step()
		_until(sim, 7)
		sim.queue_attack(2, 1)
		sim.step()
		if lethal:
			_check(sim.get_unit(1).is_empty(), "Lethal arrival-tick hit defeats before arrival")
			_check(sim.players[0]["recovering"].get("boar") == 248, "Combat recovery still starts on defeat")
		else:
			_check(sim.get_unit(1)["hp"] == 2 and sim.get_unit(1)["cell"] == Vector2i(3, 0), "Arrival cannot evade an accepted hit")
		_check(sim.get_motion(1).is_empty() and sim.movement.reservations.is_empty(), "Death or arrival releases reservations")

func _test_reservations_reset_and_end() -> void:
	var sim := _pair(Vector2i(3, 1), Vector2i(4, 2))
	sim.queue_move(0, 1, Vector2i(4, 1))
	sim.step()
	_check(not sim.can_move(1, 2, Vector2i(4, 1)), "Reserved destination unavailable to others")
	sim.queue_summon(1, "pigeon", Vector2i(4, 1))
	sim.queue_move(1, 2, Vector2i(4, 1))
	sim.step()
	_check(sim.units.size() == 2 and sim.players[1]["essence"] == 1, "Summon cannot consume essence or occupy reserved destination")
	_check(sim.get_motion(2).is_empty(), "Queued move to reserved destination rejected")
	var death := _pair(Vector2i(3, 1), Vector2i(4, 1))
	death.get_unit(1)["hp"] = 1
	death.queue_move(0, 1, Vector2i(3, 0))
	death.step()
	death.queue_attack(2, 1)
	death.step()
	_check(death.movement.reservations.is_empty(), "Mid-transit death releases destination immediately")
	death.queue_summon(0, "pigeon", Vector2i(3, 0))
	death.step()
	_check(death.units.size() == 2 and death.get_unit(3).get("cell") == Vector2i(3, 0), "Freed destination reusable after death")
	sim.queue_move(0, 1, Vector2i(3, 0))
	sim.reset()
	_check(sim.units.is_empty() and sim.movement.active.is_empty() and sim.movement.reservations.is_empty(), "Reset clears units and all movement state")
	_check(sim.queued_commands.is_empty() and sim.tick_count == 0, "Reset clears pending movement")
	sim = _pair()
	sim.queue_move(0, 1, Vector2i(3, 0))
	sim.step()
	sim.tick_count = AetherionSimulation.MATCH_LIMIT_TICKS - 1 # Timeout fixture.
	sim.step()
	_check(sim.finished and sim.movement.active.is_empty() and sim.movement.reservations.is_empty(), "Match end releases all movement state")
	_check(not sim.can_move(0, 1, Vector2i(3, 1)), "No movement after match end")
	sim.queue_move(0, 1, Vector2i(3, 1))
	_check(sim.queued_commands.is_empty(), "No new queued moves after match end")

func _test_hidden_core() -> void:
	var simulations: Array[AetherionSimulation] = []
	for hidden_cell in [Vector2i(4, 1), Vector2i(6, 2)]:
		var sim := AetherionSimulation.new()
		_check(sim.place_core(1, hidden_cell), "Place hidden core fixture")
		sim.queue_summon(0, "boar", Vector2i(3, 1))
		sim.step()
		_check(not sim.get_player_view(0)["players"][1].has("core_cell"), "Opponent core absent from presentation view")
		_check(sim.get_player_view(1)["players"][1]["core_cell"] == hidden_cell, "Owner can see own core")
		_check(sim.get_player_view(-1).is_empty(), "Invalid observer rejected")
		for x in range(8):
			for y in range(4):
				_check(sim.can_move(0, 1, Vector2i(x, y)) == (absi(x - 3) + absi(y - 1) == 1), "Movement queries independent of hidden core")
		sim.queue_move(0, 1, Vector2i(4, 1))
		sim.queue_core_attack(1, 1)
		sim.step()
		_until(sim, 8)
		sim.queue_core_attack(1, 1)
		sim.step()
		_check(sim.players[1]["core_hp"] == 12 and sim.get_unit(1)["ready_tick"] == 1, "Hidden core attack has no damage or cooldown side channel")
		_check(sim.events.is_empty(), "Hidden core attack emits no revealing event")
		_check(not sim.get_player_view(0)["players"][1].has("core_cell"), "Entering core cell does not discover it")
		simulations.append(sim)
	_check(simulations[0].get_player_view(0) == simulations[1].get_player_view(0), "Moving and probing different hidden locations yields identical observer state")
	var discovered := simulations[0]
	discovered.players[1]["core_known_to"][0] = true # Discovered only through this test fixture.
	_check(discovered.get_player_view(0)["players"][1]["core_cell"] == Vector2i(4, 1), "Discovered fixture reveals coordinates")
	discovered.queue_core_attack(1, 1)
	discovered.step()
	_check(discovered.players[1]["core_hp"] == 9 and discovered.get_unit(1)["ready_tick"] == 46, "Discovered core preserves existing damage and cooldown")
	var view := discovered.get_player_view(0)
	view["units"][0]["hp"] = 0
	_check(discovered.get_unit(1)["hp"] == 3, "Presentation cannot mutate authoritative state through snapshot")
	discovered.reset()
	_check(not discovered.players[1]["core_known_to"][0], "Reset hides opponent core again")
