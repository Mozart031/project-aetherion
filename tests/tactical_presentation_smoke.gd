extends SceneTree

var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _point(view, cell: Vector2i) -> Vector2:
	var board: Rect2 = view._board_rect()
	return board.position + (Vector2(cell.y, 7 - cell.x) + Vector2.ONE * 0.5) * board.size.x / 4.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(600, 1000)
	root.add_child(viewport)
	var scene: PackedScene = load("res://scenes/tactical_demo.tscn")
	var view = scene.instantiate()
	viewport.add_child(view)
	view.set_process(false)
	view._process(0.05)
	_check(view.sim.units.size() == 2 and not view.auto_attack, "Tactical demo has one authentic creature per player and no old auto-attack producer")
	_check(view.sim.natural_defense.enabled and view.sim.get_player_view(0)["terrain"].size() == 4, "Demo enables provisional defense and exposes four mud tiles")
	view._select_at_viewport_position(_point(view, Vector2i(1, 1)))
	_check(view.selected_unit_id == 1, "Select local creature")
	view._select_at_viewport_position(_point(view, Vector2i(6, 1)))
	view._process(0.05)
	_check(view.sim.orders.active[1]["goal"]["target_id"] == 2, "Enemy tap creates directed attack order")
	_check(view.sim.get_unit(2)["hp"] == 4, "No out-of-range attack")
	_check(view.info.text.contains("Selección: 1"), "Demo exposes selection and order status")
	view.sim.queue_stop(0, 1)
	view._process(0.05)
	_check(view.sim.orders.active.is_empty(), "Demo can interrupt an order")
	view._select_at_viewport_position(_point(view, Vector2i(3, 3)))
	view._process(0.05)
	_check(view.sim.orders.active[1]["goal"]["cell"] == Vector2i(3, 3), "Far cell tap queues a navigation goal")
	_check(not view.sim.get_player_view(0)["players"][1].has("core_cell"), "Tactical UI has no hidden enemy core")
	await process_frame
	await process_frame
	view._start_demo()
	view._process(0.05)
	_check(view.selected_unit_id == -1 and view.sim.orders.active.is_empty(), "Demo restart clears selection and orders")
	_check(view.sim.units.size() == 2 and view.sim.movement.reservations.is_empty(), "Demo restart restores fixture without stale reservations")
	_check(view.sim.terrain.cells.size() == 4 and view.info.text.contains("Barro ×2"), "Restart restores visible terrain and ecology legend")
	# Move onto the visible central mud with the real demo setup.
	view.sim.queue_destination(0, 1, Vector2i(3, 1))
	var saw_mud_step := false
	for tick in range(25):
		view._process(0.05)
		var motion: Dictionary = view.sim.get_motion(1)
		if not motion.is_empty() and motion["to"] == Vector2i(3, 1):
			saw_mud_step = true
			_check(int(motion["end_tick"]) - int(motion["start_tick"]) == 12, "Presented terrain changes authoritative duration")
			var elapsed := float(view.sim.tick_count - int(motion["start_tick"]))
			var fraction := clampf(elapsed / 12.0, 0, 1)
			_check(view._unit_visual_cell(view.sim.get_unit(1)).is_equal_approx(Vector2(1, 5 - fraction)), "Mud interpolation uses twelve ticks rather than a hardcoded six")
	_check(saw_mud_step, "Demo route actually traverses the visible mud under test")
	viewport.size = Vector2i(360, 800)
	view._process(0.01)
	_check(view.info.size.x <= 328, "Demo instructions adapt to narrow portrait viewport")
	await process_frame
	viewport.queue_free()
	if failures == 0:
		print("PASS: tactical demo selection, distant goals, directed targets, status, stop and restart")
	quit(0 if failures == 0 else 1)
