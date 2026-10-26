# Fase 24 — batalla completa por dominio territorial

**Estado: documentación actualizada; sin implementación ni rama de Fase 24.** Base: Fase 23.1 integrada en `main` en `0795d76`, versión de funcionalidad `3fc4827` (`HEAD` documental `4795810`). Las decisiones de preparación privada, superficie y secciones territoriales, criaturas conquistadoras, defensas, victoria anticipada provisional, identidad visual, Sol, desastres e interacción remota indicadas abajo están acordadas como diseño. Los detalles pendientes y la arquitectura propuesta requieren revisión; este documento no autoriza programarlos.

## Objetivo y límites

Una batalla completa y dinámica contra un rival del juego, centrada en conquistar y conservar territorio. **El dominio territorial sustituye el enfoque de victoria por descubrir/destruir el Núcleo.** La barra representa control del tablero, no probabilidad de victoria. El papel futuro del Núcleo no se redefine aquí; sus datos/código y privacidad actuales permanecen como legado compatible, sin exigir nuevas mecánicas de descubrimiento para esta fase.

Se conservan 20 Hz, combate simultáneo, movimiento y reservas, esencia y costes de cartas existentes, auténtica única por especie/jugador, recuperación individual, cuatro pilas y prioridad de órdenes explícitas. Las reglas nuevas de conquista, resistencia, restauración y Sol no deben recibir valores de balance inventados más allá de los parámetros provisionales expresamente aprobados en este documento.

Las exclusiones anteriores de desastres, cartas nuevas e interfaz de resultado se sustituyen únicamente por el diseño ahora acordado: preparación simultánea privada de 30 segundos, desastres/última resistencia, Sol y tres trucos diferentes, barra/bordes/presión territorial y presentación final. No se inventan los trucos que faltan, el catálogo de especies conquistadoras ni las huellas definitivas de terrenos, ni se programa ninguno. Sin torres emergentes, Eco del Caos, nuevas criaturas, estadísticas definitivas, red, 3D o rediseño general. Ventana informativa provisional aceptada; giro integrado en carta reservado para una fase visual futura. Distinguir normales/clasificatorias o registrar la futura modalidad «sin preparación» no autoriza implementar PvP, red, matchmaking ni variantes adicionales.

## 1. Reglas aprobadas

### Preparación privada de partida y transición a la mesa

| Aspecto | Regla aprobada |
| --- | --- |
| Preparación simultánea | Ambos jugadores disponen de **30 segundos simultáneos de preparación** al inicio de la partida. No es una fase de turnos alternados. |
| Zona de preparación y privacidad | Cada jugador ve y organiza sus propios terrenos y construcciones en una zona de preparación situada visualmente en la parte superior de su pantalla. El adversario no puede conocer la distribución preparada durante esos 30 segundos. |
| Restricción de criaturas y victoria | Las criaturas se despliegan después de terminar la preparación. El contador de victoria anticipada tampoco se activa durante los 30 segundos de preparación. |
| Descenso y unión del tablero | Al finalizar el contador de preparación, ambos mapas descienden a la mesa de combate, se alinean y chocan para formar un único tablero. |
| Naturaleza del impacto | El impacto es una transición visual, no un desastre natural: no causa daño a terrenos o construcciones ni cambia el control territorial. |
| Inicio de la batalla activa | Después de la unión comienzan el despliegue de criaturas, los ataques y las conquistas. |
| Modalidad futura «sin preparación» | Queda registrada como posibilidad futura, sin implementarla ni diseñarla en detalle en esta fase. |

### Superficie, secciones y dominio territorial

| Aspecto | Regla aprobada |
| --- | --- |
| Superficie total e inicio | El tablero tiene **32 espacios territoriales equivalentes**, inicialmente **16 por jugador**. La barra compartida comienza en **50 % / 50 %** y cada espacio equivale a **3,125 puntos porcentuales** del dominio total. |
| Terrenos de distinto tamaño | Los jugadores pueden distribuir su superficie mediante terrenos de distintos tamaños. El dominio depende de la **superficie controlada**, no del número de cartas de terreno. |
| Conquista por secciones equivalentes | Los terrenos grandes se conquistan progresivamente **por secciones equivalentes**, no completos de una vez. Los terrenos pequeños de una sección pueden conquistarse completos. |
| Continuidad visual y control por sección | Un terreno grande continúa viéndose como una pieza natural continua; las secciones lógicas no obligan a mostrar una cuadrícula visual. La conquista cambia el controlador de la sección ocupada, no necesariamente el del terreno completo. |
| Separación de estados | Control territorial, autoría/propiedad de cartas y estado ecológico se mantienen separados. Dañar, destruir, devastar o consumir recursos son acciones distintas de conquistar: un terreno devastado o agotado conserva su controlador hasta una conquista rival válida. |
| Identidad visual y resultado | Amatista `#AA65F5` y oro arcano `#E5C65D`. Los terrenos mantienen sus colores naturales; bordes luminosos discretos indican su controlador (sin fijar aquí asignación de color a índice de jugador). Dominio elevado produce presión visual sutil sin bonificaciones de combate implícitas. Al resolverse la partida, la barra se desplaza al centro y presenta victoria o derrota. |

### Criaturas conquistadoras, ocupación y defensas

| Aspecto | Regla aprobada |
| --- | --- |
| Capacidad específica de conquista | **No todas las criaturas pueden conquistar.** Es una capacidad específica de determinadas criaturas. Una criatura habilitada puede recibir una orden de conquista y desplazarse al objetivo mediante los sistemas de órdenes compatibles. |
| Ocupación e interrupción | Pasar por un terreno no equivale a conquistarlo. La ocupación de una sección desprotegida requiere **3 segundos continuos** (**60 ticks a 20 Hz**). Si la ocupación se interrumpe, el intento pierde su progreso. |
| Persistencia del control | El control territorial persiste después de que la criatura conquistadora se retire de la sección. |
| Defensas activas y recursos protegidos | Tanto criaturas defensoras como construcciones defensivas pueden impedir una conquista. Una defensa activa debe neutralizarse o superarse antes de ocupar las secciones que protege. Una barrera defensiva activa también impide apropiarse de la utilidad de los recursos protegidos, como un maizal. |
| Transferencia por conquista válida | Una conquista válida puede transferir construcciones no defensivas y recursos utilizables al nuevo controlador, siempre que sigan operativos y no estén protegidos por defensas activas. |
| Simultaneidad a 20 Hz | Ambos jugadores pueden atacar, defender, restaurar, conquistar y usar cartas simultáneamente mientras continúan las demás acciones. No introducir turnos globales ni pausar el combate para ocupar. |

### Sol, desastres y última resistencia

| Aspecto | Regla aprobada |
| --- | --- |
| Carta Sol y tres trucos | Cada jugador equipa tres cartas de truco diferentes. Sol selecciona aleatoriamente una de las tres equipadas del rival, esté disponible, utilizada o en recuperación. Puede seleccionar una ya conocida: es una apuesta y no garantiza información nueva. Revela únicamente su identidad, sin revelar disponibilidad, desactivarla ni cambiar su estado. |
| Desastres por modo | En partidas normales pueden ocurrir desastres anticipados impredecibles, menores, de alcance limitado y menos impactantes que el desastre final; no activan automáticamente la última resistencia ni terminan la partida. En clasificatorias el desastre principal se reserva para la fase final. |
| Efectos del desastre y última resistencia | Un desastre puede dañar recursos, criaturas y defensas, pero **nunca cambia automáticamente el controlador territorial**. El desastre final abre una fase de última resistencia jugable con oportunidades de remontada; su activación no es por sí sola el final de partida. |

## 2. Valores provisionales de equilibrio (sujetos a pruebas de balance)

Los siguientes parámetros numéricos están aprobados como base provisional para la modalidad territorial y dejan de figurar como indefinidos:

| Parámetro | Valor aprobado (tiempo) | Equivalencia a 20 Hz | Condiciones operativas aprobadas |
| --- | --- | --- | --- |
| Preparación privada inicial | **30 segundos simultáneos** | **600 ticks** | Organización oculta de terrenos y construcciones propios en la zona superior; sin despliegue de criaturas ni activación del contador de victoria anticipada. |
| Superficie y peso territorial | **32 espacios equivalentes** (16 por jugador al inicio) | — | Inicio en **50 % / 50 %**; cada sección equivalente representa **3,125 puntos porcentuales** del dominio total. |
| Ocupación de sección desprotegida | **3 segundos continuos** | **60 ticks** | Solo por criaturas con capacidad de conquista sobre una sección sin defensa activa; cualquier interrupción reinicia el progreso a cero. |
| Victoria anticipada por dominio | **Al menos 90 % de dominio durante 15 segundos continuos** | **300 ticks** (≥ 29 de 32 secciones equivalentes) | Si el dominio baja del **90 %**, el contador se reinicia. No se activa durante los 30 segundos de preparación. No sustituye las reglas aún pendientes de duración máxima, última resistencia o desempate. |

## 3. Decisiones todavía pendientes (no tratarlas como reglas implementables)

- **Catálogo de terrenos y preparación:** catálogo definitivo de tamaños, huellas en secciones equivalentes y restricciones de distribución o colocación durante los 30 segundos de preparación.
- **Especies conquistadoras y estadísticas:** qué criaturas concretas del catálogo tendrán la capacidad de conquistar y sus estadísticas o condiciones específicas.
- **Alcance y reglas finas de defensas y ocupación:** radio o secciones exactas que protege cada criatura defensora o construcción defensiva, clasificación explícita de construcciones defensivas frente a no defensivas transferibles, qué eventos exactos cuentan como interrupción de los 60 ticks de ocupación (daño recibido, ataque en curso, entrada de defensor, desplazamiento) y cómo se resuelven intentos de ocupación simultáneos o disputados. Llegar o destruir una defensa sigue sin convertirse por defecto en captura automática sin completar la ocupación.
- **Condiciones simultáneas de victoria, duración máxima, última resistencia y empates:** qué sucede ante condiciones simultáneas de cierre; duración máxima de la partida y activación/duración de la última resistencia (los 12000 ticks actuales, los diez minutos y la meta histórica 5–8 minutos siguen descartados como valores ratificados); resolución de empates sin reutilizar la vida del Núcleo por inercia.
- **Regiones legales de despliegue posterior a la conquista:** si el cambio de controlador de una sección modifica o no las celdas legales para invocar criaturas o las restricciones territoriales de los instintos naturales (como el límite de mitad inicial en rutas ecológicas). No alterar `owns_cell` ni el comportamiento del caballo/cerdo sin aprobación.
- **Restauración:** qué terrenos o construcciones se restauran, quién puede hacerlo y sus requisitos, costes, tiempos y efectos. La ejecución simultánea está acordada, pero aún no existen parámetros para implementarla.
- **Sol y catálogo de trucos:** ubicación de Sol en el equipamiento (si ocupa uno de los tres huecos de truco o un acceso específico), coste de esencia, reutilización/cooldown, distribución exacta del azar, duración visual/lógica del conocimiento revelado y destinatarios de notificaciones. Faltan por diseñar los otros trucos hasta completar tres distintos por jugador; no rellenar con efectos inventados.
- **Calendario y parámetros de desastres:** tiempos/ventanas por modo, avisos previos, selección, áreas/efectos numéricos y diseño concreto de las oportunidades de remontada en última resistencia. Umbral numérico exacto para el efecto visual de presión por dominio elevado.

Estos puntos siguen siendo dependencias de diseño: una propuesta técnica no los convierte en aprobados.

## Decisión aprobada — interacción desde cualquier posición válida

El jugador puede emitir una orden de interacción compatible desde cualquier posición válida de su criatura. La simulación dirige el desplazamiento y ejecuta automáticamente la acción al llegar a la posición requerida, sin solicitar una segunda confirmación.

| Interacción existente | Posición de ejecución que se conserva |
| --- | --- |
| Entrar en una cueva | Llegar a la celda de cueva y completar la preparación de entrada existente. |
| Comer maíz con caballo compatible y herido | Llegar al maizal, completar la acción existente y consumir la ración. |
| Revolcarse con cerdo compatible y herido | Llegar al barro y ejecutar la acción existente. |
| Demoler una construcción rival con gólem | Aproximarse a una celda adyacente válida y ejecutar la demolición existente. No entrar en una construcción que bloquea movimiento. |
| Atacar criatura/construcción | Mantener aproximación y alcance adyacente de la orden dirigida existente. |

«Cualquier posición válida» elimina la exigencia de estar ya junto al recurso para emitir la orden; no elimina compatibilidad, heridas requeridas, propiedad o ausencia de barreras defensivas activas cuando corresponda, rutas, obstáculos, reservas, cooldowns, salida de refugio o reglas de combate. Esta tabla recoge únicamente las acciones ya implementadas. La orden de conquistar una sección territorial mediante navegación contextual (solo para criaturas con capacidad de conquista, desplazándose al objetivo y manteniendo 60 ticks continuos de ocupación si no está protegida por defensas activas) es una **funcionalidad prevista para la Fase 24, aún no implementada**; las nuevas acciones de conquista y restauración se diseñan e implementarán aparte cuando se autorice, sin deducir aquí habilidades de reparar o capturar construcciones por cuenta propia.

Una sola orden aceptada conserva el objetivo y la acción hasta ejecutarse, cancelarse/reemplazarse válidamente o perder su objetivo. La preparación no es una segunda confirmación. No se ejecuta automáticamente una habilidad distinta por llegar cerca de un objeto sin haber recibido esa orden.

## Base real que se reutiliza

- `queue_act_at`, `TacticalOrders` con `act_at`, `ContextActions.plan/start` y la interfaz «Ir y actuar» ya permiten varios desplazamientos con ejecución automática al llegar. `context_orders_smoke.gd` cubre maíz distante, demolición desde lejos, cueva y pérdida de recurso. No reiniciar esta implementación.
- Conservar ruta ortogonal y ocupación/reservas, preparación/cooldowns, daño simultáneo y estado `blocked`. Si no hay ruta, la orden explícita mantiene su prioridad y no provoca teletransporte; podrá avanzar al abrirse una ruta, o el jugador podrá cambiarla/detenerla, como ahora.
- Si el recurso o construcción desaparece, terminar con motivo comprensible sin reactivar órdenes antiguas; completar un paso ya comprometido y conservar daño aceptado. Si cambia la disponibilidad de la acción durante el trayecto (por ejemplo, si una barrera defensiva activa protege el recurso o la sección), revalidar con las reglas aprobadas. No crear costes o reintentos con beneficios gratuitos.
- El objetivo del primer bloque es consolidar acceso contextual y verificar casos límite, incluidos órdenes durante movimiento y refugio, ejecución una vez, espera de cooldown y cancelación. El gesto concreto de entrada debe aprovechar los controles actuales sin rediseño general ni añadir confirmación al llegar.

## Estado del resto de la partida

| Sistema | Base disponible y trabajo pendiente |
| --- | --- |
| Preparación inicial | Hoy `place_terrain` solo opera en `tick_count == 0` sobre el tablero ya unido. Falta la fase de 30 s (600 ticks) con preparación privada superior de terrenos y construcciones y transición visual de unión. |
| Economía/cartas | Esencia y costes actuales; cuatro pilas, rotación por aceptación, auténtica única y recuperación. Reutilizar sin cambios de balance. |
| Combate/ecología | Ataques dirigidos y simultáneos, acciones con preparación, perfiles naturales, mantener/ecología por instancia. La estrategia rival es una capa distinta. |
| Privacidad | 23.1 filtra estado/eventos por observador y publica propiedad de terrenos presentes en combate. Durante los 30 s de preparación deberá ocultar la distribución rival de terrenos y construcciones hasta la unión del tablero. |
| Rival actual | Invocación inicial y refuerzos/ruta prefijados, pagados. Falta un controlador de decisiones para preparación y batalla territorial. |
| Territorio | `terrain_owners` registra autoría/propiedad de cartas de terreno presentes y participa en disponibilidad/ecología. Falta el mapa persistente de 32 secciones equivalentes (16 iniciales por jugador, 3,125 % cada una). |
| Terrenos, secciones y defensas | Terrenos unitarios por celda con tipo; vallas con HP. Falta el modelo de terrenos de múltiples secciones equivalentes, bloqueo de conquista y de recursos por defensas activas, transferencia de construcciones no defensivas/recursos operativos y ocupación de 60 ticks por criaturas conquistadoras. |
| Trucos | Solo Curación en catálogo. Las pilas/equipamiento admiten más entradas, pero no hay Sol ni validación de exactamente tres trucos diferentes para la nueva modalidad. |
| Núcleo/final legado | Posición/HP y privacidad conservados. `_check_end` sigue terminando por HP de Núcleo o 12000 ticks: incompatible como política final de la modalidad territorial (que incorpora victoria anticipada con ≥ 90 % durante 300 ticks y deja pendientes duración máxima/última resistencia/empates). No está cambiado por esta documentación. |
| Desastres/presentación | No hay director de desastres, última resistencia jugable, animación de descenso/choque de mapas ni barra funcional de dominio/resultado; se planifican, no se declaran implementados. |

## Arquitectura propuesta

- **Coordinador de partida:** gestión de fases en el reloj único de 20 Hz: preparación simultánea privada (600 ticks, solo terrenos y construcciones propios en zona superior), transición visual de descenso/alineación/impacto sin daño ni cambio de control, batalla activa (despliegue de criaturas, ataques, conquistas y evaluación del contador de victoria anticipada de 300 ticks al ≥ 90 %), última resistencia cuando corresponda, resultado y reinicio. Se prevé punto de extensión para una futura modalidad «sin preparación» sin implementarla ahora.
- **Controlador rival determinista:** recibe una copia de `get_player_view(rival)` del último tick resuelto y devuelve intenciones (tanto en preparación privada como en batalla activa). Selecciona cartas equipadas/disponibles, posiciones y objetivos observables. La simulación revalida y cobra por las mismas vías que al humano.
- **Órdenes contextuales compartidas:** el humano y el rival utilizan `queue_act_at`, destinos y objetivos existentes; no escriben vida, posiciones, reservas o esencia. IDs de solicitudes por jugador, sin duplicar una jugada aceptada.
- **Control territorial persistente por secciones:** registro de las **32 secciones equivalentes** (16 iniciales por jugador, 50 % / 50 %, 3,125 puntos porcentuales por sección), separado de la criatura presente, del recurso consumible y de la carta que produjo el terreno (`terrain_owners` de autoría). Un terreno grande agrupa varias secciones lógicas manteniendo su representación visual continua; conquistar cambia el controlador de la sección ocupada y puede transferir construcciones no defensivas y recursos operativos que no estén protegidos por defensas activas. Dañar, devastar, consumir recursos o retirar criaturas no borra el controlador de la sección.
- **Conquista, ocupación y defensas:** validación de capacidad conquistadora en la criatura (`can_conquer` una vez se aprueben las especies), verificación de ausencia de defensas activas (criaturas defensoras o construcciones defensivas) que protejan la sección o el recurso (como un maizal), y contador de ocupación continua de **60 ticks (3 s)** con reinicio inmediato ante interrupción. Reutilizar rutas/reservas para desplazarse al objetivo sin convertir `move_arrived` en captura instantánea.
- **Dominio y victoria:** cálculo exacto sobre 32 secciones (`secciones_controladas * 3.125%`) y contador de victoria anticipada de **300 ticks (15 s)** continuos manteniendo **≥ 90 % de dominio** (al menos 29 de 32 secciones), inactivo durante los 600 ticks de preparación y con reinicio si baja del 90 %. El cierre por tiempo máximo, última resistencia y desempate se conectarán cuando se aprueben sus reglas, manteniendo intactas las demos previas.
- **Sol y conocimiento:** efecto específico de carta y conocimiento autorizado por observador. Seleccionar entre las tres identidades equipadas rivales sin filtrar por disponibilidad, uso, recuperación o conocimiento previo; admitir una revelación repetida sin forzar una identidad nueva. Entregar únicamente la identidad seleccionada, sin equipamiento completo, esencia o disponibilidad; no desactivar ni alterar la carta. Aleatoriedad con estado/semilla controlados por simulación para reproducir partidas; no exponer ese estado a la IA rival ni usar azar dependiente del frame.
- **Desastres deterministas:** calendario/selección autoritativos parametrizados por modo una vez definidos. Impredecibles para jugadores no significa no reproducibles: usar ticks y azar reproducible, no reloj de pared. Distinguir los anticipados normales, menores y limitados, del desastre final: los anticipados no provocan por sí mismos la transición a última resistencia ni el cierre. En clasificatorias reservar el principal para la fase final. Ningún evento de desastre escribe directamente el controlador territorial.
- **Escena de partida integrada:** zona superior de preparación privada con transición visual de descenso y choque al iniciar la batalla, tablero/pilas/feedback actuales, barra compartida amatista/oro arcano y bordes discretos sobre terrenos de colores naturales continuos (sin cuadrícula forzada en terrenos grandes). La simulación decide porcentajes y resultado; la UI solo anima la unión inicial, la presión y el desplazamiento final de barra.

Archivos existentes que habrá que evaluar en una futura implementación: `simulation.gd`, `battle_cards.gd`, `match_loadout.gd`, `battle_catalog.gd`, `terrain_effects.gd`, `tactical_orders.gd`, `context_actions.gd`, `natural_intents.gd`, `main.gd`, demos/composición/feedback, pruebas y documentación. Componentes propuestos: coordinador de fases (preparación/batalla/cierre), control por secciones y defensas territoriales, política de dominio/victoria anticipada, conocimiento de cartas, desastres y rival. Ninguno creado ahora. Extraer solo los puntos necesarios y mantener las regresiones de modos antiguos.

## Rival honesto y presión táctica

Propuesta: organizar su propia superficie durante los 30 segundos de preparación sin leer la preparación humana; tras la unión del tablero, elegir despliegues según esencia propia, rutas y situación pública; conservar territorio, defender zonas amenazadas y ordenar conquistas válidas con criaturas habilitadas o recuperación de posiciones. Utilizar curación, cuevas e interacciones compatibles respetando el bloqueo de recursos por barreras defensivas activas. No perseguir un Núcleo como objetivo de victoria ni conocer secretos del adversario. Sol solo permite reaccionar a lo efectivamente revelado, no leer todo el equipamiento. No obligar a todas las criaturas a avanzar ni sustituir sus instintos por una marcha permanente.

Mantener objetivos para evitar oscilaciones; reconsiderar ante muerte, bloqueo o desaparición de recurso. Cadencia en ticks y desempates deterministas, sin ventajas económicas ni cambios ocultos de estadísticas. No reaccionar a órdenes humanas aún sin resolver. La dificultad y agresividad se ajustarán por comportamiento tras revisión, sin inventar valores definitivos.

Añadir en la futura partida una opción que desactive exclusivamente los productores prefijados —cerdo inicial, valla/jabalí y flanco—, activa por defecto en demos anteriores. No apagar ecología/defensa para quitar esos guiones. Impedir que guion e IA manden simultáneamente sobre el mismo rival.

## Flujo propuesto de partida

Preparación simultánea privada (30 s / 600 ticks: colocación de terrenos y construcciones propios en la zona superior, oculta al rival; sin criaturas ni contador de victoria) → descenso, alineación y choque visual de ambos mapas para formar el tablero único de 32 espacios (50 % / 50 %, sin daño ni cambio de control) → batalla territorial continua (despliegue de criaturas, ataques, defensas, conquistas de 3 s / 60 ticks por sección desprotegida y posibles desastres anticipados menores en normales) → victoria anticipada si un jugador mantiene **≥ 90 % de dominio durante 15 s continuos (300 ticks)**, o transición a última resistencia jugable cuando corresponda según las reglas de tiempo aún pendientes → resolución con la política aprobada → presentación central de victoria/derrota y reinicio.

La activación del desastre final no decide el ganador ni cambia propietarios. Las oportunidades de remontada deben surgir del juego y del diseño de efectos aprobado, no de adjudicar territorio automáticamente. Duración máxima, última resistencia y empates necesitan definición antes de completar el cierre por tiempo.

## 4. Riesgos o incompatibilidades técnicas identificadas

| Código actual | Riesgo / incompatibilidad con las reglas aprobadas y adaptación propuesta |
| --- | --- |
| Inicio inmediato de batalla y `place_terrain` restringido a `tick_count == 0` | Actualmente la simulación arranca en combate directo, permite invocar criaturas desde el primer tick y publica terrenos y construcciones presentes en `get_player_view`. Para cumplir los **30 s (600 ticks) de preparación privada**, la simulación deberá separar el estado de preparación (permitiendo organizar terrenos y construcciones propios mientras oculta la disposición rival y rechaza despliegues de criaturas/conquistas) hasta el tick de unión del tablero, conservando la opción directa para demos legadas y la futura modalidad «sin preparación». |
| `_check_end`, `core_hp`, `MATCH_LIMIT_TICKS` | El cierre actual evalúa destrucción del Núcleo o empate/comparación de `core_hp` a los 12000 ticks. Es incompatible con la victoria anticipada aprobada (**≥ 90 % de dominio mantenido durante 300 ticks continuos** tras la preparación) y con la eliminación del Núcleo como condición de victoria. Se requiere una política de victoria por modalidad que evalúe el contador de 300 ticks y mantenga el legado en las escenas de Fases 20–23.1. |
| `terrain_owners` usado por `BattleCards.state` y búsqueda de maíz | Sobrescribir `terrain_owners` al conquistar una sección alteraría la disponibilidad de cartas de terreno equipadas del autor original. Debe separarse el **controlador territorial de cada una de las 32 secciones** de la **autoría/carta de origen** y de la **propiedad operativa de construcciones/recursos transferibles** tras una conquista válida. |
| Consumo de maíz elimina `terrain.cells[cell]`; vista publica propietarios solo de terrenos presentes | Vincular el dominio a `terrain.cells` haría perder porcentaje territorial al consumir un maizal o al existir espacios sin carta de terreno. El dominio debe calcularse siempre sobre las **32 secciones territoriales persistentes** (3,125 % por sección), con independencia de si contienen un terreno intacto, consumido o devastado. |
| Terrenos unitarios de 1 celda y cuadrícula 2D uniforme | `terrain.cells` indexa hoy celdas individuales `Vector2i` sin noción de terrenos grandes multisección ni continuidad visual. Habrá que modelar terrenos compuestos por múltiples secciones equivalentes donde el control cambie por sección individual (conquista progresiva) mientras la presentación dibuja la pieza natural continua sin imponer una cuadrícula visual interna. |
| Ausencia de capacidad conquistadora (`can_conquer`) y de progreso de ocupación (60 ticks) | Ninguna criatura en `BattleCatalog` distingue hoy si puede conquistar, ni existe una orden o temporizador de **60 ticks continuos** interrumpible. Deberá añadirse el atributo de capacidad cuando se aprueben las especies y el estado de ocupación por sección con reinicio ante interrupción. |
| Construcciones sin distinción defensiva/transferible ni protección de recursos | `cards.buildings` solo contempla hoy la valla (`wood_fence`) como obstáculo con HP, sin distinguir entre **construcciones defensivas** (que impiden conquistar las secciones protegidas y bloquean el uso rival de recursos protegidos como un maizal) y **construcciones no defensivas / recursos operativos** (que pueden transferirse al nuevo controlador tras una conquista válida). Tampoco `TerrainEffects` ni `NaturalIntents` verifican aún si un maizal está protegido por una barrera defensiva activa antes de permitir su consumo. |
| `owns_cell` fija regiones de invocación por mitad inicial | `owns_cell` valida despliegues según las 16 celdas iniciales de cada jugador. No debe sustituirse silenciosamente por el controlador conquistado sin una decisión explícita sobre si la conquista desplaza las zonas de invocación o los límites de búsqueda ecológica. |
| Catálogo con un solo truco y ejecución fija como curación | Todos los trucos se validan hoy como curación de unidad propia. Tres trucos diferentes y Sol requieren validación por efecto propio, excepción explícita de privacidad en `get_player_view`/eventos para revelar solo la identidad de una de las tres cartas de truco equipadas rivales, y semilla determinista en simulación. |

Estas son necesidades e incompatibilidades para la futura implementación, no autorización para modificar código durante esta actualización documental.

## Bloques funcionales propuestos y pruebas

Orden propuesto de bloques grandes; iniciar cada uno requiere autorización expresa y la definición previa de sus dependencias pendientes:

1. **Preparación privada, dominio por secciones e interacción jugable.** Tras definir el catálogo de tamaños/huellas de terrenos, las especies conquistadoras y el alcance exacto de las defensas: fase de preparación simultánea privada de 30 s (600 ticks) con unión del tablero, capa persistente de 32 secciones equivalentes (50 % / 50 % inicial, 3,125 % por sección), ocupación de 60 ticks continuos por criaturas habilitadas en secciones desprotegidas, bloqueo de conquista y de recursos (como maizal) por defensas activas, transferencia de construcciones no defensivas y recursos operativos al conquistar, contador de victoria anticipada (≥ 90 % durante 300 ticks continuos tras la preparación), órdenes desde lejos sin segunda confirmación y barra/bordes continuos. Pruebas: privacidad durante los 600 ticks de preparación; unión sin daño ni cambio de control; atravesar no captura; ocupación de 60 ticks y reinicio al interrumpirse; criaturas sin capacidad de conquista rechazadas; defensa activa impide ocupar y usar recursos protegidos; conquista válida transfiere recursos/construcciones no defensivas operativas; control persiste al marcharse; daño o consumo no conquista; victoria anticipada a los 300 ticks en ≥ 90 % y reinicio si baja del 90 %.
2. **Rival territorial y tres trucos/Sol.** Tras definir cartas faltantes y parámetros operativos pendientes de Sol: controlador sobre la vista de 23.1 (en preparación y en batalla) y economía real, equipamiento de tres IDs distintos, conocimiento limitado de la revelación y aleatoriedad reproducible. Pruebas: rival prepara sin leer disposición oculta humana; no duplica auténticas ni gasta de más; guion e IA excluyentes; tres trucos distintos; Sol selecciona cualquiera de los tres equipados (disponible, utilizado o recuperándose), admite repetir una identidad conocida y revela únicamente identidad sin exponer disponibilidad ni desactivar cartas.
3. **Desastres, última resistencia y cierre integrado.** Tras definir parámetros por modo, duración máxima, última resistencia y empates: daños a recursos/criaturas/defensas, restauración y conquista simultáneas según reglas acordadas, última resistencia jugable y resultado central. Pruebas: ningún desastre o devastación cambia control por sí solo; anticipados normales respetan escala menor sin activar última resistencia ni terminar la partida; clasificatorias reservan el principal para la fase final; destrucción de defensa habilita posterior ocupación pero no concede control instantáneo gratis; fin/empate/reinicio y ausencia de órdenes después del resultado.

En cada bloque mantener las **30 suites de referencia de 23.1** para los modos existentes y añadir pruebas de la modalidad territorial, sin reescribir expectativas antiguas para encubrir regresiones. Replays reproducibles a distintos FPS y partidas completas con victoria/derrota verificadas mediante las condiciones reales de dominio territorial aprobadas, no por HP del Núcleo ni alterando artificialmente el estado para forzar resultados. Validación en Godot 4.7.2, revisión de TARS y prueba personal de jugabilidad antes de integrar una futura rama; Android físico sigue siendo independiente. Nada de esto se ejecuta o implementa por esta actualización de documentación.

## Autorización

Están acordadas las reglas descritas en la sección 1 y los valores provisionales de equilibrio de la sección 2 (preparación simultánea privada de 30 s / 600 ticks, superficie de 32 espacios equivalentes con inicio 50 % / 50 % y 3,125 % por sección, conquista progresiva por secciones por criaturas habilitadas en 3 s / 60 ticks continuos, protección de secciones y recursos por defensas activas, transferencia de construcciones no defensivas y recursos operativos, victoria anticipada con ≥ 90 % durante 15 s / 300 ticks, interacción remota, identidad visual, Sol y diseño cualitativo de desastres/última resistencia). Los detalles enumerados en la sección 3 siguen pendientes de definición. Arquitectura y bloques son propuestas para revisión. **Solo documentación: no modificar código ni iniciar implementación hasta autorización posterior.**
