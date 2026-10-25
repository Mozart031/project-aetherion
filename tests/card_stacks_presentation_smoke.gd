extends SceneTree

var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _touch(viewport: SubViewport, point: Vector2, pressed: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = pressed
	event.index = index
	viewport.push_input(event, true)

func _drag(viewport: SubViewport, point: Vector2, index: int = 0) -> void:
	var event := InputEventScreenDrag.new()
	event.position = point
	event.index = index
	viewport.push_input(event, true)

func _cycle(view, viewport: SubViewport, category: String) -> void:
	var rect: Rect2 = view.panel.cards[category].get_global_rect()
	var start := rect.get_center()
	_touch(viewport, start, true)
	_drag(viewport, start + Vector2(0, 60))
	_touch(viewport, start + Vector2(0, 60), false)

func _tap(viewport: SubViewport, point: Vector2) -> void:
	_touch(viewport, point, true)
	_touch(viewport, point, false)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 900)
	root.add_child(viewport)
	var view = load("res://scenes/battle_stacks_demo.tscn").instantiate()
	viewport.add_child(view)
	view.set_process(false)
	view.board.set_process(false)
	view.board._process(0.05)
	await process_frame
	await process_frame
	_check(view.panel.cards.size() == 4 and view.stacks.top("creature") == "pig", "Four stack components display equipped top types")
	_cycle(view, viewport, "creature")
	_check(view.stacks.top("creature") == "boar" and view.stacks.position_of("terrain") == 0, "Real GUI down swipe rotates only its stack")
	for index in range(3):
		_cycle(view, viewport, "creature")
	_check(view.stacks.top("creature") == "pig", "Repeated real GUI swipes wrap all species")
	var card_rect: Rect2 = view.panel.cards["creature"].get_global_rect()
	_tap(viewport, card_rect.get_center())
	_check(view.placement.draft.get("card") == "pig" and not view.board.tactical_input_enabled, "Tapping a card arms local placement and gates tactical clicks")
	_check(view.board.sim.players[0]["essence"] == 4, "Selecting and highlighting have no cost")
	var queued_before: int = view.board.sim.queued_commands.size() # Includes the rival's fixed flank order.
	_tap(viewport, view.board._center(Vector2i(1, 1)))
	_check(view.placement.busy() and view.board.sim.queued_commands.size() == queued_before + 1 and view.board.sim.queued_commands[-1]["type"] == "play_card", "Next board tap submits one placement, not a movement order")
	var emulated := InputEventMouseButton.new()
	emulated.position = view.board._center(Vector2i(1, 1))
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	viewport.push_input(emulated, true)
	_check(view.board.sim.queued_commands.size() == queued_before + 1, "Emulated mouse cannot duplicate touch placement")
	view.board._process(0.05)
	_check(view.board.sim.get_unit(2).get("kind") == "pig" and view.board.sim.players[0]["essence"] == 2 and view.placement.draft.is_empty(), "Tick accepts deployment and updates UI")
	_check(view.stacks.top("creature") == "pig" and view.panel.cards["creature"].data["copies_text"] == "Desplegada", "Playing preserves top card while separate copy inventory changes")
	var active_essence: int = view.board.sim.players[0]["essence"]
	_tap(viewport, card_rect.get_center())
	_check(view.placement.draft.is_empty() and view.placement.message == "species_active" and view.board.sim.players[0]["essence"] == active_essence, "Active species remains in its stack but cannot start a second deployment")
	_tap(viewport, view.board._center(Vector2i(1, 1)))
	_check(view.board.selected_unit_id == 2, "Tactical selection resumes after acknowledgement")
	_cycle(view, viewport, "creature")
	while view.board.sim.tick_count < 60:
		view.board._process(0.05)
	var destination: Vector2 = view.board._center(Vector2i(2, 1))
	card_rect = view.panel.cards["creature"].get_global_rect()
	_touch(viewport, card_rect.get_center(), true)
	_drag(viewport, destination)
	_check(view.placement.draft.get("card") == "boar", "Direct drag starts the current top species")
	_touch(viewport, destination, false)
	_check(view.placement.busy(), "Releasing over a valid cell confirms direct drag")
	view.board._process(0.05)
	_check(view.board.sim.get_unit(3).get("kind") == "boar" and view.stacks.top("creature") == "boar" and view.board.selected_unit_id == 2, "Direct deployment preserves top card and previous tactical selection")
	while view.board.sim.tick_count < 120:
		view.board._process(0.05)
	var terrain: Rect2 = view.panel.cards["terrain"].get_global_rect()
	var cursors: Dictionary = view.stacks.snapshot()
	_touch(viewport, terrain.get_center(), true)
	_drag(viewport, view.board._center(Vector2i(0, 0)))
	_touch(viewport, view.board._center(Vector2i(0, 0)), true, 1)
	_check(not view.placement.busy(), "Second finger cannot confirm the captured drag")
	_touch(viewport, view.board._center(Vector2i(0, 0)), false, 1)
	_drag(viewport, terrain.get_center())
	_touch(viewport, terrain.get_center(), false)
	_check(view.placement.draft.is_empty() and view.stacks.snapshot() == cursors, "Returning to the stack cancels without rotating or spending")
	_check(view.board.sim.players[0]["essence"] == 1, "Cancelled drag preserves accumulated essence")
	_tap(viewport, terrain.get_center())
	view._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(view.placement.draft.is_empty() and not view.panel.gesture.active() and view.board.tactical_input_enabled, "Focus loss releases gesture and unconfirmed placement")
	_touch(viewport, terrain.get_center(), true)
	_drag(viewport, terrain.get_center() - Vector2(0, 50))
	_touch(viewport, terrain.get_center() - Vector2(0, 50), false)
	_check(view.placement.draft.get("card") == "cornfield" and not view.placement.busy(), "Short GUI upward swipe arms placement for a later destination tap")
	view.panel.cancel_button.pressed.emit()
	_check(view.placement.draft.is_empty(), "Cancel button discards a local preview")
	# PC input follows the same direct-drag path, independently from emulated mouse.
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = terrain.get_center()
	viewport.push_input(mouse, true)
	var motion := InputEventMouseMotion.new()
	motion.position = view.board._center(Vector2i(0, 0))
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(motion, true)
	_check(view.placement.draft.get("card") == "cornfield", "Real mouse drag uses the same top card as touch")
	mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = false
	mouse.position = motion.position
	viewport.push_input(mouse, true)
	view.board._process(0.05)
	_check(view.board.sim.cards.terrain_owners.get(Vector2i(0, 0)) == 0 and view.stacks.top("terrain") == "cornfield", "PC drag deploys one terrain without rotating")
	_cycle(view, viewport, "terrain")
	_check(view.stacks.top("terrain") == "mud" and view.panel.cards["terrain"].data["recovery_text"] == "Falta esencia", "Unavailable types stay navigable and distinguish essence from recovery")
	for index in range(3):
		_cycle(view, viewport, "creature")
	_check(view.stacks.top("creature") == "pig", "Active authentic species is still reachable through circular navigation")
	view.board.sim.get_unit(2)["hp"] = 0 # Defeat fixture for presentation; normal cleanup starts recovery.
	view.board._process(0.05)
	var ready: int = view.board.sim.players[0]["recovering"][2]["ready_tick"]
	var species_cursor: Dictionary = view.stacks.snapshot()
	_check(view.panel.cards["creature"].data["copies_text"] == "Recuperando" and str(view.panel.cards["creature"].data["recovery_text"]).contains("rec."), "Defeated species stays visible with recovery countdown")
	_tap(viewport, card_rect.get_center())
	_check(view.placement.draft.is_empty() and view.placement.message == "species_recovering", "Recovering top card cannot start a replacement deployment")
	while view.board.sim.tick_count < ready:
		view.board._process(0.05)
	_check(view.stacks.snapshot() == species_cursor and view.panel.cards["creature"].data["copies_text"] == "Disponible", "Recovery changes availability without rotating any stack")
	_check(not view.panel.status.text.contains("recuperándose"), "Recovery completion also clears the obsolete unavailability explanation")
	_check(view.board.sim.units.all(func(unit): return unit["owner"] != 0 or unit["kind"] != "pig"), "Card recovery does not automatically recreate a creature")
	await process_frame
	viewport.size = Vector2i(360, 800)
	await process_frame
	await process_frame
	view._refresh()
	for card in view.panel.cards.values():
		_check(card.get_global_rect().end.x <= 348, "All four compact cards fit narrow portrait width")
	_check(view.board._board_rect().end.y < view.panel.get_global_rect().position.y, "Card stacks do not cover the portrait board")
	view.board._start_battle()
	_check(view.stacks.position_of("creature") == 0 and view.placement.draft.is_empty(), "Restart clears cursor, draft and pointer state")
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/battle_demo.tscn", "Previous F5 scene remains preserved")
	viewport.queue_free()
	if failures == 0:
		print("PASS: real viewport touch routing, independent stacks, direct drag, select/tap, cancellation, copy display, tactical isolation and portrait layout")
	quit(0 if failures == 0 else 1)
