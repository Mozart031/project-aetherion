extends RefCounted

## Presentation adapter: consumes observer events, never receives a simulation.
## A future hologram renderer can consume these same event/pose contracts.
const Coordinates = preload("res://scripts/board_coordinates.gd")
const LIMIT := 64
var effects: Array[Dictionary] = []
var actors: Dictionary = {}
var last_tick := -1

func reset() -> void:
	effects.clear()
	actors.clear()
	last_tick = -1

func consume(view: Dictionary) -> void:
	var tick: int = view["tick"]
	if tick < last_tick:
		reset()
	if tick == last_tick:
		return
	last_tick = tick
	effects = effects.filter(func(effect): return int(effect["expires"]) > tick)
	for event in view["events"]:
		var type: String = event["type"]
		if type not in ["attack_accepted", "damaged", "building_damaged", "defeated", "building_defeated", "special_started", "special_completed", "special_cancelled", "card_played", "card_recovered", "board_joined"]:
			continue
		var effect: Dictionary = event.duplicate(true)
		effect["tick"] = tick
		effect["expires"] = tick + (14 if type in ["defeated", "building_defeated", "card_recovered", "board_joined"] else 8)
		if type == "defeated":
			effect["actor"] = actors.get(event["unit_id"], {}).duplicate(true)
		effects.append(effect)
	if effects.size() > LIMIT:
		effects = effects.slice(effects.size() - LIMIT)
	actors.clear()
	for unit in view["units"]:
		actors[unit["id"]] = unit.duplicate(true)

func pose(unit: Dictionary, tick_time: float, observer: int, motion: Dictionary, action: Dictionary) -> Dictionary:
	var offset := Vector2.ZERO
	var angle := 0.0
	var scale := Vector2.ONE
	var flash := 0.0
	for effect in effects:
		var age := tick_time - float(effect["tick"])
		if age < 0 or tick_time >= float(effect["expires"]):
			continue
		if effect["type"] == "attack_accepted" and effect["unit_id"] == unit["id"]:
			var from := Vector2(Coordinates.logical_to_visual(effect["from_cell"], observer))
			var to := Vector2(Coordinates.logical_to_visual(effect["cell"], observer))
			offset += (to - from).normalized() * sin(minf(age / 6.0, 1.0) * PI) * 0.14
			angle += sin(minf(age / 6.0, 1.0) * PI) * (0.15 if unit["kind"] == "golem" else -0.12)
		if effect["type"] == "damaged" and effect["unit_id"] == unit["id"]:
			flash = maxf(flash, maxf(0, 1.0 - age / 5.0))
	if not motion.is_empty():
		angle += sin(tick_time * 1.7) * (0.08 if unit["kind"] == "golem" else 0.16)
	if not action.is_empty():
		var progress := clampf((tick_time - float(action["start_tick"])) / maxf(1, float(action["end_tick"] - action["start_tick"])), 0, 1)
		match action["kind"]:
			"roll": angle += progress * TAU
			"forage": scale = Vector2(1 + sin(progress * PI * 4) * 0.08, 1 - sin(progress * PI * 4) * 0.15)
			"charge": angle -= sin(progress * PI) * 0.35
			"demolish": scale = Vector2(1 - sin(progress * PI) * 0.12, 1 + sin(progress * PI) * 0.18)
			"enter": scale *= 1 - progress * 0.25
			"leave": scale *= 0.75 + progress * 0.25
	elif unit.get("sheltered", false):
		scale *= 0.75
	return {"offset": offset, "angle": angle, "scale": scale, "flash": flash}
