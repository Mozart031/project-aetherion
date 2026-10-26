# Fase 24 — batalla completa por dominio territorial

**Estado: primera mitad lógica implementada por Argon, auditada independientemente y pendiente de autorización final de integración.** Rama `feature/phase24-argon-foundations`, base `main` `cd24af3`, versión de código `ad44d7dc912366588849ff2359cbd935e635708e`. Commits: `5e9b681` (estado territorial y huellas), `4a636c5` (preparación privada) y `ad44d7d` (conquista y defensas configurables). La auditoría independiente verificó 33/33 suites, importación y cuatro arranques headless en Godot 4.7.2. TARS revisó el informe y Dirección Técnica ratificó las dos políticas descritas abajo. Este cierre solo modifica documentación y conserva UID legítimos; **no autoriza el merge ni iniciar la segunda mitad**.

## Entrega real y límites de la primera mitad

- `TerritoryControl` mantiene 32 secciones persistentes, inicio 16/16 y 50 % / 50 %, con 3,125 puntos porcentuales por sección. Separa control territorial, autoría de cartas (`terrain_owners`) y ecología (`terrain.cells`).
- Las huellas contiguas de varias secciones son **metadatos territoriales**, con control progresivo por sección y división coherente al reemplazar secciones. **No son cartas multisección jugables:** las cartas y el terreno ecológico siguen operando por celda; catálogo, costes, colocación y representación de cartas grandes siguen pendientes.
- Preparación privada simultánea implementada **solo a nivel lógico**, activable con `enable_preparation()`: 600 ticks, terrenos/construcciones permitidos y criaturas, trucos y combate bloqueados. `get_player_view` oculta disposición rival y eventos privados de preparación. El tick 600 publica `board_joined` sin daño ni cambio de control; una criatura ordenada en tick 599 todavía se rechaza al ejecutar en 600, y una orden emitida en 600 se ejecuta en 601.
- No hay presentación visual jugable de preparación superior ni descenso/choque de mapas. Las demos existentes conservan preparación desactivada y rival prefijado; su arranque directo es compatibilidad del legado, no una nueva modalidad de partida «sin preparación». Antes de conectar la preparación a una escena, su dibujo debe consumir la vista filtrada, no las colecciones completas de terrenos/construcciones.
- `queue_conquer` reutiliza `act_at`, rutas, reservas y acciones temporizadas para llegar y ocupar durante 60 ticks continuos. Capacidad configurable por especie o unidad; **ninguna especie conquista por defecto**. Cobertura defensiva configurable por secciones, con liberación al morir su responsable y bloqueo del consumo de maíz protegido.
- **Ratificación de Dirección Técnica:** recibir daño efectivo interrumpe una conquista y pierde todo el progreso; un nuevo intento necesita 60 ticks completos. La política existente `interrupt_conquest_on_damage = true` queda ratificada, sin cambiar daño, cooldowns ni combate simultáneo.
- **Ratificación de Dirección Técnica:** las defensas territoriales bloquean conquista y consumo de recursos rivales expresamente protegidos, como el maíz. **No desactivan automáticamente las habilidades naturales de barro ni el acceso a cuevas.** Se conservan los requisitos normales de cada acción.
- Todavía no hay victoria territorial funcional, barra de dominio jugable, transferencia operativa de construcciones/recursos, IA estratégica, Sol/tres trucos ni desastres/última resistencia. `_check_end` conserva el final legado por Núcleo/12000 ticks y su privacidad, no una política final aprobada para dominio. Android físico y validación visual de la futura escena territorial siguen pendientes.

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
| Ocupación e interrupción | Pasar por un terreno no equivale a conquistarlo. La ocupación de una sección desprotegida requiere **3 segundos continuos** (**60 ticks a 20 Hz**). Si la ocupación se interrumpe, el intento pierde su progreso. **Recibir daño efectivo interrumpe y reinicia los 60 ticks**, política ratificada por Dirección Técnica tras la auditoría. |
| Persistencia del control | El control territorial persiste después de que la criatura conquistadora se retire de la sección. |
| Defensas activas y recursos protegidos | Tanto criaturas defensoras como construcciones defensivas pueden impedir una conquista. Una defensa activa debe neutralizarse o superarse antes de conquistar las secciones que protege. Bloquea también el consumo de recursos rivales expresamente protegidos, como el maíz; **no desactiva automáticamente habilidades naturales de barro ni el acceso a cuevas**, conforme a la ratificación de Dirección Técnica. |
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
- **Alcance y reglas finas de defensas y ocupación:** radio o secciones definitivas que protege cada criatura defensora o construcción defensiva, clasificación de construcciones defensivas frente a no defensivas transferibles y reglas adicionales de disputa/ocupación aún no aprobadas. La base actual usa cobertura explícita configurable y cancela al perder validez, recibir daño efectivo o una orden incompatible, morir o activarse una defensa sobre la sección. El daño efectivo y la excepción de barro/cuevas ya están ratificados; no vuelven a figurar como pendientes. Llegar o destruir una defensa no concede captura automática sin completar la ocupación.
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

«Cualquier posición válida» elimina la exigencia de estar ya junto al recurso para emitir la orden; no elimina compatibilidad, heridas requeridas, propiedad, protección expresa de maíz, rutas, obstáculos, reservas, cooldowns, salida de refugio o reglas de combate. Barro y acceso a cuevas no se desactivan automáticamente por defensas territoriales. Esta tabla recoge las interacciones existentes. La primera mitad de Fase 24 añade la orden `act_at` de conquista para criaturas habilitadas por configuración, con navegación y 60 ticks continuos de ocupación desprotegida. No habilita especies por defecto ni implementa restauración o transferencia de construcciones.

Una sola orden aceptada conserva el objetivo y la acción hasta ejecutarse, cancelarse/reemplazarse válidamente o perder su objetivo. La preparación no es una segunda confirmación. No se ejecuta automáticamente una habilidad distinta por llegar cerca de un objeto sin haber recibido esa orden.

## Base real que se reutiliza

- `queue_act_at`, `TacticalOrders` con `act_at`, `ContextActions.plan/start` y la interfaz «Ir y actuar» ya permiten varios desplazamientos con ejecución automática al llegar. `context_orders_smoke.gd` cubre maíz distante, demolición desde lejos, cueva y pérdida de recurso. No reiniciar esta implementación.
- Conservar ruta ortogonal y ocupación/reservas, preparación/cooldowns, daño simultáneo y estado `blocked`. Si no hay ruta, la orden explícita mantiene su prioridad y no provoca teletransporte; podrá avanzar al abrirse una ruta, o el jugador podrá cambiarla/detenerla, como ahora.
- Si el recurso o construcción desaparece, terminar con motivo comprensible sin reactivar órdenes antiguas; completar un paso ya comprometido y conservar daño aceptado. Si cambia la disponibilidad de la acción durante el trayecto (por ejemplo, si una barrera defensiva activa protege el recurso o la sección), revalidar con las reglas aprobadas. No crear costes o reintentos con beneficios gratuitos.
- El objetivo del primer bloque es consolidar acceso contextual y verificar casos límite, incluidos órdenes durante movimiento y refugio, ejecución una vez, espera de cooldown y cancelación. El gesto concreto de entrada debe aprovechar los controles actuales sin rediseño general ni añadir confirmación al llegar.

## Estado del resto de la partida

| Sistema | Base disponible y trabajo pendiente |
| --- | --- |
| Preparación inicial | Fase lógica de 600 ticks disponible mediante `enable_preparation`; cartas de terreno/construcción operan durante ella. `place_terrain` conserva su función de fixture inicial. Falta presentación superior privada y transición visual de unión; demos legadas desactivan preparación. |
| Economía/cartas | Esencia y costes actuales; cuatro pilas, rotación por aceptación, auténtica única y recuperación. Reutilizar sin cambios de balance. |
| Combate/ecología | Ataques dirigidos y simultáneos, acciones con preparación, perfiles naturales, mantener/ecología por instancia. La estrategia rival es una capa distinta. |
| Privacidad | Vista/eventos filtrados por observador; preparación oculta terrenos, construcciones y huellas rivales hasta tick 600, con IDs aislados por jugador/bucket. Falta conectar una presentación que respete esa proyección; el dibujo de demos legadas lee colecciones completas. |
| Rival actual | Invocación inicial y refuerzos/ruta prefijados, pagados. Falta un controlador de decisiones para preparación y batalla territorial. |
| Territorio | `TerritoryControl` implementa el mapa persistente de 32 secciones, separado de `terrain_owners` y de `terrain.cells`; consumo, muerte y destrucción no eliminan dominio. |
| Terrenos, secciones y defensas | Huellas multisección solo como metadatos, cartas jugables por celda. Conquista de 60 ticks por capacidad configurable y cobertura defensiva explícita implementadas; maíz protegido bloqueado, barro/cuevas conservados. Faltan catálogo conquistador definitivo, cartas multisección jugables y transferencia operativa de construcciones/recursos. |
| Trucos | Solo Curación en catálogo. Las pilas/equipamiento admiten más entradas, pero no hay Sol ni validación de exactamente tres trucos diferentes para la nueva modalidad. |
| Núcleo/final legado | Posición/HP y privacidad conservados. `_check_end` sigue terminando por HP de Núcleo o 12000 ticks: incompatible como política final de la modalidad territorial (que incorpora victoria anticipada con ≥ 90 % durante 300 ticks y deja pendientes duración máxima/última resistencia/empates). No está cambiado por esta documentación. |
| Desastres/presentación | No hay director de desastres, última resistencia jugable, animación de descenso/choque de mapas ni barra funcional de dominio/resultado; se planifican, no se declaran implementados. |

## Arquitectura propuesta

La base de preparación, territorio y conquista ya existe en `simulation.gd`, `territory_control.gd`, `context_actions.gd` y `tactical_orders.gd`. Los puntos siguientes describen el destino completo de la fase; no declaran implementadas las extensiones visuales, de victoria, rival, transferencia, Sol o desastres.

- **Coordinador de partida:** gestión de fases en el reloj único de 20 Hz: preparación simultánea privada (600 ticks, solo terrenos y construcciones propios en zona superior), transición visual de descenso/alineación/impacto sin daño ni cambio de control, batalla activa (despliegue de criaturas, ataques, conquistas y evaluación del contador de victoria anticipada de 300 ticks al ≥ 90 %), última resistencia cuando corresponda, resultado y reinicio. Se prevé punto de extensión para una futura modalidad «sin preparación» sin implementarla ahora.
- **Controlador rival determinista:** recibe una copia de `get_player_view(rival)` del último tick resuelto y devuelve intenciones (tanto en preparación privada como en batalla activa). Selecciona cartas equipadas/disponibles, posiciones y objetivos observables. La simulación revalida y cobra por las mismas vías que al humano.
- **Órdenes contextuales compartidas:** el humano y el rival utilizan `queue_act_at`, destinos y objetivos existentes; no escriben vida, posiciones, reservas o esencia. IDs de solicitudes por jugador, sin duplicar una jugada aceptada.
- **Control territorial persistente por secciones:** registro de las **32 secciones equivalentes** (16 iniciales por jugador, 50 % / 50 %, 3,125 puntos porcentuales por sección), separado de la criatura presente, del recurso consumible y de la carta que produjo el terreno (`terrain_owners` de autoría). Un terreno grande agrupa varias secciones lógicas manteniendo su representación visual continua; conquistar cambia el controlador de la sección ocupada y puede transferir construcciones no defensivas y recursos operativos que no estén protegidos por defensas activas. Dañar, devastar, consumir recursos o retirar criaturas no borra el controlador de la sección.
- **Conquista, ocupación y defensas:** validación de capacidad conquistadora en la criatura (`can_conquer` una vez se aprueben las especies), verificación de ausencia de defensas activas (criaturas defensoras o construcciones defensivas) que protejan la sección o el recurso (como un maizal), y contador de ocupación continua de **60 ticks (3 s)** con reinicio inmediato ante interrupción. Reutilizar rutas/reservas para desplazarse al objetivo sin convertir `move_arrived` en captura instantánea.
- **Dominio y victoria:** cálculo exacto sobre 32 secciones (`secciones_controladas * 3.125%`) y contador de victoria anticipada de **300 ticks (15 s)** continuos manteniendo **≥ 90 % de dominio** (al menos 29 de 32 secciones), inactivo durante los 600 ticks de preparación y con reinicio si baja del 90 %. El cierre por tiempo máximo, última resistencia y desempate se conectarán cuando se aprueben sus reglas, manteniendo intactas las demos previas.
- **Sol y conocimiento:** efecto específico de carta y conocimiento autorizado por observador. Seleccionar entre las tres identidades equipadas rivales sin filtrar por disponibilidad, uso, recuperación o conocimiento previo; admitir una revelación repetida sin forzar una identidad nueva. Entregar únicamente la identidad seleccionada, sin equipamiento completo, esencia o disponibilidad; no desactivar ni alterar la carta. Aleatoriedad con estado/semilla controlados por simulación para reproducir partidas; no exponer ese estado a la IA rival ni usar azar dependiente del frame.
- **Desastres deterministas:** calendario/selección autoritativos parametrizados por modo una vez definidos. Impredecibles para jugadores no significa no reproducibles: usar ticks y azar reproducible, no reloj de pared. Distinguir los anticipados normales, menores y limitados, del desastre final: los anticipados no provocan por sí mismos la transición a última resistencia ni el cierre. En clasificatorias reservar el principal para la fase final. Ningún evento de desastre escribe directamente el controlador territorial.
- **Escena de partida integrada:** zona superior de preparación privada con transición visual de descenso y choque al iniciar la batalla, tablero/pilas/feedback actuales, barra compartida amatista/oro arcano y bordes discretos sobre terrenos de colores naturales continuos (sin cuadrícula forzada en terrenos grandes). La simulación decide porcentajes y resultado; la UI solo anima la unión inicial, la presión y el desplazamiento final de barra.

Archivos a evaluar para continuar: `simulation.gd`, `territory_control.gd`, `battle_cards.gd`, `match_loadout.gd`, `battle_catalog.gd`, `terrain_effects.gd`, `tactical_orders.gd`, `context_actions.gd`, `natural_intents.gd`, `main.gd`, demos/composición/feedback, pruebas y documentación. Reutilizar las bases de fases, control territorial y defensas ya implementadas. Siguen propuestos el cierre territorial, conocimiento de cartas, desastres y rival; no se crean en este cierre documental. Extraer solo los puntos necesarios y mantener las regresiones de modos antiguos.

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
| Preparación lógica disponible; demos en combate directo | `enable_preparation` implementa los 600 ticks y filtra disposición/eventos rivales hasta la unión lógica. Las demos permanecen como legado y su dibujo lee colecciones completas: no basta con activar el indicador para obtener privacidad visual. Falta una presentación que consuma la vista filtrada y anime la preparación superior/descenso/choque, sin daño ni cambio de control. |
| `_check_end`, `core_hp`, `MATCH_LIMIT_TICKS` | El cierre actual evalúa destrucción del Núcleo o empate/comparación de `core_hp` a los 12000 ticks. Es incompatible con la victoria anticipada aprobada (**≥ 90 % de dominio mantenido durante 300 ticks continuos** tras la preparación) y con la eliminación del Núcleo como condición de victoria. Se requiere una política de victoria por modalidad que evalúe el contador de 300 ticks y mantenga el legado en las escenas de Fases 20–23.1. |
| `terrain_owners` usado por `BattleCards.state` y búsqueda de maíz | Sobrescribir `terrain_owners` al conquistar una sección alteraría la disponibilidad de cartas de terreno equipadas del autor original. Debe separarse el **controlador territorial de cada una de las 32 secciones** de la **autoría/carta de origen** y de la **propiedad operativa de construcciones/recursos transferibles** tras una conquista válida. |
| Consumo de maíz elimina `terrain.cells[cell]` | Resuelto para el dominio: `TerritoryControl` conserva las 32 secciones y sus controladores independientemente del consumo, movimiento o destrucción. Mantener esta separación al añadir transferencia operativa y devastación. |
| Huellas territoriales frente a cartas jugables | Existe geometría contigua multisección y conquista progresiva de sus secciones; `terrain.cells` y cartas siguen siendo unitarios por celda. No presentar esos metadatos como cartas grandes jugables ni fijar catálogo, costes o representación continua todavía. |
| Capacidad conquistadora configurable y ocupación | Ya existen `can_unit_conquer`, `queue_conquer`/`act_at`, temporizador interrumpible de 60 ticks y reinicio por daño efectivo. Ninguna especie está habilitada por defecto; faltan asignación definitiva y balance, no el mecanismo lógico. |
| Defensas configurables frente a catálogo y transferencia operativa | Cobertura explícita por defensor/sección y bloqueo de conquista/maíz protegidos implementados, incluida revalidación de consumo. Barro y cuevas no se bloquean automáticamente. Siguen pendientes radios y clasificación definitiva de defensas, construcciones no defensivas transferibles y propiedad operativa separada de autoría. |
| `owns_cell` fija regiones de invocación por mitad inicial | `owns_cell` valida despliegues según las 16 celdas iniciales de cada jugador. No debe sustituirse silenciosamente por el controlador conquistado sin una decisión explícita sobre si la conquista desplaza las zonas de invocación o los límites de búsqueda ecológica. |
| Catálogo con un solo truco y ejecución fija como curación | Todos los trucos se validan hoy como curación de unidad propia. Tres trucos diferentes y Sol requieren validación por efecto propio, excepción explícita de privacidad en `get_player_view`/eventos para revelar solo la identidad de una de las tres cartas de truco equipadas rivales, y semilla determinista en simulación. |

Estas son las necesidades restantes y los límites reales de los cimientos auditados; no autorizan modificar código durante este cierre documental.

## Bloques funcionales propuestos y pruebas

El primer bloque está parcialmente implementado a nivel lógico en los tres commits de Argon: estado territorial, preparación privada y conquista/defensas configurables. No reiniciarlo. El resto de este plan sigue como propuesta; continuar requiere autorización expresa y resolver sus dependencias pendientes:

1. **Preparación privada, dominio por secciones e interacción jugable.** Tras definir el catálogo de tamaños/huellas de terrenos, las especies conquistadoras y el alcance exacto de las defensas: fase de preparación simultánea privada de 30 s (600 ticks) con unión del tablero, capa persistente de 32 secciones equivalentes (50 % / 50 % inicial, 3,125 % por sección), ocupación de 60 ticks continuos por criaturas habilitadas en secciones desprotegidas, bloqueo de conquista y de recursos (como maizal) por defensas activas, transferencia de construcciones no defensivas y recursos operativos al conquistar, contador de victoria anticipada (≥ 90 % durante 300 ticks continuos tras la preparación), órdenes desde lejos sin segunda confirmación y barra/bordes continuos. Pruebas: privacidad durante los 600 ticks de preparación; unión sin daño ni cambio de control; atravesar no captura; ocupación de 60 ticks y reinicio al interrumpirse; criaturas sin capacidad de conquista rechazadas; defensa activa impide ocupar y usar recursos protegidos; conquista válida transfiere recursos/construcciones no defensivas operativas; control persiste al marcharse; daño o consumo no conquista; victoria anticipada a los 300 ticks en ≥ 90 % y reinicio si baja del 90 %.
2. **Rival territorial y tres trucos/Sol.** Tras definir cartas faltantes y parámetros operativos pendientes de Sol: controlador sobre la vista de 23.1 (en preparación y en batalla) y economía real, equipamiento de tres IDs distintos, conocimiento limitado de la revelación y aleatoriedad reproducible. Pruebas: rival prepara sin leer disposición oculta humana; no duplica auténticas ni gasta de más; guion e IA excluyentes; tres trucos distintos; Sol selecciona cualquiera de los tres equipados (disponible, utilizado o recuperándose), admite repetir una identidad conocida y revela únicamente identidad sin exponer disponibilidad ni desactivar cartas.
3. **Desastres, última resistencia y cierre integrado.** Tras definir parámetros por modo, duración máxima, última resistencia y empates: daños a recursos/criaturas/defensas, restauración y conquista simultáneas según reglas acordadas, última resistencia jugable y resultado central. Pruebas: ningún desastre o devastación cambia control por sí solo; anticipados normales respetan escala menor sin activar última resistencia ni terminar la partida; clasificatorias reservan el principal para la fase final; destrucción de defensa habilita posterior ocupación pero no concede control instantáneo gratis; fin/empate/reinicio y ausencia de órdenes después del resultado.

Referencia actual: **33 suites**, las 30 de 23.1 intactas y tres nuevas (`phase24_territory_state`, `phase24_preparation`, `phase24_conquest_foundations`). Cubren territorio persistente/huellas, privacidad y transición en tick 600, navegación/ocupación/interrupciones/defensas y replays a distintos FPS. La auditoría independiente verificó además las fronteras 598–600, importación y cuatro arranques headless. **Cierre documental del 26 de octubre de 2026: 33/33 suites repetidas con éxito en Godot 4.7.2 y `git diff --check` sin errores.** Los dos UID generados corresponden a scripts de prueba versionados y legítimos, tienen identificadores distintos sin duplicados en el proyecto y se conservan. No se cambian scripts, escenas ni expectativas de pruebas.

Para los bloques restantes añadir pruebas sin debilitar las regresiones existentes. Las partidas completas con victoria/derrota por dominio y la validación visual de preparación aún no existen; deberán verificarse con las condiciones reales aprobadas, no forzando HP del Núcleo. Android físico sigue siendo una validación independiente pendiente.

## Autorización

Están acordadas las reglas de la sección 1 y los valores provisionales de la sección 2. Tras la auditoría, Dirección Técnica ratifica que el daño efectivo reinicia la conquista y que las defensas bloquean conquista/consumo de recursos expresamente protegidos, sin desactivar automáticamente barro ni cuevas. La primera mitad lógica está implementada en la rama de Argon; las huellas son metadatos y la preparación carece de presentación visual jugable. Los detalles restantes de la sección 3 y los bloques no completados siguen pendientes. **Autorizado únicamente este cierre documental y la conservación de UID legítimos. No hacer merge ni iniciar la segunda mitad hasta recibir autorización final.**
