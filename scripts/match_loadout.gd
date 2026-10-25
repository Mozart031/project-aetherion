extends RefCounted

## Equipped card TYPES, not copy inventory. Configuration changes only before play.
const Catalog = preload("res://scripts/battle_catalog.gd")
var _equipped: Dictionary = {}

func _init() -> void:
	configure(default_cards())

static func default_cards() -> Dictionary:
	var result := {}
	for category in Catalog.CATEGORIES:
		result[category] = []
	for id in Catalog.CARDS:
		result[Catalog.CARDS[id]["category"]].append(id)
	return result

func configure(value: Dictionary, catalog: Dictionary = Catalog.CARDS) -> bool:
	if value.size() != Catalog.CATEGORIES.size():
		return false
	var candidate := {}
	for category in Catalog.CATEGORIES:
		if not value.has(category) or not value[category] is Array:
			return false
		candidate[category] = []
		for id in value[category]:
			if not id is String or not catalog.has(id) or catalog[id]["category"] != category or id in candidate[category]:
				return false
			candidate[category].append(id)
	_equipped = candidate
	return true

func contains(id: String) -> bool:
	for ids in _equipped.values():
		if id in ids:
			return true
	return false

func snapshot() -> Dictionary:
	return _equipped.duplicate(true)
