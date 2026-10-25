extends VBoxContainer

signal cycle_requested(category: String)
signal placement_requested(category: String)
signal drag_preview(point: Vector2)
signal drag_released(point: Vector2, returned: bool)
signal cancel_requested

const Catalog = preload("res://scripts/battle_catalog.gd")
const Gesture = preload("res://scripts/card_stack_gesture.gd")
const CardScene = preload("res://scenes/card_stack_control.tscn")
var gesture := Gesture.new()
var cards: Dictionary = {}
var locked := false
var status: Label
var cancel_button: Button

func _ready() -> void:
	custom_minimum_size.y = 120
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for category in Catalog.CATEGORIES:
		var card = CardScene.instantiate()
		row.add_child(card)
		cards[category] = card
	var commands := HBoxContainer.new()
	commands.custom_minimum_size.y = 36
	add_child(commands)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 11)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	commands.add_child(status)
	cancel_button = Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.add_theme_font_size_override("font_size", 12)
	cancel_button.pressed.connect(func(): cancel_requested.emit())
	commands.add_child(cancel_button)

func category_at(point: Vector2) -> String:
	for category in cards:
		if cards[category].get_global_rect().has_point(point):
			return category
	return ""

func _gui_input(event: InputEvent) -> void:
	if locked:
		accept_event()
		return
	var pointer := -2
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pointer = -1
	elif event is InputEventScreenTouch and event.pressed:
		pointer = event.index
	if pointer == -2:
		return
	var point: Vector2 = get_global_transform_with_canvas() * event.position
	var category := category_at(point)
	if not category.is_empty():
		gesture.press(pointer, category, point, cards[category].get_global_rect())
		accept_event()

func _input(event: InputEvent) -> void:
	if not gesture.active():
		return
	var pointer := -1
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		pointer = event.index
	elif event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()
		return
	if pointer != gesture.pointer:
		if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouse:
			get_viewport().set_input_as_handled()
		return
	var response := {}
	var point := Vector2.ZERO
	if event is InputEventScreenDrag:
		point = event.position
		response = gesture.move(event.index, point)
	elif event is InputEventScreenTouch:
		point = event.position
		if event.canceled and event.index == gesture.pointer:
			gesture.cancel()
			cancel_requested.emit()
		elif not event.pressed:
			response = gesture.release(event.index, point)
	elif event is InputEventMouseMotion:
		point = event.position
		response = gesture.move(-1, point)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position
		if not event.pressed:
			response = gesture.release(-1, point)
	else:
		return
	get_viewport().set_input_as_handled()
	if response.get("type") == "begin":
		placement_requested.emit(response["category"])
	elif response.get("type") == "cycle":
		cycle_requested.emit(response["category"])
	elif response.get("type") == "select":
		placement_requested.emit(response["category"])
	elif response.get("type") == "drop":
		if response.get("begin", false):
			placement_requested.emit(response["category"])
		drag_released.emit(point, response["cancel"])
	if gesture.active() and gesture.direction == "up":
		drag_preview.emit(point)
