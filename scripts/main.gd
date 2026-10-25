extends Node2D

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
		accumulator -= AetherionSimulation.TICK_SECONDS
	queue_redraw()

func _clear_defeated_selection() -> void:
	if selected_unit_id != -1 and sim.get_unit(selected_unit_id).is_empty():
		selected_unit_id = -1

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_select_at_viewport_position(event.position)
	elif event is InputEventScreenTouch:
		if event.index == 0 and event.pressed:
			_select_at_viewport_position(event.position)

func _board_rect() -> Rect2:
	# Fit the full logical board inside either a portrait or landscape viewport.
	var available := get_viewport_rect().size - Vector2(32.0, 32.0)
	var cell_size := maxf(1.0, minf(available.x / AetherionSimulation.WIDTH, available.y / AetherionSimulation.HEIGHT))
	var board_size := Vector2(AetherionSimulation.WIDTH, AetherionSimulation.HEIGHT) * cell_size
	return Rect2((get_viewport_rect().size - board_size) * 0.5, board_size)

func _cell_at_viewport_position(viewport_position: Vector2) -> Vector2i:
	# Input positions are viewport coordinates, drawing uses this Node2D's space.
	var local_position := get_global_transform_with_canvas().affine_inverse() * viewport_position
	var board := _board_rect()
	if not board.has_point(local_position):
		return Vector2i(-1, -1)
	var relative := (local_position - board.position) / (board.size.x / AetherionSimulation.WIDTH)
	return Vector2i(floori(relative.x), floori(relative.y))

func _select_at_viewport_position(viewport_position: Vector2) -> void:
	var cell := _cell_at_viewport_position(viewport_position)
	selected_unit_id = -1
	for unit in sim.units:
		if int(unit["owner"]) == LOCAL_PLAYER and unit["cell"] == cell:
			selected_unit_id = int(unit["id"])
			break
	# Selection is idempotent: an emulated mouse press after a touch cannot toggle it.
	queue_redraw()

func _draw() -> void:
	var board := _board_rect()
	var cell_size := board.size.x / AetherionSimulation.WIDTH
	var origin := board.position
	for y in range(AetherionSimulation.HEIGHT):
		for x in range(AetherionSimulation.WIDTH):
			var rect := Rect2(origin + Vector2(x, y) * cell_size, Vector2.ONE * (cell_size - 2.0))
			draw_rect(rect, Color(0.16, 0.30, 0.24) if x < 4 else Color(0.30, 0.20, 0.30))
	for unit in sim.units:
		var cell: Vector2i = unit["cell"]
		var pos := origin + Vector2(cell) * cell_size + Vector2.ONE * cell_size * 0.5
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
