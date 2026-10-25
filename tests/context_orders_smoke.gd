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
	var sim := AetherionSimulation.new()
	sim.place_terrain(Vector2i(3, 1), "cornfield")
	sim.queue_summon(0, "horse", Vector2i(1, 1))
	sim.step()
	sim.get_unit(1)["hp"] = 2
	var before := sim.get_player_view(0)
	var options := sim.get_context_actions(0, 1, Vector2i(3, 1))
	_check(options[0]["enabled"] and options[0]["kind"] == "forage", "Pure query offers travel-and-eat at distant crop")
	_check(sim.get_player_view(0) == before and sim.get_context_actions(1, 1, Vector2i(3, 1)).is_empty(), "Context query is read-only and owner checked")
	sim.queue_act_at(0, 1, "forage", Vector2i(3, 1))
	_ticks(sim, 40)
	_check(sim.get_unit(1)["hp"] == 4 and sim.get_unit(1)["cell"] == Vector2i(3, 1), "Explicit go-and-act approaches then performs existing action")
	_check(sim.orders.active.is_empty() and not sim.terrain.cells.has(Vector2i(3, 1)), "Composite order completes without reviving old goals")
	sim.reset()
	sim.place_terrain(Vector2i(3, 1), "cornfield")
	sim.queue_summon(0, "horse", Vector2i(1, 1))
	sim.step()
	sim.get_unit(1)["hp"] = 2
	sim.queue_act_at(0, 1, "forage", Vector2i(3, 1))
	sim.step()
	var committed: Vector2i = sim.get_motion(1)["to"]
	sim.terrain.cells.erase(Vector2i(3, 1)) # Another consumer's resource-loss fixture.
	_ticks(sim, 20)
	_check(sim.orders.active.is_empty() and sim.get_unit(1)["cell"] == committed, "Lost resource cancels order but finishes accepted step")
	sim.reset()
	sim.queue_summon(0, "golem", Vector2i(1, 1))
	sim.queue_play_card(1, "fence", Vector2i(4, 1))
	sim.step()
	var id: int = sim.cards.buildings[0]["id"]
	sim.queue_act_at(0, 1, "demolish", Vector2i(4, 1), id)
	_ticks(sim, 50)
	_check(sim.cards.buildings.is_empty() and sim.orders.active.is_empty(), "Go-and-demolish works from outside adjacency")
	sim.reset()
	sim.place_terrain(Vector2i(2, 1), "cave")
	sim.queue_summon(0, "pig", Vector2i(1, 1))
	sim.step()
	sim.queue_act_at(0, 1, "enter", Vector2i(2, 1))
	_ticks(sim, 25)
	_check(sim.get_unit(1).get("sheltered", false), "Go-and-refuge enters after approach")
	sim.queue_hold(0, 1)
	_ticks(sim, 20)
	_check(sim.get_unit(1).get("sheltered", false), "Hold respects explicit refuge")
	sim.queue_act_at(0, 1, "leave", Vector2i(2, 1))
	_ticks(sim, 8)
	_check(not sim.get_unit(1).get("sheltered", false) and sim.orders.active.is_empty(), "Contextual leave finishes explicitly without a stale refuge goal")
	sim.queue_destination(0, 1, Vector2i(1, 1))
	_ticks(sim, 25)
	_check(not sim.get_unit(1).get("sheltered", false) and sim.get_unit(1)["cell"] == Vector2i(1, 1), "New navigation retains clear refuge exit")
	sim.reset()
	sim.place_terrain(Vector2i(3, 1), "cornfield")
	sim.queue_summon(0, "pig", Vector2i(3, 1))
	sim.queue_summon(1, "boar", Vector2i(4, 1))
	sim.step()
	sim.queue_hold(1, 2)
	sim.step()
	while sim.tick_count < int(sim.get_unit(2)["ready_tick"]) - 1:
		sim.step()
	sim.queue_play_card(0, "cave", Vector2i(3, 1))
	sim.step()
	_check(sim.terrain.cells[Vector2i(3, 1)] == "cornfield" and sim.players[0]["essence"] == 2, "Hold defense preserves the existing prohibition on terrain exchange under accepted attack")
	if failures == 0:
		print("PASS: pure contextual queries, hold, distant actions, resource loss and refuge authority")
	quit(0 if failures == 0 else 1)
