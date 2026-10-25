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

## Informational descriptions of implemented rules only; never read by combat.
const TACTICS := {
	"pig": {"brief": "Cura en barro", "role": "Criatura con recuperación contextual.", "ability": "Herido y sin orden activa busca barro cercano; puede revolcarse para curarse.", "advantage": "El barro le permite recuperar vida.", "disadvantage": "Curarse requiere barro, vida perdida y esperar su acción especial."},
	"boar": {"brief": "Prepara carga", "role": "Criatura de combate adyacente.", "ability": "Ante un rival cercano puede preparar embestida: refuerza el siguiente golpe.", "advantage": "La preparación aumenta el daño del siguiente ataque.", "disadvantage": "La preparación puede interrumpirse; no devuelve el cooldown gastado."},
	"horse": {"brief": "Come maíz", "role": "Criatura que se recupera mediante cultivos.", "ability": "Con dos o más puntos de vida perdidos y sin orden activa busca maizal propio o neutral cercano.", "advantage": "Comer maíz recupera vida.", "disadvantage": "Necesita maizal y vida perdida; consumirlo agota la ración."},
	"golem": {"brief": "Demuele vallas", "role": "Criatura con acción contra construcciones.", "ability": "Defiende adyacentes; sin amenaza inmediata puede demoler una valla rival adyacente.", "advantage": "Demolición añade daño contra la valla.", "disadvantage": "Demoler requiere preparación, alcance adyacente y poder atacar."},
	"cornfield": {"brief": "Una ración", "role": "Terreno de recuperación para el caballo.", "ability": "El caballo herido puede comer su ración.", "advantage": "Recupera vida; la carta vuelve disponible al consumirse.", "disadvantage": "Tiene una ración y desaparece al comerla."},
	"mud": {"brief": "Entrada lenta", "role": "Terreno de movimiento y recuperación.", "ability": "Retrasa la entrada; el cerdo herido puede revolcarse.", "advantage": "Permite recuperar vida al cerdo.", "disadvantage": "Entrar tarda más para todas las criaturas."},
	"cave": {"brief": "Refugio", "role": "Terreno de refugio.", "ability": "Entrada y salida con preparación; reduce daño recibido. Una orden permite salir.", "advantage": "Protege mientras la criatura está refugiada.", "disadvantage": "Dentro no puede atacar; no evita todo el daño."},
	"fence": {"brief": "Bloquea paso", "role": "Construcción que ocupa una celda.", "ability": "Bloquea movimiento y puede ser atacada.", "advantage": "Puede cerrar un paso del tablero.", "disadvantage": "Puede ser destruida; su carta entra en recuperación por combate."},
	"heal": {"brief": "Cura heridas", "role": "Truco de recuperación.", "ability": "Recupera vida de una criatura propia herida, hasta su máximo.", "advantage": "Reutilizable pagando esencia, sin recuperación artificial.", "disadvantage": "No se acepta sobre criaturas sanas o rivales."}
}

static func tactical_info(id: String) -> Dictionary:
	var result := {"brief": "", "role": "Pendiente de definición.", "ability": "Pendiente de definición.", "advantage": "Pendiente de definición.", "disadvantage": "Pendiente de definición."}
	result.merge(TACTICS.get(id, {}), true)
	return result
