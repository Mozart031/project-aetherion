extends SceneTree

var failures := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _point(view, logical: Vector2i) -> Vector2:
	var board: Rect2 = view._board_rect()
	var visual := Vector2(logical.y, 7 - logical.x)
	return view.get_global_transform_with_canvas() * (board.position + (visual + Vector2.ONE * 0.5) * board.size.x / 4.0)

func _touch(view, logical: Vector2i) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	event.position = _point(view, logical)
	view._unhandled_input(event)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 900)
	root.add_child(viewport)
	var scene: PackedScene = load("res://scenes/main.tscn")
	var view = scene.instantiate()
	viewport.add_child(view)
	view.set_process(false)
	view.auto_attack = false
	view._process(0.05)
	_touch(view, Vector2i(3, 1))
	_check(view.selected_unit_id == 1, "Touch selects own creature")
	_touch(view, Vector2i(3, 0))
	_check(view.sim.queued_commands.size() == 1, "Touch sends one movement intent")
	_check(view.sim.get_unit(1)["cell"] == Vector2i(3, 1), "UI does not change logical position")
	var mouse := InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = _point(view, Vector2i(3, 0))
	view._unhandled_input(mouse)
	_check(view.sim.queued_commands.size() == 1, "Emulated mouse after touch cannot duplicate movement")
	view._process(0.05)
	_check(view.sim.tick_count == 2 and view.sim.get_motion(1).get("end_tick") == 8, "Simulation accepts and times the order")
	_check(view._unit_visual_cell(view.sim.get_unit(1)).is_equal_approx(Vector2(1, 4)), "Interpolation starts at visual origin")
	view._process(0.025)
	_check(view.sim.tick_count == 2, "Sub-tick frame does not advance simulation")
	_check(view._unit_visual_cell(view.sim.get_unit(1)).is_equal_approx(Vector2(1.0 - 1.0 / 12.0, 4)), "Interpolation progresses between ticks")
	for iteration in range(5):
		view._process(0.025)
	_check(view._unit_visual_cell(view.sim.get_unit(1)).is_equal_approx(Vector2(0.5, 4)), "Midpoint after three ticks")
	_check(view.sim.get_unit(1)["cell"] == Vector2i(3, 1), "Visual progress never writes logical cell")
	var board: Rect2 = view._board_rect()
	mouse.device = 0
	mouse.position = board.position + Vector2(1.0, 4.5) * board.size.x / 4.0
	view._unhandled_input(mouse)
	_check(view.selected_unit_id == 1, "Click follows the rendered moving miniature")
	viewport.size = Vector2i(900, 600)
	_check(view._unit_visual_cell(view.sim.get_unit(1)).is_equal_approx(Vector2(0.5, 4)), "Resize does not change motion progress")
	for iteration in range(6):
		view._process(0.025)
	_check(view.sim.tick_count == 8 and view.sim.get_unit(1)["cell"] == Vector2i(3, 0), "Arrive after six ticks")
	_check(view._unit_visual_cell(view.sim.get_unit(1)).is_equal_approx(Vector2(0, 4)), "Visual and logical destination agree")
	_check(view.selected_unit_id == 1, "Selection follows arrival")
	# A real mouse click can send the next technical step.
	mouse.position = _point(view, Vector2i(2, 0))
	view._unhandled_input(mouse)
	_check(view.sim.queued_commands.size() == 1, "Mouse sends adjacent step")
	view._process(0.05)
	_check(view.sim.get_motion(1).get("to") == Vector2i(2, 0), "Mouse movement accepted")
	_touch(view, Vector2i(4, 1))
	_check(view.selected_unit_id == -1, "Enemy remains unselectable")
	_check(view.sim.get_player_view(0)["players"][1].get("core_cell") == null, "UI view cannot access hidden enemy core")
	await process_frame
	await process_frame
	viewport.queue_free()
	if failures == 0:
		print("PASS: movement mouse/touch input, emulation deduplication, smooth interpolation and resize")
	quit(0 if failures == 0 else 1)
