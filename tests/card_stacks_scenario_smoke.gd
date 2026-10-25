extends SceneTree

var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _play(view, category: String, id: String, cell: Vector2i) -> void:
	for turn in range(view.stacks.count(category)):
		if view.stacks.top(category) == id:
			break
		view._cycle(category)
	var essence: int = view.board.sim.players[0]["essence"]
	view._begin(category)
	view._confirm_at(view.board._center(cell))
	_check(view.placement.busy() and view.board.sim.players[0]["essence"] == essence, "Selecting actual equipped card only pays after a valid tick-confirmed deployment")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var view = load("res://scenes/battle_stacks_demo.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view.board.set_process(false)
	view.board._process(0.05)
	_play(view, "creature", "golem", Vector2i(3, 1))
	view.board._process(0.05)
	var golem: int = view.board.selected_unit_id
	view.board.sim.queue_target(0, golem, 1)
	var fence_order := false
	var demolished := false
	var lost_pig := -1
	var lost_copy := -1
	var recovery_rejected := false
	var opened_route := false
	var loss_tick := -1
	var reused := false
	var healed := false
	var played := {}
	played["golem"] = true
	# The entire encounter uses real payments, combat wounds and recovery.
	# No writes to HP, essence, positions, copy state or timers.
	while view.board.sim.tick_count < 1260:
		var sim: AetherionSimulation = view.board.sim
		if loss_tick > 0 and sim.tick_count == loss_tick:
			for turn in range(view.stacks.count("creature")):
				if view.stacks.top("creature") == "pig":
					break
				view._cycle("creature")
		if demolished and not opened_route:
			opened_route = true
			sim.queue_destination(0, golem, Vector2i(5, 2))
		if not sim.cards.buildings.is_empty() and not fence_order:
			var fence: Dictionary = sim.cards.buildings[0]
			if fence["owner"] == 1:
				fence_order = true
				sim.queue_act_at(0, golem, "demolish", fence["cell"], fence["id"])
		if loss_tick > 0:
			for unit in sim.units:
				if unit["owner"] == 1 and unit["kind"] == "boar":
					# Explicit rival hold permits a real simultaneous counter-hit after cooldown.
					sim.queue_hold(1, unit["id"])
					if sim.tick_count >= unit["ready_tick"] and not sim.orders.active.has(golem):
						sim.queue_target(0, golem, unit["id"])
		match sim.tick_count:
			180: _play(view, "creature", "pig", Vector2i(3, 1))
			420:
				_check(sim.get_unit(golem)["hp"] < 6, "Earlier actual combat wounded the golem for the heal card")
				_play(view, "trick", "heal", sim.get_unit(golem)["cell"])
			360:
				var before: int = sim.players[0]["essence"]
				view._begin("creature")
				recovery_rejected = view.placement.draft.is_empty() and view.placement.message == "species_recovering" and sim.players[0]["essence"] == before
			480: _play(view, "construction", "fence", Vector2i(0, 2))
			540: _play(view, "terrain", "cornfield", Vector2i(1, 3))
			600: _play(view, "terrain", "mud", Vector2i(0, 1))
			720: _play(view, "terrain", "cave", Vector2i(0, 3))
			900: _play(view, "creature", "horse", Vector2i(2, 3))
			1080: _play(view, "creature", "boar", Vector2i(1, 0))
			1200: _play(view, "creature", "pig", Vector2i(2, 0))
		var cursor_before: Dictionary = view.stacks.snapshot()
		var pending: Dictionary = view.placement.draft.duplicate(true)
		view.board._process(0.05)
		var expected: Dictionary = cursor_before["cursors"].duplicate()
		if pending.get("state") == "sending":
			for event in sim.events:
				if event["type"] == "card_result" and event["player"] == 0 and event["request_id"] == pending["request_id"] and event["accepted"]:
					expected[pending["category"]] = (int(expected[pending["category"]]) + 1) % view.stacks.count(pending["category"])
					break
		_check(expected == view.stacks.snapshot()["cursors"] and cursor_before["cards"] == view.stacks.snapshot()["cards"], "Only accepted matching requests rotate their category; equipment, death and recovery do not")
		var authentic := {}
		for unit in sim.units:
			var key := "%s:%s" % [unit["owner"], unit["kind"]]
			_check(not authentic.has(key), "Demo never contains two authentic units of the same species for a player")
			authentic[key] = true
		if loss_tick > 0 and sim.tick_count == loss_tick + 1:
			_check(str(view.panel.cards["creature"].data["recovery_text"]).contains("rec."), "Top species displays its recovering copy countdown while the authentic species is unavailable")
		for event in sim.events:
			if event["type"] == "card_result" and event["accepted"] and event["player"] == 0:
				played[event["card"]] = true
			if event["type"] == "summoned" and event["kind"] == "pig" and event["owner"] == 0:
				var id: int = event["unit_id"]
				if lost_pig == -1:
					lost_pig = id
					lost_copy = sim.get_unit(id)["copy_id"]
				else:
					_check(not sim.players[0]["recovering"].has(lost_pig), "No authentic replacement while its species is recovering")
					reused = sim.get_unit(id)["copy_id"] == lost_copy
			if event["type"] == "defeated" and event["unit_id"] == lost_pig:
				loss_tick = sim.tick_count
			if event["type"] == "healed":
				healed = true
			if event["type"] == "special_completed" and event["kind"] == "demolish":
				demolished = true
	_check(played.size() == 9, "Integrated circular stacks deploy all nine actual cards across four categories")
	_check(loss_tick > 0 and recovery_rejected and reused, "Same battle demonstrates defeat, rejected replacement and later reuse after recovery")
	_check(healed and demolished and sim_enemy_free(view.board.sim), "Existing directed combat, paid healing and contextual demolition remain playable")
	_check(view.board.sim.players[0]["essence"] >= 0 and view.board.sim.players[0]["essence"] <= 8, "Scenario respects essence bounds throughout")
	_check(not view.board.sim.get_player_view(0)["players"][1].has("core_cell") and view.board.sim.players[1]["core_hp"] == 12, "Card preview and the full encounter preserve hidden-core protection")
	view.queue_free()
	if failures == 0:
		print("PASS: nine real cards, independent accepted-request rotation, real economy, combat, authentic recovery and stable equipment")
	quit(0 if failures == 0 else 1)

func sim_enemy_free(sim: AetherionSimulation) -> bool:
	return sim.units.all(func(unit): return unit["owner"] == 0) and sim.cards.buildings.all(func(building): return building["owner"] == 0)
