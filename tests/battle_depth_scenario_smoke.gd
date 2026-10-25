extends SceneTree

var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var view = load("res://scenes/battle_depth_demo.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view._process(0.05)
	view.sim.queue_play_card(0, "pig", Vector2i(3, 0))
	view._process(0.05)
	var pig: int = view.selected_unit_id
	var wounded := false
	var recovered := false
	var hits := false
	var interrupted := false
	var held := false
	var golem := -1
	var demolished := false
	var fence_ordered := false
	# Real card payments and damage only; no health, position or essence fixture writes.
	for tick in range(650):
		var unit: Dictionary = view.sim.get_unit(pig)
		if not unit.is_empty() and view.sim.natural.has_goal(pig) and not interrupted and recovered:
			view.sim.queue_hold(0, pig)
			interrupted = true
		if interrupted and not held:
			held = view.sim.orders.active.get(pig, {}).get("goal", {}).get("kind") == "hold"
		if golem == -1 and view.sim.players[0]["essence"] >= 4:
			view.sim.queue_play_card(0, "golem", Vector2i(3, 1))
		for actor in view.sim.units:
			if actor["owner"] == 0 and actor["kind"] == "golem":
				golem = int(actor["id"])
		if golem != -1 and not view.sim.cards.buildings.is_empty() and not fence_ordered:
			var fence: Dictionary = view.sim.cards.buildings[0]
			view.sim.queue_act_at(0, golem, "demolish", fence["cell"], fence["id"])
			fence_ordered = true
		if demolished and not unit.is_empty() and not view.sim.get_unit(1).is_empty() and not view.sim.orders.active.has(pig):
			view.sim.queue_target(0, pig, 1)
		view._process(0.05)
		for event in view.sim.events:
			if event["type"] == "damaged" and event["unit_id"] == pig:
				wounded = true
			if event["type"] == "attack_accepted":
				hits = true
			if event["type"] == "special_completed" and event["kind"] == "roll" and event["unit_id"] == pig and event.get("source") == "natural":
				recovered = true
			if event["type"] == "special_completed" and event["kind"] == "demolish":
				demolished = true
	_check(wounded and recovered and hits, "Paid battle creates wounds, natural mud recovery and visible accepted attacks")
	_check(demolished and fence_ordered, "Same encounter includes a paid golem opening the reinforced route with go-and-demolish")
	_check(interrupted and held, "Player overrides a subsequent natural intention with persistent hold in the real encounter")
	_check(view.sim.players[0]["essence"] <= 8 and view.sim.cards.state(0, "golem", view.sim)["available"] == 0, "Integrated ecology keeps the active authentic golem unavailable and uses real essence")
	_check(not view.sim.get_player_view(0)["players"][1].has("core_cell") and view.sim.players[1]["core_hp"] == 12, "Integrated encounter never discovers or damages the hidden core")
	view.queue_free()
	if failures == 0:
		print("PASS: Phase 22 real-economy integrated combat, wounds, natural recovery, explicit intervention and go-and-demolish")
	quit(0 if failures == 0 else 1)
