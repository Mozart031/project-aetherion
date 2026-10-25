extends "res://scripts/battle_demo.gd"

const Feedback = preload("res://scripts/battle_feedback.gd")
var signals_view := Feedback.new()
var act_mode := false
var ecology_button: Button
var hold_button: Button
var act_button: Button
var intent_label: Label
var flank_ordered := false

func _start_battle() -> void:
	super._start_battle()
	sim.natural.enabled = true
	for entry in [[Vector2i(3, 0), "mud"], [Vector2i(2, 3), "cornfield"], [Vector2i(1, 2), "cave"], [Vector2i(5, 0), "mud"], [Vector2i(5, 3), "cornfield"]]:
		sim.place_terrain(entry[0], entry[1])
	signals_view.reset()
	act_mode = false
	flank_ordered = false
	last_message = "Prueba cerdo junto al barro; el rival se acerca al flanco."

func _dock_height() -> float:
	return 288.0

func _extend_controls(dock: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 40
	dock.add_child(row)
	hold_button = _button("Mantener", _hold)
	row.add_child(hold_button)
	ecology_button = _button("Ecología: sí", _toggle_ecology)
	row.add_child(ecology_button)
	act_button = _button("Ir y actuar", _arm_action)
	row.add_child(act_button)
	intent_label = _label(12)
	intent_label.custom_minimum_size.y = 32
	dock.add_child(intent_label)

func _board_rect() -> Rect2:
	var area := Rect2(Vector2(12, 126), get_viewport_rect().size - Vector2(24, 430))
	var cell := maxf(1, minf(area.size.x / 4, area.size.y / 8))
	var size := Vector2(4, 8) * cell
	return Rect2(area.position + (area.size - size) * 0.5, size)

func _hold() -> void:
	act_mode = false
	sim.queue_hold(LOCAL_PLAYER, selected_unit_id)

func _toggle_ecology() -> void:
	var unit := sim.get_unit(selected_unit_id)
	if not unit.is_empty():
		sim.queue_ecology(LOCAL_PLAYER, selected_unit_id, not unit.get("ecology_enabled", true))

func _arm_action() -> void:
	act_mode = not act_mode
	selected_card = ""
	last_message = "Toca barro, maizal, cueva o valla: irá y actuará." if act_mode else "Acción contextual cancelada."

func _choose_card(kind: String) -> void:
	act_mode = false
	super._choose_card(kind)

func _select_at_viewport_position(point: Vector2) -> void:
	if not act_mode:
		super._select_at_viewport_position(point)
		return
	var cell := _cell_at_viewport_position(point)
	var building := sim.cards.building_at(cell)
	var options := sim.get_context_actions(LOCAL_PLAYER, selected_unit_id, cell, int(building.get("id", -1)))
	# Terrain interaction takes priority over a boar's local charge on a cave.
	options.sort_custom(func(a, b): return int(a["kind"] in ["enter", "leave"]) > int(b["kind"] in ["enter", "leave"]))
	for option in options:
		if option["enabled"]:
			sim.queue_act_at(LOCAL_PLAYER, selected_unit_id, option["kind"], option["cell"], option["target_id"])
			last_message = option["label"]
			act_mode = false
			_refresh_ui()
			return
	last_message = "Sin acción compatible aquí. " + (str(options[0]["reason"]) if not options.is_empty() else "Elige una criatura propia.")
	_refresh_ui()

func _after_sim_step() -> void:
	super._after_sim_step()
	if not flank_ordered and sim.tick_count >= 1:
		flank_ordered = true
		# A fixed rival order, not a strategist or mandatory species advance.
		sim.queue_destination(1, 1, Vector2i(4, 0))
	signals_view.consume(sim.get_player_view(LOCAL_PLAYER))
	for event in sim.events:
		if event.get("unit_id", -1) != selected_unit_id:
			continue
		if event["type"] == "order_completed":
			last_message = {"resource_lost": "El recurso desapareció; orden terminada.", "target_defeated": "Objetivo derrotado.", "action_finished": "Acción completada.", "action_cancelled": "La acción fue interrumpida."}.get(event.get("reason"), last_message)
		elif event["type"] == "order_status" and event["status"] == "blocked":
			last_message = "Ruta bloqueada; puedes cambiar el destino o detener la orden."

func _reports_event(event: Dictionary) -> bool:
	return not str(event["type"]).begins_with("special_") or event.get("unit_id", -1) == selected_unit_id

func _refresh_ui() -> void:
	super._refresh_ui()
	if not is_instance_valid(intent_label):
		return
	header.text = header.text.replace("Primera batalla", "Mesa viva · Fase 22")
	var unit := sim.get_unit(selected_unit_id)
	var empty := unit.is_empty()
	hold_button.disabled = empty
	ecology_button.disabled = empty
	act_button.disabled = empty
	ecology_button.text = "Ecología: " + ("sí" if unit.get("ecology_enabled", true) else "no")
	act_button.modulate = Color.YELLOW if act_mode else Color.WHITE
	var order: Dictionary = sim.orders.active.get(selected_unit_id, {})
	hold_button.modulate = Color.YELLOW if order.get("goal", {}).get("kind") == "hold" else Color.WHITE
	var info: Dictionary = sim.get_player_view(LOCAL_PLAYER)["natural"].get(selected_unit_id, {})
	intent_label.text = "Elige una criatura: mantener, ecología o ir y actuar."
	if not empty:
		intent_label.text = ("Destino: toca un recurso compatible" if act_mode else str(info.get("reason", "Observa el entorno")))
		if sim.tick_count < int(unit.get("special_ready_tick", 0)):
			intent_label.text += " · Acción %.1fs" % (float(unit["special_ready_tick"] - sim.tick_count) / 20)
	# Keep the previous demo's counters, but use readable order names here.
	if not empty and not order.is_empty():
		var names := {"pending": "Orden recibida", "moving": "En camino", "blocked": "Ruta bloqueada", "attacking": "Atacando", "holding": "Mantiene posición", "acting": "Realiza una acción", "waiting_special": "Espera para actuar"}
		detail.text = "%s · %s HP · %s\n%s" % [Catalog.CARDS[unit["kind"]]["label"], unit["hp"], names.get(order["status"], "En espera"), last_message]

func _tick_time() -> float:
	return float(sim.tick_count) + accumulator / AetherionSimulation.TICK_SECONDS

func _pose(unit: Dictionary) -> Dictionary:
	return signals_view.pose(unit, _tick_time(), LOCAL_PLAYER, sim.get_motion(unit["id"]), sim.actions.active.get(unit["id"], {}))

func _unit_visual_cell(unit: Dictionary) -> Vector2:
	# Parent uses this exact center for selection, drawing and health bars.
	return super._unit_visual_cell(unit) + Vector2(_pose(unit)["offset"])

func _draw_actor(unit: Dictionary, center: Vector2, size: float, pose: Dictionary, alpha: float = 1) -> void:
	var color: Color = {"pig": Color(0.98, 0.55, 0.67, 0.9), "boar": Color(0.58, 0.32, 0.18, 0.9), "horse": Color(0.84, 0.65, 0.3, 0.9), "golem": Color(0.58, 0.68, 0.72, 0.9)}.get(unit["kind"], Color.CYAN)
	color = color.lerp(Color.WHITE, float(pose["flash"]) * 0.85)
	color.a *= alpha
	draw_set_transform(center, float(pose["angle"]), Vector2(pose["scale"]) * size)
	draw_circle(Vector2.ZERO, 0.29, Color(0.05, 0.08, 0.12, alpha))
	match unit["kind"]:
		"pig", "boar":
			draw_circle(Vector2.ZERO, 0.245, color)
			draw_colored_polygon(PackedVector2Array([Vector2(-0.23, -0.10), Vector2(-0.23, -0.3), Vector2(-0.04, -0.2)]), color)
			draw_colored_polygon(PackedVector2Array([Vector2(0.23, -0.10), Vector2(0.23, -0.3), Vector2(0.04, -0.2)]), color)
			draw_circle(Vector2(0, 0.10), 0.11, Color(1, 0.65, 0.65, alpha))
			if unit["kind"] == "boar":
				for x in [-0.16, 0.16]:
					draw_line(Vector2(x, 0.14), Vector2(x * 1.2, -0.02), Color(1, 0.95, 0.75, alpha), 0.055, true)
		"horse":
			draw_colored_polygon(PackedVector2Array([Vector2(-0.2, 0.22), Vector2(-0.22, -0.2), Vector2(-0.08, -0.33), Vector2(0.05, -0.15), Vector2(0.23, 0.02), Vector2(0.19, 0.23)]), color)
			draw_line(Vector2(-0.21, -0.15), Vector2(-0.21, 0.18), Color(0.24, 0.13, 0.08, alpha), 0.065, true)
		"golem":
			draw_rect(Rect2(-0.24, -0.24, 0.48, 0.46), color)
			for x in [-0.27, 0.16]:
				draw_rect(Rect2(x, 0.05, 0.12, 0.23), color.darkened(0.18))
	for x in [-0.075, 0.075]:
		draw_circle(Vector2(x, -0.06), 0.032, Color(0.06, 0.08, 0.09, alpha))
	draw_set_transform(Vector2.ZERO)
	var team := Color(0.3, 0.78, 1, alpha) if unit.get("owner", 0) == LOCAL_PLAYER else Color(1, 0.45, 0.2, alpha)
	draw_circle(center + Vector2(0, size * 0.28), size * 0.045, team)

func _draw() -> void:
	super._draw()
	var size := _board_rect().size.x / 4
	for unit in sim.units:
		var center := _board_rect().position + (_unit_visual_cell(unit) + Vector2.ONE * 0.5) * size
		_draw_actor(unit, center, size, _pose(unit))
	var time := _tick_time()
	for effect in signals_view.effects:
		var age := time - float(effect["tick"])
		var fade := clampf((float(effect["expires"]) - time) / 8, 0, 1)
		if effect["type"] == "attack_accepted":
			draw_line(_center(effect["from_cell"]), _center(effect["cell"]), Color(1, 0.88, 0.3, fade), maxf(1, size * 0.04), true)
			draw_arc(_center(effect["cell"]), size * (0.1 + minf(age, 8) * 0.025), 0, TAU, 24, Color(1, 0.4, 0.2, fade), 2, true)
		elif effect["type"] == "defeated" and not effect["actor"].is_empty():
			_draw_actor(effect["actor"], _center(effect["cell"]), size * maxf(0.2, 1 - age / 14), {"angle": age * 0.15, "scale": Vector2.ONE, "flash": 0}, fade)
		elif effect["type"] == "special_cancelled" and not sim.get_unit(effect["unit_id"]).is_empty():
			draw_arc(_center(sim.get_unit(effect["unit_id"])["cell"]), size * 0.4, 0, PI, 16, Color(1, 0.4, 0.4, fade), 2, true)
		elif effect["type"] == "card_recovered" and effect.get("player") == LOCAL_PLAYER:
			draw_rect(Rect2(_board_rect().position + Vector2(0, _board_rect().size.y + 3), Vector2(_board_rect().size.x * fade, 3)), Color(0.4, 1, 0.7, fade))
		elif effect["type"] == "card_played" and effect.has("cell"):
			draw_arc(_center(effect["cell"]), size * (0.12 + minf(age, 8) * 0.04), 0, TAU, 24, Color(0.4, 1, 0.9, fade), 2, true)
	var natural_order: Dictionary = sim.natural.view_for(LOCAL_PLAYER, sim.units).get(selected_unit_id, {}).get("goal", {})
	for cell in natural_order.get("path", []):
		draw_circle(_center(cell), maxf(2, size * 0.045), Color(0.4, 1, 0.7, 0.8))
	var order: Dictionary = sim.orders.active.get(selected_unit_id, {})
	if order.get("status") == "blocked" and order.get("goal", {}).has("cell"):
		var center := _center(order["goal"]["cell"])
		draw_line(center - Vector2.ONE * size * 0.18, center + Vector2.ONE * size * 0.18, Color(1, 0.3, 0.2), 3, true)
		draw_line(center + Vector2(-1, 1) * size * 0.18, center + Vector2(1, -1) * size * 0.18, Color(1, 0.3, 0.2), 3, true)
