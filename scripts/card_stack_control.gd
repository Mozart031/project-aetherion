extends Control

## Pure presentation of one equipped type and its separate copy inventory.
var data: Dictionary = {}
var previous_title := ""
var animation := 0.0

func show_card(value: Dictionary) -> void:
	if data.get("card", "") != value.get("card", "") and not data.is_empty():
		previous_title = str(data.get("title", ""))
		animation = 0.2
	data = value
	queue_redraw()

func _process(delta: float) -> void:
	if animation > 0:
		animation = maxf(0, animation - delta)
		queue_redraw()

func _draw() -> void:
	if data.is_empty():
		return
	var font := ThemeDB.fallback_font
	var width := size.x - 8
	var border := Color(0.8, 0.75, 0.5) if data.get("ready", false) else Color(0.4, 0.42, 0.46)
	for index in range(mini(3, int(data.get("count", 0))), 0, -1):
		draw_rect(Rect2(Vector2(index + 1, index + 1), Vector2(size.x - 6, size.y - 5)), Color(0.18, 0.22, 0.28))
		draw_rect(Rect2(Vector2(index + 1, index + 1), Vector2(size.x - 6, size.y - 5)), border, false, 1)
	var rect := Rect2(Vector2.ONE, Vector2(size.x - 6, size.y - 6))
	draw_rect(rect, Color(0.18, 0.28, 0.32) if data.get("ready", false) else Color(0.2, 0.21, 0.24))
	draw_rect(rect, Color.YELLOW if data.get("selected", false) else border, false, 2)
	draw_string(font, Vector2(5, 13), str(data.get("category_label", "")), HORIZONTAL_ALIGNMENT_LEFT, width, 10, Color(0.65, 0.85, 0.95))
	draw_string(font, Vector2(5, 30), str(data.get("title", "Vacía")), HORIZONTAL_ALIGNMENT_LEFT, width, 14, Color.WHITE if data.get("ready", false) else Color(0.7, 0.72, 0.75))
	draw_string(font, Vector2(5, 44), str(data.get("cost_text", "")), HORIZONTAL_ALIGNMENT_LEFT, width, 11, Color(1, 0.85, 0.4))
	draw_string(font, Vector2(5, 57), str(data.get("copies_text", "")), HORIZONTAL_ALIGNMENT_LEFT, width, 10, Color(0.85, 0.9, 0.9))
	draw_string(font, Vector2(5, 70), str(data.get("recovery_text", "")), HORIZONTAL_ALIGNMENT_LEFT, width, 10, Color(0.8, 0.75, 1))
	if animation > 0:
		var fraction := animation / 0.2
		draw_rect(Rect2(Vector2(4, 4 + (1 - fraction) * 22), Vector2(size.x - 10, 28)), Color(0.6, 0.7, 1, fraction * 0.35))
		draw_string(font, Vector2(6, 23 + (1 - fraction) * 22), previous_title, HORIZONTAL_ALIGNMENT_LEFT, width, 12, Color(1, 1, 1, fraction * 0.6))
