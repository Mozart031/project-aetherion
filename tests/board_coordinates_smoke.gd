extends SceneTree

const Coordinates = preload("res://scripts/board_coordinates.gd")
var failures := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _initialize() -> void:
	for player in [0, 1]:
		var seen := {}
		var local_count := 0
		var enemy_count := 0
		for x in range(8):
			for y in range(4):
				var logical := Vector2i(x, y)
				var visual: Vector2i = Coordinates.logical_to_visual(logical, player)
				_check(visual.x >= 0 and visual.x < 4 and visual.y >= 0 and visual.y < 8, "Visual bounds")
				_check(not seen.has(visual), "Every logical cell has a unique visual cell")
				seen[visual] = true
				_check(Coordinates.visual_to_logical(visual, player) == logical, "Logical round trip")
				if (x < 4) == (player == 0):
					local_count += 1
					_check(visual.y >= 4, "Local territory is below")
				else:
					enemy_count += 1
					_check(visual.y < 4, "Enemy territory is above")
				for other_x in range(8):
					for other_y in range(4):
						var other := Vector2i(other_x, other_y)
						_check(_distance(logical, other) == _distance(visual, Coordinates.logical_to_visual(other, player)), "Distances and orthogonal adjacency are preserved")
		_check(seen.size() == 32 and local_count == 16 and enemy_count == 16, "32 spaces and 16 per territory")
		for u in range(4):
			for v in range(8):
				var visual := Vector2i(u, v)
				_check(Coordinates.logical_to_visual(Coordinates.visual_to_logical(visual, player), player) == visual, "Visual round trip")
		for invalid in [Vector2i(-1, 0), Vector2i(8, 0), Vector2i(0, -1), Vector2i(0, 4)]:
			_check(Coordinates.logical_to_visual(invalid, player) == Vector2i(-1, -1), "Invalid logical coordinate rejected")
		for invalid in [Vector2i(-1, 0), Vector2i(4, 0), Vector2i(0, -1), Vector2i(0, 8)]:
			_check(Coordinates.visual_to_logical(invalid, player) == Vector2i(-1, -1), "Invalid visual coordinate rejected")
	_check(Coordinates.logical_to_visual(Vector2i(3, 1)) == Vector2i(1, 4), "Boar visual position")
	_check(Coordinates.logical_to_visual(Vector2i(4, 1)) == Vector2i(1, 3), "Turtle visual position")
	for invalid_player in [-1, 2]:
		_check(Coordinates.logical_to_visual(Vector2i.ZERO, invalid_player) == Vector2i(-1, -1), "Invalid perspective rejected")
		_check(Coordinates.visual_to_logical(Vector2i.ZERO, invalid_player) == Vector2i(-1, -1), "Invalid inverse perspective rejected")
	if failures == 0:
		print("PASS: reversible 8x4/4x8 coordinates, both perspectives, all cells and distances")
	quit(0 if failures == 0 else 1)
