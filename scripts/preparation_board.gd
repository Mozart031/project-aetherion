extends Node2D

## Renderer/hit testing consume a player view only; never a simulation.
const Layout = preload("res://scripts/preparation_board_layout.gd")
const Feedback = preload("res://scripts/battle_feedback.gd")
const Catalog = preload("res://scripts/battle_catalog.gd")
var layout := Layout.new()
var view: Dictionary = {}
var feedback := Feedback.new()
var selected_unit_id := -1

func present(snapshot: Dictionary, observer: int, joined_tick: int, tick_time: float) -> void:
	view = snapshot.duplicate(true)
	layout.observer = observer
	layout.joined_tick = joined_tick
	layout.tick_time = tick_time
	layout.viewport_size = get_viewport_rect().size
	feedback.consume(view)
	queue_redraw()

func reset() -> void:
	view.clear()
	feedback.reset()
	selected_unit_id = -1

func cell_at_viewport(point: Vector2) -> Vector2i:
	return layout.cell_at(get_global_transform_with_canvas().affine_inverse() * point)

func cell_rect_on_viewport(cell: Vector2i) -> Rect2:
	return get_global_transform_with_canvas() * layout.cell_rect(cell)

func center_on_viewport(cell: Vector2i) -> Vector2:
	return get_global_transform_with_canvas() * layout.center(cell)

func _visible_cell(cell: Vector2i) -> bool:
	return layout.is_own(cell) or layout.joined_tick >= 0

func unit_center(unit: Dictionary) -> Vector2:
	var motion: Dictionary = view.get("motions", {}).get(unit["id"], {})
	var center := layout.center(unit["cell"])
	if not motion.is_empty():
		var duration := maxf(1, float(motion["end_tick"] - motion["start_tick"]))
		var fraction := clampf((layout.tick_time - motion["start_tick"]) / duration, 0, 1)
		center = layout.center(motion["from"]).lerp(layout.center(motion["to"]), fraction)
	var pose := feedback.pose(unit, layout.tick_time, layout.observer, motion, view.get("actions", {}).get(unit["id"], {}))
	return center + Vector2(pose["offset"]) * layout.cell_size()

func hit_unit(point: Vector2) -> Dictionary:
	var local := get_global_transform_with_canvas().affine_inverse() * point
	for unit in view.get("units", []):
		if _visible_cell(unit["cell"]) and local.distance_to(unit_center(unit)) <= layout.cell_size() * 0.32:
			return unit.duplicate(true)
	return {}

func hit_building(point: Vector2) -> Dictionary:
	var cell := cell_at_viewport(point)
	for building in view.get("buildings", []):
		if building["cell"] == cell and _visible_cell(cell):
			return building.duplicate(true)
	return {}

## Audit surface shared with the draw path, including observable effects and audio.
func visual_snapshot() -> Dictionary:
	var terrain := {}
	for cell in view.get("terrain", {}):
		if _visible_cell(cell):
			terrain[cell] = view["terrain"][cell]
	var units: Array = view.get("units", []).filter(func(u): return _visible_cell(u["cell"]))
	var buildings: Array = view.get("buildings", []).filter(func(b): return _visible_cell(b["cell"]))
	var effects: Array = feedback.effects.filter(func(e): return (not e.has("cell") or _visible_cell(e["cell"])) and (layout.joined_tick >= 0 or e.get("player", layout.observer) == layout.observer))
	return {"terrain": terrain, "units": units.duplicate(true), "buildings": buildings.duplicate(true), "effects": effects.duplicate(true), "sound_cues": [], "sealed": layout.joined_tick < 0}

func _draw() -> void:
	if view.is_empty():
		return
	var font := ThemeDB.fallback_font
	var side := layout.cell_size()
	var state := visual_snapshot()
	for x in range(8):
		for y in range(4):
			var cell := Vector2i(x, y)
			var rect := layout.cell_rect(cell).grow(-1)
			var sealed: bool = not layout.is_own(cell) and state["sealed"]
			draw_rect(rect, Color(0.12, 0.14, 0.20) if sealed else Color(0.15, 0.24, 0.20))
			draw_rect(rect, Color(0.25, 0.29, 0.33), false, 1)
	if state["sealed"]:
		var sealed_rect := layout.half_rect(false)
		draw_rect(sealed_rect.grow(-2), Color(0.12, 0.14, 0.20, 0.94))
		draw_string(font, sealed_rect.get_center() + Vector2(-76, -3), "Mesa rival sellada", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.77, 0.75, 0.85))
		draw_string(font, sealed_rect.get_center() + Vector2(-50, 18), "16 secciones", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.62, 0.66, 0.72))
	for cell in state["terrain"]:
		var kind: String = state["terrain"][cell]
		var color: Color = {"mud": Color(0.58, 0.34, 0.16), "cornfield": Color(0.64, 0.66, 0.23), "cave": Color(0.44, 0.44, 0.53)}.get(kind, Color.DARK_GREEN)
		draw_rect(layout.cell_rect(cell).grow(-3), color)
		draw_string(font, layout.center(cell) + Vector2(-side * 0.4, -side * 0.27), {"mud": "Barro", "cornfield": "Maizal", "cave": "Cueva"}.get(kind, kind), HORIZONTAL_ALIGNMENT_LEFT, side * 0.85, 12, Color.WHITE)
	for building in state["buildings"]:
		var center := layout.center(building["cell"])
		draw_rect(Rect2(center - Vector2.ONE * side * 0.28, Vector2.ONE * side * 0.56), Color(0.50, 0.29, 0.13))
		draw_line(center - Vector2.ONE * side * 0.2, center + Vector2.ONE * side * 0.2, Color.BEIGE, 2)
		draw_line(center + Vector2(-1, 1) * side * 0.2, center + Vector2(1, -1) * side * 0.2, Color.BEIGE, 2)
		_health(center, side, float(building["hp"]) / float(building["max_hp"]))
	for unit in state["units"]:
		var center := unit_center(unit)
		if unit["id"] == selected_unit_id:
			draw_arc(center, side * 0.37, 0, TAU, 40, Color.YELLOW, 2, true)
		draw_circle(center, side * 0.27, Color(0.30, 0.78, 0.95) if unit["owner"] == layout.observer else Color(1, 0.55, 0.28))
		draw_string(font, center + Vector2(-9, 5), Catalog.SPECIES_LABELS.get(unit["kind"], "?"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
		_health(center, side, float(unit["hp"]) / float(AetherionSimulation.CARD_STATS[unit["kind"]]["hp"]))
	for effect in state["effects"]:
		if effect["type"] == "card_played" and effect.has("cell"):
			draw_arc(layout.center(effect["cell"]), side * 0.4, 0, TAU, 24, Color(0.4, 1, 0.8), 2, true)
		elif effect["type"] == "attack_accepted":
			draw_line(layout.center(effect["from_cell"]), layout.center(effect["cell"]), Color(1, 0.8, 0.4), 2, true)
	if layout.joined_tick >= 0 and layout.progress() < 1:
		var seam := layout.board_rect().position + Vector2(0, side * 4)
		draw_line(seam, seam + Vector2(side * 4, 0), Color(0.8, 0.75, 1, 1 - layout.progress()), 2, true)

func _health(center: Vector2, side: float, fraction: float) -> void:
	var rect := Rect2(center + Vector2(-0.3, -0.4) * side, Vector2(0.6, 0.06) * side)
	draw_rect(rect, Color(0.08, 0.1, 0.12))
	draw_rect(Rect2(rect.position, rect.size * Vector2(clampf(fraction, 0, 1), 1)), Color(0.3, 0.9, 0.35))
