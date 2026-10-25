extends "res://scripts/main.gd"

var info: Label

func _ready() -> void:
	auto_attack = false
	_start_demo()
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	info = Label.new()
	info.position = Vector2(16, 8)
	info.add_theme_font_size_override("font_size", 14)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(info)
	var buttons := HBoxContainer.new()
	buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	buttons.offset_left = 16
	buttons.offset_right = -16
	buttons.offset_top = -52
	buttons.offset_bottom = -12
	panel.add_child(buttons)
	var stop := Button.new()
	stop.text = "Detener orden"
	stop.pressed.connect(func(): sim.queue_stop(LOCAL_PLAYER, selected_unit_id))
	buttons.add_child(stop)
	var restart := Button.new()
	restart.text = "Reiniciar demo"
	restart.pressed.connect(_start_demo)
	buttons.add_child(restart)

func _start_demo() -> void:
	sim.reset()
	sim.natural_defense.enabled = true
	sim.place_terrain(Vector2i(3, 1), "mud")
	sim.place_terrain(Vector2i(3, 2), "mud")
	sim.place_terrain(Vector2i(4, 1), "mud")
	sim.place_terrain(Vector2i(4, 2), "mud")
	accumulator = 0.0
	selected_unit_id = -1
	sim.queue_summon(0, "beaver", Vector2i(1, 1))
	sim.queue_summon(0, "beaver", Vector2i(1, 2))
	sim.queue_summon(1, "beaver", Vector2i(6, 1))
	sim.queue_summon(1, "beaver", Vector2i(6, 2))

func _board_rect() -> Rect2:
	var available := get_viewport_rect().size - Vector2(32, 200)
	var cell_size := maxf(1, minf(available.x / 4.0, available.y / 8.0))
	var board_size := Vector2(4, 8) * cell_size
	return Rect2((get_viewport_rect().size - board_size) * 0.5, board_size)

func _select_at_viewport_position(point: Vector2) -> void:
	var cell := _cell_at_viewport_position(point)
	var local_point := get_global_transform_with_canvas().affine_inverse() * point
	var board := _board_rect()
	var cell_size := board.size.x / 4.0
	var hit: Dictionary = {}
	for unit in sim.get_player_view(LOCAL_PLAYER)["units"]:
		var center := board.position + (_unit_visual_cell(unit) + Vector2.ONE * 0.5) * cell_size
		if unit["cell"] == cell or local_point.distance_to(center) <= cell_size * 0.32:
			hit = unit
			break
	if not hit.is_empty() and hit["owner"] == LOCAL_PLAYER:
		selected_unit_id = int(hit["id"])
	elif selected_unit_id != -1 and not hit.is_empty():
		sim.queue_target(LOCAL_PLAYER, selected_unit_id, int(hit["id"]))
	elif selected_unit_id != -1 and cell != Vector2i(-1, -1):
		sim.queue_destination(LOCAL_PLAYER, selected_unit_id, cell)
	else:
		selected_unit_id = -1
	queue_redraw()

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(info):
		var order: Dictionary = sim.get_player_view(LOCAL_PLAYER)["orders"].get(selected_unit_id, {})
		info.size.x = maxf(1, get_viewport_rect().size.x - 32)
		info.text = "Isla del Caos — combate táctico\nAzul: elegir · Celda: ir · Rival: atacar\nBarro ×2 · Defensa adyacente sin orden\nSelección: %s · %s · Esencia %s" % [str(selected_unit_id), str(order.get("status", "sin orden")), str(sim.players[LOCAL_PLAYER]["essence"])]

func _draw() -> void:
	super._draw()
	var order: Dictionary = sim.get_player_view(LOCAL_PLAYER)["orders"].get(selected_unit_id, {})
	var board := _board_rect()
	var cell_size := board.size.x / 4.0
	for cell in sim.get_player_view(LOCAL_PLAYER)["terrain"]:
		var visual := Vector2(BoardCoordinates.logical_to_visual(cell, LOCAL_PLAYER))
		# Ground tint stays behind miniatures: a translucent frame inside each tile.
		var rect := Rect2(board.position + visual * cell_size + Vector2.ONE * 3, Vector2.ONE * (cell_size - 8))
		draw_rect(rect, Color(0.65, 0.4, 0.18, 0.75), false, cell_size * 0.12)
	for cell in order.get("path", []):
		var visual := Vector2(BoardCoordinates.logical_to_visual(cell, LOCAL_PLAYER))
		draw_circle(board.position + (visual + Vector2.ONE * 0.5) * cell_size, cell_size * 0.06, Color(1, 1, 0.3))
	if not order.is_empty() and order["goal"]["kind"] == "attack_target":
		var target: Dictionary = sim.get_unit(int(order["goal"]["target_id"]))
		if not target.is_empty():
			var center := board.position + (_unit_visual_cell(target) + Vector2.ONE * 0.5) * cell_size
			draw_arc(center, cell_size * 0.4, 0, TAU, 32, Color(1, 0.3, 0.2), 2, true)
