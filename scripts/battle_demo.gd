extends "res://scripts/main.gd"

const Catalog = preload("res://scripts/battle_catalog.gd")
var selected_card := ""
var category := "creature"
var last_message := "Elige una carta y toca tus filas inferiores."
var feedback: Array[Dictionary] = []
var header: Label
var detail: Label
var palette: HBoxContainer
var category_buttons: Array[Button] = []
var special_button: Button
var refuge_button: Button
var scheduled_fence := false
var scheduled_boar := false

func _ready() -> void:
	auto_attack = false
	_start_battle()
	_build_ui()
	_refresh_ui()

func _start_battle() -> void:
	sim.reset()
	sim.natural_defense.enabled = true
	sim.place_terrain(Vector2i(3, 1), "mud")
	sim.place_terrain(Vector2i(2, 1), "cornfield")
	sim.place_terrain(Vector2i(2, 2), "cave")
	sim.queue_play_card(1, "pig", Vector2i(6, 1))
	sim.queue_play_card(1, "pig", Vector2i(6, 2))
	accumulator = 0.0
	selected_unit_id = -1
	selected_card = ""
	scheduled_fence = false
	scheduled_boar = false
	feedback.clear()
	last_message = "Despliega en tus filas; nadie avanza sin una orden."

func _label(size: int = 14) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 13)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	header = _label(16)
	header.position = Vector2(12, 8)
	root.add_child(header)
	detail = _label(13)
	detail.position = Vector2(12, 62)
	root.add_child(detail)
	var dock := VBoxContainer.new()
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_left = 12
	dock.offset_right = -12
	dock.offset_top = -218
	dock.offset_bottom = -12
	root.add_child(dock)
	var categories := HBoxContainer.new()
	dock.add_child(categories)
	for index in range(Catalog.CATEGORIES.size()):
		var key: String = Catalog.CATEGORIES[index]
		var button := _button(Catalog.CATEGORY_LABELS[index], func(): _choose_category(key))
		button.custom_minimum_size.y = 44
		categories.add_child(button)
		category_buttons.append(button)
	palette = HBoxContainer.new()
	palette.custom_minimum_size.y = 48
	dock.add_child(palette)
	var controls := HBoxContainer.new()
	controls.custom_minimum_size.y = 42
	dock.add_child(controls)
	special_button = _button("Acción", _special)
	controls.add_child(special_button)
	refuge_button = _button("Refugio", _refuge)
	controls.add_child(refuge_button)
	controls.add_child(_button("Detener", func(): sim.queue_stop(LOCAL_PLAYER, selected_unit_id)))
	controls.add_child(_button("Reiniciar", _start_battle))
	var hint := _label(12)
	hint.text = "Azul: elegir · Celda: ir · Rival/valla: atacar\nMaizal: comer · Barro: revolcarse · Cueva: entrar/salir"
	dock.add_child(hint)
	_choose_category("creature")

func _choose_category(value: String) -> void:
	category = value
	selected_card = ""
	for child in palette.get_children():
		palette.remove_child(child)
		child.queue_free()
	for kind in Catalog.CARDS:
		if Catalog.CARDS[kind]["category"] == category:
			var key: String = kind
			var button := _button("", func(): _choose_card(key))
			button.set_meta("card", key)
			palette.add_child(button)
	_refresh_ui()

func _choose_card(kind: String) -> void:
	selected_card = kind
	last_message = "Toca una criatura propia." if kind == "heal" else "Toca un espacio de tus filas inferiores."
	_refresh_ui()

func _board_rect() -> Rect2:
	var area := Rect2(Vector2(12, 126), get_viewport_rect().size - Vector2(24, 360))
	var cell_size := maxf(1, minf(area.size.x / 4.0, area.size.y / 8.0))
	var size := Vector2(4, 8) * cell_size
	return Rect2(area.position + (area.size - size) * 0.5, size)

func _hit_unit(point: Vector2) -> Dictionary:
	var cell := _cell_at_viewport_position(point)
	var local_point := get_global_transform_with_canvas().affine_inverse() * point
	var board := _board_rect()
	for unit in sim.get_player_view(LOCAL_PLAYER)["units"]:
		var center := board.position + (_unit_visual_cell(unit) + Vector2.ONE * 0.5) * board.size.x / 4.0
		if unit["cell"] == cell or center.distance_to(local_point) < board.size.x / 4.0 * 0.32:
			return unit
	return {}

func _select_at_viewport_position(point: Vector2) -> void:
	var cell := _cell_at_viewport_position(point)
	var hit := _hit_unit(point)
	if not selected_card.is_empty():
		sim.queue_play_card(LOCAL_PLAYER, selected_card, cell, int(hit.get("id", -1)))
		selected_card = ""
	elif not hit.is_empty() and hit["owner"] == LOCAL_PLAYER:
		selected_unit_id = int(hit["id"])
	elif selected_unit_id != -1 and not hit.is_empty():
		sim.queue_target(LOCAL_PLAYER, selected_unit_id, int(hit["id"]))
	elif selected_unit_id != -1 and not sim.cards.building_at(cell).is_empty():
		sim.queue_target(LOCAL_PLAYER, selected_unit_id, int(sim.cards.building_at(cell)["id"]))
	elif selected_unit_id != -1 and cell != Vector2i(-1, -1):
		sim.queue_destination(LOCAL_PLAYER, selected_unit_id, cell)
	else:
		selected_unit_id = -1
	_refresh_ui()

func _demolition_target(unit: Dictionary) -> int:
	if unit.is_empty():
		return -1
	for building in sim.cards.buildings:
		if building["owner"] != unit["owner"] and sim._can_attack(unit, building):
			return int(building["id"])
	return -1

func _action_kind(unit: Dictionary) -> String:
	return {"pig": "roll", "horse": "forage", "boar": "charge", "golem": "demolish"}.get(unit.get("kind", ""), "")

func _special() -> void:
	var unit := sim.get_unit(selected_unit_id)
	if not unit.is_empty():
		sim.queue_special(LOCAL_PLAYER, selected_unit_id, _action_kind(unit), _demolition_target(unit))

func _refuge() -> void:
	var unit := sim.get_unit(selected_unit_id)
	if not unit.is_empty():
		sim.queue_special(LOCAL_PLAYER, selected_unit_id, "leave" if unit.get("sheltered", false) else "enter")

func _after_sim_step() -> void:
	for event in sim.get_player_view(LOCAL_PLAYER)["events"]:
		var type: String = event["type"]
		if type == "summoned" and event.get("owner") == LOCAL_PLAYER:
			selected_unit_id = int(event["unit_id"])
		if type in ["damaged", "building_damaged", "healed", "charge_hit", "special_started", "special_completed", "defeated", "building_defeated", "card_played"] and event.has("cell"):
			var effect: Dictionary = event.duplicate(true)
			effect["expires"] = sim.tick_count + 24
			feedback.append(effect)
		if type == "card_rejected" and event["player"] == LOCAL_PLAYER:
			last_message = "No se pudo jugar: " + str({"invalid_card": "carta no válida.", "unavailable": "falta esencia o copias libres.", "invalid_target": "elige una criatura propia herida.", "own_territory_required": "usa tus filas inferiores.", "occupied": "espacio ocupado o reservado.", "refuge_occupied": "haz salir primero del refugio.", "terrain_locked_or_same": "terreno igual o bajo ataque."}.get(event["reason"], "revisa el destino."))
		elif type == "special_rejected":
			last_message = "Acción no disponible: revisa terreno, vida y espera."
		elif type == "special_started":
			last_message = {"roll": "Revolcándose en el barro...", "forage": "Comiendo maíz...", "charge": "Preparando embestida...", "demolish": "Preparando demolición...", "enter": "Entrando en la cueva...", "leave": "Saliendo de la cueva..."}.get(event["kind"], "Preparando acción...")
		elif type == "special_completed":
			last_message = {"roll": "El barro ayuda a recuperar vida.", "forage": "Maizal consumido: vida recuperada.", "charge": "Embestida preparada para el siguiente golpe.", "demolish": "¡Impacto de demolición!", "enter": "Refugiado: puedes ordenar salir o moverte.", "leave": "Fuera del refugio; listo para actuar."}.get(event["kind"], "Acción completada.")
		elif type == "special_cancelled":
			last_message = "Acción interrumpida: no queda un efecto pendiente."
		elif type == "card_recovered" and event.get("player", LOCAL_PLAYER) == LOCAL_PLAYER:
			last_message = "Una copia de " + str(Catalog.CARDS.get(event["kind"], {"label": "criatura"})["label"]) + " vuelve disponible."
	if sim.tick_count > 302 and scheduled_boar and sim.units.all(func(unit): return unit["owner"] == LOCAL_PLAYER) and sim.cards.buildings.all(func(building): return building["owner"] == LOCAL_PLAYER):
		last_message = "Escenario despejado. Reinicia para otra batalla."
	feedback = feedback.filter(func(effect): return int(effect["expires"]) > sim.tick_count)
	if feedback.size() > 40:
		feedback = feedback.slice(feedback.size() - 40)
	# Fixed scenario reinforcement paid through the same economy; no autonomous advance.
	if not scheduled_fence and sim.tick_count >= 121:
		scheduled_fence = true
		sim.queue_play_card(1, "fence", Vector2i(5, 1))
	if not scheduled_boar and sim.tick_count >= 301:
		scheduled_boar = true
		sim.queue_play_card(1, "boar", Vector2i(4, 1))

func _process(delta: float) -> void:
	super._process(delta)
	_refresh_ui()

func _refresh_ui() -> void:
	if not is_instance_valid(header):
		return
	var width := maxf(1, get_viewport_rect().size.x - 24)
	header.size.x = width
	detail.size.x = width
	var unit := sim.get_unit(selected_unit_id)
	var description := "Sin selección"
	if not unit.is_empty():
		var order: Dictionary = sim.orders.active.get(selected_unit_id, {})
		var state: String = {"moving": "En camino", "attacking": "Atacando", "blocked": "Ruta bloqueada", "pending": "Orden recibida"}.get(order.get("status", ""), "Refugiado" if unit.get("sheltered", false) else "Libre")
		if sim.actions.active.has(selected_unit_id):
			state = "Preparando acción"
		description = "%s #%s · HP %s/%s · %s" % [Catalog.CARDS[unit["kind"]]["label"], str(unit["id"]), str(unit["hp"]), str(sim.CARD_STATS[unit["kind"]]["hp"]), state]
		var wait_ticks := maxi(0, int(unit.get("special_ready_tick", 0)) - sim.tick_count)
		if wait_ticks > 0:
			description += " · acción %.1fs" % (float(wait_ticks) / 20.0)
	header.text = "Isla del Caos · Primera batalla\nEsencia %s/8 · +1 en %.1f s" % [str(sim.players[LOCAL_PLAYER]["essence"]), float(60 - sim.tick_count % 60) / 20.0]
	detail.text = description + "\n" + last_message
	for button in palette.get_children():
		var kind: String = button.get_meta("card")
		var data: Dictionary = Catalog.CARDS[kind]
		var state := sim.cards.state(LOCAL_PLAYER, kind, sim)
		var suffix := "%s libres" % str(state["available"])
		if state["recovering"] > 0:
			suffix += " · R %.1fs" % (float(int(state["ready_tick"]) - sim.tick_count) / 20.0)
		button.text = "%s %sE\n%s" % [data["label"], str(data["cost"]), suffix]
		button.disabled = state["available"] <= 0 or sim.players[LOCAL_PLAYER]["essence"] < data["cost"]
		button.modulate = Color(1, 1, 0.5) if selected_card == kind else Color.WHITE
	for index in range(category_buttons.size()):
		category_buttons[index].modulate = Color(1, 1, 0.5) if category == Catalog.CATEGORIES[index] else Color.WHITE
	var kind := _action_kind(unit)
	special_button.text = {"roll": "Revolcarse", "forage": "Comer", "charge": "Embestida", "demolish": "Demoler"}.get(kind, "Acción")
	special_button.disabled = unit.is_empty() or not sim.actions.can_start(unit, kind, sim, _demolition_target(unit))
	var refuge_kind := "leave" if unit.get("sheltered", false) else "enter"
	refuge_button.text = "Salir" if refuge_kind == "leave" else "Refugio"
	refuge_button.disabled = unit.is_empty() or not sim.actions.can_start(unit, refuge_kind, sim)

func _center(cell: Vector2i) -> Vector2:
	var board := _board_rect()
	return board.position + (Vector2(BoardCoordinates.logical_to_visual(cell, LOCAL_PLAYER)) + Vector2.ONE * 0.5) * board.size.x / 4.0

func _draw() -> void:
	super._draw()
	var font := ThemeDB.fallback_font
	var cell_size := _board_rect().size.x / 4.0
	for cell in sim.terrain.cells:
		var kind: String = sim.terrain.cells[cell]
		var color: Color = {"mud": Color(0.7, 0.4, 0.15), "cornfield": Color(0.95, 0.8, 0.15), "cave": Color(0.6, 0.6, 0.75)}[kind]
		var rect := Rect2(_center(cell) - Vector2.ONE * cell_size * 0.46, Vector2.ONE * cell_size * 0.9)
		draw_rect(rect, color, false, maxf(2, cell_size * 0.06))
		draw_string(font, rect.position + Vector2(3, 13), {"mud": "B", "cornfield": "M", "cave": "C"}[kind], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	for building in sim.cards.buildings:
		var center := _center(building["cell"])
		draw_rect(Rect2(center - Vector2.ONE * cell_size * 0.3, Vector2.ONE * cell_size * 0.6), Color(0.5, 0.28, 0.12))
		draw_line(center + Vector2(-0.25, -0.25) * cell_size, center + Vector2(0.25, 0.25) * cell_size, Color.WHITE, 2)
		draw_line(center + Vector2(-0.25, 0.25) * cell_size, center + Vector2(0.25, -0.25) * cell_size, Color.WHITE, 2)
		draw_rect(Rect2(center + Vector2(-0.3, -0.4) * cell_size, Vector2(0.6 * float(building["hp"]) / 4.0, 0.06) * cell_size), Color(1, 0.5, 0.2))
	for unit in sim.units:
		var center := _board_rect().position + (_unit_visual_cell(unit) + Vector2.ONE * 0.5) * cell_size
		draw_string(font, center + Vector2(-9, 5), Catalog.SPECIES_LABELS.get(unit["kind"], "?"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		if unit.get("sheltered", false):
			draw_arc(center, cell_size * 0.34, PI, TAU, 24, Color(0.8, 0.8, 1), 4, true)
		if unit.get("charged", false):
			draw_arc(center, cell_size * 0.32, 0, TAU, 24, Color.ORANGE, 3, true)
		if sim.actions.active.has(unit["id"]):
			var action: Dictionary = sim.actions.active[unit["id"]]
			var progress := float(sim.tick_count - int(action["start_tick"])) / float(int(action["end_tick"]) - int(action["start_tick"]))
			draw_arc(center, cell_size * 0.4, -PI / 2, -PI / 2 + TAU * progress, 32, Color.CYAN, 3, true)
	var order: Dictionary = sim.orders.view_for(LOCAL_PLAYER, sim.units).get(selected_unit_id, {})
	for cell in order.get("path", []):
		draw_circle(_center(cell), maxf(2, cell_size * 0.05), Color.YELLOW)
	if not order.is_empty() and order["goal"]["kind"] == "attack_target":
		var target: Dictionary = sim.get_target(int(order["goal"]["target_id"]))
		if not target.is_empty():
			draw_arc(_center(target["cell"]), cell_size * 0.42, 0, TAU, 32, Color(1, 0.3, 0.1), 2, true)
	if not selected_card.is_empty() and selected_card != "heal":
		for x in range(4):
			for y in range(4):
				draw_rect(Rect2(_center(Vector2i(x, y)) - Vector2.ONE * cell_size * 0.45, Vector2.ONE * cell_size * 0.88), Color(0.4, 1, 0.5, 0.4), false, 1)
	for effect in feedback:
		var type: String = effect["type"]
		var text: String = {"damaged": "-%s" % str(effect.get("amount", "")), "building_damaged": "-%s" % str(effect.get("amount", "")), "healed": "+%s" % str(effect.get("amount", 0)), "charge_hit": "¡Impacto!", "special_started": "...", "special_completed": "¡Acción!", "defeated": "Derrota", "building_defeated": "Rota", "card_played": "+"}.get(type, "")
		if type == "special_completed":
			text = {"roll": "+%s · Barro" % str(effect.get("amount", 0)), "forage": "+%s · Comió" % str(effect.get("amount", 0)), "enter": "Refugiado", "leave": "Salió", "charge": "¡Preparado!", "demolish": "¡Demolición!"}.get(effect["kind"], "¡Acción!")
		var age := float(24 - (int(effect["expires"]) - sim.tick_count))
		var point := _center(effect["cell"]) + Vector2(-12, -cell_size * 0.2 - age)
		draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.85, 0.4, clampf(float(effect["expires"] - sim.tick_count) / 12, 0, 1)))
