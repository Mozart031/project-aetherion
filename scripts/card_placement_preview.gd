extends Node2D

var valid_cells: Array[Rect2] = []
var hover := Rect2()
var valid := false
var title := ""

func _draw() -> void:
	for rect in valid_cells:
		draw_rect(rect, Color(0.3, 1, 0.6, 0.13))
		draw_rect(rect, Color(0.3, 1, 0.6, 0.45), false, 1)
	if hover.size != Vector2.ZERO:
		var color := Color(0.3, 1, 0.65, 0.7) if valid else Color(1, 0.3, 0.25, 0.7)
		draw_rect(hover, color, false, 3)
		draw_string(ThemeDB.fallback_font, hover.position + Vector2(2, -4), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
