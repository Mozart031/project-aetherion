extends SceneTree

var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _scene():
	var view = load("res://scenes/battle_stacks_demo.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view.board.set_process(false)
	view.board._process(0.05)
	return view

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_acceptance_and_replay()
	_test_rejection_and_cancel()
	_test_independent_and_single()
	_test_final_tick()
	if failures == 0:
		print("PASS: automatic rotation on matching acceptance once, replay rejection, independent stacks, cancellation, singleton and final tick")
	quit(0 if failures == 0 else 1)

func _test_acceptance_and_replay() -> void:
	var view = _scene()
	var before: Dictionary = view.stacks.snapshot()
	view._begin("creature")
	view._hover(view.board._center(Vector2i(0, 0)))
	_check(view.stacks.snapshot() == before, "Preview and drag start cannot rotate")
	view._confirm_at(view.board._center(Vector2i(0, 0)))
	_check(view.stacks.snapshot() == before, "Sending a request cannot rotate before simulation acceptance")
	var command: Dictionary = view.board.sim.queued_commands[-1].duplicate(true)
	view.board._process(0.05)
	_check(view.stacks.top("creature") == "boar" and view.stacks.position_of("terrain") == 0, "One accepted pig advances only the creature stack")
	_check(view.stacks.snapshot()["cards"] == before["cards"], "Used type stays in equipped circular sequence")
	var accepted: Dictionary = view.stacks.snapshot()
	for index in range(5):
		view._on_step() # The same tick/result can be presented repeatedly.
	_check(view.stacks.snapshot() == accepted, "Duplicate presentation of accepted result cannot rotate twice")
	view.board.sim.queued_commands.append(command)
	view.board._process(0.05)
	_check(view.stacks.snapshot() == accepted and view.board.sim.players[0]["essence"] == 2, "Cached replay neither rotates nor pays a second time")
	for turn in range(3):
		view._cycle("creature")
	view._begin("creature")
	_check(view.placement.draft.is_empty() and view.placement.message == "species_active", "Rotating past an active authentic does not create a new free unit")
	view.free()

func _test_rejection_and_cancel() -> void:
	var view = _scene()
	var before: Dictionary = view.stacks.snapshot()
	view._begin("creature")
	view._confirm_at(view.board._center(Vector2i(7, 0)))
	_check(view.stacks.snapshot() == before and not view.placement.busy(), "Local invalid placement cannot rotate")
	view._cancel()
	_check(view.stacks.snapshot() == before, "Cancellation preserves all cursors")
	view._begin("creature")
	view.board.sim.queue_play_card(0, "fence", Vector2i(0, 0))
	view._confirm_at(view.board._center(Vector2i(0, 0)))
	view.board._process(0.05)
	_check(view.stacks.snapshot() == before and view.placement.message == "occupied", "Simulation rejection cannot rotate any category")
	view._confirm_at(view.board._center(Vector2i(0, 1)))
	var request: int = view.placement.draft["request_id"]
	view.board.sim.events.append({"type": "card_result", "player": 0, "card": "pig", "request_id": request - 1, "accepted": true})
	view._on_step()
	_check(view.stacks.snapshot() == before and view.placement.busy(), "A delayed older acceptance cannot advance or close a new pending request")
	var wrong := {"type": "card_result", "player": 1, "card": "pig", "request_id": request, "accepted": true}
	view.board.sim.events.append(wrong)
	view._on_step()
	_check(view.stacks.snapshot() == before and view.placement.busy(), "Another player's result cannot advance this player's stack")
	view.board.sim.events.append({"type": "card_result", "player": 0, "card": "horse", "request_id": request, "accepted": true})
	view._on_step()
	_check(view.stacks.snapshot() == before and view.placement.busy(), "Mismatched card identity cannot masquerade as acceptance")
	view.board._process(0.05)
	_check(view.stacks.top("creature") == "boar", "A later valid request advances once after an earlier rejection")
	view.free()

func _test_independent_and_single() -> void:
	var view = _scene()
	view._begin("terrain")
	view._confirm_at(view.board._center(Vector2i(0, 0)))
	view.board._process(0.05)
	_check(view.stacks.top("terrain") == "mud" and view.stacks.top("creature") == "pig", "Terrain acceptance advances independently of creatures")
	view._begin("construction")
	view._confirm_at(view.board._center(Vector2i(0, 1)))
	view.board._process(0.05)
	_check(view.stacks.top("construction") == "fence" and view.stacks.position_of("construction") == 0 and not view.panel.cards["construction"].data["ready"], "Single-card stack keeps the used card visible with current unavailable state")
	view.free()
	view = _scene()
	view._begin("creature")
	view._confirm_at(view.board._center(Vector2i(0, 0)))
	view.board._process(0.05)
	view.board.sim.get_unit(2)["hp"] = 1 # Wound fixture, unchanged healing rules.
	view._begin("trick")
	view._confirm_at(view.board._center(Vector2i(0, 0)))
	view.board._process(0.05)
	_check(view.stacks.top("trick") == "heal" and view.stacks.position_of("trick") == 0 and view.board.sim.cards.state(0, "heal", view.board.sim)["available"] == 1, "Single reusable trick retains its type without false recovery")
	view.free()

func _test_final_tick() -> void:
	var view = _scene()
	view.board.sim.tick_count = view.board.sim.MATCH_LIMIT_TICKS - 1 # Match-end boundary fixture.
	view._begin("terrain")
	view._confirm_at(view.board._center(Vector2i(0, 0)))
	view.board._process(0.05)
	_check(view.board.sim.finished and view.stacks.top("terrain") == "mud", "A correctly accepted final-tick card also rotates once")
	view._on_step()
	_check(view.stacks.position_of("terrain") == 1, "Final-tick result replay stays idempotent")
	view.free()
