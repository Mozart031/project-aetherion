extends SceneTree

var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://scenes/battle_demo.tscn")
	var view = scene.instantiate()
	root.add_child(view)
	view.set_process(false)
	view._process(0.05)
	view.sim.queue_play_card(0, "golem", Vector2i(3, 1))
	view._process(0.05)
	var golem_id: int = view.selected_unit_id
	_check(view.sim.get_unit(golem_id).get("kind") == "golem", "Player deploys golem using the initial four essence")
	var first_targeted := false
	var second_targeted := false
	var pig_requested := false
	var pig_id := -1
	var healed := false
	var rolled := false
	var demolished := false
	# Script player inputs only. No HP, essence or position writes and no enemy march.
	for frame in range(430):
		if not first_targeted:
			view.sim.queue_target(0, golem_id, 1)
			first_targeted = true
		elif view.sim.get_unit(1).is_empty() and not second_targeted:
			view.sim.queue_target(0, golem_id, 2)
			second_targeted = true
		var golem: Dictionary = view.sim.get_unit(golem_id)
		if not golem.is_empty() and not view.sim.cards.buildings.is_empty():
			var fence: Dictionary = view.sim.cards.buildings[0]
			if view.sim.actions.can_start(golem, "demolish", view.sim, int(fence["id"])):
				view.sim.queue_special(0, golem_id, "demolish", int(fence["id"]))
		if view.sim.tick_count >= 300 and not pig_requested:
			view.sim.queue_play_card(0, "pig", Vector2i(3, 1))
			pig_requested = true
		for unit in view.sim.units:
			if unit["owner"] == 0 and unit["kind"] == "pig":
				pig_id = int(unit["id"])
				if unit["hp"] <= 2 and view.sim.players[0]["essence"] >= 2:
					view.sim.queue_play_card(0, "heal", unit["cell"], pig_id)
				if view.sim.actions.can_start(unit, "roll", view.sim):
					view.sim.queue_special(0, pig_id, "roll")
		view._process(0.05)
		for event in view.sim.events:
			if event["type"] == "healed":
				healed = true
			if event["type"] == "special_completed" and event["kind"] == "roll":
				rolled = true
			if event["type"] == "special_completed" and event["kind"] == "demolish":
				demolished = true
	_check(view.sim.get_unit(1).is_empty() and view.sim.get_unit(2).is_empty(), "Directed navigation and combat defeat the initial defenders")
	_check(demolished and view.sim.cards.buildings.is_empty(), "Same battle includes prepared demolition of the paid reinforcement fence")
	_check(healed and rolled and not view.sim.get_unit(pig_id).is_empty(), "Mud action and paid healing sustain an independently controlled pig")
	_check(view.sim.units.all(func(unit): return unit["owner"] == 0), "Player can clear the fixed combat scenario using actual economy")
	_check(view.last_message.contains("despejado"), "Integrated scenario communicates completion without inventing core victory")
	_check(view.sim.players[1]["core_hp"] == 12 and not view.sim.get_player_view(0)["players"][1].has("core_cell"), "Playable encounter retains hidden-core protection")
	await process_frame
	view.queue_free()
	if failures == 0:
		print("PASS: integrated battle cleared through real card economy, navigation, combat, demolition, mud and healing")
	quit(0 if failures == 0 else 1)
