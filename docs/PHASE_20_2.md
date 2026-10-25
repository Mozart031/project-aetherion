# Fase 20.2 — primer combate táctico

Rama de origen: `codex/phase-20-2-tactical-combat`, desde `main` en `80fbdd2`. Versión `e4aa4198c1497b8e1f051cab840a343cd97b37e7` verificada visualmente por el propietario e integrada en `main` tras repetir ocho suites y arranque con éxito en Godot 4.7.2. Sin conflictos ni cambios adicionales de jugabilidad. Conservar mesa viva 3D como dirección final, vista vertical 4×8 y tiempo real simultáneo a 20 Hz.

## Entrega A

Implementada y validada antes de iniciar B, registrada en `dcd7c52`. Siete suites y arranque aprobados en Godot 4.7.2: las cinco suites existentes, `tactical_orders_smoke.gd` y `tactical_presentation_smoke.gd`.

- `tactical_orders.gd` administra objetivos explícitos separados de la ejecución en `movement.gd`. Búsqueda BFS ortogonal sobre 32 celdas, desempate fijo derecha/abajo/izquierda/arriba en coordenadas lógicas. Ocupación y reservas bloquean la ruta; no consultar Núcleos ocultos.
- `queue_destination` mantiene un destino lejano; `queue_target` persigue una criatura enemiga visible hasta una celda ortogonal adyacente y solicita ataques con el alcance, daño y cooldown existentes. Actualmente todas las criaturas son visibles; no se añade niebla ni descubrimiento de Núcleos.
- Cada tick replantea el siguiente paso cuando la criatura está libre. Conserva origen ocupado y destino reservado durante los 6 ticks de tránsito. La restricción existente del tick de llegada se conserva: el siguiente paso empieza como pronto en el tick siguiente.
- Una ruta sin salida queda `blocked`, conserva su orden y reintenta cuando se libera el tablero. No hay teletransporte, intercambios ni rutas a través de reservas. Los conflictos de pasos se resuelven por la política determinista existente: todos los contendientes se rechazan y pueden reintentar; no se garantiza progreso ante un conflicto permanente.
- Nueva orden sustituye el objetivo al siguiente tick pero conserva cualquier paso ya comprometido. `queue_stop` cancela el objetivo y termina el paso comprometido; no libera anticipadamente una reserva ni cancela daño aceptado.
- Órdenes contradictorias de una misma criatura en un tick se rechazan sin reemplazar la orden anterior; duplicados idénticos se agrupan. Objetivos aliados/inexistentes y emisores sin propiedad se rechazan. Criaturas sin ataque no aceptan órdenes de atacar.
- Objetivo derrotado completa la orden sin buscar otro enemigo; muerte propia, reinicio y final limpian órdenes. Daño y derrotas siguen siendo simultáneos, antes de llegadas.

## Demo de revisión

Escena técnica conservada: `scenes/tactical_demo.tscn` (F6; F5 conserva la demo actual). Tras la corrección de Fase 23 hay un castor azul y uno naranja: una auténtica de esa especie por jugador, pagando su coste existente. Seleccionar azul; tocar celda distante para navegar o naranja para perseguir/atacar. Se muestran estado de orden, ruta planificada y objetivo. Botones para detener y reiniciar el escenario. La demo anterior y sus pruebas se conservan; el productor antiguo de ataques automáticos se desactiva solo en la demo táctica.

## Entrega B: reglas provisionales aprobadas e implementadas

Implementada después de completar las pruebas de A. El propietario aprobó:

- Defensa únicamente contra enemigos ortogonalmente adyacentes, sin persecución, cuando no existe orden explícita ni desplazamiento en curso. No interrumpir ataques dirigidos, movimientos ni futuras acciones especiales. Menor ID como criterio técnico determinista provisional, sin definir personalidad de especies.
- Barro duplica la duración de entrada de 6 a 12 ticks, sin modificar daño ni esencia. Reglas configurables y separadas de futuras habilidades ecológicas.

`natural_defense.gd` solo produce solicitudes de ataque, con el mismo validador y cooldown existentes. `natural_defense.enabled` permite activarla/desactivarla: por compatibilidad comienza desactivada en una simulación nueva y se activa en la demo táctica. No actúa sobre criaturas con órdenes explícitas, incluso bloqueadas, ni en tránsito. También respeta órdenes explícitas recibidas ese tick, incluidos pasos técnicos y detener. No cambia de objetivo una orden de ataque dirigida.

`terrain_effects.gd` contiene el mapa público de terreno y el multiplicador configurable `mud_multiplier` (inicial 2); no contiene habilidades ni reglas por especie. `place_terrain` solo admite barro dentro del tablero antes del primer tick. La duración se fija al aceptar cada paso según su destino: entrar en barro cuesta 12 ticks, salir hacia terreno normal 6. Cambiar después un parámetro no modifica pasos comprometidos. Reiniciar elimina el mapa; la demo vuelve a colocarlo. BFS minimiza cantidad de pasos, no tiempo de viaje: no se añade optimización avanzada por coste de terreno.

La demo incorpora cuatro celdas de barro con marco marrón y leyenda. El progreso visual usa la duración real del paso, también sobre barro, y conserva barras de vida. La defensa permite intercambios simultáneos al aproximarse al rival, sin un productor de ataques independiente de las reglas.

## Validación final y límites

Ocho suites aprobadas en Godot 4.7.2: coordenadas, presentación original, combate original, movimiento, presentación de movimiento, órdenes tácticas, presentación táctica y `ecology_smoke.gd`. Arranque de la demo sin errores. A se validó y registró antes de B; las pruebas tácticas se ampliaron para bajas mutuas dirigidas, órdenes duplicadas, conflictos persistentes, final de partida y limpieza de reservas.

Cobertura de B: defensa adyacente simultánea y cooldown exacto, ausencia de persecución, activación configurable, desempate por menor ID independiente del orden de unidades, prioridad de navegación y ataques dirigidos, protección contra órdenes ajenas, duración de barro/normal/configuración, daño sin modificaciones, muerte en tránsito lento, reinicio y comparación de Núcleos ocultos con defensa/terreno/órdenes activos. La presentación prueba barro, duración autoritativa, interpolación lenta, leyenda, ventana estrecha y reinicio del escenario.

Para reproducir:

```text
godot --headless --path . --script res://tests/board_coordinates_smoke.gd
godot --headless --path . --script res://tests/presentation_smoke.gd
godot --headless --path . --script res://tests/simulation_smoke.gd
godot --headless --path . --script res://tests/movement_smoke.gd
godot --headless --path . --script res://tests/movement_presentation_smoke.gd
godot --headless --path . --script res://tests/tactical_orders_smoke.gd
godot --headless --path . --script res://tests/tactical_presentation_smoke.gd
godot --headless --path . --script res://tests/ecology_smoke.gd
godot --headless --path . --quit-after 5
```

La demo es un escenario de combate, no una partida completa: no incluye victoria por Núcleo oculto, cartas finales ni reinvocación desde interfaz. El barro es una primera interacción de terreno, no personalidad ecológica definitiva. Conflictos permanentes pueden mantener órdenes bloqueadas; se resuelven con otra orden o detener, sin prioridades secretas ni atravesar ocupación. El propietario confirmó la validación visual; queda pendiente toque real Android. La aprobación visual procede de su confirmación, además de las pruebas headless repetidas.

No añadir cartas finales, construcciones completas, IA avanzada, Núcleo descubierto, PvP ni gráficos 3D. El Núcleo rival permanece oculto; descubierto solo mediante fixtures. El comportamiento natural no decide rutas ni reemplaza órdenes explícitas.
