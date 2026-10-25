# Fase 20.1C — propuesta técnica

Estado: primera parte visual aprobada por el propietario e integrada en `main` desde `d529b93c5f2b4d910d3c11b2bb52fe9b888e6e78`. Adaptador reversible, dibujo y selección 4×8; pruebas de coordenadas, presentación, combate y arranque repetidas en Godot 4.7.2. UID locales conservados y versionados. Prueba táctil en Android pendiente. La simulación permanece intacta. Los parámetros iniciales de movimiento indicados abajo están aprobados, pero no existe implementación ni autorización para empezarla todavía. Las políticas marcadas como propuestas requieren aprobación.

## Decisiones aprobadas e invariantes

- Presentación vertical de 4 columnas por 8 filas, rival arriba y jugador local abajo. Mantener 32 espacios, 16 por jugador.
- Mantener por ahora la simulación 8×4, sus territorios definidos por `x`, Núcleos y coordenadas de unidades. La adaptación visual pertenece a presentación.
- Tiempo real simultáneo a 20 ticks/s; no introducir turnos. Conservar daño, armadura, alcance ortogonal, cooldowns, esencia y recuperación aprobados.
- Conservar Núcleos ocultos y la prohibición de retirar/intercambiar objetivos bajo ataque activo. No reinterpretar el movimiento como retirada ni equiparar automáticamente el cooldown con un ataque activo.
- La mesa 3D sigue siendo la dirección final; la vista 2D sirve para validar interacción.

## Transformación lógica y visual integrada en main

Usar un adaptador puro de presentación, con coordenadas lógicas `(x, y)` en `[0..7] × [0..3]` y visuales `(u, v)` en `[0..3] × [0..7]`. El origen visual está arriba a la izquierda; `v` crece hacia abajo.

| Perspectiva local | Lógica → visual | Visual → lógica | Territorio local en pantalla |
| --- | --- | --- | --- |
| Jugador 0 | `u = y`, `v = 7 - x` | `x = 7 - v`, `y = u` | `x = 0..3` pasa a `v = 4..7` |
| Jugador 1 | `u = 3 - y`, `v = x` | `x = v`, `y = 3 - u` | `x = 4..7` pasa a `v = 4..7` |

Es una rotación con inversa exacta: conserva vecindad ortogonal y distancias Manhattan. Ejemplo desde jugador 0: el jabalí lógico `(3, 1)` aparece en `(1, 4)` y la tortuga `(4, 1)` en `(1, 3)`, enfrentados en la frontera. La perspectiva de jugador 1 solo se prueba como transformación; la demo mantiene jugador local 0 y no añade un modo de juego ni PvP.

Flujo de entrada: posición del evento en viewport → transformación inversa del canvas → posición local → celda visual con geometría compartida → celda lógica → selección o intención de movimiento. Fuera del tablero devuelve un resultado inválido antes de convertir. Flujo de dibujo: estado lógico → celda visual → centro de miniatura, aro y barra de vida. No rotar ni escribir el estado de simulación.

Adaptar el cálculo del tablero al aspecto 4:8 y reservar márgenes para futuras pilas de cartas sin introducir esa interfaz ahora. Aplicar el mismo adaptador a territorios, criaturas, resaltados y destinos; no dibujar Núcleos rivales por disponer de sus coordenadas internas. El tamaño de ventana no debe cambiar la celda lógica elegida.

## Movimiento: parámetros aprobados y propuestas pendientes

Parámetros aprobados: un paso ortogonal por orden técnica, **6 ticks por paso** (0,3 segundos a 20 Hz), origen ocupado y destino reservado durante tránsito, sin coste de esencia y con entrada al territorio rival. Rechazar conflictos de forma determinista y mantener el movimiento independiente del cooldown de ataque. Nunca cancelar daño ya aceptado ni filtrar Núcleos ocultos en consultas, resaltados o ataques.

El movimiento manual de una casilla es exclusivamente una prueba técnica. El diseño final permitirá ordenar destinos sin controlar cada paso. Separar ejecución de trayectos, futuros comportamientos naturales y órdenes especiales: no añadir IA autónoma, rutas largas ni habilidades ahora. Los parámetros aprobados no autorizan aún implementar movimiento.

Primer incremento propuesto: seleccionar una criatura propia y tocar una celda ortogonal vacía adyacente para solicitar un trayecto. Tocar otra criatura propia cambia la selección. Los enemigos no generan ataques manuales en esta fase. El comportamiento ante destinos inválidos —conservar selección y mostrar rechazo— necesita aprobación frente a la deselección actual al tocar vacío.

Proponer `queue_move(player, unit_id, destination)` como intención para el próximo tick, validada por la simulación: propietario, existencia, partida activa, límites, distancia, ocupación y reservas. La interfaz no escribe `cell`. Añadir consulta de validación para mostrar destinos sin duplicar reglas, y eventos de movimiento aceptado/rechazado que se consuman tras cada tick.

Duración inicial aprobada: 6 ticks para todas las criaturas de la prueba técnica, sin introducir diferencias de especie. Propuesta de convención temporal para aprobar: si comienza en el tick `t`, registrar llegada en `t + 6`. Separar este tiempo de `ready_tick` para no cambiar cooldowns de ataque. El origen permanece ocupado y el destino reservado; se propone cambiar `cell` únicamente al llegar e interpolar visualmente desde el progreso autoritativo, sin usar el delta gráfico para resolver reglas.

Recomendación de conflictos: evaluar candidatos sobre la misma ocupación inicial del tick y rechazar todas las solicitudes que compitan por un destino libre; rechazar destinos ocupados, intercambios y cadenas de desplazamientos en este primer incremento. Normalizar duplicados por unidad; definir qué hacer con destinos distintos solicitados por la misma unidad. No basar el resultado entre jugadores en el orden de eventos de entrada.

### Propuesta concreta pendiente: ataques activos y tránsito

El combate actual aplica daño instantáneo en el mismo tick; no representa una ventana de ataque activo más larga. Se propone para este prototipo que un ataque esté activo desde su aceptación hasta aplicar su daño en ese tick, y que desplazarse no equivalga a retirar/intercambiar una carta. Esto es una interpretación nueva que necesita aprobación; no altera la prohibición de retirar/intercambiar un objetivo bajo ataque.

Orden propuesto: regeneración/recuperación → invocaciones actuales → evaluar ataques sobre celdas lógicas existentes → aplicar todo el daño simultáneo → derrotas y liberación de reservas → confirmar llegadas de supervivientes → resolver nuevas intenciones de movimiento → final de partida. Un ataque aceptado conserva atacante, objetivo por ID y daño aunque exista una orden de movimiento. Una derrota impide completar la llegada; el cooldown aceptado no se reinicia ni se alarga por moverse.

Durante tránsito, se propone que ambos bandos puedan atacar y recibir ataques usando la celda lógica de origen hasta la llegada. La llegada no evita un golpe aceptado ese tick y el daño se aplica antes de desplazar la celda. El trayecto sigue siendo de 6 ticks, sin pausas por cooldown. Si TARS considera que caminar debe quedar prohibido por el bloqueo bajo ataque, hace falta acordar una política distinta antes de implementar; no convertir silenciosamente ese bloqueo en 6 ticks ni en todo el cooldown.

### Propuesta concreta pendiente: Núcleos ocultos

El código actual permite `core_attack` desde la celda del Núcleo sin comprobar descubrimiento. Con entrada al territorio rival, esa vía debe protegerse antes de habilitar movimiento jugable.

Se propone registrar visibilidad del Núcleo por jugador, inicialmente no descubierto para el rival. Validación, consultas, reservas y resaltados de movimiento no dependerían de la presencia de un Núcleo oculto: entrar en su celda sería igual que entrar en otra celda libre y no lo descubriría automáticamente. No devolver coordenadas ocultas, indicadores especiales ni motivos de rechazo que permitan inferir su ubicación.

Se propone rechazar uniformemente todo ataque a un Núcleo no descubierto, antes de comprobar coincidencia con su celda, sin daño, cooldown ni evento revelador. La presentación usaría una vista filtrada sin coordenadas rivales no descubiertas. Pruebas diferenciales deben verificar que, al cambiar solo la ubicación oculta, se mantienen respuestas, resaltados y estado observable para el rival.

El evento legítimo que revela un Núcleo sigue sin definirse. Propuesta de alcance inicial para aprobar: no implementar descubrimiento automático; probar Núcleos descubiertos solo mediante fixtures de tests y conservar ocultos los rivales en el prototipo normal. Esto impediría por ahora ganar por destrucción de un Núcleo rival oculto y requiere aprobación explícita de esa limitación, o definir previamente la regla de descubrimiento real. No inventar exploración, habilidades ni señales de descubrimiento.

## Decisiones de diseño pendientes

1. Los parámetros iniciales ya están aprobados: paso ortogonal de 6 ticks, origen ocupado/destino reservado, sin esencia y con territorio rival permitido. Aprobar la convención exacta de inicio/llegada; no introducir balance por especie.
2. Mantener explícita la separación entre la prueba técnica de una casilla y las futuras órdenes por destino, comportamiento natural y órdenes especiales.
3. Política de reservas, conflictos, intercambios, cadenas y órdenes múltiples de una misma unidad. Cancelación, redirección y aceptación de otra orden durante el tránsito.
4. Aprobar o corregir la política concreta de origen durante tránsito, ataques antes de llegadas y muerte durante movimiento descrita arriba. Daño aceptado no cancelable ya es obligatorio.
5. Definición de ataque activo y relación entre movimiento y bloqueo bajo ataque. No usar todo el cooldown como bloqueo sin decisión explícita.
6. Entrada en la celda de un Núcleo, descubrimiento y autorización de ataques al Núcleo. El código actual permite atacarlo desde su propia celda sin comprobación de descubrimiento; incorporar movimiento volvería alcanzable ese camino. Resolver o delimitar este acceso antes de publicar movimiento jugable, sin revelar ubicaciones mediante resaltados o rechazos.
7. Gesto para mover, comportamiento ante toques inválidos y feedback; normalización de toque/ratón emulado para no duplicar futuras órdenes. La selección actual es idempotente, pero una orden de movimiento no debe depender de ello.

## Archivos previstos y límites

| Archivo | Cambio futuro propuesto |
| --- | --- |
| `scripts/board_coordinates.gd` (existente) | Reutilizar adaptador puro lógica/visual e inversa, ya integrado; no rehacer la rotación. |
| `scripts/main.gd` | Conservar dibujo 4×8 y entrada reversible; añadir feedback, interpolación y envío de intenciones solo tras aprobar reglas e implementación. |
| `scripts/simulation.gd` | Solo tras aprobar movimiento: validación, comandos, duración en ticks, reservas, resolución y eventos. No cambiar constantes 8×4 para rotar la vista. |
| `tests/board_coordinates_smoke.gd` (existente) | Conservar regresiones de biyectividad, límites, vecindad y perspectiva local. |
| `tests/presentation_smoke.gd` | Actualizar expectativas visuales; preservar selección y vida. |
| `tests/movement_smoke.gd` (nuevo) | Reglas de movimiento acordadas y regresiones con combate. |
| `GEMINI.md`, `docs/ROADMAP.md`, este documento | Registrar decisiones aprobadas y evidencia real de validación. |

Revisar configuración vertical de ventana/orientación en `project.godot` dentro del incremento visual, sin afirmar que existe ya una exportación Android validada. No añadir dependencias, IA, ataques manuales, mazos ni modelos 3D en este alcance. Coordinar archivos con Gemini antes de implementar si tiene trabajo activo.

## Secuencia y pruebas previstas

1. Adaptación 4×8 aprobada, validada e integrada. Tras autorizar el incremento de movimiento, crear otra rama de funcionalidad desde `main`; no repetir la fase visual.
2. Conservar pruebas de las 32 celdas para ambas perspectivas, unicidad, límites, 16 espacios por mitad, conservación de vecindad y distancia; mantener selección/vida tras redimensionar, escalado y fronteras.
3. Tras aprobar las decisiones de movimiento, implementar un incremento pequeño de simulación y entrada con duraciones en ticks. Probar unidad ajena/inexistente, destinos fuera de límites, ocupados/reservados, duplicados y conflictos invertidos en orden; no consumir recursos con rechazos.
4. Probar llegada exacta, muerte y reservas liberadas, reset/final de partida, movimiento y ataque simultáneos según la política aprobada, y reproducción del mismo registro con igual resultado. Mantener la suite de combate de la Fase 20.1A.
5. Validar en Godot 4.7.2 las suites de simulación y presentación y el arranque. Revisar visualmente tablero vertical, rival arriba, selección, vida e interpolación; probar toque real en Android como validación distinta de eventos sintéticos.

Publicar la futura rama de movimiento validada para revisión únicamente tras autorizar su implementación y acordar las políticas pendientes. La integración visual y los parámetros iniciales aprobados no autorizan implementar todavía movimiento, descubrimiento ni nuevas reglas de ataques activos.
