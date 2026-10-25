extends RefCounted

## Prototype movement modifier, independent of species ecology and combat stats.
var cells: Dictionary = {}
var mud_multiplier := 2

func reset() -> void:
	cells.clear()

func place(cell: Vector2i, kind: String) -> bool:
	if cell.x < 0 or cell.x >= 8 or cell.y < 0 or cell.y >= 4 or kind not in ["mud", "cornfield", "cave"]:
		return false
	cells[cell] = kind
	return true

func durations(base_ticks: int) -> Dictionary:
	var result := {}
	for cell in cells:
		if cells[cell] == "mud":
			result[cell] = maxi(1, base_ticks) * maxi(1, mud_multiplier)
	return result
