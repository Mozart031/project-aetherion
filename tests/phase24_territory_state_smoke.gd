extends SceneTree

const BoardCoordinates = preload("res://scripts/board_coordinates.gd")
var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_test_initial_32_sections_and_dominion()
	_test_vertical_4x8_coordinate_correspondence()
	_test_separation_from_card_authorship_and_ecology()
	_test_multisection_and_single_section_footprints()
	_test_disconnected_footprint_replacement_split()
	_test_private_footprint_projection_and_id_isolation()
	_test_persistence_after_departure_consumption_and_destruction()
	if failures == 0:
		print("PASS: 32 equivalent sections, 16/16 split, 3.125% dominion math, 8x4<->4x8 correspondence, multi-section progressive control, disconnected split coherence and persistence")
	quit(0 if failures == 0 else 1)

func _test_initial_32_sections_and_dominion() -> void:
	var sim := AetherionSimulation.new()
	var summary := sim.territory.dominion_summary()
	_check(summary["total_sections"] == 32, "Board has exactly 32 equivalent territorial spaces")
	_check(is_equal_approx(summary["percent_per_section"], 3.125), "Each space equals 3.125 percentage points")
	_check(sim.get_controlled_section_count(0) == 16 and sim.get_controlled_section_count(1) == 16, "Initial split is 16 spaces per player")
	_check(is_equal_approx(sim.get_dominion_percent(0), 50.0) and is_equal_approx(sim.get_dominion_percent(1), 50.0), "Dominion bar starts at 50% / 50%")
	for x in range(8):
		for y in range(4):
			var expected := 0 if x < 4 else 1
			_check(sim.get_section_controller(Vector2i(x, y)) == expected, "Section (%d,%d) has expected initial controller" % [x, y])
	_check(sim.get_section_controller(Vector2i(-1, 0)) == -1 and sim.get_section_controller(Vector2i(8, 0)) == -1 and sim.get_section_controller(Vector2i(0, 4)) == -1, "Out-of-bounds coordinates have no territorial controller")
	_check(not sim.set_section_controller(Vector2i(8, 1), 0)["changed"] and not sim.set_section_controller(Vector2i(0, 0), 2)["changed"], "Invalid coordinates or player indices are rejected")
	var steps := 0
	for x in range(4, 8):
		for y in range(4):
			steps += 1
			var transfer := sim.set_section_controller(Vector2i(x, y), 0)
			_check(transfer["changed"] and transfer["previous_owner"] == 1 and transfer["new_owner"] == 0, "Valid section transfer records previous and new controller")
			_check(sim.get_controlled_section_count(0) == 16 + steps and sim.get_controlled_section_count(1) == 16 - steps, "Section counts stay complementary at step %d" % steps)
			var p0 := sim.get_dominion_percent(0)
			var p1 := sim.get_dominion_percent(1)
			_check(is_equal_approx(p0, float(16 + steps) * 3.125) and is_equal_approx(p1, float(16 - steps) * 3.125) and is_equal_approx(p0 + p1, 100.0), "Exact 3.125% increment per conquered section")
	sim.reset()
	_check(sim.get_controlled_section_count(0) == 16 and sim.get_controlled_section_count(1) == 16 and is_equal_approx(sim.get_dominion_percent(0), 50.0), "Simulation reset restores 16/16 split and 50%/50% dominion")

func _test_vertical_4x8_coordinate_correspondence() -> void:
	var sim := AetherionSimulation.new()
	for observer in [0, 1]:
		var visual_seen := {}
		var lower_own := 0
		var upper_enemy := 0
		for x in range(8):
			for y in range(4):
				var logical := Vector2i(x, y)
				var visual := BoardCoordinates.logical_to_visual(logical, observer)
				_check(visual.x >= 0 and visual.x < 4 and visual.y >= 0 and visual.y < 8, "Logical section maps inside 4x8 vertical board")
				_check(not visual_seen.has(visual), "Bijective 8x4 to 4x8 section mapping")
				visual_seen[visual] = true
				var roundtrip := BoardCoordinates.visual_to_logical(visual, observer)
				_check(roundtrip == logical, "Reversible visual_to_logical adapter")
				var owner := sim.get_section_controller(roundtrip)
				if visual.y >= 4:
					if owner == observer:
						lower_own += 1
				else:
					if owner == 1 - observer:
						upper_enemy += 1
		_check(visual_seen.size() == 32 and lower_own == 16 and upper_enemy == 16, "Observer %d sees own 16 initial sections in lower 4x4 rows and enemy 16 in upper 4x4 rows" % observer)
	sim.set_section_controller(Vector2i(4, 2), 0)
	var v0 := BoardCoordinates.logical_to_visual(Vector2i(4, 2), 0)
	var v1 := BoardCoordinates.logical_to_visual(Vector2i(4, 2), 1)
	_check(v0.y < 4 and sim.get_section_controller(BoardCoordinates.visual_to_logical(v0, 0)) == 0, "Conquered rival section maps to upper half for player 0 with controller 0")
	_check(v1.y >= 4 and sim.get_section_controller(BoardCoordinates.visual_to_logical(v1, 1)) == 0, "Same section maps to lower half for player 1 with controller 0")

func _test_separation_from_card_authorship_and_ecology() -> void:
	var sim := AetherionSimulation.new()
	sim.queue_play_card(0, "cornfield", Vector2i(2, 1))
	sim.queue_play_card(1, "mud", Vector2i(5, 1))
	sim.step()
	_check(sim.cards.terrain_owners[Vector2i(2, 1)] == 0 and sim.cards.state(0, "cornfield", sim)["active"] == 1, "Card authorship marks cornfield card active for player 0")
	_check(sim.get_controlled_section_count(0) == 16 and sim.get_controlled_section_count(1) == 16, "Playing terrain cards does not change territorial section count")
	# Rival conquers section (2, 1) without destroying the cornfield or stealing card authorship.
	sim.set_section_controller(Vector2i(2, 1), 1)
	_check(sim.get_section_controller(Vector2i(2, 1)) == 1 and sim.get_controlled_section_count(1) == 17, "Section controller changes to player 1")
	_check(sim.cards.terrain_owners[Vector2i(2, 1)] == 0 and sim.cards.state(0, "cornfield", sim)["active"] == 1 and sim.cards.state(1, "cornfield", sim)["available"] == 1, "Changing section controller never corrupts terrain card authorship or availability")
	_check(sim.terrain.cells[Vector2i(2, 1)] == "cornfield", "Changing section controller preserves ecological terrain state")
	# Verify register_terrain_footprint / register_footprint cannot bypass card placement validation or mutate ecology/card authorship.
	var core_cell: Vector2i = sim.players[0]["core_cell"]
	var fp_id := sim.register_terrain_footprint([core_cell, Vector2i(core_cell.x + 1, core_cell.y)], "cave", 0)
	_check(fp_id > 0, "Territorial footprint registration records geometry metadata")
	_check(not sim.terrain.cells.has(core_cell) and not sim.cards.terrain_owners.has(core_cell) and sim.cards.state(0, "cave", sim)["active"] == 0, "register_terrain_footprint never mutates terrain.cells or cards.terrain_owners or bypasses placement rules")
	var view := sim.get_player_view(0)
	view["territory"]["section_controllers"][Vector2i(2, 1)] = 0
	view["territory"]["counts"][0] = 32
	_check(sim.get_section_controller(Vector2i(2, 1)) == 1 and sim.get_controlled_section_count(0) == 15, "Observer territory projection is an isolated deep copy")

func _test_multisection_and_single_section_footprints() -> void:
	var sim := AetherionSimulation.new()
	_check(sim.register_terrain_footprint([], "mud", 0) == -1, "Empty footprint rejected")
	_check(sim.register_terrain_footprint([Vector2i(0, 0), Vector2i(0, 0)], "mud", 0) == -1, "Duplicate sections in footprint rejected")
	_check(sim.register_terrain_footprint([Vector2i(0, 0), Vector2i(2, 2)], "mud", 0) == -1, "Non-contiguous sections in footprint rejected")
	var small_id := sim.register_terrain_footprint([Vector2i(1, 1)], "cave", 0)
	var large_cells: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(4, 2), Vector2i(5, 2)]
	var large_id := sim.register_terrain_footprint(large_cells, "cornfield", 1)
	_check(small_id > 0 and large_id > small_id, "Valid 1-section and 4-section footprints registered")
	_check(sim.get_controlled_section_count(0) == 16 and sim.get_controlled_section_count(1) == 16, "Distributing surface with different terrain sizes keeps 50%/50% dominion")
	var large_info := sim.territory.get_footprint(large_id)
	_check(large_info["section_count"] == 4 and large_info["is_unified"] and large_info["unified_controller"] == 1, "4-section terrain starts unified under player 1")
	# Progressive conquest: player 0 captures 1 section of the 4-section terrain.
	sim.set_section_controller(Vector2i(4, 1), 0)
	large_info = sim.territory.get_footprint(large_id)
	_check(not large_info["is_unified"] and large_info["unified_controller"] == -1, "Conquering one section of a large terrain does not flip the whole terrain")
	_check(large_info["controllers_by_section"][Vector2i(4, 1)] == 0 and large_info["controllers_by_section"][Vector2i(5, 1)] == 1 and large_info["controllers_by_section"][Vector2i(4, 2)] == 1 and large_info["controllers_by_section"][Vector2i(5, 2)] == 1, "Only the conquered section changes controller; other sections remain with player 1")
	_check(sim.territory.get_footprint_at(Vector2i(4, 1))["id"] == large_id and sim.territory.get_footprint_at(Vector2i(5, 2))["id"] == large_id, "Large terrain retains continuous footprint identity across all its sections")
	_check(is_equal_approx(sim.get_dominion_percent(0), 53.125) and is_equal_approx(sim.get_dominion_percent(1), 46.875), "Dominion depends on controlled surface area (17 vs 15 sections), not card count")
	# Conquering the remaining 3 sections progressively completes control of the large terrain.
	for cell in [Vector2i(5, 1), Vector2i(4, 2), Vector2i(5, 2)]:
		sim.set_section_controller(cell, 0)
	large_info = sim.territory.get_footprint(large_id)
	_check(large_info["is_unified"] and large_info["unified_controller"] == 0 and is_equal_approx(sim.get_dominion_percent(0), 62.5), "All 4 sections conquered progressively yield 20/32 (62.5%) dominion")
	# Small 1-section terrain is conquered whole when its single section changes controller.
	sim.set_section_controller(Vector2i(1, 1), 1)
	var small_info := sim.territory.get_footprint(small_id)
	_check(small_info["is_unified"] and small_info["unified_controller"] == 1, "1-section terrain is conquered whole")

func _test_disconnected_footprint_replacement_split() -> void:
	var sim := AetherionSimulation.new()
	# Case 1: Replacing a corner of a 2x2 footprint leaves a contiguous 3-section L-shaped footprint.
	var square_id := sim.register_terrain_footprint([Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)], "cornfield", 0)
	var corner_replacement_id := sim.register_terrain_footprint([Vector2i(2, 0)], "mud", 0)
	var remaining_l := sim.territory.get_footprint(square_id)
	_check(corner_replacement_id != square_id and remaining_l["section_count"] == 3, "Replacing one corner of a 2x2 leaves a 3-section footprint")
	_check(sim.territory._are_sections_contiguous(remaining_l["sections"]), "Remaining 3-section L-shape is contiguous and keeps coherent footprint identity")
	# Case 2: Replacing the middle section (0, 1) of a 3-section line [(0, 0), (0, 1), (0, 2)] via real card play disconnects (0, 0) and (0, 2).
	var line_id := sim.register_terrain_footprint([Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)], "cornfield", 0)
	sim.terrain.cells[Vector2i(0, 1)] = "cornfield"
	sim.cards.terrain_owners[Vector2i(0, 1)] = 0
	sim.queue_play_card(0, "mud", Vector2i(0, 1))
	sim.step()
	var top_fp := sim.territory.get_footprint_at(Vector2i(0, 0))
	var mid_fp := sim.territory.get_footprint_at(Vector2i(0, 1))
	var bot_fp := sim.territory.get_footprint_at(Vector2i(0, 2))
	_check(top_fp["id"] == line_id and top_fp["sections"] == [Vector2i(0, 0)], "First connected component retains original footprint ID with only its contiguous section")
	_check(bot_fp["id"] != top_fp["id"] and bot_fp["id"] != mid_fp["id"] and bot_fp["sections"] == [Vector2i(0, 2)] and bot_fp["kind"] == "cornfield", "Disconnected remnant receives a distinct coherent footprint identity")
	_check(mid_fp["kind"] == "mud" and mid_fp["sections"] == [Vector2i(0, 1)], "Replaced middle cell has its own mud footprint")
	# Case 3: Replacing bridge cell (5, 0) in a 4-section line [(4, 0), (5, 0), (6, 0), (7, 0)] splits into 1-section [(4, 0)] and 2-section [(6, 0), (7, 0)].
	var line4_id := sim.register_terrain_footprint([Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0)], "cave", 1)
	sim.register_terrain_footprint([Vector2i(5, 0)], "mud", 1)
	var left_fp := sim.territory.get_footprint_at(Vector2i(4, 0))
	var right_fp := sim.territory.get_footprint_at(Vector2i(6, 0))
	_check(left_fp["id"] == line4_id and left_fp["sections"] == [Vector2i(4, 0)], "Left component is a 1-section footprint")
	_check(right_fp["id"] != left_fp["id"] and right_fp["sections"] == [Vector2i(6, 0), Vector2i(7, 0)] and sim.territory.get_footprint_at(Vector2i(7, 0))["id"] == right_fp["id"], "Right 2-section contiguous component shares a single new footprint ID")
	for fid in sim.territory.footprints:
		_check(sim.territory._are_sections_contiguous(sim.territory.footprints[fid]["sections"]), "Every registered footprint remains orthogonally contiguous after splits")

func _test_private_footprint_projection_and_id_isolation() -> void:
	var sim := AetherionSimulation.new()
	var own_id_1 := sim.register_terrain_footprint([Vector2i(0, 0), Vector2i(0, 1)], "cornfield", 0)
	var baseline_private := sim.territory.view_for(0, true)
	# Rival registers and splits multiple footprints on their half (x in 4..7).
	sim.register_terrain_footprint([Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2)], "cornfield", 1)
	sim.register_terrain_footprint([Vector2i(4, 1)], "mud", 1)
	sim.register_terrain_footprint([Vector2i(6, 2), Vector2i(7, 2)], "cave", 1)
	var after_enemy_private := sim.territory.view_for(0, true)
	_check(baseline_private == after_enemy_private, "Private footprint projection for observer 0 is completely unaffected by rival footprints or splits")
	var own_id_2 := sim.register_terrain_footprint([Vector2i(2, 2)], "mud", 0)
	_check(own_id_2 == own_id_1 + 1, "Rival footprint allocations and splits never create sequential ID gaps in player 0's footprint counter")
	var public_view := sim.territory.view_for(0, false)
	_check(public_view["footprints"].size() > after_enemy_private["footprints"].size(), "Public projection exposes all board footprints once preparation privacy is off")

func _test_persistence_after_departure_consumption_and_destruction() -> void:
	var sim := AetherionSimulation.new()
	sim.players[0]["essence"] = 8
	sim.players[1]["essence"] = 8
	sim.queue_play_card(0, "cornfield", Vector2i(2, 1))
	sim.queue_play_card(0, "horse", Vector2i(2, 1))
	sim.queue_play_card(0, "golem", Vector2i(3, 1))
	sim.queue_play_card(1, "fence", Vector2i(4, 1))
	sim.step()
	sim.players[0]["essence"] = 8
	# Section (4, 0) is conquered by player 0, then the unit on it moves away and later dies.
	sim.queue_summon(0, "pig", Vector2i(3, 0))
	sim.step()
	var pig_id: int = sim.units.filter(func(u): return u["kind"] == "pig")[0]["id"]
	sim.queue_move(0, pig_id, Vector2i(4, 0))
	for _i in range(7):
		sim.step()
	_check(sim.get_unit(pig_id)["cell"] == Vector2i(4, 0) and sim.get_section_controller(Vector2i(4, 0)) == 1, "Simply entering/passing through a rival cell does not change its controller")
	sim.set_section_controller(Vector2i(4, 0), 0)
	sim.queue_move(0, pig_id, Vector2i(5, 0))
	for _i in range(7):
		sim.step()
	_check(sim.get_unit(pig_id)["cell"] == Vector2i(5, 0) and sim.get_section_controller(Vector2i(4, 0)) == 0, "Territorial control persists after the conquering creature leaves the section")
	# Consuming a cornfield removes the ecological resource, but territorial control persists.
	var horse_id: int = sim.units.filter(func(u): return u["kind"] == "horse")[0]["id"]
	sim.get_unit(horse_id)["hp"] = 2
	sim.queue_special(0, horse_id, "forage")
	for _i in range(7):
		sim.step()
	_check(not sim.terrain.cells.has(Vector2i(2, 1)) and sim.get_section_controller(Vector2i(2, 1)) == 0 and sim.get_controlled_section_count(0) == 17, "Consuming cornfield resource does not erase territorial section control or reduce dominion")
	# Demolishing and destroying a rival fence does not change the territorial controller of (4, 1).
	var golem_id: int = sim.units.filter(func(u): return u["kind"] == "golem")[0]["id"]
	var fence_id: int = sim.cards.buildings[0]["id"]
	sim.queue_special(0, golem_id, "demolish", fence_id)
	for _i in range(8):
		sim.step()
	_check(sim.cards.buildings.is_empty() and sim.get_section_controller(Vector2i(4, 1)) == 1 and sim.get_controlled_section_count(0) == 17, "Damaging and destroying a construction does not change the territorial controller")
