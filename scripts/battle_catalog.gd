extends RefCounted

## Provisional, original prototype cards; economy is validated by the simulation.
const CARDS := {
	"pig": {"label": "Cerdo", "category": "creature", "cost": 2},
	"boar": {"label": "Jabalí", "category": "creature", "cost": 3},
	"horse": {"label": "Caballo", "category": "creature", "cost": 3},
	"golem": {"label": "Gólem", "category": "creature", "cost": 4},
	"cornfield": {"label": "Maizal", "category": "terrain", "cost": 1},
	"mud": {"label": "Barro", "category": "terrain", "cost": 1},
	"cave": {"label": "Cueva", "category": "terrain", "cost": 2},
	"fence": {"label": "Valla", "category": "construction", "cost": 2},
	"heal": {"label": "Curación", "category": "trick", "cost": 2}
}
const CATEGORIES := ["creature", "terrain", "construction", "trick"]
const CATEGORY_LABELS := ["Criatura", "Terreno", "Construcción", "Truco"]
const SPECIES_LABELS := {"pig": "Ce", "boar": "Ja", "horse": "Ca", "golem": "Go"}

static func target_mode(id: String) -> String:
	return "own_wounded_unit" if CARDS.get(id, {}).get("category") == "trick" else "own_cell"
