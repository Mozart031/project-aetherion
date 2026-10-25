extends SceneTree

var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _fixture() -> AetherionSimulation:
	var sim := AetherionSimulation.new()
	sim.queue_summon(0, "boar", Vector2i(1, 1))
	sim.queue_summon(1, "turtle", Vector2i(6, 1))
	sim.step()
	return sim

func _ticks(sim: AetherionSimulation, count: int) -> void:
	for index in range(count):
		sim.step()

func _initialize() -> void:
	var sim := _fixture()
	sim.queue_destination(0, 1, Vector2i(5, 2))
	_ticks(sim, 60)
	_check(sim.get_unit(1)["cell"] == Vector2i(5, 2) and sim.orders.active.is_empty(), "Long destination completes without manual steps")
	_check(sim.players[0]["essence"] == 2, "Navigation preserves essence regeneration and has no cost")
	var occupied := {Vector2i(2, 1): 99}
	var path: Array[Vector2i] = sim.orders.find_path(Vector2i(1, 1), [Vector2i(3, 1)], occupied)
	_check(path.size() == 4 and Vector2i(2, 1) not in path, "BFS detours around occupancy")
	_check(path == sim.orders.find_path(Vector2i(1, 1), [Vector2i(3, 1)], occupied), "Routing tie breaks are reproducible")
	var blocked := {}
	for direction in sim.orders.DIRECTIONS:
		blocked[Vector2i(1, 1) + direction] = true
	_check(sim.orders.find_path(Vector2i(1, 1), [Vector2i(5, 1)], blocked).is_empty(), "Blocked route returns no path")
	sim = _fixture()
	sim.queue_destination(0, 1, Vector2i(6, 1))
	_ticks(sim, 4)
	_check(sim.orders.active[1]["status"] == "blocked" and sim.get_motion(1).is_empty(), "Occupied destination remains explicitly blocked")
	sim.queue_move(1, 2, Vector2i(6, 0))
	_ticks(sim, 70)
	_check(sim.get_unit(1)["cell"] == Vector2i(6, 1) and sim.orders.active.is_empty(), "Blocked order replans after obstacle leaves")
	sim = _fixture()
	sim.queue_target(0, 1, 2)
	_ticks(sim, 32)
	_check(sim.get_unit(1)["cell"] == Vector2i(5, 1), "Directed attacker approaches to adjacent range")
	_check(sim.get_unit(2)["hp"] == 4 and sim.orders.active[1]["status"] == "attacking", "Directed attack uses existing damage and range")
	var ready: int = sim.get_unit(1)["ready_tick"]
	_ticks(sim, 4)
	_check(sim.get_unit(2)["hp"] == 4 and sim.get_unit(1)["ready_tick"] == ready, "Persistent directed order respects cooldown")
	_ticks(sim, 180)
	_check(sim.get_unit(2).is_empty() and sim.orders.active.is_empty(), "Defeated target completes attack order")
	_check(sim.players[1]["recovering"].has("turtle"), "Directed defeat retains recovery")
	sim = _fixture()
	sim.queue_target(0, 1, 2)
	_ticks(sim, 8)
	sim.queue_move(1, 2, Vector2i(6, 0))
	_ticks(sim, 50)
	_check(sim.orders.active[1]["status"] == "attacking" and sim.get_unit(2)["hp"] < 5, "Chase replans for moving target")
	sim = _fixture()
	sim.queue_destination(0, 1, Vector2i(5, 1))
	sim.step()
	var committed_to: Vector2i = sim.get_motion(1)["to"]
	sim.queue_destination(0, 1, Vector2i(0, 0))
	sim.step()
	_check(sim.get_motion(1)["to"] == committed_to, "Replacement does not cancel committed step")
	_ticks(sim, 70)
	_check(sim.get_unit(1)["cell"] == Vector2i(0, 0), "Replacement takes effect after current step")
	sim.queue_destination(0, 1, Vector2i(5, 0))
	sim.step()
	committed_to = sim.get_motion(1)["to"]
	sim.queue_stop(0, 1)
	sim.step()
	_check(sim.orders.active.is_empty(), "Stop clears goal")
	_ticks(sim, 20)
	_check(sim.get_unit(1)["cell"] == committed_to and sim.movement.active.is_empty(), "Stop finishes committed step and releases reservation")
	sim = _fixture()
	sim.queue_destination(1, 1, Vector2i(0, 0))
	sim.queue_target(0, 1, 1)
	sim.step()
	_check(sim.orders.active.is_empty(), "Foreign units and friendly targets rejected")
	sim.queue_destination(0, 1, Vector2i(-1, 0))
	sim.queue_target(0, 1, 999)
	sim.step()
	_check(sim.orders.active.is_empty(), "Invalid or contradictory goals rejected")
	var reference := {}
	for reverse_order in [false, true]:
		sim = _fixture()
		var goals := [Vector2i(0, 0), Vector2i(3, 3)]
		if reverse_order:
			goals.reverse()
		for goal in goals:
			sim.queue_destination(0, 1, goal)
		sim.step()
		if reverse_order:
			_check(sim.get_player_view(0) == reference, "Contradictory goals produce identical state and events")
		else:
			reference = sim.get_player_view(0)
	var first := _fixture()
	var second := _fixture()
	second.players[1]["core_cell"] = Vector2i(5, 1)
	for candidate in [first, second]:
		candidate.queue_destination(0, 1, Vector2i(5, 1))
	for tick in range(45):
		first.step()
		second.step()
		_check(first.get_player_view(0) == second.get_player_view(0), "Navigation does not leak hidden core position")
	sim.reset()
	_check(sim.orders.active.is_empty(), "Reset clears orders")
	_test_order_lifecycle()
	if failures == 0:
		print("PASS: Delivery A orthogonal routing, chasing, directed combat, blocked/replaced/stopped orders and hidden cores")
	quit(0 if failures == 0 else 1)

func _test_order_lifecycle() -> void:
	var sim := _fixture()
	for repeat in range(3):
		sim.queue_destination(0, 1, Vector2i(5, 0))
	sim.step()
	var accepted := 0
	for event in sim.events:
		if event["type"] == "order_accepted":
			accepted += 1
	_check(accepted == 1 and sim.orders.active.size() == 1, "Duplicate persistent goals accepted only once")
	var reference := {}
	for reverse_order in [false, true]:
		sim = AetherionSimulation.new()
		sim.queue_summon(0, "boar", Vector2i(3, 1))
		sim.queue_summon(1, "boar", Vector2i(4, 2))
		sim.step()
		var commands := [[0, 1], [1, 2]]
		if reverse_order:
			commands.reverse()
		for command in commands:
			sim.queue_destination(command[0], command[1], Vector2i(4, 1))
		sim.step()
		_check(sim.orders.active[1]["status"] == "blocked" and sim.orders.active[2]["status"] == "blocked", "Contested first steps expose blocked status for both orders")
		_check(sim.movement.reservations.is_empty(), "Conflict creates no reservation")
		if reverse_order:
			_check(sim.get_player_view(0) == reference, "Contested persistent orders deterministic under input reversal")
		else:
			reference = sim.get_player_view(0)
	sim = AetherionSimulation.new()
	sim.queue_summon(0, "boar", Vector2i(3, 1))
	sim.queue_summon(1, "boar", Vector2i(4, 1))
	sim.step()
	sim.queue_target(0, 1, 2)
	sim.queue_target(1, 2, 1)
	sim.step()
	_check(sim.get_unit(1)["hp"] == 1 and sim.get_unit(2)["hp"] == 1, "Both directed attacks resolve in the same tick")
	_ticks(sim, 36)
	_check(sim.units.is_empty() and sim.orders.active.is_empty(), "Directed mutual death cleans both explicit orders")
	sim = _fixture()
	sim.queue_destination(0, 1, Vector2i(5, 0))
	sim.step()
	sim.tick_count = AetherionSimulation.MATCH_LIMIT_TICKS - 1
	sim.step()
	_check(sim.finished and sim.orders.active.is_empty() and sim.movement.reservations.is_empty(), "Match end clears navigation and reservations")
	sim.queue_destination(0, 1, Vector2i(0, 0))
	sim.queue_target(0, 1, 2)
	sim.queue_stop(0, 1)
	_check(sim.queued_commands.is_empty(), "No tactical commands accepted after match end")
