extends SceneTree

var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _tick(sim: AetherionSimulation, count: int) -> void:
	for index in range(count):
		sim.step()

func _pig() -> AetherionSimulation:
	var sim := AetherionSimulation.new()
	sim.place_terrain(Vector2i(3, 1), "mud")
	sim.queue_summon(0, "pig", Vector2i(1, 1))
	sim.step()
	sim.get_unit(1)["hp"] = 2
	sim.natural.enabled = true
	sim.natural_defense.enabled = true
	return sim

func _initialize() -> void:
	_test_recovery_and_rest()
	_test_player_priority()
	_test_claims_and_copies()
	_test_boar_and_golem()
	_test_boundaries_and_privacy()
	_test_damage_and_interruptions()
	if failures == 0:
		print("PASS: situational species profiles, bounded routes, resource claims, explicit authority, rest and hidden cores")
	quit(0 if failures == 0 else 1)

func _test_recovery_and_rest() -> void:
	var sim := _pig()
	var moves := 0
	var rolls := 0
	for index in range(160):
		sim.step()
		for event in sim.events:
			if event["type"] == "move_started":
				moves += 1
			if event["type"] == "special_completed" and event["kind"] == "roll":
				rolls += 1
	_check(sim.get_unit(1)["cell"] == Vector2i(3, 1) and sim.get_unit(1)["hp"] == 4, "Wounded pig reaches local mud and recovers")
	_check(moves == 2 and rolls == 2, "Only purposeful steps; repeated recovery stays in place and respects cooldown")
	_check(sim.natural.planner.active.is_empty() and sim.natural.claims.is_empty(), "Healthy pig rests and releases intention")
	var cell: Vector2i = sim.get_unit(1)["cell"]
	_tick(sim, 100)
	_check(sim.get_unit(1)["cell"] == cell and sim.actions.active.is_empty(), "No aimless movement or healthy recovery loops")
	sim = AetherionSimulation.new()
	sim.place_terrain(Vector2i(2, 1), "cornfield")
	sim.queue_summon(0, "horse", Vector2i(1, 1))
	sim.step()
	sim.get_unit(1)["hp"] = 2
	sim.natural.enabled = true
	_tick(sim, 30)
	_check(sim.get_unit(1)["hp"] == 4 and not sim.terrain.cells.has(Vector2i(2, 1)), "Horse seeks and consumes a single nearby ration")
	_check(sim.players[0]["recovering"].is_empty(), "Natural crop consumption does not create combat recovery")
	sim.reset()
	sim.place_terrain(Vector2i(2, 1), "cornfield")
	sim.queue_summon(0, "horse", Vector2i(1, 1))
	sim.step()
	sim.get_unit(1)["hp"] = 3
	_tick(sim, 40)
	_check(sim.get_unit(1)["cell"] == Vector2i(1, 1) and sim.terrain.cells.has(Vector2i(2, 1)), "Horse does not waste a ration for only one missing HP")
	sim.get_unit(1)["hp"] = 2
	sim.cards.terrain_owners[Vector2i(2, 1)] = 1
	_tick(sim, 40)
	_check(sim.get_unit(1)["cell"] == Vector2i(1, 1), "Horse does not automatically consume rival crops")

func _test_player_priority() -> void:
	var sim := _pig()
	sim.step()
	var committed: Vector2i = sim.get_motion(1)["to"]
	sim.queue_hold(0, 1)
	sim.step()
	_check(sim.natural.claims.is_empty() and sim.orders.active[1]["goal"]["kind"] == "hold", "Explicit hold releases natural resource goal")
	_tick(sim, 100)
	_check(sim.get_unit(1)["cell"] == committed and sim.get_unit(1)["hp"] == 2, "Hold finishes committed step and prevents natural recovery trips")
	sim.queue_stop(0, 1)
	_tick(sim, 35)
	_check(sim.get_unit(1)["cell"] == Vector2i(3, 1) and sim.get_unit(1)["hp"] > 2, "Stop keeps its old meaning: cancel order and permit ecology again")
	sim = _pig()
	sim.step()
	sim.queue_ecology(0, 1, false)
	_tick(sim, 50)
	_check(sim.get_unit(1)["cell"] == Vector2i(2, 1) and not sim.get_unit(1)["ecology_enabled"], "Disable ecology preserves accepted step but prevents further natural movement")
	_check(sim.natural.claims.is_empty(), "Disable releases resource intention")
	sim.queue_ecology(1, 1, true)
	sim.step()
	_check(not sim.get_unit(1)["ecology_enabled"], "Rival cannot toggle another player's ecology")
	sim.queue_ecology(0, 1, true)
	_tick(sim, 40)
	_check(sim.get_unit(1)["hp"] > 2, "Player can enable situational ecology again")
	sim = _pig()
	sim.queue_summon(1, "pig", Vector2i(6, 1))
	sim.step()
	sim.queue_destination(0, 1, Vector2i(6, 1))
	_tick(sim, 30)
	_check(sim.orders.active[1]["status"] == "blocked" and sim.natural.claims.is_empty(), "Blocked explicit order never yields to an instinct")
	# Explicit refuge is persistent even without a navigation goal.
	sim = AetherionSimulation.new()
	sim.place_terrain(Vector2i(1, 1), "cave")
	sim.place_terrain(Vector2i(2, 1), "mud")
	sim.queue_summon(0, "pig", Vector2i(1, 1))
	sim.step()
	sim.get_unit(1)["hp"] = 2
	sim.queue_special(0, 1, "enter")
	_tick(sim, 7)
	sim.natural.enabled = true
	_tick(sim, 80)
	_check(sim.get_unit(1).get("sheltered", false) and sim.get_unit(1)["cell"] == Vector2i(1, 1), "Natural recovery cannot abandon player refuge")

func _test_claims_and_copies() -> void:
	var sim := AetherionSimulation.new()
	sim.place_terrain(Vector2i(2, 1), "mud")
	sim.queue_summon(0, "pig", Vector2i(1, 1))
	sim.queue_summon(1, "pig", Vector2i(4, 2))
	sim.step()
	# Rival legally enters the local half by explicit order before both seek mud.
	sim.queue_destination(1, 2, Vector2i(2, 2))
	_tick(sim, 20)
	sim.queue_stop(1, 2)
	sim.step()
	sim.get_unit(1)["hp"] = 3
	sim.get_unit(2)["hp"] = 3
	sim.natural.enabled = true
	sim.step()
	_check(sim.natural.claims[Vector2i(2, 1)]["unit_id"] == 1, "Equal-age resource requests from opposing authentic pigs use stable ID")
	_check(sim.get_motion(2).is_empty(), "Second player does not contend for claimed mud")
	_tick(sim, 30)
	_check(sim.get_unit(1)["hp"] == 4 and sim.get_unit(2)["hp"] == 3, "Opposing authentic creatures keep independent health and state")
	sim.queue_destination(0, 1, Vector2i(0, 1))
	_tick(sim, 35)
	_check(sim.get_unit(2)["hp"] == 4, "Waiting rival recovers after an explicit order frees mud")
	sim = _pig()
	sim.step()
	sim.get_unit(1)["hp"] = 0 # Death fixture, then normal cleanup.
	sim.step()
	_check(sim.natural.claims.is_empty() and sim.natural.planner.active.is_empty(), "Death releases resource claims and natural goals")
	sim.reset()
	_check(sim.natural.threats.is_empty() and sim.natural.explanations.is_empty(), "Reset clears species memory")

func _test_boar_and_golem() -> void:
	var sim := AetherionSimulation.new()
	sim.queue_summon(0, "boar", Vector2i(3, 1))
	sim.queue_summon(1, "pig", Vector2i(4, 1))
	sim.step()
	sim.natural.enabled = true
	sim.natural_defense.enabled = true
	_tick(sim, 10)
	_check(sim.get_unit(2).is_empty() and sim.get_unit(1)["cell"] == Vector2i(3, 1), "Boar prepares charge and reacts locally without pursuing")
	sim.natural.record_hit(9, 1, 20)
	sim.natural.record_hit(8, 1, 20)
	_check(sim.natural.preferred_target(sim.get_unit(1), [7, 8, 9], 21) == 8, "Recent aggressor tie uses smallest ID")
	_check(sim.natural.preferred_target(sim.get_unit(1), [7, 8, 9], 61) == 7, "Threat expires after forty ticks")
	sim = AetherionSimulation.new()
	sim.queue_summon(0, "golem", Vector2i(3, 1))
	sim.queue_play_card(1, "fence", Vector2i(4, 1))
	sim.step()
	sim.natural.enabled = true
	sim.natural_defense.enabled = true
	_tick(sim, 10)
	_check(sim.cards.buildings.is_empty() and sim.get_unit(1)["cell"] == Vector2i(3, 1), "Idle golem demolishes adjacent rival structure without marching")
	sim.reset()
	sim.natural.enabled = false
	sim.queue_summon(0, "golem", Vector2i(3, 1))
	sim.queue_summon(1, "pig", Vector2i(4, 2))
	sim.queue_play_card(1, "fence", Vector2i(4, 1))
	sim.step()
	sim.get_unit(2)["cell"] = Vector2i(3, 2)
	sim.natural.enabled = true
	sim.step()
	_check(sim.cards.buildings.size() == 1 and sim.get_unit(2).is_empty(), "Golem prioritizes immediate creature threat over demolition")

func _test_boundaries_and_privacy() -> void:
	var sim := AetherionSimulation.new()
	sim.place_terrain(Vector2i(4, 1), "mud")
	sim.queue_summon(0, "pig", Vector2i(3, 1))
	sim.step()
	sim.get_unit(1)["hp"] = 2
	sim.natural.enabled = true
	_tick(sim, 40)
	_check(sim.get_unit(1)["cell"] == Vector2i(3, 1), "Natural navigation never crosses territorial half")
	sim = _pig()
	sim.queue_play_card(0, "fence", Vector2i(2, 1))
	_tick(sim, 40)
	_check(sim.get_unit(1)["cell"] == Vector2i(1, 1), "Two-step limit measures actual route around obstacles")
	var pair: Array[AetherionSimulation] = []
	for core in [Vector2i(4, 1), Vector2i(6, 2)]:
		sim = AetherionSimulation.new()
		sim.place_core(1, core)
		sim.place_terrain(Vector2i(2, 1), "mud")
		sim.queue_summon(0, "pig", Vector2i(1, 1))
		sim.queue_summon(0, "pigeon", Vector2i(0, 0))
		sim.step()
		sim.get_unit(1)["hp"] = 2
		sim.natural.enabled = true
		pair.append(sim)
	for tick in range(100):
		for candidate in pair:
			candidate.queue_core_attack(2, 1)
			candidate.step()
		_check(pair[0].get_player_view(0) == pair[1].get_player_view(0), "Species decisions and explanations cannot reveal hidden core")

func _test_damage_and_interruptions() -> void:
	var sim := AetherionSimulation.new()
	sim.place_terrain(Vector2i(0, 1), "mud")
	sim.queue_summon(0, "pig", Vector2i(2, 1))
	sim.queue_summon(1, "horse", Vector2i(4, 1))
	sim.step()
	sim.get_unit(1)["hp"] = 2
	sim.get_unit(2)["cell"] = Vector2i(2, 2) # Adjacent attacker fixture.
	sim.natural.enabled = true
	sim.step()
	_check(sim.movement.active.has(1), "Natural path commits a normal reserved step")
	sim.queue_attack(2, 1)
	sim.step()
	_check(sim.get_unit(1).is_empty() and sim.get_motion(1).is_empty() and sim.natural.claims.is_empty(), "Accepted damage kills a naturally moving creature and frees its claim/reservation")
	_check(sim.players[0]["recovering"].has(1), "Natural movement grants no immunity or exemption from per-copy combat recovery")
	sim = AetherionSimulation.new()
	sim.place_terrain(Vector2i(1, 1), "mud")
	sim.queue_summon(0, "pig", Vector2i(1, 1))
	sim.step()
	sim.get_unit(1)["hp"] = 3
	sim.natural.enabled = true
	sim.step()
	var ready: int = sim.get_unit(1)["special_ready_tick"]
	_check(sim.actions.active[1]["source"] == "natural", "Instinct uses the existing timed special action")
	sim.queue_hold(0, 1)
	sim.queue_hold(0, 1)
	sim.step()
	_tick(sim, 10)
	_check(sim.actions.active.is_empty() and sim.get_unit(1)["hp"] == 3 and sim.get_unit(1)["special_ready_tick"] == ready, "Duplicate hold interrupts preparation once without healing or refunding spent cooldown")
	sim.get_unit(1)["hp"] = 0
	sim.step()
	_check(sim.actions.outcomes.is_empty(), "Death cleans finished/interrupted action outcomes as well as active preparations")
