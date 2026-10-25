extends RefCounted

const Loadout = preload("res://scripts/match_loadout.gd")
const Catalog = preload("res://scripts/battle_catalog.gd")
var _cards: Dictionary = {}
var _cursors: Dictionary = {}

func configure(equipped: Dictionary, catalog: Dictionary = Catalog.CARDS) -> bool:
	var validated := Loadout.new()
	if not validated.configure(equipped, catalog):
		return false
	_cards = validated.snapshot()
	reset()
	return true

func reset() -> void:
	_cursors.clear()
	for category in _cards:
		_cursors[category] = 0

func top(category: String) -> String:
	var ids: Array = _cards.get(category, [])
	return "" if ids.is_empty() else str(ids[_cursors[category]])

func cycle(category: String) -> String:
	var ids: Array = _cards.get(category, [])
	if not ids.is_empty():
		_cursors[category] = (int(_cursors[category]) + 1) % ids.size()
	return top(category)

func position_of(category: String) -> int:
	return int(_cursors.get(category, 0))

func count(category: String) -> int:
	return _cards.get(category, []).size()

func snapshot() -> Dictionary:
	return {"cards": _cards.duplicate(true), "cursors": _cursors.duplicate()}
