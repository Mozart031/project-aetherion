extends RefCounted

## Local uncommitted draft. Only confirmation sends a command; no economy writes.
var draft: Dictionary = {}
var next_request_id := 1
var message := ""

func reset() -> void:
	draft.clear()
	next_request_id = 1
	message = ""

func busy() -> bool:
	return draft.get("state") == "sending"

func begin(player: int, category: String, card: String, sim) -> bool:
	if busy():
		return false
	draft.clear()
	var readiness: Dictionary = sim.cards.availability(player, card, sim)
	if not readiness["valid"]:
		message = readiness["reason"]
		return false
	draft = {"player": player, "category": category, "card": card, "state": "preview"}
	message = ""
	return true

func cancel() -> bool:
	if busy():
		return false # A confirmed command is not a locally cancellable draft.
	draft.clear()
	message = ""
	return true

func preview(sim, cell: Vector2i, target_id: int = -1) -> Dictionary:
	if draft.is_empty():
		return {"valid": false, "reason": "no_draft"}
	return sim.get_card_placement(draft["player"], draft["card"], cell, target_id)

func confirm(sim, cell: Vector2i, target_id: int = -1) -> bool:
	if draft.is_empty() or busy():
		return false
	var option := preview(sim, cell, target_id)
	if not option["valid"]:
		message = option["reason"]
		return false
	draft["request_id"] = next_request_id
	next_request_id += 1
	draft["state"] = "sending"
	sim.queue_play_card(draft["player"], draft["card"], cell, target_id, draft["request_id"])
	return true

## Returns one matched acceptance for presentation; clearing the draft deduplicates it.
func consume(view: Dictionary) -> Dictionary:
	if draft.is_empty():
		return {}
	if busy():
		for event in view["events"]:
			if event["type"] != "card_result" or event["player"] != draft["player"] or event["request_id"] != draft["request_id"] or event.get("card") != draft["card"]:
				continue
			if event["accepted"]:
				var played := draft.duplicate(true)
				draft.clear()
				message = "accepted"
				return played
			draft["state"] = "preview"
			message = event["reason"]
			break
	# Even an acceptance in the final tick must be consumed before game-over cleanup.
	if view["finished"]:
		draft.clear()
		message = "match_finished"
	return {}
