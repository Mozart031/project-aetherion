# Fase 24 — primera batalla completa contra un rival del juego

**Estado: planificación para revisión de TARS y aprobación del director creativo. Sin implementación ni rama de Fase 24.** Base: Fase 23.1 cerrada, revisada y validada, versión de funcionalidad `3fc4827`, integrada en main. Este documento distingue decisiones aprobadas de propuestas pendientes; no autoriza programarlas.

## Objetivo y límites

Una batalla completa y dinámica contra un rival que utilice los sistemas existentes: desplegar, defender, explorar, combatir, interactuar con el entorno y alcanzar un resultado real. Mantener simultaneidad a 20 Hz, tablero visual 4×8/lógica 8×4, una auténtica por especie/jugador, prioridad de órdenes explícitas y las reglas de combate/economía de 21–23.1.

Sin desastres, torres emergentes, Eco del Caos, nuevas criaturas/cartas, estadísticas definitivas, red, 3D o rediseño visual. Ventana informativa provisional aceptada; giro integrado en carta reservado para una fase visual futura.

## Decisión aprobada — interacción desde cualquier posición válida

El jugador puede emitir una orden de interacción compatible desde cualquier posición válida de su criatura. La simulación dirige el desplazamiento y ejecuta automáticamente la acción al llegar a la posición requerida, sin solicitar una segunda confirmación.

| Interacción existente | Posición de ejecución que se conserva |
| --- | --- |
| Entrar en una cueva | Llegar a la celda de cueva y completar la preparación de entrada existente. |
| Comer maíz con caballo compatible y herido | Llegar al maizal, completar la acción existente y consumir la ración. |
| Revolcarse con cerdo compatible y herido | Llegar al barro y ejecutar la acción existente. |
| Demoler una construcción rival con gólem | Aproximarse a una celda adyacente válida y ejecutar la demolición existente. No entrar en una construcción que bloquea movimiento. |
| Atacar criatura/construcción | Mantener aproximación y alcance adyacente de la orden dirigida existente. |

«Cualquier posición válida» elimina la exigencia de estar ya junto al recurso para emitir la orden; no elimina compatibilidad, heridas requeridas, propiedad cuando corresponda, rutas, obstáculos, reservas, cooldowns, salida de refugio o reglas de combate. No autoriza nuevas acciones sobre construcciones, como reparar o capturar.

Una sola orden aceptada conserva el objetivo y la acción hasta ejecutarse, cancelarse/reemplazarse válidamente o perder su objetivo. La preparación no es una segunda confirmación. No se ejecuta automáticamente una habilidad distinta por llegar cerca de un objeto sin haber recibido esa orden.

## Base real que se reutiliza

- `queue_act_at`, `TacticalOrders` con `act_at`, `ContextActions.plan/start` y la interfaz «Ir y actuar» ya permiten varios desplazamientos con ejecución automática al llegar. `context_orders_smoke.gd` cubre maíz distante, demolición desde lejos, cueva y pérdida de recurso. No reiniciar esta implementación.
- Conservar ruta ortogonal y ocupación/reservas, preparación/cooldowns, daño simultáneo y estado `blocked`. Si no hay ruta, la orden explícita mantiene su prioridad y no provoca teletransporte; podrá avanzar al abrirse una ruta, o el jugador podrá cambiarla/detenerla, como ahora.
- Si el recurso o construcción desaparece, terminar con motivo comprensible sin reactivar órdenes antiguas; completar un paso ya comprometido y conservar daño aceptado. Si cambia la disponibilidad de la acción durante el trayecto, revalidar con las reglas existentes. No crear costes o reintentos con beneficios gratuitos.
- El objetivo del primer bloque es consolidar acceso contextual y verificar casos límite, incluidos órdenes durante movimiento y refugio, ejecución una vez, espera de cooldown y cancelación. El gesto concreto de entrada debe aprovechar los controles actuales sin rediseño general ni añadir confirmación al llegar.

## Estado del resto de la partida

| Sistema | Base disponible y trabajo pendiente |
| --- | --- |
| Economía/cartas | Esencia y costes actuales; cuatro pilas, rotación por aceptación, auténtica única y recuperación. Reutilizar sin cambios de balance. |
| Combate/ecología | Ataques dirigidos y simultáneos, acciones con preparación, perfiles naturales, mantener/ecología por instancia. La estrategia rival es una capa distinta. |
| Privacidad | 23.1 filtra estado/eventos por observador y publica propiedad de terrenos presentes. IA solo recibe su vista; no estado crudo ni cola humana pendiente. |
| Rival actual | Invocación inicial y refuerzos/ruta prefijados, pagados. Falta un controlador de decisiones. |
| Núcleo | Posición/HP provisionales, colocación antes del primer tick, conocimiento por observador, rechazo del oculto y daño con cooldown desde su misma casilla. Descubrimiento real y orden jugable pendientes. |
| Final | Destrucción de Núcleo o 12000 ticks; comparación de HP y empate. Faltan presentación del resultado y desempates previstos por fuerza/control. «Escenario despejado» no es victoria. |

## Arquitectura propuesta

- **Coordinador de partida:** preparación, inicio, avance fijo, productores de órdenes, resultado y reinicio. Reutilizar un único reloj de 20 Hz, sin Timer independiente para IA.
- **Controlador rival determinista:** recibe una copia de `get_player_view(rival)` del último tick resuelto y devuelve intenciones. Selecciona cartas equipadas/disponibles, posiciones y objetivos observables. La simulación revalida y cobra por las mismas vías que al humano.
- **Órdenes contextuales compartidas:** el humano y el rival utilizan `queue_act_at`, destinos y objetivos existentes; no escriben vida, posiciones, reservas o esencia. IDs de solicitudes por jugador, sin duplicar una jugada aceptada.
- **Reglas de Núcleo bajo autoridad de simulación:** cambio acotado después de aprobar descubrimiento/ataque; consultas y rutas no pueden depender de coordenadas secretas.
- **Escena de partida integrada:** composición de tablero, pilas y feedback actuales. Solo controles funcionales necesarios de inicio/Núcleo/resultado, sin rediseño visual.

Archivos existentes previstos: `simulation.gd`, `tactical_orders.gd`, `context_actions.gd`, `main.gd`, `battle_demo.gd`, `battle_depth_demo.gd`, composición de `battle_stacks_demo.gd`, pruebas y documentación. Nuevos componentes propuestos: coordinador, controlador rival y escena de partida; no creados todavía. Extraer solo los puntos de configuración necesarios, sin reescribir sistemas completos.

## Rival honesto y presión táctica

Propuesta: elegir despliegues según espacio, esencia propia y situación visible; defender incursiones y su propio Núcleo conocido; disputar terreno y explorar sin conocer la ubicación del Núcleo humano. Usar curación, cuevas y acciones existentes con intención. No obligar a todas las criaturas a avanzar ni sustituir sus instintos por una marcha permanente.

Mantener objetivos para evitar oscilaciones; reconsiderar ante muerte, bloqueo o desaparición de recurso. Cadencia en ticks y desempates deterministas, sin ventajas económicas ni cambios ocultos de estadísticas. No reaccionar a órdenes humanas aún sin resolver. La dificultad y agresividad se ajustarán por comportamiento tras revisión, sin inventar valores definitivos.

Añadir en la futura partida una opción que desactive exclusivamente los productores prefijados —cerdo inicial, valla/jabalí y flanco—, activa por defecto en demos anteriores. No apagar ecología/defensa para quitar esos guiones. Impedir que guion e IA manden simultáneamente sobre el mismo rival.

## Propuesta de Núcleo y decisiones pendientes

Estas propuestas **no están aprobadas por la decisión de interacción remota**:

| Decisión | Propuesta conservadora para revisión |
| --- | --- |
| Descubrimiento | Contacto al completar una llegada viva a su casilla; nunca por consultas, resaltados o reservas. Alternativas requieren definir sus condiciones antes de implementar. |
| Persistencia del conocimiento | Mantenerlo conocido el resto de la partida, pendiente de aprobación. |
| Ataque | Mantener misma casilla, ataque base y cooldown actuales; decidir expresamente si embestida modifica daño al Núcleo. Descubrir no aplica daño gratis. |
| Colocación/capas | Acordar preparación y configuración inicial; confirmar superposición con terrenos/construcciones, sin bloqueos secretos. |
| Tiempo y desempate | Conservar provisionalmente HP de Núcleo y empate; no inventar fórmulas de fuerza/control. |
| Escenario/dificultad | Acordar distribución de terrenos, elección del Núcleo rival, agresividad y ritmo de decisiones. |

El objetivo de duración 5–8 minutos es una meta para probar, no una garantía con el balance actual. No introducir señales de mitad de partida, revelaciones forzadas o desastres para resolver atascos sin diseño aprobado.

## Bloques funcionales propuestos y pruebas

1. **Interacción contextual y base de partida.** Consolidar la orden única desde lejos hasta ejecutar acción existente, sin repetir trabajo de `act_at`; preparar separación de guion y futuro controlador. Pruebas de cuevas/maizales/construcciones desde distintas posiciones, obstáculos/rutas que se abren, reservas, muerte, desaparición de objetivo, espera de cooldown, preparación, cancelación y ejecución única sin segunda confirmación. Mantener prioridad sobre instintos y bloqueo de 23.1 solo cuando corresponda.
2. **Rival con economía real.** Desplegar, defender, disputar/explorar y usar acciones existentes. Pruebas de mismo presupuesto/auténtica única, propiedad, solicitudes duplicadas, objetivos derrotados y rutas bloqueadas; cambiar solo secretos rivales no altera decisiones antes de observación legítima. Probar ambas perspectivas, replays por tick a distintos FPS y ausencia de productores duplicados.
3. **Núcleos y batalla completa.** Solo tras aprobar sus decisiones: preparación, descubrimiento legítimo, orden de ataque, destrucción, victoria/derrota/empate y reinicio. Pruebas de muerte antes de llegada, daño simultáneo, cooldown, privacidad de eventos/consultas, timeout y prohibición de comandos al terminar. Escenarios completos con economía y daño reales, sin editar HP/esencia para forzar resultados.

En cada bloque conservar las **30 suites de referencia de 23.1**, añadir regresiones correspondientes y validar en Godot 4.7.2. La prueba de extremo a extremo debe demostrar finales por Núcleo en escenarios reproducibles, no únicamente timeout. Validación personal de jugabilidad y revisión de TARS antes de integrar una futura rama. Android físico sigue siendo una comprobación independiente.

## Autorización

Está aprobada la decisión de diseño de interacción remota con acción automática al llegar. El resto es un plan actualizado para revisión. **No se ha programado Fase 24; esperar autorización explícita de implementación y resolver las decisiones de Núcleo antes de modificarlas.**
