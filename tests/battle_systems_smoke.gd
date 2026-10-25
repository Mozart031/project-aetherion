extends SceneTree

var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _ticks(sim: AetherionSimulation, count: int) -> void:
	for tick in range(count):
		sim.step()

func _initialize() -> void:
	_test_copies()
	_test_cards_and_terrain()
	_test_refuge()
	_test_construction()
	_test_hidden_core()
	if failures == 0:
		print("PASS: battle card economy, independent copies/recovery, terrain exchange, real refuge, construction and hidden core")
	quit(0 if failures == 0 else 1)

func _test_copies() -> void:
	var sim := AetherionSimulation.new()
	sim.players[0]["essence"] = 8
	sim.queue_play_card(0, "pig", Vector2i(3, 1))
	sim.queue_play_card(0, "pig", Vector2i(2, 1))
	sim.step()
	_check(sim.units.size() == 2 and sim.get_unit(1)["copy_id"] != sim.get_unit(2)["copy_id"], "Same species can have distinct active copies")
	_check(sim.cards.state(0, "pig", sim)["available"] == 1, "Provisional pool has three configurable copies")
	sim.queue_summon(1, "boar", Vector2i(4, 1))
	sim.step()
	sim.get_unit(1)["hp"] = 1
	sim.queue_attack(3, 1)
	sim.step()
	_check(sim.get_unit(1).is_empty() and sim.get_unit(2)["hp"] == 4, "Defeat affects only one instance")
	_check(sim.players[0]["recovering"].has(1) and not sim.players[0]["recovering"].has(2), "Recovery is keyed by defeated instance, not species")
	var state := sim.cards.state(0, "pig", sim)
	_check(state["recovering"] == 1 and state["active"] == 1 and state["available"] == 1, "Recovery, activity and availability are separate")
	sim.queue_play_card(0, "pig", Vector2i(1, 1))
	sim.queue_destination(0, 2, Vector2i(2, 0))
	sim.step()
	_check(sim.get_unit(4)["kind"] == "pig" and sim.orders.active.has(2), "Other copies can deploy and receive orders during individual recovery")
	_check(sim.cards.state(0, "pig", sim)["available"] == 0, "No over-allocation of copies")
	var essence: int = sim.players[0]["essence"]
	sim.queue_play_card(0, "pig", Vector2i(0, 0))
	sim.step()
	_check(sim.units.size() == 3 and sim.players[0]["essence"] == essence, "Rejected exhausted copy does not spend essence")
	_ticks(sim, 238)
	_check(sim.tick_count == 243 and sim.cards.state(0, "pig", sim)["available"] == 1, "Defeated copy returns exactly after its own recovery")
	_check(sim.get_unit(1).is_empty(), "Recovery does not automatically respawn")
	sim.cards.copies_per_species = 2
	sim.reset()
	_check(sim.cards.state(0, "pig", sim)["available"] == 2, "Pool count configurable on reset")
	sim = AetherionSimulation.new()
	sim.queue_summon(0, "pig", Vector2i(3, 1))
	sim.queue_summon(0, "pig", Vector2i(3, 2))
	sim.queue_summon(1, "boar", Vector2i(4, 1))
	sim.step()
	sim.get_unit(1)["hp"] = 1
	sim.get_unit(2)["hp"] = 1
	sim.queue_attack(3, 1)
	sim.step()
	sim.get_unit(3)["cell"] = Vector2i(4, 2) # Independent second-defeat fixture.
	sim.get_unit(3)["ready_tick"] = 0
	sim.step()
	sim.queue_attack(3, 2)
	sim.step()
	_check(sim.players[0]["recovering"][1]["ready_tick"] == 242 and sim.players[0]["recovering"][2]["ready_tick"] == 244, "Two defeated copies keep different recovery deadlines")
	_ticks(sim, 238)
	_check(sim.tick_count == 242 and sim.cards.state(0, "pig", sim)["recovering"] == 1 and sim.cards.state(0, "pig", sim)["available"] == 2, "Recovering first copy does not prematurely release or delay second copy")
	_ticks(sim, 2)
	_check(sim.cards.state(0, "pig", sim)["available"] == 3, "All copies return independently at their deadlines")

func _test_cards_and_terrain() -> void:
	var sim := AetherionSimulation.new()
	sim.players[0]["essence"] = 8
	sim.queue_play_card(0, "cornfield", Vector2i(1, 1))
	sim.step()
	_check(sim.terrain.cells[Vector2i(1, 1)] == "cornfield" and sim.players[0]["essence"] == 7, "Terrain deploys through essence economy")
	sim.queue_play_card(0, "mud", Vector2i(1, 1))
	sim.step()
	_check(sim.cards.state(0, "cornfield", sim)["available"] == 1 and sim.players[0]["recovering"].is_empty(), "Normal exchange returns terrain immediately without defeat recovery")
	sim.queue_play_card(0, "horse", Vector2i(1, 1))
	sim.step()
	sim.get_unit(1)["hp"] = 1
	sim.queue_play_card(0, "cornfield", Vector2i(1, 1))
	sim.step()
	_check(sim.cards.state(0, "mud", sim)["available"] == 1, "Replaced mud is reusable, not recovering")
	sim.queue_special(0, 1, "forage")
	sim.step()
	_ticks(sim, 6)
	_check(sim.get_unit(1)["hp"] == 3 and sim.cards.state(0, "cornfield", sim)["available"] == 1, "Eating consumes one ration and releases its card without recovery")
	_check(sim.players[0]["recovering"].is_empty(), "No post-use cooldown on consumed terrain")
	sim.players[0]["essence"] = 8
	sim.queue_play_card(0, "heal", Vector2i.ZERO, 1)
	sim.step()
	_check(sim.get_unit(1)["hp"] == 4 and sim.players[0]["essence"] == 6, "Healing caps HP and pays essence")
	sim.get_unit(1)["hp"] = 2
	sim.queue_play_card(0, "heal", Vector2i.ZERO, 1)
	sim.step()
	_check(sim.get_unit(1)["hp"] == 4 and sim.players[0]["essence"] == 4, "Trick reusable next tick without artificial cooldown")
	sim.queue_play_card(0, "heal", Vector2i.ZERO, 1)
	sim.queue_play_card(0, "pig", Vector2i(6, 0))
	sim.step()
	_check(sim.players[0]["essence"] == 4, "Healthy target and enemy deployment rejected without payment")
	# Terrain exchange cannot withdraw a cell's terrain under an accepted attack.
	sim = AetherionSimulation.new()
	sim.queue_summon(0, "pig", Vector2i(3, 1))
	sim.queue_summon(1, "turtle", Vector2i(4, 1))
	sim.step()
	sim.players[0]["essence"] = 8
	sim.terrain.cells[Vector2i(3, 1)] = "cornfield"
	sim.cards.terrain_owners[Vector2i(3, 1)] = 0
	sim.queue_play_card(0, "mud", Vector2i(3, 1))
	sim.queue_attack(2, 1)
	sim.step()
	_check(sim.terrain.cells[Vector2i(3, 1)] == "cornfield" and sim.get_unit(1)["hp"] == 3, "Attack lock preserves terrain and accepted damage")

func _test_refuge() -> void:
	var sim := AetherionSimulation.new()
	sim.players[0]["essence"] = 8
	sim.queue_play_card(0, "cave", Vector2i(3, 1))
	sim.queue_play_card(0, "pig", Vector2i(3, 1))
	sim.queue_summon(1, "turtle", Vector2i(4, 1))
	sim.step()
	sim.queue_special(0, 1, "enter")
	sim.step()
	_check(not sim.get_unit(1).get("sheltered", false), "Refuge entry has preparation")
	_ticks(sim, 6)
	_check(sim.get_unit(1).get("sheltered", false), "Explicit six-tick entry creates refuge state")
	sim.queue_attack(1, 2)
	sim.queue_attack(2, 1)
	sim.step()
	_check(sim.get_unit(2)["hp"] == 5 and sim.get_unit(1)["hp"] == 3, "Sheltered unit cannot attack and still receives minimum one damage")
	sim.queue_play_card(0, "mud", Vector2i(3, 1))
	sim.step()
	_check(sim.terrain.cells[Vector2i(3, 1)] == "cave", "Cannot remove an occupied refuge under its occupant")
	sim.queue_destination(0, 1, Vector2i(2, 1))
	sim.step()
	_check(sim.actions.active[1]["kind"] == "leave" and sim.orders.active.has(1), "Movement order automatically schedules clear exit")
	_ticks(sim, 6)
	_check(not sim.get_unit(1).get("sheltered", false) and sim.get_unit(1)["cell"] == Vector2i(3, 1), "Six-tick exit clears refuge before moving")
	_ticks(sim, 8)
	_check(sim.get_unit(1)["cell"] == Vector2i(2, 1), "Refuge does not permanently block player navigation")
	# Contextual protection reduces a stronger hit by one, not all damage.
	sim = AetherionSimulation.new()
	sim.queue_summon(0, "pig", Vector2i(3, 1))
	sim.queue_summon(1, "boar", Vector2i(4, 1))
	sim.step()
	sim.get_unit(1)["sheltered"] = true # Combat-only fixture.
	sim.queue_attack(2, 1)
	sim.step()
	_check(sim.get_unit(1)["hp"] == 2, "Refuge reduces three damage to two without invulnerability")

func _test_construction() -> void:
	var sim := AetherionSimulation.new()
	sim.queue_play_card(1, "fence", Vector2i(4, 1))
	sim.queue_play_card(0, "golem", Vector2i(3, 1))
	sim.step()
	var fence: Dictionary = sim.cards.buildings[0]
	_check(not sim.can_move(0, 1, Vector2i(4, 1)), "Fence blocks movement and routes")
	sim.queue_special(0, 1, "demolish", fence["id"])
	sim.step()
	_check(sim.cards.buildings.size() == 1 and sim.actions.active.has(1), "Demolition visibly prepares, not instant deletion")
	_ticks(sim, 6)
	_check(sim.cards.buildings.is_empty() and sim.get_unit(1)["ready_tick"] == 64, "Golem demolition applies normal attack plus two after preparation")
	_check(sim.cards.state(1, "fence", sim)["recovering"] == 1 and sim.cards.state(1, "fence", sim)["ready_tick"] == 128, "Only destroyed construction enters 120-tick combat recovery")
	_ticks(sim, 120)
	_check(sim.cards.state(1, "fence", sim)["available"] == 1, "Construction becomes available at its own recovery expiry")
	sim.reset()
	_check(sim.cards.buildings.is_empty() and sim.actions.active.is_empty(), "Reset clears buildings and actions")
	# Accepted demolition still lands when its caster is lethally hit in that tick.
	sim.queue_summon(0, "golem", Vector2i(3, 1))
	sim.queue_summon(1, "boar", Vector2i(4, 2))
	sim.step()
	sim.players[1]["essence"] = 2
	sim.queue_play_card(1, "fence", Vector2i(4, 1))
	sim.step()
	var building_id: int = sim.cards.buildings[0]["id"]
	sim.queue_special(0, 1, "demolish", building_id)
	sim.step()
	sim.get_unit(2)["cell"] = Vector2i(3, 2)
	sim.get_unit(1)["hp"] = 1
	_ticks(sim, 5)
	sim.queue_attack(2, 1)
	sim.step()
	_check(sim.get_unit(1).is_empty() and sim.cards.buildings.is_empty(), "Lethal hit cannot cancel already accepted demolition damage")

func _test_hidden_core() -> void:
	var simulations: Array[AetherionSimulation] = []
	for core in [Vector2i(4, 1), Vector2i(6, 2)]:
		var sim := AetherionSimulation.new()
		sim.place_core(1, core)
		sim.queue_play_card(0, "pig", Vector2i(3, 1))
		sim.queue_play_card(0, "mud", Vector2i(3, 1))
		sim.step()
		sim.queue_destination(0, 1, Vector2i(4, 1))
		simulations.append(sim)
	for tick in range(20):
		for sim in simulations:
			sim.queue_core_attack(1, 1)
			sim.step()
		_check(simulations[0].get_player_view(0) == simulations[1].get_player_view(0), "Cards, copies and navigation do not expose hidden core location")
