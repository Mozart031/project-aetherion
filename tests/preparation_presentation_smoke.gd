extends SceneTree

const Scene = preload("res://scenes/preparation_demo.tscn")
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

func _tap(viewport: SubViewport, point: Vector2) -> void:
	_touch(viewport, point, true)
	_touch(viewport, point, false)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 900)
	root.add_child(viewport)
	var demo = Scene.instantiate()
	demo.fixed_rival_preparation = false
	viewport.add_child(demo)
	demo.set_process(false)
	await process_frame
	await process_frame
	_check(demo.phase_label.text.ends_with("30 s") and demo.panel.cards.size() == 4 and demo.board.visual_snapshot()["sealed"], "Initial portrait UI has a tick-based countdown, four stacks and sealed rival")
	var own_rect: Rect2 = demo.board.cell_rect_on_viewport(Vector2i(2, 1))
	var cursors: Dictionary = demo.stacks.snapshot()
	for category in ["creature", "trick"]:
		_tap(viewport, demo.panel.cards[category].get_global_rect().get_center())
		_check(demo.placement.draft.is_empty() and demo.placement.message == "preparation_phase", "Creature/trick GUI placement is blocked during preparation")
	_check(demo.stacks.snapshot() == cursors and demo.sim.players[0]["essence"] == 4, "Blocked selection has neither cost nor automatic rotation")
	_tap(viewport, demo.panel.cards["terrain"].get_global_rect().get_center())
	_check(demo.placement.draft.get("card") == "cornfield" and demo.overlay.valid_cells.size() == 16, "Terrain selection highlights exactly the sixteen own sections")
	var before_enemy_tap: int = demo.sim.queued_commands.size()
	_tap(viewport, demo.board.center_on_viewport(Vector2i(5, 1)))
	_check(demo.sim.queued_commands.size() == before_enemy_tap and not demo.placement.busy(), "The sealed half cannot submit a placement or expose a hidden rejection")
	_tap(viewport, demo.board.center_on_viewport(Vector2i(2, 1)))
	_check(demo.placement.busy(), "A local section tap submits the selected terrain")
	demo._process(0.05)
	_check(demo.sim.terrain.cells.get(Vector2i(2, 1)) == "cornfield" and demo.sim.players[0]["essence"] == 3 and demo.stacks.top("terrain") == "mud", "Accepted terrain uses real economy and rotates exactly once")
	# Construction placement is also usable during preparation.
	_tap(viewport, demo.panel.cards["construction"].get_global_rect().get_center())
	_tap(viewport, demo.board.center_on_viewport(Vector2i(0, 0)))
	demo._process(0.05)
	_check(demo.sim.cards.buildings.size() == 1 and demo.sim.players[0]["essence"] == 1, "Construction deployment follows the existing occupancy and cost rules")
	_tap(viewport, demo.panel.cards["construction"].get_global_rect().get_center())
	_check(demo.placement.draft.is_empty() and demo.sim.players[0]["essence"] == 1, "Unavailable construction cannot be reused or spend essence")
	# A short upward swipe arms placement; returning a longer drag cancels it.
	var terrain_start: Vector2 = demo.panel.cards["terrain"].get_global_rect().get_center()
	_touch(viewport, terrain_start, true)
	_drag(viewport, terrain_start - Vector2(0, 50))
	_touch(viewport, terrain_start - Vector2(0, 50), false)
	_check(demo.placement.draft.get("card") == "mud", "Upward swipe retains the existing select-then-tap path")
	demo.panel.cancel_button.pressed.emit()
	terrain_start = demo.panel.cards["terrain"].get_global_rect().get_center()
	_touch(viewport, terrain_start, true)
	_drag(viewport, demo.board.center_on_viewport(Vector2i(3, 2)))
	_drag(viewport, terrain_start)
	_touch(viewport, terrain_start, false)
	_check(demo.placement.draft.is_empty() and demo.stacks.top("terrain") == "mud" and demo.sim.players[0]["essence"] == 1, "Returning to the pile cancels without rotation or payment")
	# Countdown and a captured, unconfirmed pointer on the exact layout boundary.
	while demo.sim.tick_count < 599:
		demo._process(0.05)
	_check(demo.phase_label.text.ends_with("1 s") and demo.join_count == 0, "Tick 599 still shows one preparation second and no reveal")
	var essence_before: int = demo.sim.players[0]["essence"]
	terrain_start = demo.panel.cards["terrain"].get_global_rect().get_center()
	var destination: Vector2 = demo.board.center_on_viewport(Vector2i(3, 2))
	_touch(viewport, terrain_start, true)
	_drag(viewport, destination)
	_touch(viewport, destination, true, 1)
	_touch(viewport, destination, false, 1)
	_check(demo.panel.gesture.active() and not demo.placement.busy(), "Only the original pointer owns the pending drag")
	demo._process(0.05)
	_check(demo.sim.tick_count == 600 and demo.join_count == 1 and demo.phase_label.text.begins_with("Combate"), "Tick 600 reveals and transitions once")
	_check(not demo.panel.gesture.active() and demo.placement.draft.is_empty() and demo.stacks.top("terrain") == "mud" and demo.sim.players[0]["essence"] == essence_before, "Layout transition cancels the unsent drag without cost or rotation")
	_touch(viewport, destination, false)
	_check(demo.sim.queued_commands.is_empty(), "Releasing the cancelled pointer cannot create a late deployment")
	_check(demo.board.cell_rect_on_viewport(Vector2i(2, 1)) == own_rect, "The own board keeps its original screen reference at join")
	# Combat and placement are available during the visual transition, not after it.
	_tap(viewport, demo.panel.cards["creature"].get_global_rect().get_center())
	_tap(viewport, demo.board.center_on_viewport(Vector2i(3, 1)))
	demo._process(0.05)
	_check(demo.sim.tick_count == 601 and demo.sim.get_unit(1).get("kind") == "pig" and demo.board.layout.progress() < 1, "A creature deploys on tick 601 while the join is still animating")
	# Isolate manual target/hit geometry from the existing automatic defense profile.
	demo.sim.natural.enabled = false
	demo.sim.natural_defense.enabled = false
	demo.sim.queue_play_card(1, "pig", Vector2i(4, 1))
	demo.sim.queue_play_card(1, "fence", Vector2i(4, 2))
	demo._process(0.05)
	_check(demo.board.hit_building(demo.board.center_on_viewport(Vector2i(4, 2))).get("owner") == 1, "Moving rival construction drawing and hit testing share one transform")
	_tap(viewport, demo.board.get_global_transform_with_canvas() * demo.board.unit_center(demo.sim.get_player_view(0)["units"][0]))
	_check(demo.selected_unit_id == 1, "A creature can be selected during the transition")
	_tap(viewport, demo.board.center_on_viewport(Vector2i(4, 1)))
	demo._process(0.05)
	_check(demo.sim.orders.active[1]["goal"].get("target_id") == 2 and demo.sim.get_unit(2)["hp"] == 3, "An animated enemy can be targeted and damaged before the transition ends")
	_tap(viewport, demo.board.center_on_viewport(Vector2i(3, 0)))
	demo._process(0.05)
	demo._process(0.05)
	var own_unit: Dictionary = demo.sim.get_player_view(0)["units"][0]
	_tap(viewport, demo.board.get_global_transform_with_canvas() * demo.board.unit_center(own_unit))
	_check(demo.selected_unit_id == 1, "Interpolated creature drawing and selection also share the animated geometry")
	while demo.sim.tick_count < 612:
		demo._process(0.05)
	_check(demo.board.layout.progress() == 1 and demo.board.cell_rect_on_viewport(Vector2i(2, 1)) == own_rect, "The visual join finishes in 12 ticks without moving own territory")
	_check(demo.sim.get_controlled_section_count(0) == 16 and demo.sim.players[0]["core_hp"] == 12 and demo.sim.players[1]["core_hp"] == 12, "The cinematic never changes controllers or core HP")
	# A confirmed terrain request on the final preparation tick must survive the join.
	demo.restart()
	while demo.sim.tick_count < 599:
		demo._process(0.05)
	demo._begin("terrain")
	demo._confirm_at(demo.board.center_on_viewport(Vector2i(2, 1)))
	_check(demo.placement.busy(), "Final preparation placement is already submitted")
	demo._process(0.05)
	_check(demo.sim.terrain.cells.get(Vector2i(2, 1)) == "cornfield" and demo.stacks.top("terrain") == "mud" and demo.sim.players[0]["essence"] == 7, "Tick-600 acceptance is consumed before cancelling gestures")
	demo._accept_view(demo.sim.get_player_view(0))
	_check(demo.stacks.top("terrain") == "mud" and demo.join_count == 1 and demo.sim.players[0]["essence"] == 7, "Repeated responses cannot rotate, charge or animate twice")
	# Real movement can put a drawn creature inside the temporary gap itself.
	demo.sim.queue_play_card(0, "pig", Vector2i(3, 0))
	demo.sim.queue_play_card(1, "pig", Vector2i(4, 3))
	demo._process(0.05)
	demo.sim.queue_destination(0, 1, Vector2i(4, 0))
	demo.sim.queue_destination(1, 2, Vector2i(3, 3))
	while demo.sim.tick_count < 605:
		demo._process(0.05)
	var visible_units: Array = demo.sim.get_player_view(0)["units"]
	var own_gap_center: Vector2 = demo.board.get_global_transform_with_canvas() * demo.board.unit_center(visible_units[0])
	var rival_gap_center: Vector2 = demo.board.get_global_transform_with_canvas() * demo.board.unit_center(visible_units[1])
	_check(demo.board.cell_at_viewport(own_gap_center) == Vector2i(-1, -1) and demo.board.cell_at_viewport(rival_gap_center) == Vector2i(-1, -1), "Both interpolation centers really lie in the temporary gap")
	_tap(viewport, own_gap_center)
	_check(demo.selected_unit_id == 1, "A drawn own creature remains selectable inside the moving gap")
	_tap(viewport, rival_gap_center)
	_check(demo.sim.queued_commands[-1]["goal"].get("target_id") == 2, "A drawn rival in the gap can be targeted without guessing a logical cell")
	# Verify transformed canvas input and narrow portrait UI with the same components.
	demo.board.position = Vector2(10, 4)
	demo.board.scale = Vector2(0.95, 0.95)
	for cell in [Vector2i(2, 1), Vector2i(6, 2)]:
		_check(demo.board.cell_at_viewport(demo.board.center_on_viewport(cell)) == cell, "Canvas-transformed rendering and hit testing remain inverse")
	viewport.size = Vector2i(360, 800)
	await process_frame
	await process_frame
	demo._refresh()
	for card in demo.panel.cards.values():
		_check(card.get_global_rect().end.x <= 348, "All four existing stacks remain compact in narrow portrait")
	_check(demo.board.layout.board_rect().end.y < demo.panel.get_global_rect().position.y, "Board and card dock do not overlap")
	demo.restart()
	_check(demo.phase_label.text.ends_with("30 s") and demo.join_count == 0 and demo.board.feedback.effects.is_empty() and demo.placement.draft.is_empty(), "Restart clears countdown, reveal, effects and pending input")
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/battle_demo.tscn", "F5 and all legacy scenes remain unchanged")
	viewport.free()
	if failures == 0:
		print("PASS: real touch placement, piles/cancellation, countdown, tick-600 pending requests, tick-601 combat, shared moving transforms, portrait resize and restart")
	quit(0 if failures == 0 else 1)
