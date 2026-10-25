extends SceneTree

var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _ticks(sim: AetherionSimulation, count: int) -> void:
	for tick in range(count):
		sim.step()

func _initialize() -> void:
	var sim := AetherionSimulation.new()
	sim.place_terrain(Vector2i(3, 1), "mud")
	sim.queue_summon(0, "pig", Vector2i(3, 1))
	sim.step()
	_check(sim.get_unit(1)["hp"] == 4 and sim.players[0]["essence"] == 2, "Pig provisional stats and cost")
	sim.queue_special(0, 1, "roll")
	sim.step()
	_check(sim.actions.active.is_empty(), "No healing action while healthy")
	sim.get_unit(1)["hp"] = 2
	sim.queue_special(0, 1, "roll")
	sim.step()
	_check(sim.actions.active.has(1) and sim.get_unit(1)["hp"] == 2, "Roll has visible preparation rather than immediate heal")
	_ticks(sim, 5)
	_check(sim.get_unit(1)["hp"] == 2, "No premature special completion")
	sim.step()
	_check(sim.get_unit(1)["hp"] == 3 and sim.actions.active.is_empty(), "Roll heals one at exact completion")
	sim.queue_special(0, 1, "roll")
	sim.step()
	_check(sim.actions.active.is_empty(), "Special cooldown independent and enforced")
	sim = AetherionSimulation.new()
	sim.terrain.cells[Vector2i(3, 1)] = "cornfield" # Terrain fixture, no deployment rules bypass in gameplay.
	sim.queue_summon(0, "horse", Vector2i(3, 1))
	sim.step()
	sim.get_unit(1)["hp"] = 1
	sim.queue_special(0, 1, "forage")
	sim.step()
	_check(sim.terrain.cells.has(Vector2i(3, 1)), "Maizal remains until action completes")
	_ticks(sim, 6)
	_check(sim.get_unit(1)["hp"] == 3 and not sim.terrain.cells.has(Vector2i(3, 1)), "Horse consumes crop with visible board consequence and heals two")
	_check(sim.players[0]["recovering"].is_empty(), "Consuming terrain is not combat recovery")
	sim = AetherionSimulation.new()
	sim.queue_summon(0, "boar", Vector2i(3, 1))
	sim.queue_summon(1, "turtle", Vector2i(4, 1))
	sim.step()
	sim.queue_special(0, 1, "charge")
	sim.queue_attack(2, 1)
	sim.step()
	_check(sim.get_unit(1)["hp"] == 2 and sim.actions.active.has(1), "Preparation does not prevent incoming damage")
	_ticks(sim, 6)
	_check(sim.get_unit(1).get("charged", false), "Completed preparation arms the next strike")
	sim.queue_attack(1, 2)
	sim.step()
	_check(sim.get_unit(2)["hp"] == 3 and not sim.get_unit(1).get("charged", false), "Charge gives exactly one extra damage on the next accepted attack")
	sim.reset()
	_check(sim.actions.active.is_empty() and sim.units.is_empty(), "Reset clears preparations and buffs with units")
	sim.queue_summon(0, "boar", Vector2i(3, 1))
	sim.step()
	sim.queue_special(0, 1, "charge")
	sim.step()
	sim.queue_destination(0, 1, Vector2i(1, 1))
	sim.step()
	_check(sim.actions.active.is_empty() and sim.orders.active.has(1), "New explicit destination can interrupt preparation")
	_check(not sim.get_unit(1).get("charged", false), "Interrupted preparation has no effect")
	var reference := {}
	for reverse_order in [false, true]:
		sim.reset()
		sim.queue_summon(0, "boar", Vector2i(3, 1))
		sim.step()
		if reverse_order:
			sim.queue_special(0, 1, "charge")
		sim.queue_destination(0, 1, Vector2i(1, 1))
		if not reverse_order:
			sim.queue_special(0, 1, "charge")
		sim.step()
		_check(sim.orders.active.is_empty() and sim.actions.active.is_empty(), "Contradictory destination and special are both rejected")
		if reverse_order:
			_check(sim.get_player_view(0) == reference, "Mixed explicit command conflicts are deterministic")
		else:
			reference = sim.get_player_view(0)
	if failures == 0:
		print("PASS: provisional creature stats, timed specials, board consequences, interruption and damage regressions")
	quit(0 if failures == 0 else 1)
