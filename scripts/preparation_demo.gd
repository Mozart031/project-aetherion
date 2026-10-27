extends Node

## Independent composition. Only this coordinator owns simulation/command access.
signal simulation_stepped
const Board = preload("res://scripts/preparation_board.gd")
const Stacks = preload("res://scripts/card_stack_model.gd")
const Placement = preload("res://scripts/card_placement_controller.gd")
const StackPanel = preload("res://scripts/card_stacks_panel.gd")
const Preview = preload("res://scripts/card_placement_preview.gd")
const Catalog = preload("res://scripts/battle_catalog.gd")
@export var local_player := 0
@export var fixed_rival_preparation := true
var sim := AetherionSimulation.new()
var stacks := Stacks.new()
var placement := Placement.new()
var board := Board.new()
var panel := StackPanel.new()
var overlay := Preview.new()
var accumulator := 0.0
var joined_tick := -1
var join_count := 0
var phase_label: Label
var essence_label: Label
var selected_unit_id := -1
var _view: Dictionary = {}
var _hover := Vector2(-1000, -1000)
var _back_policy := true

func _ready() -> void:
	_back_policy = get_tree().quit_on_go_back
	get_tree().quit_on_go_back = false
	add_child(board)
	add_child(overlay)
	_build_ui()
	panel.cycle_requested.connect(_cycle)
	panel.placement_requested.connect(_begin)
	panel.drag_preview.connect(_hover_at)
	panel.drag_released.connect(_drop)
	panel.cancel_requested.connect(_cancel)
	panel.info_requested.connect(_inspect)
	restart()

func _exit_tree() -> void:
	if is_instance_valid(get_tree()):
		get_tree().quit_on_go_back = _back_policy

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	phase_label = Label.new()
	phase_label.position = Vector2(12, 12)
	phase_label.add_theme_font_size_override("font_size", 20)
	hud.add_child(phase_label)
	essence_label = Label.new()
	essence_label.position = Vector2(12, 46)
	essence_label.add_theme_font_size_override("font_size", 14)
	hud.add_child(essence_label)
	var dock := VBoxContainer.new()
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_left = 12
	dock.offset_right = -12
	dock.offset_top = -178
	dock.offset_bottom = -12
	hud.add_child(dock)
	dock.add_child(panel)
	var restart_button := Button.new()
	restart_button.text = "Reiniciar preparación"
	restart_button.custom_minimum_size.y = 32
	restart_button.pressed.connect(restart)
	dock.add_child(restart_button)

func restart() -> void:
	sim.reset()
	sim.enable_preparation()
	sim.enable_territorial_victory()
	# Reuse the existing battle demo's ecology/adjacent defense, not a new rival AI.
	sim.natural.enabled = true
	sim.natural_defense.enabled = true
	# No legacy reinforcement producer or new strategist. A paid setup fixture only.
	if fixed_rival_preparation:
		var rival := 1 - local_player
		var x := rival * 4
		sim.queue_play_card(rival, "cornfield", Vector2i(x + 1, 1), -1, 1)
		sim.queue_play_card(rival, "fence", Vector2i(x, 2), -1, 2)
		sim.queue_play_card(rival, "mud", Vector2i(x + 2, 2), -1, 3)
	accumulator = 0
	joined_tick = -1
	join_count = 0
	selected_unit_id = -1
	placement.reset()
	stacks.configure(sim.loadouts[local_player].snapshot())
	panel.gesture.cancel()
	panel.close_info()
	board.reset()
	_hover = Vector2(-1000, -1000)
	_view = sim.get_player_view(local_player)
	_refresh()

func _process(delta: float) -> void:
	# Same fixed-step cadence and long-frame bound as the legacy runner.
	accumulator += minf(delta, 0.25)
	while accumulator + 0.000001 >= AetherionSimulation.TICK_SECONDS:
		sim.step()
		accumulator = maxf(0, accumulator - AetherionSimulation.TICK_SECONDS)
		_accept_view(sim.get_player_view(local_player))
		simulation_stepped.emit()
	_refresh()

func _accept_view(snapshot: Dictionary) -> void:
	_view = snapshot.duplicate(true)
	# Consume accepted requests before cancelling unconfirmed gestures on layout change.
	var played: Dictionary = placement.consume(_view)
	if not played.is_empty():
		stacks.cycle(played["category"])
		panel.close_info(played["category"])
	for event in _view["events"]:
		if event["type"] == "board_joined" and joined_tick < 0:
			joined_tick = int(event["tick"])
			join_count += 1
			panel.gesture.cancel()
			if not placement.busy() and not placement.draft.is_empty():
				placement.cancel()
			_hover = Vector2(-1000, -1000)
	if selected_unit_id != -1 and not _view["units"].any(func(u): return u["id"] == selected_unit_id):
		selected_unit_id = -1
	_refresh()

func _cycle(category: String) -> void:
	if placement.busy():
		return
	if placement.draft.get("category") == category:
		placement.cancel()
	elif placement.draft.is_empty():
		placement.message = ""
	stacks.cycle(category)
	panel.close_info(category)
	_refresh()

func _begin(category: String) -> void:
	panel.close_info()
	placement.begin(local_player, category, stacks.top(category), sim)
	_refresh()

func _cancel() -> void:
	panel.gesture.cancel()
	panel.close_info()
	placement.cancel()
	_hover = Vector2(-1000, -1000)
	_refresh()

func _inspect(category: String, back: bool) -> void:
	if placement.busy():
		return
	_cancel()
	if back:
		panel.show_reverse(category)
	else:
		panel.close_info(category)
	_refresh()

func _hover_at(point: Vector2) -> void:
	_hover = point
	_refresh_preview()

func _drop(point: Vector2, returned: bool) -> void:
	if returned:
		_cancel()
	else:
		_confirm_at(point)

func _confirm_at(point: Vector2) -> void:
	var cell: Vector2i = board.cell_at_viewport(point)
	var hit: Dictionary = board.hit_unit(point)
	if cell == Vector2i(-1, -1) and not hit.is_empty():
		cell = hit["cell"] # A moving unit can be drawn in the inter-board gap.
	# Do not probe a sealed rival's occupancy, targets or placement responses.
	if cell == Vector2i(-1, -1) or (joined_tick < 0 and not board.layout.is_own(cell)):
		return
	placement.confirm(sim, cell, int(hit.get("id", -1)))
	_hover = point
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.index != 0 or not event.pressed or event.canceled:
			return
		point = event.position
	elif event is InputEventMouseButton:
		if event.device == InputEvent.DEVICE_ID_EMULATION or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
			return
		point = event.position
	else:
		return
	if panel.gesture.active() or panel.sheet.visible:
		return
	var cell: Vector2i = board.cell_at_viewport(point)
	var unit: Dictionary = board.hit_unit(point)
	if cell == Vector2i(-1, -1) and unit.is_empty():
		return
	get_viewport().set_input_as_handled()
	if not placement.draft.is_empty():
		_confirm_at(point)
		return
	if joined_tick < 0 or sim.finished:
		return
	if not unit.is_empty() and unit["owner"] == local_player:
		selected_unit_id = int(unit["id"])
	elif selected_unit_id != -1:
		var target: Dictionary = unit if not unit.is_empty() else board.hit_building(point)
		if not target.is_empty() and target["owner"] != local_player:
			sim.queue_target(local_player, selected_unit_id, int(target["id"]))
		else:
			sim.queue_destination(local_player, selected_unit_id, cell)
	_refresh()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_WM_GO_BACK_REQUEST] and is_instance_valid(panel) and is_instance_valid(panel.status):
		_cancel()

func _refresh() -> void:
	if not is_instance_valid(panel.status) or _view.is_empty():
		return
	board.selected_unit_id = selected_unit_id
	board.present(_view, local_player, joined_tick, float(_view["tick"]) + accumulator / AetherionSimulation.TICK_SECONDS)
	var preparing: bool = _view["phase"] == "preparation"
	phase_label.text = "Preparación privada · %d s" % ceili(float(_view["preparation_remaining_ticks"]) / 20.0) if preparing else "Combate · Isla del Caos"
	if _view["finished"]:
		phase_label.text = "Victoria" if _view["winner"] == local_player else "Derrota"
	essence_label.text = "Esencia: %s/8 · %s" % [_view["players"][local_player]["essence"], "Terrenos y construcciones" if preparing else "Toca para ir o atacar"]
	panel.locked = placement.busy()
	panel.cancel_button.disabled = placement.draft.is_empty() or placement.busy()
	for index in range(Catalog.CATEGORIES.size()):
		var category: String = Catalog.CATEGORIES[index]
		var id := stacks.top(category)
		# Owner-only rule query: never rival equipment, inventory or exact essence.
		var state: Dictionary = sim.cards.availability(local_player, id, sim)
		var availability := "Desplegada" if state["active"] > 0 else ("Recuperando" if state["recovering"] > 0 else "Disponible")
		var hint := "↓ / ↑ colocar"
		if state["reason"] == "preparation_phase":
			availability = "Solo combate"
			hint = "Tras preparar"
		elif state["recovering"] > 0:
			hint = "Rec. %.1f s" % maxf(0, float(state["ready_tick"] - _view["tick"]) / 20)
		elif not state["valid"]:
			hint = "En tablero" if state["active"] > 0 else "Falta esencia"
		panel.cards[category].show_card({"card": id, "category_label": Catalog.CATEGORY_LABELS[index], "title": Catalog.CARDS.get(id, {"label": "Vacía"})["label"], "ready": state["valid"], "count": stacks.count(category), "cost_text": "%sE · %s/%s" % [state["cost"], stacks.position_of(category) + 1, stacks.count(category)], "copies_text": availability, "recovery_text": hint, "selected": placement.draft.get("category") == category or panel.inspected_category == category, "back": panel.inspected_category == category, "brief": Catalog.tactical_info(id)["brief"]})
	panel.status.text = {"preparation_phase": "Ahora solo terrenos y construcciones.", "unavailable": "Falta esencia o disponibilidad.", "occupied": "Espacio ocupado o reservado.", "own_territory_required": "Coloca en tus 16 secciones inferiores.", "species_active": "Esta especie ya está desplegada.", "species_recovering": "Esta especie está recuperándose.", "accepted": "Carta jugada correctamente.", "terrain_locked_or_same": "Terreno igual o bajo ataque.", "match_finished": "Partida terminada."}.get(placement.message, "↓ Recorrer · ↑ Colocar · ← Ficha")
	if placement.busy():
		panel.status.text = "Confirmando colocación..."
	elif not placement.draft.is_empty() and placement.message.is_empty():
		panel.status.text = "Arrastra o toca una sección propia."
	_refresh_preview()

func _refresh_preview() -> void:
	overlay.valid_cells.clear()
	overlay.hover = Rect2()
	if not placement.draft.is_empty() and not placement.busy():
		for x in range(local_player * 4, local_player * 4 + 4):
			for y in range(4):
				var cell := Vector2i(x, y)
				if placement.preview(sim, cell)["valid"]:
					overlay.valid_cells.append(board.cell_rect_on_viewport(cell))
		var cell: Vector2i = board.cell_at_viewport(_hover)
		var hit: Dictionary = board.hit_unit(_hover)
		if cell == Vector2i(-1, -1) and not hit.is_empty():
			cell = hit["cell"]
		if cell != Vector2i(-1, -1) and (joined_tick >= 0 or board.layout.is_own(cell)):
			overlay.hover = board.cell_rect_on_viewport(cell)
			overlay.valid = placement.preview(sim, cell, int(hit.get("id", -1)))["valid"]
			overlay.title = Catalog.CARDS[placement.draft["card"]]["label"]
	overlay.queue_redraw()

func presentation_snapshot() -> Dictionary:
	var cards := {}
	for category in panel.cards:
		cards[category] = panel.cards[category].data.duplicate(true)
	return {"board": board.visual_snapshot(), "phase": phase_label.text, "essence": essence_label.text, "cards": cards, "status": panel.status.text, "highlights": overlay.valid_cells.duplicate(), "hover": overlay.hover, "selected": selected_unit_id, "joined_tick": joined_tick, "join_count": join_count}
