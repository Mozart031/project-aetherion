extends SceneTree

var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _click(view, cell: Vector2i) -> void:
	var board: Rect2 = view._board_rect()
	var point := board.position + (Vector2(cell.y, 7 - cell.x) + Vector2.ONE * 0.5) * board.size.x / 4.0
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	view._unhandled_input(event)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 900)
	root.add_child(viewport)
	var scene: PackedScene = load("res://scenes/battle_demo.tscn")
	var view = scene.instantiate()
	viewport.add_child(view)
	view.set_process(false)
	view._process(0.05)
	_check(view.category_buttons.size() == 4 and view.palette.get_child_count() == 4, "Four card spaces and four creature choices accessible without covering battle")
	_check(view.sim.units.size() == 2 and view.sim.units[0]["owner"] == 1, "Scenario starts with stationary defenders and local deployment freedom")
	view._choose_card("pig")
	_click(view, Vector2i(3, 1))
	_check(view.sim.get_unit(3).is_empty(), "UI sends intent rather than creating creatures")
	view._process(0.05)
	_check(view.sim.get_unit(3)["kind"] == "pig" and view.selected_unit_id == 3, "Card deployment creates and selects own instance")
	_check(view.sim.players[0]["essence"] == 2 and view.header.text.contains("Esencia 2/8"), "Visible essence matches authoritative payment")
	view.sim.get_unit(3)["hp"] = 1 # Wounded fixture to inspect healing feedback.
	view._choose_category("trick")
	_check(view.palette.get_child_count() == 1, "Trick accessible from its dedicated space")
	view._choose_card("heal")
	_click(view, Vector2i(3, 1))
	view._process(0.05)
	_check(view.sim.get_unit(3)["hp"] == 3 and view.sim.players[0]["essence"] == 0, "Trick targets own creature and spends essence")
	_check(view.feedback.any(func(effect): return effect["type"] == "healed"), "Healing has persistent visual feedback")
	_check(not view.special_button.disabled and view.special_button.text == "Revolcarse", "Contextual action matches pig on mud")
	view.special_button.pressed.emit()
	view._process(0.05)
	_check(view.sim.actions.active.has(3) and view.special_button.disabled, "Action button sends a timed preparation with progress state")
	for tick in range(6):
		view._process(0.05)
	_check(view.sim.get_unit(3)["hp"] == 4, "Action visibly completes and heals")
	_check(view.feedback.any(func(effect): return effect["type"] == "special_completed"), "Completion persists beyond a single simulation tick")
	_check(view.detail.text.contains("acción"), "Special cooldown countdown is visible without treating it as card recovery")
	view._choose_category("terrain")
	_check(view.palette.get_child_count() == 3, "Cornfield, cave and mud accessible from terrain space")
	view._choose_category("construction")
	_check(view.palette.get_child_count() == 1, "Construction has its own usable slot")
	view._choose_card("fence")
	_click(view, Vector2i(1, 1))
	view._process(0.05)
	_check(view.sim.cards.buildings.is_empty() and view.last_message.contains("No se pudo"), "Rejected deployment reports feedback without creating free buildings")
	# Input still supports long navigation; no forced march is issued by the scenario.
	_click(view, Vector2i(1, 1))
	view._process(0.05)
	_check(view.sim.orders.active[3]["goal"]["cell"] == Vector2i(1, 1), "Explicit navigation works alongside card interface")
	await process_frame
	await process_frame
	viewport.size = Vector2i(360, 800)
	view._process(0.01)
	await process_frame
	var board: Rect2 = view._board_rect()
	_check(board.end.y <= 582 and board.position.y >= 126, "Portrait board stays between instructions and card dock")
	_check(view.header.size.x <= 336 and view.palette.size.x <= 336, "Header and card choices fit narrow portrait window")
	view._start_battle()
	view._process(0.05)
	_check(view.selected_unit_id == -1 and view.sim.orders.active.is_empty() and view.sim.actions.active.is_empty(), "Restart clears selection, paths and specials")
	_check(view.sim.cards.state(0, "pig", view.sim)["available"] == 3 and view.sim.players[0]["essence"] == 4, "Restart restores independent card pool and economy")
	_check(not view.sim.get_player_view(0)["players"][1].has("core_cell"), "Integrated presentation does not expose hidden core")
	viewport.queue_free()
	if failures == 0:
		print("PASS: integrated battle UI, four card spaces, deployment, essence, specials, feedback and portrait layout")
	quit(0 if failures == 0 else 1)
