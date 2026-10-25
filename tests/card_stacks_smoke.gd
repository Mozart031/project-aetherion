extends SceneTree

const Loadout = preload("res://scripts/match_loadout.gd")
const Stacks = preload("res://scripts/card_stack_model.gd")
const Catalog = preload("res://scripts/battle_catalog.gd")
var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var model := Stacks.new()
	_check(model.configure(Loadout.default_cards()), "Default equipped types configure four stacks")
	var sequence := ["pig", "boar", "horse", "golem"]
	for id in sequence:
		_check(model.top("creature") == id, "Each species is a distinct circular entry")
		model.cycle("creature")
	_check(model.top("creature") == "pig" and model.count("creature") == 4, "Four rotations wrap without turning copies into entries")
	model.cycle("creature")
	model.cycle("terrain")
	_check(model.top("creature") == "boar" and model.top("terrain") == "mud", "Stack cursors remain independent")
	for index in range(8):
		_check(model.cycle("construction") == "fence", "A one-card stack stays on the same type")
	var before := model.snapshot()
	var invalid := Loadout.default_cards()
	invalid["creature"].append("pig")
	_check(not model.configure(invalid) and before == model.snapshot(), "Duplicate species entries reject atomically instead of representing copies")
	invalid = Loadout.default_cards()
	invalid["terrain"].append("golem")
	_check(not model.configure(invalid), "Wrong category cannot be equipped")
	invalid = Loadout.default_cards()
	invalid["creature"].append("unknown")
	_check(not model.configure(invalid), "Unknown IDs reject")
	var empty := {"creature": [], "terrain": [], "construction": [], "trick": []}
	_check(model.configure(empty) and model.top("creature") == "" and model.cycle("creature") == "", "Empty stacks are safe and explicit")
	var future_catalog: Dictionary = Catalog.CARDS.duplicate(true)
	future_catalog["test_wall"] = {"category": "construction"}
	future_catalog["test_trick"] = {"category": "trick"}
	var future := Loadout.default_cards()
	future["construction"].append("test_wall")
	future["trick"].append("test_trick")
	_check(model.configure(future, future_catalog) and model.cycle("construction") == "test_wall" and model.cycle("trick") == "test_trick", "New catalog fixtures reuse the same stack engine without adding playable mechanics")
	var sim := AetherionSimulation.new()
	var equipped := Loadout.default_cards()
	equipped["creature"] = ["horse", "pig"]
	_check(sim.configure_loadout(0, equipped), "Equip once before the first tick")
	equipped["creature"].clear()
	_check(sim.loadouts[0].contains("horse"), "Match configuration is isolated from caller mutations")
	sim.queue_play_card(0, "boar", Vector2i(1, 1))
	sim.step()
	_check(sim.units.is_empty() and sim.players[0]["essence"] == 4 and sim.events[0]["reason"] == "not_equipped", "Simulation rejects unequipped types without cost")
	_check(not sim.configure_loadout(0, Loadout.default_cards()), "Equipment cannot be edited during battle")
	model.configure(sim.loadouts[0].snapshot())
	var cursor_before := model.snapshot()
	sim.queue_play_card(0, "horse", Vector2i(1, 1))
	sim.step()
	_check(sim.get_unit(1).get("kind") == "horse" and cursor_before == model.snapshot(), "Playing a card cannot rotate any cursor")
	sim.reset()
	_check(not sim.loadouts[0].contains("boar") and sim.loadouts[0].contains("horse"), "Restart preserves the equipped match configuration")
	if failures == 0:
		print("PASS: equipped types, independent circular stacks, empty/single/future catalogs, immutable loadout and copy separation")
	quit(0 if failures == 0 else 1)
