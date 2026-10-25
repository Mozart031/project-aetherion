extends SceneTree

const Feedback = preload("res://scripts/battle_feedback.gd")
var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var signals_view := Feedback.new()
	var unit := {"id": 1, "kind": "pig", "cell": Vector2i(3, 1), "hp": 4, "owner": 0}
	var view := {"tick": 1, "units": [unit], "events": []}
	signals_view.consume(view)
	view["tick"] = 2
	view["events"] = [{"type": "attack_accepted", "unit_id": 1, "target_id": 2, "from_cell": Vector2i(3, 1), "cell": Vector2i(4, 1)}, {"type": "damaged", "unit_id": 1, "amount": 1, "cell": unit["cell"]}]
	var before := view.duplicate(true)
	signals_view.consume(view)
	signals_view.consume(view)
	_check(signals_view.effects.size() == 2, "Repeated rendering of same tick never duplicates effects")
	var pose := signals_view.pose(unit, 4.0, 0, {}, {})
	_check(pose["offset"].y < 0 and pose["flash"] > 0, "Accepted hit directs lunge and damage flash in rotated view")
	_check(view == before, "Reducer and animation never mutate observed state")
	var roll := signals_view.pose(unit, 5, 0, {}, {"kind": "roll", "start_tick": 2, "end_tick": 8})
	var eat := signals_view.pose(unit, 5, 0, {}, {"kind": "forage", "start_tick": 2, "end_tick": 8})
	_check(roll["angle"] != eat["angle"], "Species actions have distinct presentation poses")
	view["tick"] = 3
	view["units"] = []
	view["events"] = [{"type": "defeated", "unit_id": 1, "kind": "pig", "cell": unit["cell"]}]
	signals_view.consume(view)
	_check(signals_view.actors.is_empty() and signals_view.effects[-1]["actor"] == unit, "Defeat retains a short visual ghost, not a live target")
	view["tick"] = 4
	view["events"] = []
	for index in range(200):
		view["events"].append({"type": "card_recovered", "player": 0, "kind": "pig"})
	signals_view.consume(view)
	_check(signals_view.effects.size() == Feedback.LIMIT, "Effect budget is bounded even during an event burst")
	view["tick"] = 100
	view["events"] = []
	signals_view.consume(view)
	_check(signals_view.effects.is_empty(), "Effects expire without further combat")
	signals_view.reset()
	_check(signals_view.last_tick == -1 and signals_view.actors.is_empty(), "Restart clears all presentation memory")
	if failures == 0:
		print("PASS: observer-only animation events, directional impact, species poses, defeat ghosts, deduplication and bounded effects")
	quit(0 if failures == 0 else 1)
