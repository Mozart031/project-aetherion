extends SceneTree

var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _pair(a := Vector2i(3, 1), b := Vector2i(4, 1)) -> AetherionSimulation:
	var sim := AetherionSimulation.new()
	sim.queue_summon(0, "boar", a)
	sim.queue_summon(1, "boar", b)
	sim.step()
	sim.natural_defense.enabled = true
	return sim

func _ticks(sim: AetherionSimulation, count: int) -> void:
	for index in range(count):
		sim.step()

func _initialize() -> void:
	_test_defense()
	_test_priority()
	_test_mud()
	_test_hidden_core_and_reset()
	if failures == 0:
		print("PASS: provisional adjacent defense, explicit priority, mud timing, configuration and hidden-core regressions")
	quit(0 if failures == 0 else 1)

func _test_defense() -> void:
	var sim := _pair()
	sim.step()
	_check(sim.get_unit(1)["hp"] == 1 and sim.get_unit(2)["hp"] == 1, "Idle adjacent defense resolves damage simultaneously")
	_ticks(sim, 35)
	_check(sim.units.size() == 2 and sim.get_unit(1)["hp"] == 1, "Defense respects cooldown before exact expiry")
	sim.step()
	_check(sim.units.is_empty() and sim.players[0]["recovering"].has(1) and sim.players[1]["recovering"].has(2), "Defensive mutual defeat and individual recovery at cooldown expiry")
	sim = _pair(Vector2i(1, 1), Vector2i(6, 1))
	_ticks(sim, 20)
	_check(sim.get_unit(1)["cell"] == Vector2i(1, 1) and sim.get_unit(2)["cell"] == Vector2i(6, 1), "No autonomous pursuit or navigation")
	_check(sim.get_unit(1)["hp"] == 3 and sim.movement.active.is_empty(), "Distant enemies do not trigger defense")
	sim = _pair()
	sim.natural_defense.enabled = false
	sim.step()
	_check(sim.get_unit(1)["hp"] == 3 and sim.get_unit(2)["hp"] == 3, "Defense is configurable and can be disabled")
	for reverse_units in [false, true]:
		sim = AetherionSimulation.new()
		sim.queue_summon(0, "boar", Vector2i(3, 1))
		sim.queue_summon(1, "pigeon", Vector2i(5, 1))
		sim.queue_summon(1, "pigeon", Vector2i(4, 2))
		sim.step()
		sim.get_unit(1)["cell"] = Vector2i(4, 1) # Test fixture with two adjacent enemies.
		if reverse_units:
			sim.units.reverse()
		sim.natural_defense.enabled = true
		sim.step()
		_check(sim.get_unit(2).is_empty() and sim.get_unit(3)["hp"] == 2, "Provisional lowest-ID target independent of unit iteration order")

func _test_priority() -> void:
	var sim := _pair()
	sim.queue_destination(0, 1, Vector2i(0, 1))
	sim.step()
	_check(sim.get_unit(2)["hp"] == 3 and sim.get_unit(1)["hp"] == 1, "Explicit navigation suppresses outgoing defense but not incoming damage")
	_check(not sim.get_motion(1).is_empty(), "Incoming attack does not interrupt explicit movement")
	_ticks(sim, 8)
	_check(sim.orders.active.has(1) and sim.get_unit(2)["hp"] == 3, "Persistent destination remains higher priority than defense")
	sim = _pair()
	sim.queue_move(0, 1, Vector2i(3, 0))
	sim.step()
	_check(sim.get_unit(2)["hp"] == 3 and not sim.get_motion(1).is_empty(), "Legacy explicit step is not interrupted by natural attack")
	sim.step()
	_check(sim.get_unit(2)["hp"] == 3, "In-progress displacement suppresses natural defense")
	sim = AetherionSimulation.new()
	sim.queue_summon(0, "beaver", Vector2i(3, 1))
	sim.queue_summon(1, "beaver", Vector2i(4, 1))
	sim.queue_summon(1, "pigeon", Vector2i(6, 2))
	sim.step()
	sim.natural_defense.enabled = true
	sim.queue_target(0, 1, 3)
	sim.step()
	_check(sim.get_unit(2)["hp"] == 4 and sim.orders.active[1]["goal"]["target_id"] == 3, "Directed target is not replaced by adjacent lower-ID enemy")
	sim = _pair()
	sim.queue_destination(1, 1, Vector2i(0, 0))
	sim.step()
	_check(sim.get_unit(2)["hp"] == 1, "Unauthorized foreign order cannot suppress defense")
	sim = _pair()
	sim.queue_destination(0, 1, Vector2i(4, 1))
	sim.step()
	_check(sim.orders.active[1]["status"] == "blocked" and sim.get_unit(2)["hp"] == 3, "Even blocked explicit order outranks natural defense")

func _test_mud() -> void:
	var sim := AetherionSimulation.new()
	_check(sim.place_terrain(Vector2i(4, 1), "mud"), "Place test mud before match")
	_check(not sim.place_terrain(Vector2i(8, 1), "mud") and not sim.place_terrain(Vector2i(3, 1), "lava"), "Reject out-of-bounds and unsupported terrain")
	sim.queue_summon(0, "boar", Vector2i(3, 1))
	sim.step()
	_check(not sim.place_terrain(Vector2i(3, 1), "mud"), "Terrain layout cannot be changed mid-match")
	sim.queue_destination(0, 1, Vector2i(5, 1))
	sim.step()
	_check(sim.get_motion(1)["end_tick"] == 14 and sim.get_motion(1)["to"] == Vector2i(4, 1), "Entering mud doubles initial six ticks to twelve")
	_check(sim.movement.reservations.get(Vector2i(4, 1)) == 1 and sim.get_unit(1)["cell"] == Vector2i(3, 1), "Mud preserves origin and destination reservation")
	_ticks(sim, 11)
	_check(sim.tick_count == 13 and sim.get_unit(1)["cell"] == Vector2i(3, 1), "No early arrival into mud")
	sim.step()
	_check(sim.get_unit(1)["cell"] == Vector2i(4, 1), "Mud arrival at tick fourteen")
	sim.step()
	_check(sim.get_motion(1)["end_tick"] == 21, "Leaving mud for normal terrain takes six ticks")
	_check(sim.players[0]["essence"] == 1 and sim.get_unit(1)["hp"] == 3, "Terrain changes neither essence nor HP")
	sim = AetherionSimulation.new()
	sim.terrain.mud_multiplier = 3
	sim.place_terrain(Vector2i(3, 0), "mud")
	sim.queue_summon(0, "boar", Vector2i(3, 1))
	sim.step()
	sim.queue_move(0, 1, Vector2i(3, 0))
	sim.step()
	_check(sim.get_motion(1)["end_tick"] == 20, "Mud multiplier configurable independently of species")
	sim.terrain.mud_multiplier = 2
	_check(sim.get_motion(1)["end_tick"] == 20, "Committed duration unaffected by later configuration")
	sim = AetherionSimulation.new()
	sim.place_terrain(Vector2i(3, 0), "mud")
	sim.queue_summon(0, "boar", Vector2i(3, 1))
	sim.queue_summon(1, "boar", Vector2i(4, 1))
	sim.step()
	sim.queue_move(0, 1, Vector2i(3, 0))
	sim.step()
	sim.queue_attack(2, 1)
	sim.step()
	_check(sim.get_unit(1)["hp"] == 1 and sim.get_unit(2)["ready_tick"] == 39, "Mud leaves attack damage and cooldown unchanged")
	sim.get_unit(1)["hp"] = 1
	sim.get_unit(2)["ready_tick"] = 0 # Ready-attack fixture for lethal damage while on slow step.
	sim.queue_attack(2, 1)
	sim.step()
	_check(sim.get_unit(1).is_empty() and sim.movement.reservations.is_empty(), "Death releases slow-terrain reservation")

func _test_hidden_core_and_reset() -> void:
	var simulations: Array[AetherionSimulation] = []
	for core in [Vector2i(4, 1), Vector2i(6, 2)]:
		var sim := AetherionSimulation.new()
		sim.place_core(1, core)
		sim.place_terrain(Vector2i(4, 1), "mud")
		sim.natural_defense.enabled = true
		sim.queue_summon(0, "boar", Vector2i(3, 1))
		sim.queue_summon(1, "boar", Vector2i(6, 1))
		sim.step()
		sim.queue_target(0, 1, 2)
		simulations.append(sim)
	for tick in range(45):
		for sim in simulations:
			sim.queue_core_attack(1, 1)
			sim.step()
		_check(simulations[0].get_player_view(0) == simulations[1].get_player_view(0), "Defense, terrain and directed combat cannot reveal hidden core")
	simulations[0].reset()
	_check(simulations[0].terrain.cells.is_empty() and simulations[0].orders.active.is_empty() and simulations[0].movement.reservations.is_empty(), "Reset clears terrain, goals and reservations")
	_check(not simulations[0].players[1]["core_known_to"][0], "Reset preserves hidden-core policy")
