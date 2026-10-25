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
	_check(view.sim.units.size() == 4 and not view.auto_attack, "Tactical demo has four existing creatures and no old auto-attack producer")
	view._select_at_viewport_position(_point(view, Vector2i(1, 1)))
	_check(view.selected_unit_id == 1, "Select local creature")
	view._select_at_viewport_position(_point(view, Vector2i(6, 1)))
	view._process(0.05)
	_check(view.sim.orders.active[1]["goal"]["target_id"] == 3, "Enemy tap creates directed attack order")
	_check(view.sim.get_unit(3)["hp"] == 4, "No out-of-range attack")
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
	_check(view.sim.units.size() == 4 and view.sim.movement.reservations.is_empty(), "Demo restart restores fixture without stale reservations")
	viewport.queue_free()
	if failures == 0:
		print("PASS: tactical demo selection, distant goals, directed targets, status, stop and restart")
	quit(0 if failures == 0 else 1)
