extends SceneTree

var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _touch(view, cell: Vector2i) -> void:
	var event := InputEventScreenTouch.new()
	event.pressed = true
	event.index = 0
	event.position = view._center(cell)
	view._unhandled_input(event)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 900)
	root.add_child(viewport)
	var view = load("res://scenes/battle_depth_demo.tscn").instantiate()
	viewport.add_child(view)
	view.set_process(false)
	view._process(0.05)
	_check(view.sim.natural.enabled and view.category_buttons.size() == 4, "New integrated scene enables species ecology and preserves card categories")
	view._choose_card("pig")
	_touch(view, Vector2i(1, 2))
	view._process(0.05)
	var id: int = view.selected_unit_id
	view.hold_button.pressed.emit()
	view._process(0.05)
	_check(view.sim.orders.active[id]["goal"]["kind"] == "hold", "Quick hold is an explicit persistent order")
	view.ecology_button.pressed.emit()
	view._process(0.05)
	_check(not view.sim.get_unit(id)["ecology_enabled"] and view.ecology_button.text.contains("no"), "Ecology toggle shows authoritative per-copy state")
	view.act_button.pressed.emit()
	_touch(view, Vector2i(2, 2))
	view._process(0.05)
	_check(view.sim.orders.active[id]["goal"]["kind"] == "act_at", "Touch resource in go-and-act mode submits a composite goal")
	view._process(0.125)
	var unit: Dictionary = view.sim.get_unit(id)
	var board: Rect2 = view._board_rect()
	var apparent: Vector2 = board.position + (view._unit_visual_cell(unit) + Vector2.ONE * 0.5) * board.size.x / 4
	_check(view._hit_unit(apparent).get("id") == id, "Animated actor and hit selection use the same apparent center as HP bars")
	for tick in range(22):
		view._process(0.05)
	_check(view.sim.get_unit(id).get("sheltered", false), "Contextual arrival performs refuge preparation and entry")
	_check(view.intent_label.text.contains("Refugio"), "Selected creature explains why ecology remains inactive in refuge")
	var before: Dictionary = view.sim.get_player_view(0)
	for frame in range(100):
		view._pose(view.sim.get_unit(id))
	_check(before == view.sim.get_player_view(0), "Extra rendered frames do not alter simulation")
	await process_frame
	await process_frame
	viewport.size = Vector2i(360, 800)
	await process_frame
	view._refresh_ui()
	_check(view._board_rect().end.y < 800 - view._dock_height(), "Portrait board clears the extended controls")
	_check(view.palette.size.x <= 336 and view.intent_label.size.x <= 336, "Cards and explanations fit a narrow portrait viewport")
	view._start_battle()
	_check(view.signals_view.effects.is_empty() and view.sim.natural.claims.is_empty() and not view.act_mode, "Restart clears ecological intentions, armed input and effects")
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/battle_demo.tscn", "F5 keeps the approved previous demo unchanged")
	viewport.queue_free()
	if failures == 0:
		print("PASS: Phase 22 touch controls, go-and-act, refuge, shared animation selection, restart and portrait layout")
	quit(0 if failures == 0 else 1)
