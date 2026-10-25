# Fase 20.1C — propuesta técnica

Estado: primera parte visual implementada en `codex/phase-20-1c-vertical-board`, pendiente de revisión e integración. Adaptador reversible, dibujo y selección 4×8 validados con pruebas headless en Godot 4.7.2; revisión visual y toque en Android pendientes. La Fase 20.1B está aprobada tras pruebas visuales; su simulación permanece intacta. No hay movimiento implementado: las recomendaciones de movimiento de este documento necesitan aprobación explícita de TARS y del propietario antes de implementarse.

## Decisiones aprobadas e invariantes

- Presentación vertical de 4 columnas por 8 filas, rival arriba y jugador local abajo. Mantener 32 espacios, 16 por jugador.
- Mantener por ahora la simulación 8×4, sus territorios definidos por `x`, Núcleos y coordenadas de unidades. La adaptación visual pertenece a presentación.
- Tiempo real simultáneo a 20 ticks/s; no introducir turnos. Conservar daño, armadura, alcance ortogonal, cooldowns, esencia y recuperación aprobados.
- Conservar Núcleos ocultos y la prohibición de retirar/intercambiar objetivos bajo ataque activo. No reinterpretar el movimiento como retirada ni equiparar automáticamente el cooldown con un ataque activo.
- La mesa 3D sigue siendo la dirección final; la vista 2D sirve para validar interacción.

## Transformación lógica y visual implementada en la rama de revisión

Usar un adaptador puro de presentación, con coordenadas lógicas `(x, y)` en `[0..7] × [0..3]` y visuales `(u, v)` en `[0..3] × [0..7]`. El origen visual está arriba a la izquierda; `v` crece hacia abajo.

| Perspectiva local | Lógica → visual | Visual → lógica | Territorio local en pantalla |
| --- | --- | --- | --- |
| Jugador 0 | `u = y`, `v = 7 - x` | `x = 7 - v`, `y = u` | `x = 0..3` pasa a `v = 4..7` |
| Jugador 1 | `u = 3 - y`, `v = x` | `x = v`, `y = 3 - u` | `x = 4..7` pasa a `v = 4..7` |

Es una rotación con inversa exacta: conserva vecindad ortogonal y distancias Manhattan. Ejemplo desde jugador 0: el jabalí lógico `(3, 1)` aparece en `(1, 4)` y la tortuga `(4, 1)` en `(1, 3)`, enfrentados en la frontera. La perspectiva de jugador 1 solo se prueba como transformación; la demo mantiene jugador local 0 y no añade un modo de juego ni PvP.

Flujo de entrada: posición del evento en viewport → transformación inversa del canvas → posición local → celda visual con geometría compartida → celda lógica → selección o intención de movimiento. Fuera del tablero devuelve un resultado inválido antes de convertir. Flujo de dibujo: estado lógico → celda visual → centro de miniatura, aro y barra de vida. No rotar ni escribir el estado de simulación.

Adaptar el cálculo del tablero al aspecto 4:8 y reservar márgenes para futuras pilas de cartas sin introducir esa interfaz ahora. Aplicar el mismo adaptador a territorios, criaturas, resaltados y destinos; no dibujar Núcleos rivales por disponer de sus coordenadas internas. El tamaño de ventana no debe cambiar la celda lógica elegida.

## Movimiento recomendado, pendiente de aprobación

Primer incremento propuesto: seleccionar una criatura propia y tocar una celda ortogonal vacía adyacente para solicitar un trayecto. Tocar otra criatura propia cambia la selección. Los enemigos no generan ataques manuales en esta fase. El comportamiento ante destinos inválidos —conservar selección y mostrar rechazo— necesita aprobación frente a la deselección actual al tocar vacío.

Proponer `queue_move(player, unit_id, destination)` como intención para el próximo tick, validada por la simulación: propietario, existencia, partida activa, límites, distancia, ocupación y reservas. La interfaz no escribe `cell`. Añadir consulta de validación para mostrar destinos sin duplicar reglas, y eventos de movimiento aceptado/rechazado que se consuman tras cada tick.

Recomendación de duración: trayecto no instantáneo medido en ticks enteros y parámetro configurable; valor y diferencias entre especies pendientes. Separar este tiempo de `ready_tick` para no cambiar cooldowns de ataque. Conservar la celda de origen como ocupada durante el tránsito y reservar el destino; cambiar la celda lógica únicamente al llegar. Interpolar visualmente desde el progreso autoritativo, sin usar el delta gráfico para resolver reglas.

Recomendación de conflictos: evaluar candidatos sobre la misma ocupación inicial del tick y rechazar todas las solicitudes que compitan por un destino libre; rechazar destinos ocupados, intercambios y cadenas de desplazamientos en este primer incremento. Normalizar duplicados por unidad; definir qué hacer con destinos distintos solicitados por la misma unidad. No basar el resultado entre jugadores en el orden de eventos de entrada.

Orden de tick propuesto para revisar antes de aprobar: regeneración/recuperación → invocaciones actuales → llegadas pendientes → validación y reservas de nuevos movimientos → evaluación de ataques → daño simultáneo → derrotas/liberación de reservas → final de partida. Definir expresamente si una llegada en ese tick cambia el alcance del ataque y si puede salir una unidad que recibe un ataque. La política afecta a mecánicas y no se implementará por iniciativa del agente.

## Decisiones de diseño pendientes

1. Alcance inicial: un paso ortogonal por orden frente a rutas continuas. Recomendación: un paso; sin pathfinding todavía.
2. Duración/velocidad, coste de esencia si existe y permiso para entrar en territorio rival. No inferir permiso de invasión a partir de las restricciones de invocación.
3. Política de reservas, conflictos, intercambios, cadenas y órdenes múltiples de una misma unidad. Cancelación, redirección y aceptación de otra orden durante el tránsito.
4. Posición válida para alcance durante el tránsito, ataques al moverse, orden llegada/ataque y muerte durante movimiento. Preservar daño simultáneo y liberación correcta de reservas.
5. Definición de ataque activo y relación entre movimiento y bloqueo bajo ataque. No usar todo el cooldown como bloqueo sin decisión explícita.
6. Entrada en la celda de un Núcleo, descubrimiento y autorización de ataques al Núcleo. El código actual permite atacarlo desde su propia celda sin comprobación de descubrimiento; incorporar movimiento volvería alcanzable ese camino. Resolver o delimitar este acceso antes de publicar movimiento jugable, sin revelar ubicaciones mediante resaltados o rechazos.
7. Gesto para mover, comportamiento ante toques inválidos y feedback; normalización de toque/ratón emulado para no duplicar futuras órdenes. La selección actual es idempotente, pero una orden de movimiento no debe depender de ello.

## Archivos previstos y límites

| Archivo | Cambio futuro propuesto |
| --- | --- |
| `scripts/board_coordinates.gd` (nuevo) | Adaptador puro lógica/visual e inversa, independiente de simulación. |
| `scripts/main.gd` | Dibujo 4×8, entrada reversible, selección, feedback e interpolación; envío de intenciones después de aprobar reglas. |
| `scripts/simulation.gd` | Solo tras aprobar movimiento: validación, comandos, duración en ticks, reservas, resolución y eventos. No cambiar constantes 8×4 para rotar la vista. |
| `tests/board_coordinates_smoke.gd` (nuevo) | Biyectividad, límites, vecindad y perspectiva local. |
| `tests/presentation_smoke.gd` | Actualizar expectativas visuales; preservar selección y vida. |
| `tests/movement_smoke.gd` (nuevo) | Reglas de movimiento acordadas y regresiones con combate. |
| `GEMINI.md`, `docs/ROADMAP.md`, este documento | Registrar decisiones aprobadas y evidencia real de validación. |

Revisar configuración vertical de ventana/orientación en `project.godot` dentro del incremento visual, sin afirmar que existe ya una exportación Android validada. No añadir dependencias, IA, ataques manuales, mazos ni modelos 3D en este alcance. Coordinar archivos con Gemini antes de implementar si tiene trabajo activo.

## Secuencia y pruebas previstas

1. Tras autorizar el incremento correspondiente, crear rama de funcionalidad desde `main`. Adaptar primero coordenadas y presentación 4×8, conservando simulación y combate; revisar visualmente en Godot 4.7.2 antes de añadir movimiento.
2. Probar ida y vuelta de las 32 celdas para ambas perspectivas, unicidad, límites, 16 espacios por mitad, conservación de vecindad y distancia; comprobar selección/vida tras redimensionar, escalado y fronteras.
3. Tras aprobar las decisiones de movimiento, implementar un incremento pequeño de simulación y entrada con duraciones en ticks. Probar unidad ajena/inexistente, destinos fuera de límites, ocupados/reservados, duplicados y conflictos invertidos en orden; no consumir recursos con rechazos.
4. Probar llegada exacta, muerte y reservas liberadas, reset/final de partida, movimiento y ataque simultáneos según la política aprobada, y reproducción del mismo registro con igual resultado. Mantener la suite de combate de la Fase 20.1A.
5. Validar en Godot 4.7.2 las suites de simulación y presentación y el arranque. Revisar visualmente tablero vertical, rival arriba, selección, vida e interpolación; probar toque real en Android como validación distinta de eventos sintéticos.

Publicar la rama validada para revisión según el alcance autorizado. La aprobación de la Fase 20.1B y la distribución 4×8 no aprueba por sí sola ninguna regla de movimiento de esta propuesta.
