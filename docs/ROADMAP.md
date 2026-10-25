# Hoja de ruta — Project Aetherion / Isla del Caos

Documento de continuidad y avance. Las reglas aprobadas se mantienen en [GEMINI.md](../GEMINI.md). Esta hoja de ruta registra únicamente el alcance comunicado; no asigna fases ni fechas a objetivos todavía sin concretar.

## Hitos y estado

**Fase 23 cerrada e integrada en main:** revisión favorable de TARS y funcionamiento actual de la demo aceptado por el director creativo, con autorización expresa de integración. Origen `codex/phase-23-circular-card-stacks`, versión aprobada `9796ddb`, base `597757d`. Ramas sincronizadas antes de integrar; historial preservado, sin conflictos ni código adicional. Las 27 suites volvieron a pasar en Godot 4.7.2 antes de fusionar; importación y cuatro arranques sobre la integración aprobados. Código, escenas y pruebas idénticos a la versión revisada; este cierre añade solo documentación.

**Corrección de auténtica única verificada por TARS e integrada:** una por especie/jugador; actividad/recuperación impiden reinvocar sin gastar. La carta permanece equipada y muestra Disponible/Desplegada/Recuperando. Informe histórico de 25 suites en [PHASE_23_UNIQUE_SPECIES_REVIEW.md](PHASE_23_UNIQUE_SPECIES_REVIEW.md). Eco del Caos sigue solo como concepto futuro.

**Decisión posterior a la prueba jugable del director creativo, aceptada e integrada:** avance automático solo al aceptar una jugada, una vez por `request_id` correlacionado. Cancelación/rechazo/duplicados no avanzan; cursores independientes y longitud uno conservados. Izquierda abre reverso informativo y derecha vuelve al frente; datos verificados o pendientes explícitos, sin órdenes, gasto o pausa. [Informe de interacción](PHASE_23_INTERACTION_REVIEW.md). La ventana actual queda aceptada; pendiente para una futura fase visual un reverso integrado en la carta con animación de giro. No se implementa en este cierre.

**Registro final de integración de Fase 22:** `597757d025b21b83860aec014a016502c28d87f4`, publicado en main tras autorización oficial del director creativo. Merge con historial preservado y sin conflictos; 19 suites y arranques de ambas demos repetidos con éxito, sin código de jugabilidad adicional.

**Entrega de Fase 23 integrada:** bloques desde ese main en `codex/phase-23-circular-card-stacks`. A: `858a792`, equipamiento/tipos/transacciones; B: `080fd3f`, gestos y demo; auténtica única: `14193bb`; rotación y reverso: `9796ddb`. Todos revisados y aceptados; 27 suites y cuatro arranques en Godot 4.7.2. Abrir `scenes/battle_stacks_demo.tscn` con F6. Android físico pendiente. Estado en [PHASE_23.md](PHASE_23.md). **Fase 24 no iniciada; alcance por planificar por separado.**

| Hito | Alcance | Estado y evidencia |
| --- | --- | --- |
| Fase 20: base de simulación | Tablero 8×4, simulación a 20 Hz, invocación, esencia, combate, recuperación y final provisional. | Base implementada en `cfe2cdd849028c395eb093bd801e5a1cafc106b7`. Limitaciones en [PHASE_20.md](PHASE_20.md). |
| Fase 20.1A: regresiones de combate | Corregir HP esperado del jabalí; probar ataques y derrotas simultáneas, cooldowns y comandos duplicados. | Completada y publicada en `main` en `5319303d62698a48f1471b69c2b2eb91775ad5b2`, incluyendo `GEMINI.md`. Pruebas headless aprobadas en Godot 4.7.2. |
| Sincronización documental | Incorporar la metodología de colaboración y esta hoja de ruta; confirmar Git y conservar el trabajo existente. | Documentación actualizada; base local y remota confirmada en `5319303` y suite aprobada en Godot 4.7.2. El commit y la confirmación de publicación se comunican al entregar; no se incluye código de la Fase 20.1B. |
| Fase 20.1B: selección y vida | Selección de criaturas propias por clic/toque, resaltado, barras de vida, limpieza tras derrota y coordenadas adaptadas a la ventana. | Aprobada por el propietario tras pruebas visuales en Godot. Integración en `main` de `3b2455b8b5f64eadb3e7a0085cd6b9205b8bfa0f`; pruebas de presentación, combate y arranque repetidas en Godot 4.7.2. Simulación intacta. |
| Fase 20.1C, primera parte: adaptación vertical | Conversión visual 4×8 y entrada reversible, conservando lógica 8×4 y combate. | Aprobada por el propietario e integrada en `main` desde `d529b93c5f2b4d910d3c11b2bb52fe9b888e6e78`. Alcance revisado; pruebas de coordenadas, presentación, combate y arranque repetidas en Godot 4.7.2. UID conservados y versionados. |
| Fase 20.1C, movimiento interactivo | Prueba técnica de un paso ortogonal de 6 ticks, origen ocupado/destino reservado, sin esencia, territorio rival permitido y cooldown de ataque independiente. | Revisada por TARS y aprobada visualmente por el propietario en Godot: selección y desplazamiento a celda vecina confirmados. Integrada en `main` desde `487a6b3be304b3d5c42408878b3561ee0b177e12`, sin conflictos. Cinco suites y arranque repetidos con éxito en Godot 4.7.2. Núcleo rival oculto en el prototipo; descubierto solo en fixtures. |

## Distribución visual aprobada

**Registro de integración Fase 21:** `765bc8a72a8d82dbe93f1a4633c13afc24b047ff`, tras aprobación de TARS y validación visual del propietario. Doce suites y arranque aprobados en Godot 4.7.2; integración sin conflictos y sin cambios adicionales de jugabilidad.

**Fase 22 — Dinamismo y profundidad de batalla:** ambos bloques aprobados por TARS y Dirección Creativa e implementados en `codex/phase-22-battle-depth`, base `main` `1c740d6`. [Reglas, arquitectura, pruebas y límites](PHASE_22.md). Perfiles situacionales de cuatro especies, recursos disputados, mantener posición, ecología por instancia, ir y actuar y presentación por eventos. Dieciocho suites aprobadas en Godot 4.7.2; renderizado vertical revisado por el implementador. **Integrada en main desde `fe82be9` tras revisión de TARS y autorización oficial del director creativo. Merge sin conflictos, historial preservado; 19 suites y ambas demos aprobadas nuevamente en Godot 4.7.2.**

**Revisión final de Fase 22:** [informe](PHASE_22_FINAL_REVIEW.md) sobre implementación `2cda472`. Prueba manual positiva comunicada por Dirección Creativa, expresamente parcial. **19/19 suites**, dos arranques e importación aprobados en Godot 4.7.2. Añadida prueba de controles por copia, prioridad de ataque manual, recuperación exacta, persecución/curación del cerdo y resultado/acumulador real. Sin cambios de jugabilidad. Límites: resultado por vida de Núcleos, sin desempate por fuerza/control, Núcleo aún oculto y pérdida de tiempo de pared ante bloqueos largos. TARS reconoce las 19 pruebas y las limitaciones; revisión técnica favorable. Rama sincronizada y main es ancestro directo, sin divergencia: preparada para integración. Autorización oficial recibida e integración realizada sin cambios adicionales de jugabilidad; limitaciones conservadas.

**Fase 23 — Pilas circulares de cartas:** [implementación y pruebas](PHASE_23.md) **integrada en main tras revisión de TARS y aprobación del director creativo**. Cuatro pilas independientes, una auténtica por especie/jugador; abajo recorre, arriba/arrastre o selección/toque coloca, izquierda/derecha consulta reverso/frente. Aceptar avanza solo esa pila una vez; rechazo/cancelación no. Validación pura y pago tras confirmación válida; 27 suites y cuatro demos aprobadas. Pendientes Android real y futuro reverso integrado con giro; sin 3D ni estadísticas definitivas.

**Fase 21 — Primera batalla jugable:** aprobada por TARS y validada visualmente por el propietario; integrada en `main` desde `2607c60587e7f8f46499539bed22d926158fd6ee`, rama `codex/phase-21-first-playable-battle` (base `ab75787`). [Estado y reglas](PHASE_21.md): escena integrada con cuatro categorías de cartas, despliegue, cuatro criaturas, terrenos, acciones temporizadas, refugio, valla y curación. La regla anterior de múltiples copias fue sustituida en la corrección de Fase 23 por una auténtica por especie/jugador; se mantiene la recuperación tras derrota; intercambios/consumo de terreno sin recuperación artificial; refugio real y salida explícita. Doce suites y una batalla completa con economía real pasan en Godot 4.7.2; captura renderizada revisada por el implementador. Doce suites y arranque repetidos con éxito en Godot 4.7.2 antes de integrar. Sin conflictos ni cambios de jugabilidad adicionales; código integrado idéntico al de la rama aprobada. Pendiente prueba táctil Android.

Fase 20.2 verificada visualmente por el propietario e integrada en `main` desde `e4aa4198c1497b8e1f051cab840a343cd97b37e7`: ver [combate táctico](PHASE_20_2.md). Entrega A registrada en `dcd7c52`: navegación ortogonal a destinos, persecución, ataques dirigidos y bloqueos/interrupciones, con siete suites y arranque aprobados antes de B. Entrega B implementada después: defensa adyacente sin interrumpir órdenes y barro de entrada ×2, con reglas provisionales confirmadas por el propietario y configuración separada. Ocho suites y arranque pasan en Godot 4.7.2. Demo táctica como escena de F5. Integración sin conflictos ni cambios adicionales de jugabilidad, tras repetir ocho suites y arranque en Godot 4.7.2. Prueba táctil Android pendiente. Núcleo rival sigue oculto, sin mecánica de descubrimiento.

Isla del Caos utiliza **4 columnas × 8 filas** en `main`, con el rival en las cuatro filas superiores y el jugador local en las cuatro inferiores: 32 espacios y 16 por jugador. Se conservan las dimensiones lógicas 8×4; el adaptador reversible se aplica al dibujo, selección y posiciones de barras. La demo mantiene jugador local 0; ambas perspectivas del adaptador se prueban sin añadir PvP. El movimiento básico aprobado también está integrado en `main`.

### Validación de la adaptación vertical

```text
godot --headless --path . --script res://tests/board_coordinates_smoke.gd
godot --headless --path . --script res://tests/presentation_smoke.gd
godot --headless --path . --script res://tests/simulation_smoke.gd
godot --headless --path . --quit-after 5
```

Las cuatro comprobaciones pasan en Godot 4.7.2 y se repiten para la integración. Se cubren las 32 celdas en ambas perspectivas, inversas, unicidad, límites, 16 espacios por mitad y distancias de todos los pares; además, selección y entrada tras redimensionar, aspecto 4:8, rival arriba/local abajo, esquinas, exclusión de bordes, transformación del canvas, vida y limpieza tras derrota. La versión visual fue aprobada por el propietario; la prueba táctil en Android sigue pendiente. La simulación, sus pruebas y las escenas no se modifican. La ventana se puede redimensionar; este incremento no modifica la configuración de exportación u orientación Android.

## Movimiento básico integrado

Parámetros aprobados e integrados en `main`: un paso ortogonal de 6 ticks configurables, origen ocupado, destino reservado, sin coste de esencia, entrada al territorio rival, rechazo determinista de conflictos e independencia del cooldown de ataque. El daño ya aceptado no se cancela al moverse. Consultas y vistas de presentación no filtran ubicaciones de Núcleos ocultos; atacarlos no consume cooldown ni genera eventos reveladores.

La orden manual de una casilla es solo una prueba técnica. El diseño final permitirá ordenar destinos sin controlar cada paso; ejecución de movimiento, comportamiento natural y órdenes especiales se mantienen separados. No hay IA autónoma, rutas largas ni habilidades implementadas. El propietario aprobó conservar oculto el Núcleo rival en este prototipo y probar descubierto solo mediante fixtures. Esto impide por ahora ganar destruyendo un Núcleo rival aún oculto; el descubrimiento real sigue pendiente de diseño.

### Validación de movimiento en Godot 4.7.2

```text
godot --headless --path . --script res://tests/movement_smoke.gd
godot --headless --path . --script res://tests/movement_presentation_smoke.gd
```

Ambas suites nuevas pasan, además de las tres suites existentes de coordenadas, presentación y combate; las cinco y el arranque headless se repitieron con éxito antes de la integración aprobada. La importación del editor ya fue validada al publicar la rama. Se prueban ocupación, reservas, conflictos en órdenes invertidos, duplicados, órdenes contradictorias, daño en tránsito y al llegar, muerte y bajas mutuas, recuperación, reutilización de destinos, reinicio, fin de partida, diferencias de ubicación del Núcleo oculto, protección de vistas y ataque descubierto mediante fixture. La prueba de presentación cubre clic/toque, ratón emulado, interpolación entre ticks, selección en tránsito y resize. Revisión de TARS y aprobación visual del propietario recibidas; toque real en Android pendiente. Código integrado idéntico al de la rama aprobada; solo se actualiza documentación en esta integración.

## Objetivos posteriores ya registrados

Movimiento validado en la simulación, ataques iniciados por el jugador y retroalimentación de daño, derrota y recuperación forman parte de la meta de prototipo interactivo de `GEMINI.md`. Su desglose, orden y reglas pendientes deben acordarse antes de implementarlos; no forman parte de la Fase 20.1B.

La dirección artística aprobada es una mesa física 3D con criaturas, terrenos y construcciones invocados como hologramas mágicos a todo color, ligera transparencia y estilo cartoon fantástico. Las invocaciones emergen desde el suelo. Fase 22 prepara eventos y presentación 2D, conserva la demo anterior en F5 y añade `scenes/battle_depth_demo.tscn` para F6. Nombres/avatares superiores, barra de dominio PvP y cuatro categorías con pilas inferiores quedan documentados para el futuro; sin PvP real ni 3D definitivo.

## Método de entrega y coordinación

1. Leer `GEMINI.md`, verificar el estado local y remoto y delimitar el incremento sin repetir trabajo terminado.
2. Codex implementa; ChatGPT Work apoya tareas extensas; Gemini revisa independientemente cuando corresponda; TARS supervisa arquitectura y reglas. Coordinar archivos antes de editar cuando Gemini esté trabajando; evitar ediciones simultáneas sobre los mismos archivos.
3. Mantener `main` estable. Usar ramas de funcionalidad `codex/` para cambios importantes e integrar solo trabajo aprobado y validado.
4. Hacer incrementos pequeños, con pruebas automatizadas y validación en Godot 4.7. Registrar resultados y limitaciones reales.
5. Publicar mediante commit descriptivo y push el alcance previamente aprobado. Consultar cambios de alcance o riesgo significativo, alteraciones de reglas, eliminaciones de archivos y nuevas dependencias.
6. Actualizar el estado de los hitos y comunicar únicamente los resultados esenciales y los commits. GitHub es el punto de sincronización con TARS.

## Validación de referencia

Ejecutar con Godot 4.7, usando la ruta del ejecutable si no está en `PATH`:

```text
godot --headless --path . --script res://tests/simulation_smoke.gd
```

La suite conserva las comprobaciones de invocación y esencia e incluye daño simultáneo, derrotas mutuas en ambos órdenes de comandos, límites exactos de cooldown y duplicados sin daño adicional ni ejecución diferida. No representa una validación de interfaz o de Android.

### Validación y controles de la Fase 20.1B

```text
godot --headless --path . --script res://tests/presentation_smoke.gd
godot --headless --path . --quit-after 5
```

- Clic izquierdo o toque primario selecciona la criatura propia del jugador 0; un aro amarillo indica selección. Tocar una celda vacía, un enemigo o fuera del tablero limpia la selección. Soltar, clic derecho y toques secundarios no la cambian.
- Las barras muestran la fracción de vida de ambos bandos. La selección desaparece al resolverse la derrota. El combate automático de la demo permanece activo y no se generan comandos al seleccionar.
- El tablero se ajusta al tamaño del viewport y comparte geometría con la entrada; las posiciones de ratón y toque se convierten al espacio local de dibujo.
- La prueba automatizada cubre selección propia, rechazo de enemigos, liberación de entradas, ratón emulado tras toque, ventanas verticales y horizontales, transformación del nodo, vida tras daño, límites de barras y derrota durante un frame con varios ticks. Comprueba que la selección no altera unidades, jugadores ni comandos.
- Validación headless en Godot 4.7.2 y aprobación visual comunicada por el propietario. Pruebas de presentación, combate y arranque repetidas para la integración. La prueba táctil en dispositivo Android sigue pendiente. La demo 2D continúa siendo provisional. No se han añadido movimiento, ataques manuales ni reglas nuevas.

## Decisiones pendientes fuera del incremento actual

- Validación táctil en dispositivo Android, distinta de los eventos sintéticos y la aprobación visual en Godot.
- Futuras ventanas de ataque activo y retirada/intercambio: no se han introducido ni confundido con desplazamiento.
- Mecánica real de descubrimiento del Núcleo, fuera del prototipo aprobado.
- Balance posterior de especies, construcciones y acciones; identidad y recuperación de la auténtica por especie/jugador, según la corrección actual de Fase 23.

Las Fases 20.1C, 20.2, 21, 22 y 23 están integradas con sus respectivas revisiones y aprobaciones del propietario. Fase 24 no iniciada: se planificará aparte. IA avanzada y descubrimiento real del Núcleo siguen fuera de alcance.
