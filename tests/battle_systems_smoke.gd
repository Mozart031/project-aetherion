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
		print("PASS: battle card economy, unique species/recovery, terrain exchange, real refuge, construction and hidden core")
	quit(0 if failures == 0 else 1)

func _test_copies() -> void:
	var sim := AetherionSimulation.new()
	sim.queue_play_card(0, "pig", Vector2i(3, 1))
	sim.queue_play_card(0, "pig", Vector2i(2, 1))
	sim.queue_play_card(1, "pig", Vector2i(4, 1))
	sim.step()
	_check(sim.units.size() == 2 and sim.cards.state(0, "pig", sim)["active"] == 1 and sim.cards.state(1, "pig", sim)["active"] == 1, "One authentic pig per player; same species on opposite players is legal")
	_check(sim.players[0]["essence"] == 2 and sim.cards.state(0, "pig", sim)["available"] == 0, "Second simultaneous summon rejects without charging")
	sim.get_unit(1)["hp"] = 1 # Defeat fixture, attack damage unchanged.
	sim.queue_attack(2, 1)
	sim.step()
	var ready: int = sim.players[0]["recovering"][1]["ready_tick"]
	sim.queue_play_card(0, "pig", Vector2i(1, 1))
	sim.step()
	_check(sim.get_unit(3).is_empty() and sim.players[0]["essence"] == 2, "Recovering authentic species cannot be replaced with another copy")
	_check(sim.cards.state(0, "pig", sim)["recovering"] == 1 and sim.cards.state(0, "pig", sim)["available"] == 0, "Defeated species stays unavailable")
	while sim.tick_count < ready:
		sim.step()
	_check(sim.cards.state(0, "pig", sim)["available"] == 1 and sim.get_unit(1).is_empty(), "Recovery returns the card, never an automatic unit")
	sim.queue_play_card(0, "pig", Vector2i(1, 1))
	sim.step()
	_check(sim.get_unit(3).get("copy_id") == 0 and sim.get_unit(2)["owner"] == 1, "After recovery a new unit uses the same unique species slot, independently of the rival")
	sim.reset()
	_check(sim.cards.state(0, "pig", sim)["available"] == 1 and sim.cards.copies[0]["pig"].size() == 1, "Reset always restores one authentic species slot")

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
