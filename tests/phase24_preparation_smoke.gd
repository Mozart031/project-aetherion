extends SceneTree

const Feedback = preload("res://scripts/battle_feedback.gd")
const Stacks = preload("res://scripts/card_stack_model.gd")
const Placement = preload("res://scripts/card_placement_controller.gd")
var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_test_legacy_default_and_600_tick_lifecycle()
	_test_allowed_and_blocked_actions_during_preparation()
	_test_strict_symmetric_privacy_and_id_isolation()
	_test_tick_600_transition_feedback_and_combat_activation()
	_test_cross_fps_and_command_order_determinism()
	if failures == 0:
		print("PASS: 600-tick simultaneous private preparation, creature/combat blocking, zero-leak privacy, deterministic tick-600 board join and post-prep combat across FPS")
	quit(0 if failures == 0 else 1)

func _test_legacy_default_and_600_tick_lifecycle() -> void:
	var legacy := AetherionSimulation.new()
	_check(not legacy.is_preparation_phase() and legacy.match_phase == "combat" and legacy.preparation_remaining_ticks() == 0, "Legacy mode starts directly in combat by default")
	var sim := AetherionSimulation.new()
	_check(sim.enable_preparation(true) and sim.is_preparation_phase() and sim.match_phase == "preparation" and sim.preparation_remaining_ticks() == 600, "Enabling preparation at tick 0 starts 600-tick countdown")
	sim.step()
	_check(not sim.enable_preparation(false), "Cannot toggle preparation mode after match has started")
	_check(sim.tick_count == 1 and sim.is_preparation_phase() and sim.preparation_remaining_ticks() == 599, "Tick 1 advances countdown to 599 remaining ticks")
	while sim.tick_count < 599:
		sim.step()
	_check(sim.tick_count == 599 and sim.is_preparation_phase() and sim.preparation_remaining_ticks() == 1, "At tick 599 preparation is still active with 1 tick remaining")
	sim.step()
	_check(sim.tick_count == 600 and not sim.is_preparation_phase() and sim.match_phase == "combat" and sim.preparation_remaining_ticks() == 0, "At tick 600 preparation ends deterministically and combat begins")
	sim.reset()
	_check(sim.is_preparation_phase() and sim.preparation_remaining_ticks() == 600, "Resetting a preparation-enabled simulation restores the 600-tick preparation phase")

func _test_allowed_and_blocked_actions_during_preparation() -> void:
	var sim := AetherionSimulation.new()
	sim.enable_preparation(true)
	var stacks := Stacks.new()
	var placement := Placement.new()
	stacks.configure(sim.loadouts[0].snapshot())
	var initial_creature_top := stacks.top("creature")
	var initial_terrain_top := stacks.top("terrain")
	# Preview and attempt creature and trick plays during preparation.
	_check(not placement.begin(0, "creature", initial_creature_top, sim) and placement.message == "preparation_phase", "CardPlacementController rejects starting creature draft during preparation")
	var creature_preview := sim.get_card_placement(0, initial_creature_top, Vector2i(2, 1))
	var trick_preview := sim.get_card_placement(0, "heal", Vector2i(2, 1), 1)
	_check(not creature_preview["valid"] and creature_preview["reason"] == "preparation_phase", "Creature preview is rejected with preparation_phase")
	_check(not trick_preview["valid"] and trick_preview["reason"] == "preparation_phase", "Trick preview is rejected with preparation_phase")
	sim.queue_play_card(0, initial_creature_top, Vector2i(2, 1), -1, 1)
	sim.queue_summon(0, "pig", Vector2i(3, 1))
	sim.queue_summon(1, "boar", Vector2i(4, 1))
	sim.step()
	var view0 := sim.get_player_view(0)
	var view1 := sim.get_player_view(1)
	_check(sim.units.is_empty() and sim.players[0]["essence"] == 4 and sim.players[1]["essence"] == 4, "Creature card play and direct summons are blocked without spending essence")
	_check(stacks.top("creature") == initial_creature_top, "Rejected creature play during preparation does not rotate creature stack")
	_check(view0["events"].any(func(e): return e["type"] == "card_result" and not e["accepted"] and e["reason"] == "preparation_phase"), "Owner receives private preparation_phase rejection")
	_check(view1["events"].is_empty(), "Rival receives no events from owner's rejected preparation play")
	# Valid terrain and construction placements during preparation.
	var terrain_preview := sim.get_card_placement(0, initial_terrain_top, Vector2i(2, 1))
	var fence_preview := sim.get_card_placement(0, "fence", Vector2i(3, 1))
	_check(terrain_preview["valid"] and fence_preview["valid"], "Terrain and construction previews are valid during preparation")
	placement.next_request_id = 2
	_check(placement.begin(0, "terrain", initial_terrain_top, sim) and placement.confirm(sim, Vector2i(2, 1)), "CardPlacementController confirms terrain placement during preparation")
	sim.queue_play_card(0, "fence", Vector2i(3, 1), -1, 10)
	sim.step()
	view0 = sim.get_player_view(0)
	var accepted_draft := placement.consume(view0)
	if not accepted_draft.is_empty():
		stacks.cycle(accepted_draft["category"])
	_check(sim.terrain.cells.get(Vector2i(2, 1), "") == initial_terrain_top and sim.cards.buildings.size() == 1, "Terrain and construction are placed on own half during preparation")
	_check(stacks.top("terrain") != initial_terrain_top, "Accepted terrain placement advances terrain stack once")
	# Verify normal terrain exchange and standard essence regeneration (+1 at tick 60) during preparation.
	var essence_after_plays: int = sim.players[0]["essence"]
	while sim.tick_count < 60:
		sim.step()
	_check(sim.players[0]["essence"] == mini(sim.MAX_ESSENCE, essence_after_plays + 1), "Standard +1 essence per 60 ticks applies during preparation without special economic rules")

func _test_strict_symmetric_privacy_and_id_isolation() -> void:
	var sim_quiet := AetherionSimulation.new()
	var sim_active := AetherionSimulation.new()
	sim_quiet.enable_preparation(true)
	sim_active.enable_preparation(true)
	for tick in range(600):
		# Player 0 performs the exact same actions in both simulations, including after Player 1 has acted.
		match tick:
			0:
				for s in [sim_quiet, sim_active]:
					s.queue_play_card(0, "cornfield", Vector2i(2, 1), -1, 1)
			50:
				for s in [sim_quiet, sim_active]:
					s.queue_play_card(0, "mud", Vector2i(2, 1), -1, 2)
			120:
				for s in [sim_quiet, sim_active]:
					s.queue_play_card(0, "fence", Vector2i(3, 1), -1, 3)
					s.queue_play_card(0, "cave", Vector2i(0, 2), -1, 4)
		# Only in sim_active, Player 1 places terrains, swaps terrains, builds a fence, splits footprints, and triggers rejections.
		match tick:
			0:
				sim_active.queue_play_card(1, "mud", Vector2i(5, 1), -1, 1)
				sim_active.queue_play_card(1, "pig", Vector2i(4, 1), -1, 2)
			10:
				sim_active.queue_play_card(1, "fence", Vector2i(4, 2), -1, 3)
				sim_active.register_terrain_footprint([Vector2i(6, 0), Vector2i(6, 1), Vector2i(6, 2)], "cornfield", 1)
			30:
				sim_active.queue_play_card(1, "cornfield", Vector2i(5, 1), -1, 4)
				sim_active.register_terrain_footprint([Vector2i(6, 1)], "mud", 1)
			599:
				sim_active.queue_play_card(1, "cave", Vector2i(7, 3), -1, 5)
		if tick < 599:
			_check(sim_quiet.get_player_view(0) == sim_active.get_player_view(0), "Observer 0 view at preparation tick %d is bit-for-bit identical regardless of rival preparation" % tick)
		sim_quiet.step()
		sim_active.step()
		if sim_quiet.tick_count < 600:
			_check(sim_quiet.get_player_view(0) == sim_active.get_player_view(0), "Post-step observer 0 view at tick %d leaks neither rival terrains, buildings, footprints, events nor ID gaps" % sim_quiet.tick_count)
	# At tick 600, both simulations transition to combat; even on tick 600, Player 1's last-tick preparation card_played event is not leaked in Player 0's events.
	var v0_at_600 := sim_active.get_player_view(0)
	_check(not v0_at_600["events"].any(func(e): return e["type"] == "card_played" and e.get("player", -1) == 1), "Rival preparation card_played event on tick 600 remains private")
	_check(v0_at_600["events"].any(func(e): return e["type"] == "board_joined" and e["tick"] == 600), "Public board_joined event is emitted at tick 600")
	_check(v0_at_600["terrain"].has(Vector2i(5, 1)) and v0_at_600["terrain"].has(Vector2i(7, 3)) and v0_at_600["buildings"].size() == 2, "At tick 600 the joined board reveals rival terrains and constructions")

func _test_tick_600_transition_feedback_and_combat_activation() -> void:
	var sim := AetherionSimulation.new()
	sim.enable_preparation(true)
	var feedback := Feedback.new()
	sim.queue_play_card(0, "cornfield", Vector2i(2, 1))
	sim.queue_play_card(0, "fence", Vector2i(3, 1))
	sim.queue_play_card(1, "cave", Vector2i(5, 1))
	sim.queue_play_card(1, "fence", Vector2i(4, 1))
	for _i in range(599):
		sim.step()
		feedback.consume(sim.get_player_view(0))
	# Queue a creature at tick 599 (executes on tick 600, still blocked by preparation).
	_check(not sim.get_card_placement(0, "golem", Vector2i(2, 2))["valid"], "At tick 599 next-tick preview is still in preparation")
	sim.queue_play_card(0, "golem", Vector2i(2, 2), -1, 50)
	sim.step()
	_check(sim.tick_count == 600 and sim.match_phase == "combat" and sim.units.is_empty(), "Creature queued before tick 600 is rejected on the final preparation tick")
	var v0 := sim.get_player_view(0)
	var v1 := sim.get_player_view(1)
	var snapshot_before_feedback := v0.duplicate(true)
	feedback.consume(v0)
	_check(v0 == snapshot_before_feedback and feedback.effects.any(func(e): return e["type"] == "board_joined"), "BattleFeedback consumes board_joined event without mutating observer view")
	_check(sim.players[0]["core_hp"] == 12 and sim.players[1]["core_hp"] == 12, "Board join collision deals zero core damage")
	for building in sim.cards.buildings:
		_check(building["hp"] == 4, "Board join collision deals zero construction damage")
	_check(sim.get_controlled_section_count(0) == 16 and sim.get_controlled_section_count(1) == 16 and is_equal_approx(sim.get_dominion_percent(0), 50.0), "Board join collision preserves 16/16 (50%/50%) territorial control")
	_check(v0["terrain"] == v1["terrain"] and v0["buildings"] == v1["buildings"], "After tick 600 both observers share the same public board state")
	# Now at tick 600, combat and creature deployment are active.
	sim.players[0]["essence"] = 8
	sim.players[1]["essence"] = 8
	_check(sim.get_card_placement(0, "golem", Vector2i(3, 2))["valid"] and sim.get_card_placement(1, "pig", Vector2i(5, 1))["valid"], "At tick 600 creature placement previews are valid")
	sim.queue_play_card(0, "golem", Vector2i(3, 2), -1, 51)
	sim.queue_play_card(1, "pig", Vector2i(5, 1), -1, 52)
	sim.step()
	_check(sim.units.size() == 2, "Creatures deploy on tick 601 after preparation ends")
	var golem_id: int = sim.units.filter(func(u): return u["kind"] == "golem")[0]["id"]
	var rival_fence_id: int = sim.cards.buildings.filter(func(b): return b["owner"] == 1)[0]["id"]
	sim.queue_act_at(0, golem_id, "demolish", Vector2i(4, 1), rival_fence_id)
	for _i in range(20):
		sim.step()
	_check(sim.cards.buildings.filter(func(b): return b["owner"] == 1).is_empty(), "Post-preparation combat allows golem to navigate and demolish rival construction prepared during the 600 ticks")

func _scripted_match_input(sim: AetherionSimulation) -> void:
	match sim.tick_count:
		0:
			sim.queue_play_card(0, "cornfield", Vector2i(2, 1), -1, 1)
			sim.queue_play_card(1, "mud", Vector2i(5, 1), -1, 1)
		120:
			sim.queue_play_card(0, "fence", Vector2i(3, 1), -1, 2)
			sim.queue_play_card(1, "fence", Vector2i(4, 1), -1, 2)
		300:
			sim.queue_play_card(0, "cave", Vector2i(1, 2), -1, 3)
			sim.queue_play_card(1, "cornfield", Vector2i(6, 1), -1, 3)
		600:
			sim.queue_play_card(0, "golem", Vector2i(2, 1), -1, 4)
			sim.queue_play_card(1, "boar", Vector2i(5, 1), -1, 4)
		605:
			var golem_id: int = sim.units.filter(func(u): return u["owner"] == 0)[0]["id"]
			var enemy_fence_id: int = sim.cards.buildings.filter(func(b): return b["owner"] == 1)[0]["id"]
			sim.queue_act_at(0, golem_id, "demolish", Vector2i(4, 1), enemy_fence_id)

func _replay_preparation_at_fps(fps: float) -> Array:
	var sim := AetherionSimulation.new()
	sim.enable_preparation(true)
	sim.natural.enabled = true
	sim.natural_defense.enabled = true
	var snapshots := []
	var accumulator := 0.0
	while sim.tick_count < 630:
		accumulator += 1.0 / fps
		while accumulator + 0.000001 >= sim.TICK_SECONDS and sim.tick_count < 630:
			_scripted_match_input(sim)
			sim.step()
			if sim.tick_count in [1, 121, 301, 599, 600, 601, 615, 630]:
				snapshots.append([sim.get_player_view(0), sim.get_player_view(1)])
			accumulator -= sim.TICK_SECONDS
	return snapshots

func _test_cross_fps_and_command_order_determinism() -> void:
	var base := _replay_preparation_at_fps(20.0)
	_check(base == _replay_preparation_at_fps(30.0) and base == _replay_preparation_at_fps(120.0), "Preparation, tick-600 transition and post-prep combat are identical across 20, 30 and 120 FPS")
	var pair: Array[AetherionSimulation] = []
	for reverse in [false, true]:
		var sim := AetherionSimulation.new()
		sim.enable_preparation(true)
		var cmds_tick_1 := [
			{"type": "play_card", "player": 0, "card": "cornfield", "cell": Vector2i(2, 1), "target_id": -1, "request_id": 1},
			{"type": "play_card", "player": 1, "card": "mud", "cell": Vector2i(5, 1), "target_id": -1, "request_id": 1}
		]
		var cmds_tick_2 := [
			{"type": "play_card", "player": 0, "card": "fence", "cell": Vector2i(3, 1), "target_id": -1, "request_id": 2},
			{"type": "play_card", "player": 1, "card": "fence", "cell": Vector2i(4, 1), "target_id": -1, "request_id": 2}
		]
		if reverse:
			cmds_tick_1.reverse()
			cmds_tick_2.reverse()
		sim.queued_commands.append_array(cmds_tick_1)
		sim.step()
		sim.queued_commands.append_array(cmds_tick_2)
		sim.step()
		pair.append(sim)
	_check(pair[0].get_player_view(0) == pair[1].get_player_view(0) and pair[0].get_player_view(1) == pair[1].get_player_view(1), "Simultaneous preparation commands produce identical observer views regardless of command order")
