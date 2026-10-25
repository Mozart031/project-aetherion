extends SceneTree

func _initialize() -> void:
	var sim := AetherionSimulation.new()
	assert(sim.players[0]["essence"] == 4)
	assert(sim.owns_cell(0, Vector2i(3, 1)))
	assert(not sim.owns_cell(0, Vector2i(4, 1)))
	sim.queue_summon(0, "boar", Vector2i(3, 1))
	sim.queue_summon(1, "turtle", Vector2i(4, 1))
	sim.step()
	assert(sim.units.size() == 2)
	assert(sim.players[0]["essence"] == 1)
	sim.queue_attack(1, 2)
	sim.queue_attack(2, 1)
	sim.step()
	assert(sim.get_unit(1)["hp"] == 2) # turtle deals minimum 1 damage despite armor
	assert(sim.get_unit(2)["hp"] == 4) # boar 3 - turtle armor 2 = 1
	for i in range(58):
		sim.step()
	assert(sim.players[0]["essence"] == 2)
	_test_simultaneous_attacks()
	_test_attack_cooldowns()
	_test_duplicate_attacks()
	print("PASS: Phase 20.1A simulation smoke tests")
	quit()


func _make_combat_pair(first_kind: String, second_kind: String) -> AetherionSimulation:
	var sim := AetherionSimulation.new()
	sim.queue_summon(0, first_kind, Vector2i(3, 1))
	sim.queue_summon(1, second_kind, Vector2i(4, 1))
	sim.step()
	assert(sim.units.size() == 2, "Combat fixture must summon both units")
	return sim


func _test_simultaneous_attacks() -> void:
	# Both command orders must allow a lethally hit unit to strike back.
	for reverse_order in [false, true]:
		var sim := _make_combat_pair("boar", "boar")
		var first_id: int = 2 if reverse_order else 1
		var second_id: int = 1 if reverse_order else 2
		sim.queue_attack(first_id, second_id)
		sim.queue_attack(second_id, first_id)
		sim.step()
		assert(sim.get_unit(1)["hp"] == 1, "First boar must receive 2 damage")
		assert(sim.get_unit(2)["hp"] == 1, "Second boar must receive 2 damage")
		while sim.tick_count < 37:
			sim.step()
		sim.queue_attack(first_id, second_id)
		sim.queue_attack(second_id, first_id)
		sim.step()
		assert(sim.tick_count == 38)
		assert(sim.units.is_empty(), "Both boars must die in the same tick")
		var defeat_count := 0
		for event in sim.events:
			if event["type"] == "defeated":
				defeat_count += 1
		assert(defeat_count == 2, "Both defeats must produce events")
		for player in sim.players:
			assert(player["recovering"].values()[0]["ready_tick"] == 278, "Both individual recovery timers start on defeat")
	print("PASS: simultaneous damage and mutual defeats in both command orders")


func _test_attack_cooldowns() -> void:
	var sim := _make_combat_pair("boar", "turtle")
	sim.queue_attack(1, 2)
	sim.queue_attack(2, 1)
	sim.step()
	assert(sim.get_unit(1)["ready_tick"] == 38)
	assert(sim.get_unit(2)["ready_tick"] == 46)
	# Retry every tick: rejected attacks must not extend either cooldown.
	for tick in range(3, 47):
		sim.queue_attack(1, 2)
		sim.queue_attack(2, 1)
		sim.step()
		assert(sim.tick_count == tick)
		assert(sim.get_unit(2)["hp"] == (4 if tick < 38 else 3), "Boar attacks again exactly at tick 38")
		assert(sim.get_unit(1)["hp"] == (2 if tick < 46 else 1), "Turtle attacks again exactly at tick 46")
		assert(sim.get_unit(1)["ready_tick"] == (38 if tick < 38 else 74))
		assert(sim.get_unit(2)["ready_tick"] == (46 if tick < 46 else 90))
	print("PASS: independent cooldowns, rejection before expiry and acceptance on expiry")


func _test_duplicate_attacks() -> void:
	var sim := _make_combat_pair("boar", "turtle")
	for repeat in range(3):
		sim.queue_attack(1, 2)
		sim.queue_attack(2, 1)
	sim.step()
	assert(sim.get_unit(1)["hp"] == 2, "Duplicate turtle commands must deal damage only once")
	assert(sim.get_unit(2)["hp"] == 4, "Duplicate boar commands must deal damage only once")
	assert(sim.get_unit(1)["ready_tick"] == 38)
	assert(sim.get_unit(2)["ready_tick"] == 46)
	assert(sim.queued_commands.is_empty(), "All commands must be consumed in their tick")
	# Duplicates received during cooldown must neither hit nor remain pending.
	for repeat in range(3):
		sim.queue_attack(1, 2)
		sim.queue_attack(2, 1)
	sim.step()
	assert(sim.get_unit(1)["hp"] == 2)
	assert(sim.get_unit(2)["hp"] == 4)
	assert(sim.get_unit(1)["ready_tick"] == 38)
	assert(sim.get_unit(2)["ready_tick"] == 46)
	assert(sim.queued_commands.is_empty())
	while sim.tick_count < 46:
		sim.step()
	assert(sim.get_unit(1)["hp"] == 2, "Rejected commands must not execute later")
	assert(sim.get_unit(2)["hp"] == 4, "Rejected commands must not execute later")
	print("PASS: duplicate commands apply once and are not deferred")
