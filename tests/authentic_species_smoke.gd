extends SceneTree

var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	for kind in ["pig", "boar", "horse", "golem"]:
		for owner in [0, 1]:
			_test_species(kind, owner)
	if failures == 0:
		print("PASS: one authentic unit per species/player, simultaneous and direct rejection, no charge, exact recovery, independent rival and fresh identity")
	quit(0 if failures == 0 else 1)

func _test_species(kind: String, owner: int) -> void:
	var sim := AetherionSimulation.new()
	# Funds and wound fixtures isolate uniqueness; combat stats/recovery unchanged.
	sim.players[0]["essence"] = 8
	sim.players[1]["essence"] = 8
	var cell := Vector2i(3 if owner == 0 else 4, 1)
	var rival_cell := Vector2i(4 if owner == 0 else 3, 1)
	var second_cell := Vector2i(2 if owner == 0 else 5, 2)
	sim.queue_play_card(owner, kind, cell, -1, 1)
	sim.queue_play_card(owner, kind, second_cell, -1, 2)
	sim.queue_play_card(1 - owner, kind, rival_cell)
	sim.step()
	_check(sim.units.size() == 2 and sim.get_unit(1)["owner"] == owner and sim.get_unit(2)["owner"] == 1 - owner, "Same species is legal once for each player")
	var essence: int = 8 - int(sim.CARD_STATS[kind]["cost"])
	_check(sim.players[owner]["essence"] == essence and sim.cards.state(owner, kind, sim)["available"] == 0, "Second same-tick deployment rejects without spending essence")
	_check(sim.cards.availability(owner, kind, sim)["reason"] == "species_active", "Active species has an explicit unavailable reason")
	sim.queue_summon(owner, kind, second_cell)
	sim.queue_play_card(owner, kind, second_cell)
	sim.step()
	_check(sim.units.size() == 2 and sim.players[owner]["essence"] == essence, "Direct summon and card APIs both enforce active uniqueness")
	sim.get_unit(1)["hp"] = 1
	sim.queue_attack(2, 1)
	sim.step()
	var ready: int = sim.players[owner]["recovering"][1]["ready_tick"]
	_check(sim.cards.availability(owner, kind, sim)["reason"] == "species_recovering", "Defeated species stays in recovery, not a spare copy pool")
	sim.queue_summon(owner, kind, second_cell)
	sim.queue_play_card(owner, kind, second_cell)
	sim.step()
	_check(sim.get_unit(3).is_empty() and sim.players[owner]["essence"] == essence, "Both entry points reject during recovery without cost")
	while sim.tick_count < ready - 2:
		sim.step()
	var before: int = sim.players[owner]["essence"]
	sim.queue_play_card(owner, kind, second_cell)
	sim.step()
	_check(sim.tick_count == ready - 1 and sim.get_unit(3).is_empty() and sim.players[owner]["essence"] == before, "Not available one tick before exact recovery deadline")
	_check(sim.cards.state(1 - owner, kind, sim)["active"] == 1, "Rival's same species is unaffected by this player's defeat")
	sim.step()
	_check(sim.cards.state(owner, kind, sim)["available"] == 1 and sim.get_unit(3).is_empty(), "Recovery releases a card without automatically spawning a unit")
	var payment_before: int = sim.players[owner]["essence"]
	sim.queue_play_card(owner, kind, second_cell)
	sim.step()
	_check(sim.get_unit(3).get("kind") == kind and sim.get_unit(3)["copy_id"] == 0 and sim.players[owner]["essence"] == payment_before - sim.CARD_STATS[kind]["cost"], "After recovery a new paid identity reuses the only authentic slot")
	_check(sim.cards.copies[owner][kind].size() == 1 and sim.cards.state(owner, kind, sim)["active"] == 1, "Only one authentic slot can exist per species/player")
