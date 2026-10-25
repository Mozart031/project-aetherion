# Fase 20.1C — propuesta técnica

Estado: primera parte visual aprobada por el propietario e integrada en `main` desde `d529b93c5f2b4d910d3c11b2bb52fe9b888e6e78`. Adaptador reversible, dibujo y selección 4×8; pruebas de coordenadas, presentación, combate y arranque repetidas en Godot 4.7.2. UID locales conservados y versionados. Prueba táctil en Android pendiente. El primer movimiento funcional de codex/phase-20-1c-basic-movement fue revisado por TARS, aprobado visualmente por el propietario e integrado en main desde el commit 487a6b3be304b3d5c42408878b3561ee0b177e12. Se mantienen dimensiones lógicas y reglas de combate; se añade la protección de descubrimiento aprobada.

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

## Movimiento básico aprobado e integrado en main

Rama de origen: `codex/phase-20-1c-basic-movement`, creada desde `main` en `696a9d1`. Commit de funcionalidad `487a6b3be304b3d5c42408878b3561ee0b177e12`, revisado por TARS y aprobado visualmente por el propietario: selección y movimiento a celda vecina comprobados en Godot. Integración en `main` autorizada, sin conflictos ni cambios adicionales de jugabilidad.

### Contrato y separación de responsabilidades

- Seleccionar criatura propia y tocar celda ortogonal adyacente libre envía `queue_move(player, unit_id, destination)`. La interfaz consulta `can_move` para evitar órdenes evidentemente inválidas; la simulación vuelve a validar al resolver el tick.
- Trayecto inicial de 6 ticks, configurable mediante `move_duration_ticks` (mínimo efectivo 1). Aceptado en `t`, llega en `t + duración`; un cambio de configuración no altera trayectos ya iniciados.
- Origen ocupado y destino reservado hasta llegada o muerte. Se permite territorio rival, sin coste de esencia ni cambios del cooldown de ataque.
- `scripts/movement.gd` ejecuta intenciones y administra reservas bajo control de la simulación. No decide objetivos, comportamiento natural ni órdenes especiales. Un paso manual es solo una prueba técnica; el diseño final permitirá ordenar destinos y acciones sin dirigir cada paso.
- La presentación interpola origen/destino con progreso autoritativo en ticks más la fracción del acumulador del frame. Miniatura, aro y barra de vida comparten posición. No modifica `cell`.
- Seleccionar otra criatura propia cambia la selección; tocar un destino válido conserva la selección y envía la orden. Se conserva la deselección ante enemigo, fuera del tablero o destino inválido. Se ignora ratón emulado para que un toque no genere otra orden.

### Resolución determinista

Después de las invocaciones se captura ocupación y criaturas ya en tránsito, antes de daño y llegadas. Todos los candidatos del tick usan esa misma instantánea.

- Rechazar destinos ocupados/reservados, diagonales, saltos, intercambios y cadenas hacia orígenes aún ocupados. Un destino recién liberado por muerte o llegada queda utilizable en el tick siguiente para nuevas órdenes de movimiento.
- Agrupar órdenes por criatura. Duplicados idénticos forman una única intención; destinos contradictorios rechazan toda la intención de esa criatura. Órdenes ajenas o de criaturas inexistentes no alteran una orden legítima.
- Si varios candidatos válidos compiten por un destino libre, rechazar todos. Resolver criaturas por ID para eventos reproducibles; el orden de llegada de comandos no decide ganadores.
- No permitir redirección ni nuevas órdenes durante tránsito, incluido el tick de llegada. No guardar movimientos rechazados para ejecutarlos más tarde.
- Las invocaciones también respetan reservas y no descuentan esencia si el destino está reservado.

### Ataques, daño, muerte y fin

Se conserva el combate instantáneo existente: ataques evaluados sobre las celdas lógicas de origen, daño acumulado y aplicado simultáneamente, derrotas, llegadas de supervivientes, comprobación de final y aceptación de nuevos movimientos si la partida sigue activa. No hay cambios de daño, armadura, alcance ni intervalos de ataque.

Ambos bandos pueden atacar y recibir daño en tránsito con la celda lógica de origen hasta llegar. Una orden de movimiento no cancela daño aceptado, aunque llegue en ese mismo tick; un ataque letal elimina la unidad antes de confirmar llegada y libera su reserva. El daño no pausa el desplazamiento ni reinicia cooldowns. El movimiento es desplazamiento, no retirada/intercambio: no se añaden estas operaciones ni nuevas ventanas temporales de ataque activo.

Reinicio elimina unidades, órdenes, trayectos y reservas. Final de partida vacía trayectos y reservas y rechaza nuevos movimientos. Una llegada ya vencida se resuelve tras el daño antes de comprobar final, pero no se inicia otro trayecto al terminar.

### Núcleos ocultos: decisión adicional aprobada

El propietario eligió mantener oculto el Núcleo rival en el prototipo y probar el estado descubierto exclusivamente mediante fixtures. No se implementa un desencadenante de descubrimiento ni se revela al entrar en su celda. Por esta limitación aprobada, todavía no puede ganarse destruyendo un Núcleo rival no descubierto.

- `core_known_to` registra visibilidad por observador, con propietario visible y rival oculto al reiniciar. No se añade una acción pública para descubrirlo.
- Validación y reservas de movimiento no consultan la posición del Núcleo: atravesar su celda libre produce el mismo resultado que cualquier otra.
- Rechazar ataques a Núcleos no descubiertos antes de comprobar coordenadas, sin daño, consumo de cooldown ni eventos reveladores. Para descubierto se conservan condiciones, daño y cooldown existentes.
- `get_player_view(observer)` devuelve copias sin coordenadas del Núcleo rival oculto ni metadatos de visibilidad; la presentación obtiene sus unidades de esta vista. Es una separación de presentación en un prototipo local, no una garantía de seguridad multijugador.
- Tests comparan dos ubicaciones ocultas con consultas, movimiento y ataques iguales: el estado observable del rival debe ser idéntico. Los fixtures pueden marcar descubierto y comprobar el ataque existente; no son una mecánica de juego.

## Archivos del incremento

| Archivo | Responsabilidad |
| --- | --- |
| `scripts/movement.gd` y su UID | Ejecución determinista de trayectos y reservas, sin IA ni planificación. |
| `scripts/simulation.gd` | API de órdenes/consultas, ciclo de movimiento tras daño, ocupación de invocaciones, vista filtrada y protección de Núcleos. |
| `scripts/main.gd` | Entrada por clic/toque, envío de órdenes, selección e interpolación visual. |
| `tests/movement_smoke.gd` y su UID | Movimiento, conflictos, combate en tránsito, reservas, reinicio, fin y Núcleos ocultos. |
| `tests/movement_presentation_smoke.gd` y su UID | Entrada, ratón emulado, interpolación entre ticks, selección en tránsito y resize. |
| `GEMINI.md`, `docs/ROADMAP.md`, este documento | Reglas aprobadas, decisiones y validación real. |

El adaptador 4×8, las escenas y `project.godot` se conservan. Sin dependencias, nuevas criaturas, IA autónoma, rutas largas, habilidades, ataques manuales ni cambios visuales ajenos al movimiento. La demo mantiene combate automático y jugador local 0.

## Validación realizada en Godot 4.7.2

```text
godot --headless --path . --script res://tests/board_coordinates_smoke.gd
godot --headless --path . --script res://tests/presentation_smoke.gd
godot --headless --path . --script res://tests/simulation_smoke.gd
godot --headless --path . --script res://tests/movement_smoke.gd
godot --headless --path . --script res://tests/movement_presentation_smoke.gd
godot --headless --path . --quit-after 5
godot --headless --editor --path . --quit
```

Cinco suites aprobadas, arranque sin errores e importación del editor correcta con generación de UID. Cobertura nueva: límites/propiedad, entrada rival, duración configurable y llegada exacta, ocupación, reservas e invocaciones, conflictos invertidos, duplicados y contradicciones, daño al iniciar/en tránsito/al llegar, bajas mutuas, muerte y recuperación, liberación y reutilización de reservas, reinicio/final, vistas separadas, consultas independientes del Núcleo y ataque descubierto solo en fixtures. La presentación prueba ratón y toque, exclusión de emulación, progreso entre ticks, posición visual sin escritura lógica, selección e interpolación tras resize.

Cinco suites y arranque repetidos con éxito en Godot 4.7.2 antes de integrar; código idéntico al de la rama aprobada. Revisión de TARS y aprobación visual recibidas. Pendiente toque real en Android. El diseño de descubrimiento real y las futuras órdenes por destino/comportamientos requieren otro incremento aprobado. No implementar todavía IA autónoma, rutas largas ni habilidades especiales.
