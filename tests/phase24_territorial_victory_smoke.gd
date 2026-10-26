extends SceneTree

var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _ticks(sim: AetherionSimulation, count: int) -> void:
	for _i in range(count):
		sim.step()

func _held(sim: AetherionSimulation, player: int) -> int:
	return int(sim.get_territorial_victory_progress()["held_ticks"][player])

## Explicit territory fixtures for boundary tests; the replay below conquers normally.
func _share(sim: AetherionSimulation, owner: int, count: int) -> void:
	for x in range(8):
		for y in range(4):
			sim.set_section_controller(Vector2i(x, y), owner if x * 4 + y < count else 1 - owner)

func _initialize() -> void:
	_test_threshold_and_300_ticks_for_both_players()
	_test_interruption_and_opponent_handoff()
	_test_preparation_boundary_and_reset()
	_test_legacy_policy_and_configuration()
	_test_final_tick_capture_loss()
	_test_simultaneous_capture_order()
	_test_final_tick_damage_and_post_end_guards()
	_test_real_conquests_across_fps()
	if failures == 0:
		print("PASS: territorial victory at 29/32 for 300 full ticks, both players, resets, preparation, legacy compatibility, simultaneous conquests/damage, post-end guards and real conquest replays across FPS")
	quit(0 if failures == 0 else 1)

func _test_threshold_and_300_ticks_for_both_players() -> void:
	for player in [0, 1]:
		var sim := AetherionSimulation.new()
		_check(sim.enable_territorial_victory(), "Territorial mode can be enabled at tick zero")
		_share(sim, player, 28)
		_ticks(sim, 310)
		_check(not sim.finished and _held(sim, player) == 0, "28/32 never starts a victory hold")
		_share(sim, player, 29)
		_check(is_equal_approx(sim.get_dominion_percent(player), 90.625), "29 sections are exactly 90.625 percent")
		_ticks(sim, 100)
		_share(sim, player, 30)
		_ticks(sim, 100)
		_share(sim, player, 29)
		_ticks(sim, 99)
		_check(not sim.finished and _held(sim, player) == 299 and _held(sim, 1 - player) == 0, "Remaining above threshold preserves 299 consecutive ticks without early victory")
		sim.step()
		_check(sim.finished and sim.winner == player and _held(sim, player) == 300, "Player %d wins on exactly the 300th full tick" % player)
		for observer in [0, 1]:
			var ending: Array = sim.get_player_view(observer)["events"].filter(func(e): return e["type"] == "match_end")
			_check(ending.size() == 1 and ending[0]["winner"] == player, "Both observers receive the same single public result")
	var full := AetherionSimulation.new()
	full.enable_territorial_victory()
	_share(full, 0, 32)
	full.step()
	_check(not full.finished and _held(full, 0) == 1, "Even 100 percent control requires the full hold")

func _test_interruption_and_opponent_handoff() -> void:
	var sim := AetherionSimulation.new()
	sim.enable_territorial_victory()
	_share(sim, 0, 29)
	_ticks(sim, 299)
	_share(sim, 0, 28)
	sim.step()
	_check(not sim.finished and _held(sim, 0) == 0, "A single tick at 28 sections clears all 299 accumulated ticks")
	_share(sim, 0, 29)
	_ticks(sim, 299)
	_check(not sim.finished and _held(sim, 0) == 299, "Restoring the threshold requires a new full hold")
	_share(sim, 1, 29)
	sim.step()
	_check(not sim.finished and _held(sim, 0) == 0 and _held(sim, 1) == 1, "The opponent cannot inherit another player's progress")
	_ticks(sim, 299)
	_check(sim.finished and sim.winner == 1, "Opponent wins only after its own 300 consecutive ticks")

func _test_preparation_boundary_and_reset() -> void:
	for player in [0, 1]:
		var sim := AetherionSimulation.new()
		sim.enable_preparation()
		sim.enable_territorial_victory()
		_share(sim, player, 29)
		_ticks(sim, 599)
		_check(sim.is_preparation_phase() and not sim.finished and _held(sim, player) == 0, "Preparation never accrues territorial victory time")
		sim.step()
		_check(sim.tick_count == 600 and not sim.is_preparation_phase() and _held(sim, player) == 0, "The board-join tick does not count as combat occupation time")
		sim.step()
		_check(sim.tick_count == 601 and _held(sim, player) == 1, "Tick 601 is the first full combat tick")
		_ticks(sim, 298)
		_check(sim.tick_count == 899 and not sim.finished and _held(sim, player) == 299, "Tick 899 is still one tick short")
		sim.step()
		_check(sim.tick_count == 900 and sim.finished and sim.winner == player, "Preparation plus 300 combat ticks ends exactly at tick 900")
		sim.reset()
		_check(sim.territorial_victory_enabled and sim.is_preparation_phase() and not sim.finished and sim.winner == -1, "Reset preserves configured policies and clears the result")
		_check(_held(sim, 0) == 0 and _held(sim, 1) == 0 and sim.get_controlled_section_count(0) == 16, "Reset clears both holds and restores 16/16")

func _test_legacy_policy_and_configuration() -> void:
	var legacy := AetherionSimulation.new()
	_share(legacy, 0, 32)
	_ticks(legacy, 301)
	_check(not legacy.territorial_victory_enabled and not legacy.finished and _held(legacy, 0) == 0, "Legacy mode does not acquire territorial victory implicitly")
	legacy.players[1]["core_hp"] = 0
	legacy.step()
	_check(legacy.finished and legacy.winner == 0, "Legacy core destruction still ends the match")
	var timeout := AetherionSimulation.new()
	timeout.tick_count = timeout.MATCH_LIMIT_TICKS - 1
	timeout.players[1]["core_hp"] = 3
	timeout.step()
	_check(timeout.finished and timeout.winner == 0, "Legacy timeout still compares core HP")
	var territorial := AetherionSimulation.new()
	territorial.enable_territorial_victory()
	territorial.players[0]["core_hp"] = 0 # Explicit legacy-core fixture, not discovery gameplay.
	territorial.tick_count = territorial.MATCH_LIMIT_TICKS - 1
	territorial.step()
	_check(not territorial.finished and territorial.winner == -1, "Territorial policy does not invent a core or legacy-time victory")
	_check(not territorial.enable_territorial_victory(false) and territorial.territorial_victory_enabled, "The policy cannot change after tick zero")
	var progress := territorial.get_territorial_victory_progress()
	progress["held_ticks"][0] = 300
	progress["required_ticks"] = 1
	_check(_held(territorial, 0) == 0 and territorial.get_territorial_victory_progress()["required_ticks"] == 300, "Progress queries return isolated copies without advancing time")
	territorial.reset()
	_check(territorial.enable_territorial_victory(false) and not territorial.territorial_victory_enabled, "A reset allows choosing legacy policy again")

func _test_final_tick_capture_loss() -> void:
	var sim := AetherionSimulation.new()
	sim.enable_territorial_victory()
	sim.set_species_can_conquer("pig")
	sim.queue_summon(1, "pig", Vector2i(4, 1))
	sim.step()
	_share(sim, 0, 29)
	_ticks(sim, 239)
	sim.queue_conquer(1, 1, Vector2i(4, 1))
	sim.step()
	_ticks(sim, 59)
	_check(_held(sim, 0) == 299 and sim.get_conquest_progress(1)["remaining_ticks"] == 1, "The rival capture will finish on the potential winning tick")
	sim.step()
	_check(not sim.finished and sim.get_controlled_section_count(0) == 28 and _held(sim, 0) == 0, "A real capture on the 300th tick resets the hold before victory evaluation")

func _simultaneous_exchange(reverse_ids: bool, reverse_commands: bool) -> Array:
	var sim := AetherionSimulation.new()
	sim.enable_territorial_victory()
	sim.set_species_can_conquer("pig")
	var players_to_spawn: Array = [1, 0] if reverse_ids else [0, 1]
	for player in players_to_spawn:
		sim.queue_summon(player, "pig", Vector2i(2 if player == 0 else 5, 1))
	sim.step()
	_share(sim, 0, 29)
	var commands: Array[Dictionary] = []
	for unit in sim.units:
		var cell := Vector2i(7, 1) if unit["owner"] == 0 else Vector2i(0, 0)
		unit["cell"] = cell # Symmetric position fixture isolates action-resolution order.
		commands.append({"type": "order", "player": unit["owner"], "unit_id": unit["id"], "goal": {"kind": "act_at", "action": "conquer", "cell": cell, "target_id": -1}})
	if reverse_commands:
		commands.reverse()
	sim.queued_commands.append_array(commands)
	var trace := []
	var captures := 0
	for _i in range(300):
		sim.step()
		captures += sim.events.filter(func(e): return e["type"] == "section_conquered").size()
		trace.append([sim.tick_count, sim.get_controlled_section_count(0), sim.get_territorial_victory_progress(), sim.finished, sim.winner])
	_check(captures == 2 and sim.get_section_controller(Vector2i(7, 1)) == 0 and sim.get_section_controller(Vector2i(0, 0)) == 1, "Both opposing conquests actually complete in the same tick")
	_check(sim.finished and sim.winner == 0 and _held(sim, 0) == 300, "Same-tick gain/loss preserves 29 sections and the continuous hold")
	return trace

func _test_simultaneous_capture_order() -> void:
	var baseline := _simultaneous_exchange(false, false)
	_check(baseline == _simultaneous_exchange(false, true), "Reversing simultaneous commands does not change the result")
	_check(baseline == _simultaneous_exchange(true, false) and baseline == _simultaneous_exchange(true, true), "Reversing actor IDs/action completion order cannot cause a transient reset or victory")

func _test_final_tick_damage_and_post_end_guards() -> void:
	var sim := AetherionSimulation.new()
	sim.enable_territorial_victory()
	sim.queue_summon(0, "pig", Vector2i(3, 1))
	sim.queue_summon(1, "pig", Vector2i(4, 1))
	sim.step()
	_share(sim, 0, 29)
	_ticks(sim, 298)
	sim.queue_destination(1, 2, Vector2i(4, 3))
	sim.step()
	_check(_held(sim, 0) == 299 and sim.movement.active.has(2) and sim.orders.active.has(2), "A committed movement/order is still active before the winning tick")
	sim.queue_attack(1, 2)
	sim.queue_attack(2, 1)
	sim.step()
	_check(sim.finished and sim.winner == 0 and sim.get_unit(1)["hp"] == 3 and sim.get_unit(2)["hp"] == 3, "Both accepted attacks still deal simultaneous damage on the winning tick")
	_check(sim.events.filter(func(e): return e["type"] == "attack_accepted").size() == 2, "Victory does not discard either accepted attack")
	_check(sim.movement.active.is_empty() and sim.orders.active.is_empty() and sim.actions.active.is_empty(), "Territorial victory uses the existing match cleanup")
	var snapshot := [sim.get_player_view(0), sim.get_player_view(1), sim.get_territorial_victory_progress()]
	sim.queue_play_card(0, "horse", Vector2i(2, 1), -1, 1)
	sim.queue_conquer(0, 1, Vector2i(7, 3))
	sim.queue_attack(1, 2)
	sim.queue_move(0, 1, Vector2i(3, 0))
	sim.step()
	_check(sim.queued_commands.is_empty() and snapshot == [sim.get_player_view(0), sim.get_player_view(1), sim.get_territorial_victory_progress()], "Post-result commands/steps cannot spend essence, change progress or emit another result")

func _conquest_replay(fps: float) -> Array:
	var sim := AetherionSimulation.new()
	sim.enable_preparation()
	sim.enable_territorial_victory()
	sim.set_species_can_conquer("horse") # Test configuration, not a default species rule.
	var targets: Array[Vector2i] = []
	for x in range(4, 8):
		for y in range(4):
			if targets.size() < 13:
				targets.append(Vector2i(x, y))
	var next_target := 0
	var threshold_tick := -1
	var accumulator := 0.0
	var trace := []
	while not sim.finished and sim.tick_count < 10000:
		accumulator += 1.0 / fps
		while accumulator + 0.000001 >= sim.TICK_SECONDS and not sim.finished and sim.tick_count < 10000:
			if sim.tick_count == 600:
				sim.queue_play_card(0, "horse", Vector2i(3, 0))
			if not sim.units.is_empty():
				var id: int = sim.units[0]["id"]
				while next_target < targets.size() and sim.get_section_controller(targets[next_target]) == 0:
					next_target += 1
				if next_target < targets.size() and not sim.orders.active.has(id) and not sim.actions.active.has(id):
					sim.queue_conquer(0, id, targets[next_target])
			sim.step()
			if threshold_tick == -1 and sim.get_controlled_section_count(0) == 29:
				threshold_tick = sim.tick_count
				_check(_held(sim, 0) == 0, "A real threshold capture starts the hold without counting an incomplete tick")
			trace.append([sim.get_player_view(0), sim.get_player_view(1), sim.get_territorial_victory_progress()])
			accumulator -= sim.TICK_SECONDS
	_check(threshold_tick > 600 and sim.finished and sim.winner == 0 and sim.tick_count == threshold_tick + 300, "Thirteen real conquests from 16/16 yield victory exactly 15 seconds after the threshold capture")
	_check(sim.get_controlled_section_count(0) == 29 and sim.players[0]["core_hp"] == 12 and sim.players[1]["core_hp"] == 12, "Gameplay replay wins by territory without modifying core HP or territorial controllers through fixtures")
	return trace

func _test_real_conquests_across_fps() -> void:
	var baseline := _conquest_replay(20.0)
	_check(baseline == _conquest_replay(30.0) and baseline == _conquest_replay(120.0), "Every fixed-tick observer view, event, hold and final result matches across 20/30/120 FPS")
