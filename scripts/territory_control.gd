extends RefCounted
class_name TerritoryControl

## Persistent 32-section territorial dominion state (8x4 logical, 4x8 vertical).
## Strictly separated from card authorship (cards.terrain_owners) and ecology (terrain.cells).
const WIDTH := 8
const HEIGHT := 4
const TOTAL_SECTIONS := WIDTH * HEIGHT
const INITIAL_SECTIONS_PER_PLAYER := 16
const PERCENT_PER_SECTION := 3.125
const CONQUEST_TICKS := 60

var section_controllers: Dictionary = {}
var footprints: Dictionary = {}
var section_footprint: Dictionary = {}
var next_footprint_id_by_bucket: Dictionary = {}
var conquest_ticks := CONQUEST_TICKS
var interrupt_conquest_on_damage := true
var conquering_species: Dictionary = {}
var conquering_units: Dictionary = {}
var defender_coverage: Dictionary = {}
var protected_sections_by_player: Dictionary = {0: {}, 1: {}}

func _init() -> void:
	reset()

func reset() -> void:
	section_controllers.clear()
	footprints.clear()
	section_footprint.clear()
	next_footprint_id_by_bucket = {-1: 1, 0: 1001, 1: 2001}
	conquest_ticks = CONQUEST_TICKS
	interrupt_conquest_on_damage = true
	conquering_species.clear()
	conquering_units.clear()
	defender_coverage.clear()
	protected_sections_by_player = {0: {}, 1: {}}
	for x in range(WIDTH):
		var initial_owner := 0 if x < 4 else 1
		for y in range(HEIGHT):
			section_controllers[Vector2i(x, y)] = initial_owner

func is_valid_section(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT

func is_initial_section_of(player: int, cell: Vector2i) -> bool:
	if player not in [0, 1] or not is_valid_section(cell):
		return false
	return cell.x >= player * 4 and cell.x < player * 4 + 4

func get_controller(cell: Vector2i) -> int:
	return int(section_controllers.get(cell, -1))

func set_controller(cell: Vector2i, new_owner: int) -> Dictionary:
	if not is_valid_section(cell) or new_owner not in [0, 1]:
		return {"changed": false, "cell": cell, "previous_owner": -1, "new_owner": -1, "footprint_id": -1}
	var previous_owner := int(section_controllers[cell])
	section_controllers[cell] = new_owner
	return {
		"changed": previous_owner != new_owner,
		"cell": cell,
		"previous_owner": previous_owner,
		"new_owner": new_owner,
		"footprint_id": int(section_footprint.get(cell, -1))
	}

func controlled_sections(player: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if player not in [0, 1]:
		return result
	for x in range(WIDTH):
		for y in range(HEIGHT):
			var cell := Vector2i(x, y)
			if int(section_controllers.get(cell, -1)) == player:
				result.append(cell)
	return result

func controlled_count(player: int) -> int:
	if player not in [0, 1]:
		return 0
	var count := 0
	for cell in section_controllers:
		if int(section_controllers[cell]) == player:
			count += 1
	return count

func dominion_percent(player: int) -> float:
	return float(controlled_count(player)) * PERCENT_PER_SECTION

func dominion_summary() -> Dictionary:
	var count_0 := controlled_count(0)
	var count_1 := controlled_count(1)
	return {
		"total_sections": TOTAL_SECTIONS,
		"percent_per_section": PERCENT_PER_SECTION,
		"counts": [count_0, count_1],
		"percentages": [float(count_0) * PERCENT_PER_SECTION, float(count_1) * PERCENT_PER_SECTION]
	}

func _connected_components(cells: Array[Vector2i]) -> Array:
	var components := []
	if cells.is_empty():
		return components
	var lookup := {}
	for cell in cells:
		lookup[cell] = true
	var visited := {}
	for start in cells:
		if visited.has(start):
			continue
		var reachable := {start: true}
		visited[start] = true
		var queue: Array[Vector2i] = [start]
		var cursor := 0
		while cursor < queue.size():
			var current := queue[cursor]
			cursor += 1
			for dir in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
				var neighbor: Vector2i = current + dir
				if lookup.has(neighbor) and not visited.has(neighbor):
					visited[neighbor] = true
					reachable[neighbor] = true
					queue.append(neighbor)
		var ordered_component: Array[Vector2i] = []
		for cell in cells:
			if reachable.has(cell):
				ordered_component.append(cell)
		components.append(ordered_component)
	return components

func _are_sections_contiguous(cells: Array[Vector2i]) -> bool:
	return not cells.is_empty() and _connected_components(cells).size() == 1

func _bucket_for_sections(cells: Array[Vector2i], author: int) -> int:
	if author in [0, 1]:
		var all_in_author_half := true
		for cell in cells:
			if not is_initial_section_of(author, cell):
				all_in_author_half = false
				break
		if all_in_author_half:
			return author
	var all_p0 := true
	var all_p1 := true
	for cell in cells:
		if not is_initial_section_of(0, cell):
			all_p0 = false
		if not is_initial_section_of(1, cell):
			all_p1 = false
	if all_p0:
		return 0
	if all_p1:
		return 1
	return -1

func _allocate_footprint_id(cells: Array[Vector2i], author: int) -> int:
	var bucket := _bucket_for_sections(cells, author)
	var id := int(next_footprint_id_by_bucket[bucket])
	next_footprint_id_by_bucket[bucket] = id + 1
	return id

## Registers a contiguous territorial footprint without mutating card authorship or terrain ecology.
func register_footprint(cells: Array, kind: String, author: int = -1) -> int:
	if cells.is_empty() or kind.is_empty():
		return -1
	var normalized: Array[Vector2i] = []
	for entry in cells:
		if not entry is Vector2i or not is_valid_section(entry) or entry in normalized:
			return -1
		normalized.append(entry)
	if not _are_sections_contiguous(normalized):
		return -1
	for cell in normalized:
		_detach_section_from_footprint(cell)
	var id := _allocate_footprint_id(normalized, author)
	footprints[id] = {
		"id": id,
		"kind": kind,
		"author": author,
		"sections": normalized.duplicate()
	}
	for cell in normalized:
		section_footprint[cell] = id
	return id

func _detach_section_from_footprint(cell: Vector2i) -> void:
	if not section_footprint.has(cell):
		return
	var old_id: int = int(section_footprint[cell])
	section_footprint.erase(cell)
	if not footprints.has(old_id):
		return
	var old_data: Dictionary = footprints[old_id]
	var remaining: Array[Vector2i] = []
	for section in old_data["sections"]:
		if section != cell:
			remaining.append(section)
	if remaining.is_empty():
		footprints.erase(old_id)
		return
	var components := _connected_components(remaining)
	footprints[old_id]["sections"] = components[0]
	for idx in range(1, components.size()):
		var component: Array[Vector2i] = components[idx]
		var split_id := _allocate_footprint_id(component, int(old_data["author"]))
		footprints[split_id] = {
			"id": split_id,
			"kind": str(old_data["kind"]),
			"author": int(old_data["author"]),
			"sections": component
		}
		for section in component:
			section_footprint[section] = split_id

func get_footprint(footprint_id: int) -> Dictionary:
	if not footprints.has(footprint_id):
		return {}
	var data: Dictionary = footprints[footprint_id]
	var sections: Array[Vector2i] = data["sections"].duplicate()
	var controllers_by_section := {}
	var owners := {}
	for cell in sections:
		var owner := get_controller(cell)
		controllers_by_section[cell] = owner
		owners[owner] = true
	var unified_controller := int(owners.keys()[0]) if owners.size() == 1 else -1
	return {
		"id": int(data["id"]),
		"kind": str(data["kind"]),
		"author": int(data["author"]),
		"sections": sections,
		"section_count": sections.size(),
		"controllers_by_section": controllers_by_section,
		"is_unified": owners.size() == 1,
		"unified_controller": unified_controller
	}

func get_footprint_at(cell: Vector2i) -> Dictionary:
	if not section_footprint.has(cell):
		return {}
	return get_footprint(int(section_footprint[cell]))

func _is_footprint_visible_to(data: Dictionary, observer: int, hide_enemy_footprints: bool) -> bool:
	if not hide_enemy_footprints:
		return true
	if observer not in [0, 1]:
		return false
	for cell in data["sections"]:
		if not is_initial_section_of(observer, cell):
			return false
	return true

func view_for(observer: int, hide_enemy_footprints: bool = false) -> Dictionary:
	var summary := dominion_summary()
	var projected_footprints := {}
	var ids := footprints.keys()
	ids.sort()
	for id in ids:
		var raw: Dictionary = footprints[id]
		if _is_footprint_visible_to(raw, observer, hide_enemy_footprints):
			projected_footprints[id] = get_footprint(int(id))
	return {
		"total_sections": summary["total_sections"],
		"percent_per_section": summary["percent_per_section"],
		"section_controllers": section_controllers.duplicate(true),
		"counts": summary["counts"].duplicate(),
		"percentages": summary["percentages"].duplicate(),
		"footprints": projected_footprints
	}

func set_species_can_conquer(kind: String, enabled: bool = true) -> void:
	if kind.is_empty():
		return
	if enabled:
		conquering_species[kind] = true
	else:
		conquering_species.erase(kind)

func set_unit_can_conquer(unit_id: int, enabled: bool = true) -> void:
	if unit_id <= 0:
		return
	conquering_units[unit_id] = enabled

func clear_unit_state(unit_id: int) -> void:
	conquering_units.erase(unit_id)
	defender_coverage.erase(unit_id)

func can_unit_conquer(unit: Dictionary) -> bool:
	if unit.is_empty():
		return false
	var id := int(unit.get("id", -1))
	if conquering_units.has(id):
		return bool(conquering_units[id])
	return bool(conquering_species.get(str(unit.get("kind", "")), false))

func set_defender_coverage(defender_id: int, cells: Array) -> void:
	if defender_id <= 0:
		return
	var valid_cells: Array[Vector2i] = []
	for entry in cells:
		if entry is Vector2i and is_valid_section(entry) and entry not in valid_cells:
			valid_cells.append(entry)
	if valid_cells.is_empty():
		defender_coverage.erase(defender_id)
	else:
		defender_coverage[defender_id] = valid_cells

func clear_defender_coverage(defender_id: int) -> void:
	defender_coverage.erase(defender_id)

func set_section_protected(owner: int, cell: Vector2i, protected: bool = true) -> void:
	if owner not in [0, 1] or not is_valid_section(cell):
		return
	if protected:
		protected_sections_by_player[owner][cell] = true
	else:
		protected_sections_by_player[owner].erase(cell)

func is_section_protected_against(cell: Vector2i, attacker_owner: int, units: Array = [], buildings: Array = []) -> bool:
	if attacker_owner not in [0, 1] or not is_valid_section(cell):
		return false
	var defender_owner := 1 - attacker_owner
	if get_controller(cell) != defender_owner:
		return false
	if protected_sections_by_player[defender_owner].get(cell, false):
		return true
	for unit in units:
		if int(unit.get("owner", -1)) == defender_owner and int(unit.get("hp", 0)) > 0 and not unit.get("sheltered", false):
			var uid := int(unit["id"])
			if defender_coverage.has(uid) and cell in defender_coverage[uid]:
				return true
	for building in buildings:
		if int(building.get("owner", -1)) == defender_owner and int(building.get("hp", 0)) > 0:
			var bid := int(building["id"])
			if defender_coverage.has(bid) and cell in defender_coverage[bid]:
				return true
	return false
