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
	assert(sim.get_unit(1)["hp"] == 3) # turtle attack is absorbed to minimum 1
	assert(sim.get_unit(2)["hp"] == 4) # boar 3 - turtle armor 2 = 1
	for i in range(58):
		sim.step()
	assert(sim.players[0]["essence"] == 2)
	print("PASS: Phase 20 simulation smoke tests")
	quit()
