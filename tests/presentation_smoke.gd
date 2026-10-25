extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _point(view, cell: Vector2i) -> Vector2:
	var board: Rect2 = view._board_rect()
	# Independent expected rotation for the current local player (0).
	var visual_cell := Vector2i(cell.y, 7 - cell.x)
	var local_point := board.position + (Vector2(visual_cell) + Vector2.ONE * 0.5) * (board.size.x / 4.0)
	return view.get_global_transform_with_canvas() * local_point

func _click(view, point: Vector2, pressed: bool = true, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = pressed
	view._unhandled_input(event)

func _touch(view, point: Vector2, pressed: bool = true, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = pressed
	event.index = index
	view._unhandled_input(event)

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(600, 900)
	root.add_child(viewport)
	var scene: PackedScene = load("res://scenes/main.tscn")
	var view = scene.instantiate()
	viewport.add_child(view)
	view.set_process(false)
	view.sim.step() # Resolve the demo summons without changing simulation rules.
	_check(view.selected_unit_id == -1, "Nothing selected at startup")
	var initial_units: Array = view.sim.units.duplicate(true)
	var initial_players: Array = view.sim.players.duplicate(true)
	_click(view, _point(view, Vector2i(3, 1)))
	_check(view.selected_unit_id == 1, "Mouse selects own creature")
	_click(view, _point(view, Vector2i(4, 1)), false)
	_click(view, _point(view, Vector2i(4, 1)), true, MOUSE_BUTTON_RIGHT)
	_check(view.selected_unit_id == 1, "Release and right click do not change selection")
	_touch(view, _point(view, Vector2i(4, 1)), true, 1)
	_check(view.selected_unit_id == 1, "Secondary touch does not change selection")
	_click(view, _point(view, Vector2i(4, 1)))
	_check(view.selected_unit_id == -1, "Enemy creatures cannot be selected")
	_touch(view, _point(view, Vector2i(3, 1)))
	_check(view.selected_unit_id == 1, "Primary touch selects own creature")
	_touch(view, _point(view, Vector2i(4, 1)), false)
	_check(view.selected_unit_id == 1, "Touch release does not change selection")
	_click(view, _point(view, Vector2i(3, 1)))
	_check(view.selected_unit_id == 1, "Emulated mouse after touch keeps selection")
	_click(view, _point(view, Vector2i(0, 0)))
	_check(view.selected_unit_id == -1, "Empty cell clears selection")
	_touch(view, _point(view, Vector2i(3, 1)))
	_click(view, Vector2(-10, -10))
	_check(view.selected_unit_id == -1, "Outside board clears selection")
	for size in [Vector2i(360, 800), Vector2i(1200, 600)]:
		viewport.size = size
		var board: Rect2 = view._board_rect()
		_check(Rect2(Vector2.ZERO, Vector2(size)).encloses(board), "Board fits resized viewport")
		_check(is_equal_approx(board.size.y, board.size.x * 2.0), "Board has vertical 4:8 aspect")
		_check(_point(view, Vector2i(4, 1)).y < board.get_center().y, "Enemy is above midpoint")
		_check(_point(view, Vector2i(3, 1)).y > board.get_center().y, "Local creature is below midpoint")
		for y in range(4):
			for x in range(8):
				var cell := Vector2i(x, y)
				_check(view._cell_at_viewport_position(_point(view, cell)) == cell, "Every visual cell maps to its logical cell after resize")
		_check(view._cell_at_viewport_position(board.position) == Vector2i(7, 0), "Top left maps to logical far enemy corner")
		_check(view._cell_at_viewport_position(board.end - Vector2.ONE * 0.01) == Vector2i(0, 3), "Bottom right maps to logical local corner")
		_check(view._cell_at_viewport_position(board.position - Vector2(0.01, 0)) == Vector2i(-1, -1), "Left boundary outside rejected")
		_check(view._cell_at_viewport_position(board.position - Vector2(0, 0.01)) == Vector2i(-1, -1), "Top boundary outside rejected")
		_click(view, _point(view, Vector2i(3, 1)))
		_check(view.selected_unit_id == 1, "Selection follows viewport resize")
		_check(view._cell_at_viewport_position(board.end) == Vector2i(-1, -1), "Bottom/right boundary excluded")
	view.position = Vector2(12, 20)
	view.scale = Vector2(0.8, 0.8)
	_touch(view, _point(view, Vector2i(3, 1)))
	_check(view.selected_unit_id == 1, "Input respects canvas transformation")
	_check(view.sim.units == initial_units, "Selection must not mutate units")
	_check(view.sim.players == initial_players, "Selection must not mutate player state")
	_check(view.sim.queued_commands.is_empty(), "Selection must not generate combat commands")
	_check(is_equal_approx(view._health_fraction(view.sim.get_unit(1)), 1.0), "Full HP bar")
	view.sim.queue_attack(1, 2)
	view.sim.queue_attack(2, 1)
	view.sim.step()
	_check(is_equal_approx(view._health_fraction(view.sim.get_unit(1)), 2.0 / 3.0), "Own HP bar follows damage")
	_check(is_equal_approx(view._health_fraction(view.sim.get_unit(2)), 0.8), "Enemy HP bar follows damage")
	# Let the unchanged demo combat defeat the selected boar through real ticks.
	view._process(0.25)
	_check(view.selected_unit_id == 1, "Selection survives while creature is alive")
	for iteration in range(18):
		view._process(0.25)
	_check(view.sim.get_unit(1).is_empty(), "Demo combat defeats selected boar")
	_check(view.selected_unit_id == -1, "Selection clears after defeat during multi-tick frame")
	# These snapshots test drawing bounds without modifying the simulation state.
	_check(is_zero_approx(view._health_fraction({"kind": "boar", "hp": -1})), "HP bar clamps at zero")
	_check(is_equal_approx(view._health_fraction({"kind": "boar", "hp": 5}), 1.0), "HP bar clamps at maximum")
	await process_frame
	await process_frame
	viewport.queue_free()
	if failures == 0:
		print("PASS: vertical 4x8 selection, input coordinates, HP bars and defeat cleanup")
	quit(0 if failures == 0 else 1)
