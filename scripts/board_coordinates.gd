extends RefCounted

## Pure presentation adapter. Never changes the logical 8 x 4 simulation.
const VISUAL_WIDTH := 4
const VISUAL_HEIGHT := 8
const INVALID_CELL := Vector2i(-1, -1)

static func logical_to_visual(cell: Vector2i, local_player: int = 0) -> Vector2i:
	if cell.x < 0 or cell.x >= 8 or cell.y < 0 or cell.y >= 4:
		return INVALID_CELL
	match local_player:
		0:
			return Vector2i(cell.y, 7 - cell.x)
		1:
			return Vector2i(3 - cell.y, cell.x)
	return INVALID_CELL

static func visual_to_logical(cell: Vector2i, local_player: int = 0) -> Vector2i:
	if cell.x < 0 or cell.x >= VISUAL_WIDTH or cell.y < 0 or cell.y >= VISUAL_HEIGHT:
		return INVALID_CELL
	match local_player:
		0:
			return Vector2i(7 - cell.y, cell.x)
		1:
			return Vector2i(cell.y, 3 - cell.x)
	return INVALID_CELL
