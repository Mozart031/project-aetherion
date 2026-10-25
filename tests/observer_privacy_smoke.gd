extends SceneTree

var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_test_fields()
	_test_events()
	_test_dead_recipient()
	_test_live_routes()
	_test_terrain()
	if failures == 0:
		print("PASS: symmetric observer privacy, private recipients after death, public effects, unknown-event denial, live terrain ownership and isolated snapshots")
	quit(0 if failures == 0 else 1)

func _test_fields() -> void:
	for observer in [0, 1]:
		var enemy: int = 1 - observer
		var sim := AetherionSimulation.new()
		sim.queue_play_card(0, "pig", Vector2i(3, 1))
		sim.queue_play_card(1, "pig", Vector2i(4, 1))
		sim.step()
		var own_id: int = sim.units.filter(func(unit): return unit["owner"] == observer)[0]["id"]
		var enemy_id: int = sim.units.filter(func(unit): return unit["owner"] == enemy)[0]["id"]
		var view := sim.get_player_view(observer)
		_check(view["players"][observer].has("essence") and view["players"][observer].has("recovering") and view["players"][observer].has("core_cell"), "Owner retains economy, recovery and own core")
		_check(view["players"][enemy].keys() == ["core_hp"], "Enemy player exposes neither economy/recovery nor hidden core")
		sim.events.clear()
		var baseline := sim.get_player_view(observer)
		sim.players[enemy]["essence"] = 0
		sim.players[enemy]["recovering"][1000] = {"kind": "horse", "ready_tick": 321}
		sim.players[enemy]["core_cell"] = Vector2i(enemy * 4 + 2, 3)
		sim.loadouts[enemy].configure({"creature": [], "terrain": [], "construction": [], "trick": []}) # Private equipment fixture.
		var hidden := sim.get_unit(enemy_id)
		hidden["ready_tick"] = 999
		hidden["special_ready_tick"] = 888
		hidden["ecology_enabled"] = false
		hidden["copy_id"] = 42
		hidden["future_private_field"] = "secret"
		sim.orders.active[enemy_id] = {"goal": {"kind": "move_to", "cell": Vector2i.ZERO}, "path": [], "status": "pending"}
		sim.natural.enabled = true
		sim.natural.explanations[enemy_id] = "private intent"
		# Enabling ecology also adds the owner's natural panel; exclude only that known change.
		baseline["natural"] = sim.natural.view_for(observer, sim.units)
		_check(baseline == sim.get_player_view(observer), "Changing only enemy private state cannot alter this observer's view")
		_check(sim.get_player_view(enemy)["players"][enemy]["recovering"].has(1000), "The same recovery is still visible to its owner")
		sim.actions.active[enemy_id] = {"kind": "roll", "cell": hidden["cell"], "start_tick": 1, "end_tick": 7, "target_id": 123, "source": "natural", "future_secret": true}
		var action: Dictionary = sim.get_player_view(observer)["actions"][enemy_id]
		_check(action.has("start_tick") and action.has("end_tick") and not action.has("source") and not action.has("target_id") and not action.has("future_secret"), "Enemy preparation retains animation timing without internal intent")
		sim.players[enemy]["core_known_to"][observer] = true # Existing discovery fixture only.
		_check(sim.get_player_view(observer)["players"][enemy]["core_cell"] == sim.players[enemy]["core_cell"], "Existing discovered-core fixture remains visible")
		view = sim.get_player_view(observer)
		view["units"].filter(func(unit): return unit["id"] == own_id)[0]["hp"] = 0
		view["players"][observer]["recovering"][20] = {}
		view["actions"][enemy_id]["kind"] = "edited"
		_check(sim.get_unit(own_id)["hp"] == 4 and not sim.players[observer]["recovering"].has(20) and sim.actions.active[enemy_id]["kind"] == "roll", "Nested snapshots cannot mutate simulation")
	_check(AetherionSimulation.new().get_player_view(-1).is_empty(), "Invalid observers receive no state")

func _test_events() -> void:
	var sim := AetherionSimulation.new()
	var private_types := ["card_result", "card_rejected", "card_recovered", "order_accepted", "order_rejected", "order_status", "order_stopped", "order_completed", "natural_state", "ecology_changed", "ecology_rejected", "special_rejected", "move_rejected"]
	for owner in [0, 1]:
		for type in private_types:
			sim.events = [{"type": type, "player": owner, "unit_id": 999, "reason": "private"}]
			_check(sim.get_player_view(owner)["events"].size() == 1 and sim.get_player_view(1 - owner)["events"].is_empty(), "Private event stays with recorded recipient even without live actor: " + type)
		sim.events = [{"type": "future_unknown", "player": owner, "secret": 42}]
		_check(sim.get_player_view(0)["events"].is_empty() and sim.get_player_view(1)["events"].is_empty(), "Unknown event is denied by default")
	sim.events = [{"type": "order_rejected", "unit_id": 999}]
	_check(sim.get_player_view(0)["events"].is_empty() and sim.get_player_view(1)["events"].is_empty(), "Private event with no recipient fails closed")
	sim.events = [{"type": "attack_accepted", "unit_id": 1, "target_id": 2, "from_cell": Vector2i(3, 1), "cell": Vector2i(4, 1), "amount": 1, "source": "natural", "future_secret": 12}, {"type": "match_end", "winner": -1}]
	for owner in [0, 1]:
		var public: Array = sim.get_player_view(owner)["events"]
		_check(public.size() == 2 and public[0]["amount"] == 1 and not public[0].has("source") and not public[0].has("future_secret"), "Public attack and outcome remain visible without private or unknown payload fields")

func _test_dead_recipient() -> void:
	for control in ["hold", "invalid_special", "mixed"]:
		var sim := AetherionSimulation.new()
		sim.natural.enabled = true
		sim.queue_play_card(0, "boar", Vector2i(3, 1))
		sim.queue_play_card(1, "pig", Vector2i(4, 1))
		sim.step()
		sim.get_unit(2)["hp"] = 1 # Defeat fixture; commands still emit before real simultaneous damage.
		sim.queue_ecology(1, 2, false)
		sim.queue_play_card(1, "pig", Vector2i(5, 1), -1, 20)
		if control in ["hold", "mixed"]:
			sim.queue_hold(1, 2)
		if control in ["invalid_special", "mixed"]:
			sim.queue_special(1, 2, "charge")
		sim.queue_attack(1, 2)
		sim.step()
		_check(sim.get_unit(2).is_empty(), "Recipient really died in this tick")
		var owner_events: Array = sim.get_player_view(1)["events"]
		var enemy_events: Array = sim.get_player_view(0)["events"]
		_check(owner_events.any(func(event): return event["type"] == "card_rejected") and owner_events.any(func(event): return event["type"] == "ecology_changed"), "Owner receives own rejected card and ecology control after death")
		var control_type: String = {"hold": "order_accepted", "invalid_special": "special_rejected", "mixed": "order_rejected"}[control]
		_check(owner_events.any(func(event): return event["type"] == control_type) and owner_events.any(func(event): return event["type"] == "natural_state"), "Emitter records recipient for private order/special/natural event before death")
		_check(enemy_events.all(func(event): return event.get("player", -1) == 0 if event["type"] in ["card_rejected", "card_result", "order_accepted", "order_rejected", "order_status", "ecology_changed", "special_rejected", "natural_state"] else true), "Enemy cannot recover private events from deceased unit; it still receives its own")
		for view in [sim.get_player_view(0), sim.get_player_view(1)]:
			_check(view["events"].any(func(event): return event["type"] == "attack_accepted") and view["events"].any(func(event): return event["type"] == "defeated"), "Both observers retain visible attack and defeat")

func _test_live_routes() -> void:
	var sim := AetherionSimulation.new()
	sim.queue_play_card(0, "pig", Vector2i(3, 1))
	sim.queue_play_card(1, "pig", Vector2i(4, 1))
	sim.step()
	sim.queue_move(1, 2, Vector2i(3, 1))
	sim.step()
	_check(sim.get_player_view(1)["events"].any(func(event): return event["type"] == "move_rejected") and not sim.get_player_view(0)["events"].any(func(event): return event["type"] == "move_rejected"), "Real rejected movement is owner-only")
	sim.queue_ecology(1, 2, true)
	sim.queue_ecology(1, 2, false)
	sim.queue_destination(1, 2, Vector2i(-1, -1))
	sim.step()
	_check(sim.get_player_view(1)["events"].any(func(event): return event["type"] == "ecology_rejected") and sim.get_player_view(1)["events"].any(func(event): return event["type"] == "order_rejected"), "Conflicting ecology and invalid order retain the actual recipient")
	sim.queue_hold(1, 2)
	sim.step()
	sim.queue_stop(1, 2)
	sim.step()
	_check(sim.get_player_view(1)["events"].any(func(event): return event["type"] == "order_stopped") and sim.get_player_view(0)["events"].is_empty(), "Accepted stop acknowledgement is private")
	sim.queue_destination(1, 2, sim.get_unit(2)["cell"])
	sim.step()
	_check(sim.get_player_view(1)["events"].any(func(event): return event["type"] == "order_completed") and sim.get_player_view(0)["events"].is_empty(), "Completed order acknowledgement is private")
	sim.players[1]["recovering"][999] = {"kind": "fence", "ready_tick": sim.tick_count + 1} # Recovery boundary fixture.
	sim.step()
	_check(sim.get_player_view(1)["events"].any(func(event): return event["type"] == "card_recovered") and sim.get_player_view(0)["events"].is_empty(), "Recovery completion does not expose enemy availability")

func _test_terrain() -> void:
	var sim := AetherionSimulation.new()
	sim.place_terrain(Vector2i(1, 1), "mud")
	sim.queue_play_card(0, "cornfield", Vector2i(2, 1))
	sim.queue_play_card(1, "cave", Vector2i(5, 1))
	sim.step()
	for observer in [0, 1]:
		var owners: Dictionary = sim.get_player_view(observer)["terrain_owners"]
		_check(owners[Vector2i(1, 1)] == -1 and owners[Vector2i(2, 1)] == 0 and owners[Vector2i(5, 1)] == 1, "Present terrain ownership and neutrality are public for both sides")
	sim.queue_play_card(0, "cave", Vector2i(2, 1))
	sim.step()
	_check(sim.get_player_view(1)["terrain"][Vector2i(2, 1)] == "cave" and sim.get_player_view(1)["terrain_owners"][Vector2i(2, 1)] == 0, "Normal exchange preserves correct live ownership")
	sim.terrain.cells.erase(Vector2i(2, 1)) # Consumed-terrain projection fixture; stale internal owner exists.
	_check(not sim.get_player_view(0)["terrain_owners"].has(Vector2i(2, 1)), "Projection never exposes stale ownership of absent terrain")
	var snapshot := sim.get_player_view(0)
	snapshot["terrain_owners"][Vector2i(5, 1)] = 0
	_check(sim.cards.terrain_owners[Vector2i(5, 1)] == 1, "Ownership projection is isolated")
	sim.reset()
	_check(sim.get_player_view(0)["terrain_owners"].is_empty(), "Restart clears projected ownership")
	var consumed := AetherionSimulation.new()
	consumed.queue_play_card(0, "cornfield", Vector2i(2, 1))
	consumed.queue_play_card(0, "horse", Vector2i(2, 1))
	consumed.step()
	consumed.get_unit(1)["hp"] = 1 # Wounded horse fixture; real forage consumes the terrain.
	consumed.queue_special(0, 1, "forage")
	for tick in range(7):
		consumed.step()
	_check(not consumed.get_player_view(1)["terrain_owners"].has(Vector2i(2, 1)) and consumed.get_unit(1)["hp"] == 3, "Real consumption removes public ownership without changing forage")
