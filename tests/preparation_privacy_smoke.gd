extends SceneTree

const Scene = preload("res://scenes/preparation_demo.tscn")
var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _new_view(rival: bool, observer: int = 0):
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 900)
	root.add_child(viewport)
	var demo = Scene.instantiate()
	demo.fixed_rival_preparation = rival
	demo.local_player = observer
	viewport.add_child(demo)
	demo.set_process(false)
	return demo

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for observer in [0, 1]:
		var quiet = _new_view(false, observer)
		var active = _new_view(true, observer)
		await process_frame
		await process_frame
		for demo in [quiet, active]:
			demo._begin("terrain")
			var own := Vector2i(observer * 4 + 2, 1)
			demo._confirm_at(demo.board.center_on_viewport(own))
		for tick in range(600):
			if tick == 30:
				# Private opponent rejections and economy must not affect UI state.
				active.sim.queue_play_card(1 - observer, "pig", Vector2i((1 - observer) * 4 + 1, 1), -1, 10)
			if tick == 90:
				active.sim.players[1 - observer]["recovering"][999] = {"kind": "golem", "ready_tick": 750}
			if tick == 120:
				for demo in [quiet, active]:
					demo._begin("terrain") # Mud is now above; highlights own sections only.
					demo._hover_at(demo.board.center_on_viewport(Vector2i((1 - observer) * 4 + 3, 3)))
			quiet._process(0.05)
			active._process(0.05)
			if tick < 599:
				_check(quiet.presentation_snapshot() == active.presentation_snapshot(), "Rival layouts, rejections, essence/recovery and actions cannot leak through UI/effects/counters/highlights at tick %d" % (tick + 1))
				_check(active.presentation_snapshot()["board"]["sound_cues"].is_empty(), "Hidden activity produces no sound cues")
				_check(active.board.hit_building(active.board.center_on_viewport(Vector2i((1 - observer) * 4, 2))).is_empty(), "Sealed constructions cannot be hit-tested")
		_check(active.join_count == 1 and active.joined_tick == 600 and not active.board.visual_snapshot()["sealed"], "Public board_joined reveals the rival only on tick 600")
		_check(active.board.visual_snapshot()["buildings"].size() == 1 and quiet.board.visual_snapshot()["buildings"].is_empty(), "Previously private constructions become observable at join")
		_check(active.sim.players[1 - observer]["essence"] == 8, "Paid fixed rival setup follows normal essence regeneration")
		var snapshot: Dictionary = active.presentation_snapshot()
		active.sim.players[1 - observer]["essence"] = 3
		active.sim.players[1 - observer]["recovering"].clear()
		active._accept_view(active.sim.get_player_view(observer))
		_check(snapshot == active.presentation_snapshot() and active.join_count == 1, "Post-join private rival economy stays hidden and repeated join delivery does not replay transition")
		for node in active.find_children("*", "", true, false):
			_check(not (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D), "The demo contains no audio producer that could bypass filtered events")
		quiet.get_parent().free()
		active.get_parent().free()
	_test_cross_fps()
	if failures == 0:
		print("PASS: symmetric visual privacy through tick 599 including effects/audio/counters/highlights, public reveal, private economy after join and fixed-step determinism")
	quit(0 if failures == 0 else 1)

func _replay(fps: float) -> Array:
	var demo = _new_view(true)
	var trace := []
	demo.simulation_stepped.connect(func():
		trace.append([demo.sim.get_player_view(0), demo.sim.get_player_view(1), demo.phase_label.text, demo.join_count])
		match demo.sim.tick_count:
			120:
				demo._begin("terrain")
				demo._confirm_at(demo.board.center_on_viewport(Vector2i(2, 1)))
			240:
				demo._begin("construction")
				demo._confirm_at(demo.board.center_on_viewport(Vector2i(0, 0)))
			600:
				demo._begin("creature")
				demo._confirm_at(demo.board.center_on_viewport(Vector2i(3, 0)))
			601:
				demo.sim.queue_destination(0, 1, Vector2i(4, 0))
			610:
				demo.sim.queue_target(0, 1, int(demo.sim.cards.buildings.filter(func(b): return b["owner"] == 1)[0]["id"]))
	)
	while demo.sim.tick_count < 620:
		demo._process(1.0 / fps)
	_check(demo.join_count == 1 and demo.board.layout.progress() == 1, "The join completes once at all tested frame rates")
	_check(demo.sim.units.size() == 1 and int(demo.sim.cards.buildings.filter(func(b): return b["owner"] == 1)[0]["hp"]) < 4, "The deterministic replay includes paid placements, movement and combat through the join")
	demo.get_parent().free()
	return trace

func _test_cross_fps() -> void:
	var baseline := _replay(20.0)
	_check(baseline == _replay(30.0) and baseline == _replay(120.0), "Every logical tick, filtered event, countdown and join event matches at 20/30/120 FPS")
	var late = _new_view(true)
	while late.sim.tick_count < 598:
		late._process(0.05)
	late._process(0.25)
	_check(late.sim.tick_count == 603 and late.join_count == 1 and late.joined_tick == 600, "A frame resolving several ticks never misses board_joined")
	late.restart()
	_check(late.join_count == 0 and late.board.visual_snapshot()["sealed"] and late.board.feedback.effects.is_empty(), "Restart clears reveal, feedback and transition state")
	late.get_parent().free()
