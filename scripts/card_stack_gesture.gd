extends RefCounted

## One captured pointer, one gesture decision. Coordinates are viewport logical units.
var threshold := 48.0
var horizontal_threshold := 32.0
var axis_ratio := 1.3
var tap_slop := 12.0
var pointer := -2
var category := ""
var origin := Vector2.ZERO
var current := Vector2.ZERO
var origin_rect := Rect2()
var direction := ""
var left_origin := false
var max_distance := 0.0

func active() -> bool:
	return pointer != -2

func cancel() -> void:
	pointer = -2
	category = ""
	direction = ""
	left_origin = false
	max_distance = 0

func press(id: int, stack: String, point: Vector2, rect: Rect2) -> bool:
	if active() or stack.is_empty():
		return false
	pointer = id
	category = stack
	origin = point
	current = point
	origin_rect = rect
	direction = ""
	left_origin = false
	max_distance = 0
	return true

func move(id: int, point: Vector2) -> Dictionary:
	if id != pointer or not active():
		return {}
	current = point
	var delta := current - origin
	max_distance = maxf(max_distance, delta.length())
	left_origin = left_origin or not origin_rect.has_point(point)
	if direction.is_empty() and absf(delta.y) >= threshold and absf(delta.y) >= absf(delta.x) * axis_ratio:
		direction = "up" if delta.y < 0 else "down"
		if direction == "up":
			return {"type": "begin", "category": category}
	elif direction.is_empty() and absf(delta.x) >= horizontal_threshold and absf(delta.x) >= absf(delta.y) * axis_ratio:
		direction = "left" if delta.x < 0 else "right"
	return {}

func release(id: int, point: Vector2) -> Dictionary:
	if id != pointer or not active():
		return {}
	# Recognize a final displacement even if the OS coalesced the drag events.
	var begun := move(id, point)
	var delta := point - origin
	var result := {"type": "none", "category": category, "point": point}
	if direction == "up":
		result["type"] = "drop"
		result["begin"] = not begun.is_empty()
		result["cancel"] = left_origin and origin_rect.has_point(point)
	elif direction == "down" and delta.y >= threshold and delta.y >= absf(delta.x) * axis_ratio:
		result["type"] = "cycle"
	elif direction == "left" and delta.x <= -horizontal_threshold and -delta.x >= absf(delta.y) * axis_ratio:
		result["type"] = "back"
	elif direction == "right" and delta.x >= horizontal_threshold and delta.x >= absf(delta.y) * axis_ratio:
		result["type"] = "front"
	elif direction.is_empty() and max_distance <= tap_slop:
		result["type"] = "select"
	cancel()
	return result
