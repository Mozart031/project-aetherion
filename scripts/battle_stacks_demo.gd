extends Node

## Composition: approved battle view + card UI/controller. No combat producer here.
const Stacks = preload("res://scripts/card_stack_model.gd")
const Placement = preload("res://scripts/card_placement_controller.gd")
const StackPanel = preload("res://scripts/card_stacks_panel.gd")
const Preview = preload("res://scripts/card_placement_preview.gd")
const Catalog = preload("res://scripts/battle_catalog.gd")
const BattleScene = preload("res://scenes/battle_depth_demo.tscn")
var stacks := Stacks.new()
var placement := Placement.new()
var panel := StackPanel.new()
var overlay := Preview.new()
var board
var hover_point := Vector2(-1000, -1000)
var preserved_selection := -1
var _preview_key := ""
var _back_policy := true

func _ready() -> void:
	_back_policy = get_tree().quit_on_go_back
	get_tree().quit_on_go_back = false
	board = BattleScene.instantiate()
	board.card_picker = panel
	board.card_picker_extra_height = 28.0
	board.header_title = "Pilas circulares · Fase 23"
	board.simulation_stepped.connect(_on_step)
	board.battle_restarted.connect(_on_restart)
	panel.cycle_requested.connect(_cycle)
	panel.placement_requested.connect(_begin)
	panel.drag_preview.connect(_hover)
	panel.drag_released.connect(_drop)
	panel.cancel_requested.connect(_cancel)
	add_child(board)
	add_child(overlay)
	# Existing action controls abandon unconfirmed card placement, not player orders.
	for row in panel.get_parent().get_children():
		if row == panel or not row is HBoxContainer:
			continue
		for button in row.get_children():
			if button is Button:
				button.pressed.connect(_abandon_for_tactic)
	_refresh()

func _exit_tree() -> void:
	if is_instance_valid(get_tree()):
		get_tree().quit_on_go_back = _back_policy

func _on_restart() -> void:
	placement.reset()
	stacks.configure(board.sim.loadouts[0].snapshot())
	panel.gesture.cancel()
	preserved_selection = -1
	hover_point = Vector2(-1000, -1000)
	_preview_key = ""
	board.tactical_input_enabled = true
	_refresh()

func _on_step() -> void:
	placement.consume(board.sim.get_player_view(0))
	if preserved_selection != -1 and not board.sim.get_unit(preserved_selection).is_empty():
		board.selected_unit_id = preserved_selection
	if placement.draft.is_empty():
		preserved_selection = -1
	_refresh()

func _cycle(category: String) -> void:
	if placement.busy():
		return
	if placement.draft.get("category") == category:
		placement.cancel()
		preserved_selection = -1
	stacks.cycle(category)
	_preview_key = ""
	_refresh()

func _begin(category: String) -> void:
	if placement.busy():
		return
	if placement.draft.is_empty():
		preserved_selection = board.selected_unit_id
	board.act_mode = false
	board.selected_card = ""
	placement.begin(0, category, stacks.top(category), board.sim)
	if placement.draft.is_empty():
		preserved_selection = -1
	_preview_key = ""
	_refresh()

func _cancel() -> void:
	panel.gesture.cancel()
	placement.cancel()
	if placement.draft.is_empty():
		preserved_selection = -1
	hover_point = Vector2(-1000, -1000)
	_preview_key = ""
	_refresh()

func _abandon_for_tactic() -> void:
	_cancel()

func _hover(point: Vector2) -> void:
	hover_point = point
	_refresh_preview()

func _drop(point: Vector2, returned: bool) -> void:
	if returned:
		_cancel()
	else:
		_confirm_at(point)

func _confirm_at(point: Vector2) -> void:
	var cell: Vector2i = board._cell_at_viewport_position(point)
	if cell != Vector2i(-1, -1):
		var hit: Dictionary = board._hit_unit(point)
		placement.confirm(board.sim, cell, int(hit.get("id", -1)))
	hover_point = point
	_refresh()

func _input(event: InputEvent) -> void:
	if not is_instance_valid(board):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel()
		get_viewport().set_input_as_handled()
		return
	if panel.gesture.active() or placement.draft.is_empty():
		return
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and event.index != 0:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()
		return
	var point := Vector2(-1000, -1000)
	var confirm := false
	if event is InputEventMouseButton:
		point = event.position
		confirm = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	elif event is InputEventScreenTouch:
		point = event.position
		confirm = event.index == 0 and event.pressed and not event.canceled
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		point = event.position
	else:
		return
	if board._cell_at_viewport_position(point) != Vector2i(-1, -1):
		if confirm:
			_confirm_at(point)
		else:
			_hover(point)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if is_instance_valid(board) and what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_WM_GO_BACK_REQUEST]:
		_cancel()

func _process(_delta: float) -> void:
	if is_instance_valid(board):
		_refresh()

func _reason_text() -> String:
	return {"unavailable": "Falta esencia o una copia libre.", "occupied": "Espacio ocupado o reservado.", "own_territory_required": "Coloca en tus filas inferiores.", "invalid_target": "Elige una criatura propia herida.", "not_equipped": "Carta no equipada.", "refuge_occupied": "Primero sal del refugio.", "terrain_locked_or_same": "Terreno igual o bajo ataque.", "accepted": "Carta desplegada; sigue arriba.", "match_finished": "Partida terminada."}.get(placement.message, "")

func _refresh() -> void:
	if not is_instance_valid(panel.status):
		return
	board.tactical_input_enabled = placement.draft.is_empty()
	panel.locked = placement.busy()
	panel.cancel_button.disabled = placement.draft.is_empty() or placement.busy()
	var labels := ["Criaturas", "Terrenos", "Construcción", "Trucos"]
	for index in range(Catalog.CATEGORIES.size()):
		var category: String = Catalog.CATEGORIES[index]
		var id := stacks.top(category)
		var state: Dictionary = board.sim.cards.availability(0, id, board.sim)
		var copies := "Vacía"
		if not id.is_empty():
			copies = "%s libre · %s act." % [state["available"], state["active"]] if category == "creature" else ("Disponible" if state["available"] > 0 else ("En tablero" if state["active"] > 0 else "Recuperando"))
		var recovery := "↓ otra · ↑ colocar"
		if state["recovering"] > 0:
			recovery = "%s rec. %.1fs" % [state["recovering"], maxf(0, float(state["ready_tick"] - board.sim.tick_count) / 20)]
		elif state["available"] > 0 and not state["valid"]:
			recovery = "Falta esencia"
		panel.cards[category].show_card({"card": id, "category_label": labels[index], "title": Catalog.CARDS.get(id, {"label": "Vacía"})["label"], "ready": state["valid"], "count": stacks.count(category), "cost_text": "%sE · %s/%s" % [state["cost"], stacks.position_of(category) + 1 if stacks.count(category) else 0, stacks.count(category)], "copies_text": copies, "recovery_text": recovery, "selected": placement.draft.get("category") == category})
	panel.status.text = _reason_text()
	if placement.busy():
		panel.status.text = "Confirmando colocación..."
	elif not placement.draft.is_empty() and panel.status.text.is_empty():
		panel.status.text = "Arrastra al tablero o toca un destino."
	elif placement.draft.is_empty() and panel.status.text.is_empty():
		panel.status.text = "↓ Recorrer · ↑ o toque: colocar"
	_refresh_preview()

func _target_at(cell: Vector2i) -> int:
	for unit in board.sim.units:
		if unit["cell"] == cell:
			return int(unit["id"])
	return -1

func _cell_rect(cell: Vector2i) -> Rect2:
	var size: float = board._board_rect().size.x / 4
	return Rect2(board._center(cell) - Vector2.ONE * size * 0.48, Vector2.ONE * size * 0.96)

func _refresh_preview() -> void:
	if placement.draft.is_empty():
		overlay.valid_cells.clear()
		overlay.hover = Rect2()
		_preview_key = ""
	else:
		var key := "%s:%s:%s" % [board.sim.tick_count, placement.draft["card"], board._board_rect()]
		if key != _preview_key:
			_preview_key = key
			overlay.valid_cells.clear()
			for x in range(8):
				for y in range(4):
					var cell := Vector2i(x, y)
					if placement.preview(board.sim, cell, _target_at(cell))["valid"]:
						overlay.valid_cells.append(_cell_rect(cell))
		var hover_cell: Vector2i = board._cell_at_viewport_position(hover_point)
		overlay.hover = Rect2() if hover_cell == Vector2i(-1, -1) else _cell_rect(hover_cell)
		var hit: Dictionary = board._hit_unit(hover_point)
		overlay.valid = placement.preview(board.sim, hover_cell, int(hit.get("id", -1)))["valid"]
		overlay.title = Catalog.CARDS[placement.draft["card"]]["label"]
	overlay.queue_redraw()
