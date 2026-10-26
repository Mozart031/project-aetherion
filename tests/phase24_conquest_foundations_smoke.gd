extends SceneTree

const Feedback = preload("res://scripts/battle_feedback.gd")
var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _ticks(sim: AetherionSimulation, count: int) -> void:
	for _i in range(count):
		sim.step()

func _initialize() -> void:
	_test_configurable_conquer_capability_and_non_conqueror_rejection()
	_test_navigation_60_tick_occupation_and_persistence()
	_test_interruption_resets_60_tick_progress()
	_test_explicit_defense_coverage_blocking_interruption_and_neutralization()
	_test_preparation_blocking_and_simultaneous_cross_fps_determinism()
	if failures == 0:
		print("PASS: configurable conquest capability, act_at navigation, 60-tick continuous occupation, interruption reset, explicit defense coverage and simultaneous cross-FPS determinism")
	quit(0 if failures == 0 else 1)

func _test_configurable_conquer_capability_and_non_conqueror_rejection() -> void:
	var sim := AetherionSimulation.new()
	sim.players[0]["essence"] = 8
	sim.players[1]["essence"] = 8
	sim.queue_play_card(0, "pig", Vector2i(3, 1))
	sim.queue_play_card(0, "horse", Vector2i(3, 2))
	sim.step()
	var pig_id: int = sim.units.filter(func(u): return u["kind"] == "pig")[0]["id"]
	var horse_id: int = sim.units.filter(func(u): return u["kind"] == "horse")[0]["id"]
	# By default, no species in the catalog automatically has conquest capability.
	_check(not sim.can_unit_conquer(sim.get_unit(pig_id)) and not sim.can_unit_conquer(sim.get_unit(horse_id)), "No species has conquest capability by default in the catalog")
	var default_actions := sim.get_context_actions(0, pig_id, Vector2i(4, 1))
	_check(not default_actions.any(func(a): return a["kind"] == "conquer"), "Non-conquering unit does not expose conquer context action")
	sim.queue_conquer(0, pig_id, Vector2i(4, 1))
	sim.step()
	_check(sim.orders.active.is_empty() and sim.get_player_view(0)["events"].any(func(e): return e["type"] == "order_rejected"), "Non-conquering unit rejects act_at conquer order")
	# Move non-conquering pig onto rival section (4, 1) and wait 80 ticks: never conquers.
	sim.queue_destination(0, pig_id, Vector2i(4, 1))
	_ticks(sim, 80)
	_check(sim.get_unit(pig_id)["cell"] == Vector2i(4, 1) and sim.get_section_controller(Vector2i(4, 1)) == 1, "Non-conquering unit standing on rival section for 80 ticks never captures it")
	sim.queue_special(0, pig_id, "conquer")
	sim.step()
	_check(sim.actions.active.is_empty() and sim.get_player_view(0)["events"].any(func(e): return e["type"] == "special_rejected"), "Non-conquering unit rejects direct special conquer")
	# Configure species-level and unit-level capability.
	sim.set_species_can_conquer("horse", true)
	_check(sim.can_unit_conquer(sim.get_unit(horse_id)) and not sim.can_unit_conquer(sim.get_unit(pig_id)), "Species-level configuration enables horse only")
	sim.set_unit_can_conquer(horse_id, false)
	sim.set_unit_can_conquer(pig_id, true)
	_check(not sim.can_unit_conquer(sim.get_unit(horse_id)) and sim.can_unit_conquer(sim.get_unit(pig_id)), "Per-unit override can disable or enable conquest independently")
	var enabled_actions := sim.get_context_actions(0, pig_id, Vector2i(4, 1))
	_check(enabled_actions.any(func(a): return a["kind"] == "conquer" and a["enabled"] and a["immediate"]), "Enabled conquering unit on rival section exposes immediate conquer action")
	var own_cell_actions := sim.get_context_actions(0, pig_id, Vector2i(3, 1))
	_check(own_cell_actions.any(func(a): return a["kind"] == "conquer" and not a["enabled"]), "Cannot conquer a section already controlled by own player")

func _test_navigation_60_tick_occupation_and_persistence() -> void:
	var sim := AetherionSimulation.new()
	var feedback := Feedback.new()
	sim.set_species_can_conquer("horse", true)
	var large_id := sim.register_terrain_footprint([Vector2i(4, 1), Vector2i(5, 1), Vector2i(4, 2), Vector2i(5, 2)], "cornfield", 1)
	sim.queue_play_card(0, "horse", Vector2i(2, 1))
	sim.step()
	var horse_id: int = sim.units[0]["id"]
	# Order distant conquest of (5, 1) from (2, 1): must traverse (3, 1) and (4, 1) before occupying (5, 1).
	var distant_options := sim.get_context_actions(0, horse_id, Vector2i(5, 1))
	_check(distant_options.any(func(a): return a["kind"] == "conquer" and a["enabled"] and not a["immediate"]), "Distant rival section offers travel-and-conquer")
	sim.queue_conquer(0, horse_id, Vector2i(5, 1))
	# 3 orthogonal steps * 6 ticks = 18 ticks of travel; wait until arrival starts conquer.
	var started_tick := -1
	for _i in range(30):
		sim.step()
		feedback.consume(sim.get_player_view(0))
		for e in sim.events:
			if e["type"] == "special_started" and e["unit_id"] == horse_id and e["kind"] == "conquer":
				started_tick = sim.tick_count
		if started_tick != -1:
			break
	_check(started_tick != -1 and sim.get_unit(horse_id)["cell"] == Vector2i(5, 1), "Unit navigates to target section and automatically starts occupation on arrival")
	_check(sim.get_section_controller(Vector2i(4, 1)) == 1, "Passing through rival section (4, 1) en route does not conquer it")
	# Step 59 ticks of occupation: still not conquered at tick 59.
	_ticks(sim, 59)
	var progress_59 := sim.get_conquest_progress(horse_id)
	_check(progress_59["active"] and progress_59["elapsed_ticks"] == 59 and progress_59["remaining_ticks"] == 1, "At 59 ticks of occupation, 1 tick remains")
	_check(sim.get_section_controller(Vector2i(5, 1)) == 1 and sim.get_controlled_section_count(0) == 16, "Section is not captured before completing all 60 continuous ticks")
	# 60th tick completes occupation and transfers control of (5, 1) only.
	sim.step()
	var v0 := sim.get_player_view(0)
	feedback.consume(v0)
	_check(sim.get_section_controller(Vector2i(5, 1)) == 0 and sim.get_controlled_section_count(0) == 17 and is_equal_approx(sim.get_dominion_percent(0), 53.125), "60th continuous tick captures section (5, 1) and updates dominion to 53.125%")
	_check(v0["events"].any(func(e): return e["type"] == "section_conquered" and e["cell"] == Vector2i(5, 1) and e["player"] == 0 and e["previous_owner"] == 1), "Public section_conquered event is emitted on completion")
	_check(feedback.effects.any(func(e): return e["type"] == "section_conquered"), "BattleFeedback records section_conquered presentation effect")
	var fp_info := sim.territory.get_footprint(large_id)
	_check(not fp_info["is_unified"] and fp_info["controllers_by_section"][Vector2i(5, 1)] == 0 and fp_info["controllers_by_section"][Vector2i(4, 1)] == 1, "Conquering one section of a 4-section terrain flips only that section")
	# Move unit away from (5, 1): territorial control persists.
	sim.queue_destination(0, horse_id, Vector2i(2, 1))
	_ticks(sim, 25)
	_check(sim.get_unit(horse_id)["cell"] == Vector2i(2, 1) and sim.get_section_controller(Vector2i(5, 1)) == 0 and sim.get_controlled_section_count(0) == 17, "Territorial control persists after the conquering unit leaves")

func _test_interruption_resets_60_tick_progress() -> void:
	var sim := AetherionSimulation.new()
	sim.set_species_can_conquer("pig", true)
	sim.queue_summon(0, "pig", Vector2i(3, 1))
	sim.queue_summon(1, "boar", Vector2i(5, 1))
	sim.step()
	var pig_id: int = sim.units.filter(func(u): return u["kind"] == "pig")[0]["id"]
	var boar_id: int = sim.units.filter(func(u): return u["kind"] == "boar")[0]["id"]
	# Move pig to (4, 1) and start conquering.
	sim.queue_conquer(0, pig_id, Vector2i(4, 1))
	while not sim.get_conquest_progress(pig_id)["active"]:
		sim.step()
	_ticks(sim, 35)
	_check(sim.get_conquest_progress(pig_id)["elapsed_ticks"] == 35, "Occupation reaches 35/60 ticks")
	# Interrupt 1: Explicit stop order resets progress to 0 without altering special_ready_tick cooldown.
	sim.get_unit(pig_id)["special_ready_tick"] = 500
	sim.queue_stop(0, pig_id)
	sim.step()
	_check(not sim.get_conquest_progress(pig_id)["active"] and sim.get_section_controller(Vector2i(4, 1)) == 1, "Explicit stop cancels occupation without capturing")
	_check(int(sim.get_unit(pig_id)["special_ready_tick"]) == 500, "Interrupting conquest never modifies species skill cooldown")
	# Restart conquest while special_ready_tick is on cooldown: conquest still starts and begins at 0 elapsed ticks.
	sim.queue_conquer(0, pig_id, Vector2i(4, 1))
	sim.step()
	_check(sim.get_conquest_progress(pig_id)["active"] and sim.get_conquest_progress(pig_id)["elapsed_ticks"] == 0 and int(sim.get_unit(pig_id)["special_ready_tick"]) == 500, "Restarted conquest begins at 0 elapsed ticks independently of skill cooldown")
	_ticks(sim, 40)
	_check(sim.get_section_controller(Vector2i(4, 1)) == 1 and sim.get_conquest_progress(pig_id)["elapsed_ticks"] == 40, "Interrupted progress was truly reset; 40 new ticks is not enough")
	# Interrupt 2: Incoming combat damage from adjacent boar interrupts occupation.
	sim.queue_attack(boar_id, pig_id)
	sim.step()
	_check(not sim.get_conquest_progress(pig_id)["active"] and sim.get_section_controller(Vector2i(4, 1)) == 1, "Receiving combat damage interrupts active conquest occupation")
	# Restart conquest after eliminating threat, then complete full 60 continuous ticks.
	sim.get_unit(boar_id)["cell"] = Vector2i(7, 3)
	sim.queue_conquer(0, pig_id, Vector2i(4, 1))
	sim.step()
	_ticks(sim, 59)
	_check(sim.get_section_controller(Vector2i(4, 1)) == 1, "59 ticks after restart still has not captured")
	sim.step()
	_check(sim.get_section_controller(Vector2i(4, 1)) == 0, "Full 60 continuous ticks after restart captures section")

func _test_explicit_defense_coverage_blocking_interruption_and_neutralization() -> void:
	var sim := AetherionSimulation.new()
	sim.players[0]["essence"] = 8
	sim.players[1]["essence"] = 8
	sim.set_species_can_conquer("horse", true)
	sim.place_terrain(Vector2i(2, 1), "cornfield")
	sim.place_terrain(Vector2i(4, 1), "cornfield")
	sim.queue_play_card(0, "horse", Vector2i(3, 1))
	sim.queue_play_card(0, "golem", Vector2i(3, 2))
	sim.queue_summon(1, "turtle", Vector2i(5, 1))
	sim.queue_play_card(1, "fence", Vector2i(4, 2))
	sim.step()
	var horse_id: int = sim.units.filter(func(u): return u["kind"] == "horse")[0]["id"]
	var golem_id: int = sim.units.filter(func(u): return u["kind"] == "golem")[0]["id"]
	var turtle_id: int = sim.units.filter(func(u): return u["kind"] == "turtle")[0]["id"]
	var fence_id: int = sim.cards.buildings[0]["id"]
	sim.get_unit(horse_id)["hp"] = 2
	# Configure explicit defense coverage: turtle protects (4, 1) and even attempts to list own-player section (2, 1); fence protects (5, 2).
	sim.set_defender_coverage(turtle_id, [Vector2i(4, 1), Vector2i(2, 1)])
	sim.set_defender_coverage(fence_id, [Vector2i(5, 2)])
	_check(sim.is_section_protected_against(Vector2i(4, 1), 0) and sim.is_section_protected_against(Vector2i(5, 2), 0), "Configured defender unit and construction protect their assigned rival sections")
	_check(not sim.is_section_protected_against(Vector2i(4, 0), 0) and not sim.is_section_protected_against(Vector2i(2, 1), 0), "Unassigned sections and sections already controlled by player 0 are never blocked by rival defense coverage")
	var own_crop_actions := sim.get_context_actions(0, horse_id, Vector2i(2, 1))
	_check(own_crop_actions.filter(func(a): return a["kind"] == "forage")[0]["enabled"], "Rival defense coverage never blocks ecological forage on player 0's own controlled section")
	# Protected section (4, 1) blocks both conquest and appropriating the cornfield utility (forage).
	var actions_on_protected := sim.get_context_actions(0, horse_id, Vector2i(4, 1))
	var conquer_opt: Dictionary = actions_on_protected.filter(func(a): return a["kind"] == "conquer")[0]
	var forage_opt: Dictionary = actions_on_protected.filter(func(a): return a["kind"] == "forage")[0]
	_check(not conquer_opt["enabled"] and not forage_opt["enabled"], "Active defense blocks both conquering (4, 1) and foraging its protected cornfield")
	sim.queue_conquer(0, horse_id, Vector2i(4, 1))
	sim.step()
	_check(sim.orders.active.is_empty() and sim.get_player_view(0)["events"].any(func(e): return e["type"] == "order_rejected"), "Conquer order on protected section is rejected")
	# Start conquering unprotected section (4, 0), then mid-occupation expand fence coverage to (4, 0).
	sim.queue_conquer(0, horse_id, Vector2i(4, 0))
	while not sim.get_conquest_progress(horse_id)["active"]:
		sim.step()
	_ticks(sim, 25)
	_check(sim.get_conquest_progress(horse_id)["elapsed_ticks"] == 25, "Horse is 25/60 ticks into conquering unprotected (4, 0)")
	sim.set_defender_coverage(fence_id, [Vector2i(5, 2), Vector2i(4, 0)])
	sim.step()
	_check(not sim.get_conquest_progress(horse_id)["active"] and sim.get_section_controller(Vector2i(4, 0)) == 1, "Activating defense coverage over an occupied section immediately interrupts conquest")
	# Neutralize defenses: golem demolishes the rival fence, and turtle is defeated.
	sim.queue_act_at(0, golem_id, "demolish", Vector2i(4, 2), fence_id)
	while not sim.cards.buildings.is_empty():
		sim.step()
	_check(not sim.is_section_protected_against(Vector2i(4, 0), 0) and not sim.is_section_protected_against(Vector2i(5, 2), 0), "Destroying defensive construction automatically removes its protection coverage")
	# Defeat turtle via combat damage -> (4, 1) becomes unprotected and its cornfield and section can now be used/conquered.
	sim.get_unit(turtle_id)["cell"] = Vector2i(3, 3)
	sim.get_unit(turtle_id)["hp"] = 1
	sim.queue_attack(golem_id, turtle_id)
	while not sim.get_unit(turtle_id).is_empty():
		sim.queue_attack(golem_id, turtle_id)
		sim.step()
	_check(not sim.is_section_protected_against(Vector2i(4, 1), 0), "Neutralizing defending creature automatically removes its protection coverage")
	sim.queue_conquer(0, horse_id, Vector2i(4, 1))
	while sim.get_section_controller(Vector2i(4, 1)) != 0:
		sim.step()
	_check(sim.get_section_controller(Vector2i(4, 1)) == 0, "Once defense is neutralized, conquering unit can occupy for 60 ticks and capture (4, 1)")

func _scripted_conquest_scenario(sim: AetherionSimulation, reverse_commands: bool = false) -> void:
	match sim.tick_count:
		0:
			var prep_cmds := [
				{"type": "play_card", "player": 0, "card": "cornfield", "cell": Vector2i(2, 1), "target_id": -1, "request_id": 1},
				{"type": "play_card", "player": 1, "card": "mud", "cell": Vector2i(5, 2), "target_id": -1, "request_id": 1}
			]
			if reverse_commands:
				prep_cmds.reverse()
			sim.queued_commands.append_array(prep_cmds)
		600:
			sim.queue_play_card(0, "horse", Vector2i(3, 1), -1, 2)
			sim.queue_play_card(1, "horse", Vector2i(4, 2), -1, 2)
		601:
			var u0: int = sim.units.filter(func(u): return u["owner"] == 0)[0]["id"]
			var u1: int = sim.units.filter(func(u): return u["owner"] == 1)[0]["id"]
			var order_cmds := [
				{"type": "order", "player": 0, "unit_id": u0, "goal": {"kind": "act_at", "action": "conquer", "cell": Vector2i(4, 1), "target_id": -1}},
				{"type": "order", "player": 1, "unit_id": u1, "goal": {"kind": "act_at", "action": "conquer", "cell": Vector2i(3, 2), "target_id": -1}}
			]
			if reverse_commands:
				order_cmds.reverse()
			sim.queued_commands.append_array(order_cmds)

func _run_full_conquest_replay(fps: float, reverse_commands: bool = false) -> Array:
	var sim := AetherionSimulation.new()
	sim.enable_preparation(true)
	sim.set_species_can_conquer("horse", true)
	# Verify conquest is blocked during preparation.
	var dummy_unit := {"id": 99, "owner": 0, "kind": "horse", "cell": Vector2i(4, 1), "hp": 4}
	_check(not sim.actions.plan(dummy_unit, "conquer", Vector2i(4, 1), -1, sim)["enabled"], "Conquest plan is disabled during preparation phase")
	var snapshots := []
	var accumulator := 0.0
	while sim.tick_count < 675:
		accumulator += 1.0 / fps
		while accumulator + 0.000001 >= sim.TICK_SECONDS and sim.tick_count < 675:
			_scripted_conquest_scenario(sim, reverse_commands)
			sim.step()
			if sim.tick_count in [1, 599, 600, 601, 610, 667, 668, 675]:
				snapshots.append([sim.get_player_view(0), sim.get_player_view(1)])
			accumulator -= sim.TICK_SECONDS
	_check(sim.get_section_controller(Vector2i(4, 1)) == 0 and sim.get_section_controller(Vector2i(3, 2)) == 1, "Both players complete their simultaneous conquests deterministically")
	_check(sim.get_controlled_section_count(0) == 16 and sim.get_controlled_section_count(1) == 16 and is_equal_approx(sim.get_dominion_percent(0), 50.0), "Simultaneous 1-for-1 section swap preserves 16/16 (50%/50%) total dominion")
	return snapshots

func _test_preparation_blocking_and_simultaneous_cross_fps_determinism() -> void:
	var base_20 := _run_full_conquest_replay(20.0, false)
	var reversed_20 := _run_full_conquest_replay(20.0, true)
	var base_30 := _run_full_conquest_replay(30.0, false)
	var base_120 := _run_full_conquest_replay(120.0, false)
	_check(base_20 == reversed_20, "Simultaneous conquests by both players are independent of command execution order")
	_check(base_20 == base_30 and base_20 == base_120, "Preparation + navigation + 60-tick conquest replay is identical across 20, 30 and 120 FPS")
