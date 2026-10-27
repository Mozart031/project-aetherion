extends RefCounted

## Presentation geometry only. No simulation reference or logical-position writes.
const Coordinates = preload("res://scripts/board_coordinates.gd")
const JOIN_TICKS := 12.0 # 0.6 seconds at the existing 20 Hz; purely visual.
const INVALID := Vector2i(-1, -1)
var viewport_size := Vector2(480, 900)
var observer := 0
var joined_tick := -1
var tick_time := 0.0

func progress() -> float:
	return 0.0 if joined_tick < 0 else clampf((tick_time - joined_tick) / JOIN_TICKS, 0, 1)

func cell_size() -> float:
	var available := viewport_size - Vector2(24, 290)
	return maxf(1, minf(available.x / 4.0, available.y / 8.4))

func board_rect() -> Rect2:
	var cell := cell_size()
	return Rect2(Vector2((viewport_size.x - cell * 4) * 0.5, 100 + cell * 0.4), Vector2(4, 8) * cell)

func is_own(cell: Vector2i) -> bool:
	return cell.x >= observer * 4 and cell.x < observer * 4 + 4 and cell.y >= 0 and cell.y < 4

func cell_rect(cell: Vector2i) -> Rect2:
	var visual := Coordinates.logical_to_visual(cell, observer)
	if visual == INVALID:
		return Rect2()
	var side := cell_size()
	var offset := Vector2.ZERO if is_own(cell) else Vector2(0, -side * 0.4 * (1 - progress()))
	return Rect2(board_rect().position + Vector2(visual) * side + offset, Vector2.ONE * side)

func center(cell: Vector2i) -> Vector2:
	return cell_rect(cell).get_center()

func cell_at(point: Vector2) -> Vector2i:
	# Inverse of the very same rectangles used to draw, including the moving half.
	for x in range(8):
		for y in range(4):
			var cell := Vector2i(x, y)
			if cell_rect(cell).has_point(point):
				return cell
	return INVALID

func half_rect(own: bool) -> Rect2:
	var first := Vector2i(observer * 4, 0) if own else Vector2i((1 - observer) * 4, 0)
	var result := cell_rect(first)
	for x in range(8):
		for y in range(4):
			var cell := Vector2i(x, y)
			if is_own(cell) == own:
				result = result.merge(cell_rect(cell))
	return result
