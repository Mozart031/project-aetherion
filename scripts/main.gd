extends Node2D

const BoardCoordinates = preload("res://scripts/board_coordinates.gd")

var sim := AetherionSimulation.new()
var accumulator := 0.0
var auto_attack := true
var selected_unit_id := -1
const LOCAL_PLAYER := 0

func _ready() -> void:
	sim.queue_summon(0, "boar", Vector2i(3, 1))
	sim.queue_summon(1, "turtle", Vector2i(4, 1))
	queue_redraw()

func _process(delta: float) -> void:
	accumulator += minf(delta, 0.25)
	while accumulator >= AetherionSimulation.TICK_SECONDS:
		# Demo-only command producer: combat is resolved by the simulation.
		if auto_attack and sim.units.size() == 2:
			sim.queue_attack(int(sim.units[0]["id"]), int(sim.units[1]["id"]))
			sim.queue_attack(int(sim.units[1]["id"]), int(sim.units[0]["id"]))
		sim.step()
		_clear_defeated_selection()
		_after_sim_step()
		accumulator -= AetherionSimulation.TICK_SECONDS
	queue_redraw()

func _after_sim_step() -> void:
	pass

func _clear_defeated_selection() -> void:
	if selected_unit_id != -1 and sim.get_unit(selected_unit_id).is_empty():
		selected_unit_id = -1

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_select_at_viewport_position(event.position)
	elif event is InputEventScreenTouch:
		if event.index == 0 and event.pressed:
			_select_at_viewport_position(event.position)

func _board_rect() -> Rect2:
	# Fit the vertical presentation without changing logical simulation dimensions.
	var available := get_viewport_rect().size - Vector2(32.0, 32.0)
	var cell_size := maxf(1.0, minf(available.x / BoardCoordinates.VISUAL_WIDTH, available.y / BoardCoordinates.VISUAL_HEIGHT))
	var board_size := Vector2(BoardCoordinates.VISUAL_WIDTH, BoardCoordinates.VISUAL_HEIGHT) * cell_size
	return Rect2((get_viewport_rect().size - board_size) * 0.5, board_size)

func _cell_at_viewport_position(viewport_position: Vector2) -> Vector2i:
	# Input positions are viewport coordinates, drawing uses this Node2D's space.
	var local_position := get_global_transform_with_canvas().affine_inverse() * viewport_position
	var board := _board_rect()
	if not board.has_point(local_position):
		return Vector2i(-1, -1)
	var relative := (local_position - board.position) / (board.size.x / BoardCoordinates.VISUAL_WIDTH)
	return BoardCoordinates.visual_to_logical(Vector2i(floori(relative.x), floori(relative.y)), LOCAL_PLAYER)

func _select_at_viewport_position(viewport_position: Vector2) -> void:
	var cell := _cell_at_viewport_position(viewport_position)
	var local_position := get_global_transform_with_canvas().affine_inverse() * viewport_position
	var board := _board_rect()
	var cell_size := board.size.x / BoardCoordinates.VISUAL_WIDTH
	for unit in sim.get_player_view(LOCAL_PLAYER)["units"]:
		var drawn_position := board.position + (_unit_visual_cell(unit) + Vector2.ONE * 0.5) * cell_size
		if int(unit["owner"]) == LOCAL_PLAYER and (unit["cell"] == cell or local_position.distance_to(drawn_position) <= cell_size * 0.32):
			selected_unit_id = int(unit["id"])
			queue_redraw()
			return
	if selected_unit_id != -1 and sim.can_move(LOCAL_PLAYER, selected_unit_id, cell):
		sim.queue_move(LOCAL_PLAYER, selected_unit_id, cell)
	else:
		selected_unit_id = -1
	queue_redraw()

func _unit_visual_cell(unit: Dictionary) -> Vector2:
	var motion := sim.get_motion(int(unit["id"]))
	if motion.is_empty():
		return Vector2(BoardCoordinates.logical_to_visual(unit["cell"], LOCAL_PLAYER))
	var visual_from := Vector2(BoardCoordinates.logical_to_visual(motion["from"], LOCAL_PLAYER))
	var visual_to := Vector2(BoardCoordinates.logical_to_visual(motion["to"], LOCAL_PLAYER))
	var tick_time := float(sim.tick_count) + accumulator / AetherionSimulation.TICK_SECONDS
	var progress := clampf((tick_time - float(motion["start_tick"])) / float(int(motion["end_tick"]) - int(motion["start_tick"])), 0.0, 1.0)
	return visual_from.lerp(visual_to, progress)

func _draw() -> void:
	var board := _board_rect()
	var cell_size := board.size.x / BoardCoordinates.VISUAL_WIDTH
	var origin := board.position
	for y in range(AetherionSimulation.HEIGHT):
		for x in range(AetherionSimulation.WIDTH):
			var visual_cell := BoardCoordinates.logical_to_visual(Vector2i(x, y), LOCAL_PLAYER)
			var rect := Rect2(origin + Vector2(visual_cell) * cell_size, Vector2.ONE * (cell_size - 2.0))
			draw_rect(rect, Color(0.16, 0.30, 0.24) if x < 4 else Color(0.30, 0.20, 0.30))
	for unit in sim.get_player_view(LOCAL_PLAYER)["units"]:
		var pos := origin + _unit_visual_cell(unit) * cell_size + Vector2.ONE * cell_size * 0.5
		if int(unit["id"]) == selected_unit_id:
			draw_arc(pos, cell_size * 0.36, 0.0, TAU, 48, Color(1.0, 0.95, 0.3), maxf(2.0, cell_size * 0.04), true)
		draw_circle(pos, cell_size * 0.28, Color(0.30, 0.78, 0.95) if int(unit["owner"]) == 0 else Color(1.0, 0.55, 0.28))
		draw_circle(pos, cell_size * 0.07, Color.BLACK)
		var bar := Rect2(pos + Vector2(-0.35, -0.44) * cell_size, Vector2(0.7, 0.09) * cell_size)
		draw_rect(bar, Color(0.12, 0.12, 0.12))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * _health_fraction(unit), bar.size.y)), Color(0.3, 0.9, 0.35))

func _health_fraction(unit: Dictionary) -> float:
	var max_hp: int = AetherionSimulation.CARD_STATS[unit["kind"]]["hp"]
	return clampf(float(unit["hp"]) / float(max_hp), 0.0, 1.0)
