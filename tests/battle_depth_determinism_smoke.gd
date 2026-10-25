extends SceneTree

var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _input(sim: AetherionSimulation) -> void:
	match sim.tick_count:
		0:
			sim.place_terrain(Vector2i(3, 0), "mud")
			sim.place_terrain(Vector2i(2, 3), "cornfield")
			sim.queue_play_card(0, "pig", Vector2i(3, 0))
			sim.queue_play_card(0, "pig", Vector2i(3, 3))
			sim.queue_play_card(1, "pig", Vector2i(4, 0))
			sim.queue_play_card(1, "pig", Vector2i(4, 3))
		30: sim.queue_hold(0, 1)
		50: sim.queue_stop(0, 1)
		80: sim.queue_destination(0, 2, Vector2i(2, 0))
		100: sim.queue_ecology(0, 1, false)
		120: sim.queue_ecology(0, 1, true)
		160: sim.queue_act_at(0, 1, "roll", Vector2i(3, 0))

func _replay(fps: float) -> Array:
	var sim := AetherionSimulation.new()
	sim.natural.enabled = true
	sim.natural_defense.enabled = true
	var history := []
	var accumulator := 0.0
	while sim.tick_count < 350:
		accumulator += 1.0 / fps
		while accumulator + 0.000001 >= sim.TICK_SECONDS and sim.tick_count < 350:
			_input(sim)
			sim.step()
			history.append(sim.get_player_view(0))
			accumulator -= sim.TICK_SECONDS
	return history

func _initialize() -> void:
	var expected := _replay(20)
	_check(expected == _replay(30) and expected == _replay(120), "Same tick inputs produce identical states/events across render rates")
	var pair: Array[AetherionSimulation] = []
	for reverse in [false, true]:
		var sim := AetherionSimulation.new()
		sim.natural.enabled = true
		sim.queue_play_card(0, "pig", Vector2i(1, 1))
		sim.queue_play_card(0, "pig", Vector2i(2, 2))
		sim.step()
		var commands := [{"type": "order", "player": 0, "unit_id": 1, "goal": {"kind": "move_to", "cell": Vector2i(2, 1)}}, {"type": "order", "player": 0, "unit_id": 2, "goal": {"kind": "move_to", "cell": Vector2i(2, 1)}}]
		if reverse:
			commands.reverse()
		sim.queued_commands.append_array(commands)
		sim.step()
		pair.append(sim)
	_check(pair[0].movement.active.is_empty() and pair[0].get_player_view(0) == pair[1].get_player_view(0), "Same-cell explicit conflicts reject both independently of command order with ecology enabled")
	if failures == 0:
		print("PASS: Phase 22 tick replay across FPS and deterministic simultaneous conflicts")
	quit(0 if failures == 0 else 1)
