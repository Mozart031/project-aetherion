extends PanelContainer

## Expanded reverse: readable on narrow screens, scrollable, no simulation reference.
signal closed
var heading: Label
var body: Label
var scroll: ScrollContainer
var details: Dictionary = {}
var _scroll_pointer := -1
var _scroll_origin := Vector2.ZERO
var _scroll_start := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.08, 0.10, 0.14, 1.0)
	background.border_color = Color(0.48, 0.55, 0.63)
	background.set_border_width_all(1)
	background.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", background)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 15)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.clip_text = true
	row.add_child(heading)
	var close_button := Button.new()
	close_button.text = "Cerrar"
	close_button.add_theme_font_size_override("font_size", 12)
	close_button.pressed.connect(func(): closed.emit())
	row.add_child(close_button)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	body = Label.new()
	body.add_theme_font_size_override("font_size", 14)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(body)
	var hint := Label.new()
	hint.text = "→ en la carta: frente · Desliza la ficha para leer"
	hint.add_theme_font_size_override("font_size", 10)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(hint)
	visibility_changed.connect(func():
		if not visible:
			_scroll_pointer = -1
	)
	hide()

func _input(event: InputEvent) -> void:
	# Handle native touches explicitly, independently of OS mouse emulation.
	if not visible:
		return
	if _scroll_pointer != -1:
		if event is InputEventScreenDrag and event.index == _scroll_pointer:
			scroll.scroll_vertical = _scroll_start + int(_scroll_origin.y - event.position.y)
		elif event is InputEventScreenTouch and event.index == _scroll_pointer and (event.canceled or not event.pressed):
			_scroll_pointer = -1
		if event is InputEventScreenTouch or event is InputEventScreenDrag or (event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed and not event.canceled and scroll.get_global_rect().has_point(event.position):
		_scroll_pointer = event.index
		_scroll_origin = event.position
		_scroll_start = scroll.scroll_vertical
		get_viewport().set_input_as_handled()

func show_info(title: String, info: Dictionary) -> void:
	details = info.duplicate(true)
	heading.text = title + " · Ficha táctica"
	body.text = "Función: %s\n\nAcción / instinto: %s\n\nVentaja: %s\n\nDesventaja: %s" % [info["role"], info["ability"], info["advantage"], info["disadvantage"]]
	scroll.scroll_vertical = 0
	show()
