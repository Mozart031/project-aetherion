extends SceneTree

const Catalog = preload("res://scripts/battle_catalog.gd")
var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _touch(viewport: SubViewport, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = pressed
	viewport.push_input(event, true)

func _swipe(view, viewport: SubViewport, category: String, delta: Vector2) -> void:
	var start: Vector2 = view.panel.cards[category].get_global_rect().get_center()
	_touch(viewport, start, true)
	var event := InputEventScreenDrag.new()
	event.position = start + delta
	viewport.push_input(event, true)
	_touch(viewport, start + delta, false)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog_before: Dictionary = Catalog.CARDS.duplicate(true)
	for card in Catalog.CARDS:
		var info: Dictionary = Catalog.tactical_info(card)
		for field in ["brief", "role", "ability", "advantage", "disadvantage"]:
			_check(not info[field].is_empty(), "Known cards have verified tactical fields: " + card + "/" + field)
		info["advantage"] = "local edit"
		_check(Catalog.tactical_info(card)["advantage"] != "local edit", "Informational queries return independent dictionaries")
	var unknown: Dictionary = Catalog.tactical_info("future_undefined_card")
	_check(unknown["brief"].is_empty(), "Undefined cards have no invented front trait")
	for field in ["role", "ability", "advantage", "disadvantage"]:
		_check(unknown[field] == "Pendiente de definición.", "Unknown tactical fields explicitly remain pending")
	_check(Catalog.CARDS == catalog_before, "Tactical descriptions do not change card costs or catalog rules")
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
	var cursors: Dictionary = view.stacks.snapshot()
	var state: Dictionary = view.board.sim.get_player_view(0).duplicate(true)
	var queued: Array = view.board.sim.queued_commands.duplicate(true)
	var selected: int = view.board.selected_unit_id
	_swipe(view, viewport, "creature", Vector2(-40, 1))
	_check(view.panel.inspected_category == "creature" and view.panel.sheet.visible and view.panel.cards["creature"].data["back"], "Left swipe opens the actual card reverse and readable sheet")
	_check(view.panel.sheet.details == Catalog.tactical_info("pig") and view.panel.sheet.body.text.contains("Desventaja:"), "Reverse displays all four verified tactical sections")
	_check(view.placement.draft.is_empty() and view.stacks.snapshot() == cursors and view.board.selected_unit_id == selected, "Informational gesture does not select a target, deploy or rotate")
	_check(view.board.sim.get_player_view(0) == state and view.board.sim.queued_commands == queued and not paused, "Reading neither pauses nor mutates simulation, economy or orders")
	_check(view.panel.cards["creature"].data["brief"] == Catalog.tactical_info("pig")["brief"], "Front trait is sourced from verified catalog metadata")
	await process_frame
	await process_frame
	var sheet_point: Vector2 = view.panel.sheet.get_global_rect().get_center()
	_touch(viewport, sheet_point, true)
	_touch(viewport, sheet_point, false)
	_check(view.board.selected_unit_id == selected and view.board.sim.queued_commands == queued, "Touches on the tactical sheet cannot leak into the board")
	view.board._process(0.05)
	_check(view.board.sim.tick_count == state["tick"] + 1 and view.panel.sheet.visible, "Battle continues ticking while the reverse remains visible")
	_swipe(view, viewport, "creature", Vector2(40, 0))
	_check(not view.panel.sheet.visible and not view.panel.cards["creature"].data["back"] and view.stacks.snapshot() == cursors, "Right swipe restores the front without rotating")
	_swipe(view, viewport, "creature", Vector2(-40, 40))
	_swipe(view, viewport, "creature", Vector2(-20, 0))
	_check(view.placement.draft.is_empty() and not view.panel.sheet.visible and view.stacks.snapshot() == cursors, "Ambiguous diagonal and short horizontal drags neither flip nor deploy")
	_swipe(view, viewport, "creature", Vector2(-40, 0))
	_swipe(view, viewport, "creature", Vector2(0, 60))
	_check(view.stacks.top("creature") == "boar" and not view.panel.sheet.visible, "Down swipe from reverse retains independent manual cycling")
	_swipe(view, viewport, "creature", Vector2(-40, 0))
	_check(view.panel.sheet.details == Catalog.tactical_info("boar"), "Reverse follows the currently visible species")
	_swipe(view, viewport, "creature", Vector2(0, -50))
	_check(view.placement.draft.get("card") == "boar" and not view.panel.sheet.visible, "Up swipe from reverse closes information and begins normal placement")
	var essence: int = view.board.sim.players[0]["essence"]
	_swipe(view, viewport, "terrain", Vector2(-40, 0))
	_check(view.placement.draft.is_empty() and view.panel.inspected_category == "terrain" and view.board.sim.players[0]["essence"] == essence, "Information abandons only an unconfirmed local preview without spending")
	view._cancel()
	for index in range(3):
		view._cycle("creature")
	view._begin("creature")
	view._confirm_at(view.board._center(Vector2i(1, 1)))
	view.board._process(0.05)
	var unit_id: int = view.board.sim.units.filter(func(unit): return unit["owner"] == 0 and unit["kind"] == "pig")[0]["id"]
	for index in range(3):
		view._cycle("creature")
	view.board.selected_unit_id = unit_id
	view.board.sim.queue_move(0, unit_id, Vector2i(2, 1))
	view.board._process(0.05)
	queued = view.board.sim.queued_commands.duplicate(true)
	state = view.board.sim.get_player_view(0).duplicate(true)
	_swipe(view, viewport, "creature", Vector2(-40, 0))
	_check(view.panel.cards["creature"].data["copies_text"] == "Desplegada" and view.panel.sheet.visible, "Active species remains inspectable with its blocked availability")
	_check(view.board.sim.get_player_view(0) == state and view.board.sim.queued_commands == queued and view.board.selected_unit_id == unit_id, "Opening information preserves an existing explicit movement order and selection")
	view.board.sim.get_unit(unit_id)["hp"] = 0 # Presentation fixture; normal defeat cleanup starts recovery.
	view.board._process(0.05)
	_check(view.panel.cards["creature"].data["copies_text"] == "Recuperando" and view.panel.sheet.visible, "Recovery availability updates while reading the reverse")
	_swipe(view, viewport, "creature", Vector2(40, 0))
	view._begin("creature")
	_check(view.placement.draft.is_empty() and view.placement.message == "species_recovering", "Inspecting a recovering card never makes its authentic creature deployable")
	_swipe(view, viewport, "creature", Vector2(-40, 0))
	viewport.size = Vector2i(360, 800)
	await process_frame
	await process_frame
	var rect: Rect2 = view.panel.sheet.get_global_rect()
	_check(rect.position.x >= 0 and rect.end.x <= 360 and rect.position.y >= 0 and rect.end.y < view.panel.get_global_rect().position.y, "Expanded reverse fits narrow portrait and leaves the four gesture targets accessible")
	_check(view.panel.sheet.body.size.x <= view.panel.sheet.scroll.size.x and view.panel.sheet.body.get_theme_font_size("font_size") >= 13, "Reverse text wraps at readable size instead of shrinking into a card")
	_check(view.panel.sheet.scroll.get_v_scroll_bar().max_value > view.panel.sheet.scroll.size.y, "Long tactical descriptions have vertical scrolling")
	var scroll_start: Vector2 = view.panel.sheet.scroll.get_global_rect().get_center()
	var before_scroll: Dictionary = view.stacks.snapshot()
	_touch(viewport, scroll_start, true)
	var scroll_drag := InputEventScreenDrag.new()
	scroll_drag.position = scroll_start - Vector2(0, 60)
	scroll_drag.relative = Vector2(0, -60)
	viewport.push_input(scroll_drag, true)
	_touch(viewport, scroll_drag.position, false)
	_check(view.panel.sheet.scroll.scroll_vertical > 0 and view.stacks.snapshot() == before_scroll and view.placement.draft.is_empty(), "Touch scroll reads the reverse without cycling cards or starting placement")
	view.board._start_battle()
	_check(view.panel.inspected_category.is_empty() and not view.panel.sheet.visible, "Restart clears information state")
	viewport.queue_free()
	if failures == 0:
		print("PASS: verified card information, horizontal GUI gestures, vertical isolation, no simulation side effects, active/recovering inspection and portrait sheet")
	quit(0 if failures == 0 else 1)
