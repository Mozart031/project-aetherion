# Fase 20.2 — primer combate táctico

Rama de revisión: `codex/phase-20-2-tactical-combat`, desde `main` en `80fbdd2`. No integrar sin revisión de TARS y validación visual del propietario. Conservar mesa viva 3D como dirección final, vista vertical 4×8 y tiempo real simultáneo a 20 Hz.

## Entrega A

Implementada y validada antes de iniciar B. Siete suites y arranque aprobados en Godot 4.7.2: las cinco suites existentes, `tactical_orders_smoke.gd` y `tactical_presentation_smoke.gd`.

- `tactical_orders.gd` administra objetivos explícitos separados de la ejecución en `movement.gd`. Búsqueda BFS ortogonal sobre 32 celdas, desempate fijo derecha/abajo/izquierda/arriba en coordenadas lógicas. Ocupación y reservas bloquean la ruta; no consultar Núcleos ocultos.
- `queue_destination` mantiene un destino lejano; `queue_target` persigue una criatura enemiga visible hasta una celda ortogonal adyacente y solicita ataques con el alcance, daño y cooldown existentes. Actualmente todas las criaturas son visibles; no se añade niebla ni descubrimiento de Núcleos.
- Cada tick replantea el siguiente paso cuando la criatura está libre. Conserva origen ocupado y destino reservado durante los 6 ticks de tránsito. La restricción existente del tick de llegada se conserva: el siguiente paso empieza como pronto en el tick siguiente.
- Una ruta sin salida queda `blocked`, conserva su orden y reintenta cuando se libera el tablero. No hay teletransporte, intercambios ni rutas a través de reservas. Los conflictos de pasos se resuelven por la política determinista existente: todos los contendientes se rechazan y pueden reintentar; no se garantiza progreso ante un conflicto permanente.
- Nueva orden sustituye el objetivo al siguiente tick pero conserva cualquier paso ya comprometido. `queue_stop` cancela el objetivo y termina el paso comprometido; no libera anticipadamente una reserva ni cancela daño aceptado.
- Órdenes contradictorias de una misma criatura en un tick se rechazan sin reemplazar la orden anterior; duplicados idénticos se agrupan. Objetivos aliados/inexistentes y emisores sin propiedad se rechazan. Criaturas sin ataque no aceptan órdenes de atacar.
- Objetivo derrotado completa la orden sin buscar otro enemigo; muerte propia, reinicio y final limpian órdenes. Daño y derrotas siguen siendo simultáneos, antes de llegadas.

## Demo de revisión

F5 abre `scenes/tactical_demo.tscn`. Dos castores azules y dos naranjas, existentes en los datos, respetan el presupuesto inicial de esencia. Seleccionar azul; tocar celda distante para navegar o naranja para perseguir/atacar. Se muestran estado de orden, ruta planificada y objetivo. Botones para detener y reiniciar el escenario. La demo anterior y sus pruebas se conservan; el productor antiguo de ataques automáticos se desactiva solo en la demo táctica.

## Entrega B: reglas provisionales aprobadas

Pendiente de implementación después de validar A. El propietario aprobó:

- Defensa únicamente contra enemigos ortogonalmente adyacentes, sin persecución, cuando no existe orden explícita ni desplazamiento en curso. No interrumpir ataques dirigidos, movimientos ni futuras acciones especiales. Menor ID como criterio técnico determinista provisional, sin definir personalidad de especies.
- Barro duplica la duración de entrada de 6 a 12 ticks, sin modificar daño ni esencia. Reglas configurables y separadas de futuras habilidades ecológicas.

No añadir cartas finales, construcciones completas, IA avanzada, Núcleo descubierto, PvP ni gráficos 3D. El Núcleo rival permanece oculto; descubierto solo mediante fixtures. El comportamiento natural no decide rutas ni reemplaza órdenes explícitas.
