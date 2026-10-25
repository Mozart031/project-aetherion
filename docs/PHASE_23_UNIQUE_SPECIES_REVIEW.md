# Fase 23 — corrección de criatura auténtica única

Informe histórico de revisión en `codex/phase-23-circular-card-stacks`, sobre entrega anterior `080fd3f` y base main `597757d`. Esta corrección sustituye la antigua regla de tres copias por especie. **Estado posterior: Fase 23 integrada en main**, incluida esta corrección, tras revisión de TARS y aceptación/autorización expresa del director creativo. Cierre y validación actual en [PHASE_23.md](PHASE_23.md#cierre-de-integración).

**Actualización posterior:** TARS verificó esta corrección en `14193bb`; el director creativo probó la demo y solicitó rotación al aceptar y reverso informativo. La antigua conservación de carta superior queda sustituida; la unicidad y recuperación de este informe se mantienen. Estado/pruebas actuales en [PHASE_23_INTERACTION_REVIEW.md](PHASE_23_INTERACTION_REVIEW.md).

## Regla aplicada y comportamiento observable

| Estado de la especie, por jugador | Invocar | Carta en pila | Esencia |
| --- | --- | --- | --- |
| Disponible | Sí, tras confirmar destino válido y tener esencia. | Permanece en el recorrido; la aceptación avanza solo su pila. | Coste existente al aceptar. |
| Desplegada | No, aunque existan esencia y destinos libres. | Visible como Desplegada; se puede recorrer a otro tipo. | Rechazo sin gasto. |
| Recuperando tras derrota | No hasta completar el plazo existente. | Visible como Recuperando y con cuenta atrás. | Rechazo sin gasto. |
| Recuperación terminada | Se devuelve la disponibilidad, sin reaparición automática. | Misma posición y tipo superior. | Nueva invocación requiere pagar y confirmar. |

Cada jugador puede tener su propia auténtica de la misma especie. Las especies distintas y el rival no se bloquean entre sí. Un reinicio restaura una única disponibilidad por especie. No hay límite ampliable de copias ni excepción de manifestación implementada.

## Archivos y decisiones

- `scripts/battle_cards.gd`: se elimina `copies_per_species`; constante `AUTHENTIC_UNITS_PER_SPECIES = 1`. Se conserva un registro interno `copy_id = 0` por compatibilidad con identidad/recuperación existentes. `free_copy`, usado por la invocación directa y por cartas, niega cualquier segundo despliegue. `availability` distingue `species_active` y `species_recovering` antes de cobrar.
- `scripts/battle_stacks_demo.gd`: etiquetas Disponible/Desplegada/Recuperando, motivos claros y desaparición del aviso al terminar recuperación. Derrotar y recuperar no rotan; la decisión posterior permite avanzar una vez al aceptar una jugada.
- `scripts/battle_demo.gd`: eliminado el segundo cerdo inicial del mismo rival; queda uno, con su coste anterior. Se mantienen intentos de valla en tick 121 y jabalí en 301, pagados y validados por la misma simulación. No se añade sustituto ni compensación de balance.
- `scripts/tactical_demo.gd`: eliminado el segundo castor de cada jugador de la demo técnica anterior. Todas las demos pasan por la misma restricción; no existe una ruta especial de refuerzos que la omita.
- Pruebas anteriores: retiradas expectativas de dos auténticas propias simultáneas o una sustituta durante recuperación. Los casos de competencia ecológica usan auténticas de jugadores distintos; los controles independientes usan especies distintas. Se adaptan IDs/cantidades a la retirada de duplicados.
- Escenarios: las entradas de prueba apartan al gólem mediante órdenes normales para liberar casillas de refuerzo. El escenario de pilas obtiene heridas por combate real y paga curación; el intento de reemplazo durante recuperación se rechaza, y solo hay reinvocación posterior. Se comprueba unicidad por especie/jugador en cada tick.
- Documentación: `GEMINI.md`, `docs/PHASE_23.md`, `docs/ROADMAP.md` y referencias de 21/22 actualizadas o marcadas históricas para no mantener instrucciones contradictorias.

**Sin ajustes de HP, ataque, armadura, costes, esencia, movimiento, daño simultáneo, cooldowns, duración de recuperación, habilidades ecológicas ni Núcleos.** No se modifican estadísticas para compensar la reducción de unidades. Sin nuevas dependencias, cartas jugables o 3D.

## Pruebas ejecutadas

Godot `4.7.2.stable.official.ed1daf0bf`: **25/25 suites**, las 24 existentes adaptadas y `authentic_species_smoke.gd`. Se comprueba salida correcta, `PASS:` y ausencia de errores de scripts.

La suite nueva cubre cerdo, jabalí, caballo y gólem para **ambos jugadores**, con fondos/heridas de fixture explícitos para aislar la regla: duplicados en un tick y ticks posteriores, invocación por carta y directa, rechazos sin coste, actividad, recuperación, independencia rival, un tick antes del plazo, disponibilidad sin autoaparición y una nueva identidad pagada tras recuperar. Los parámetros de combate no se alteran para esa prueba.

`card_stacks_presentation_smoke.gd` verifica por GUI de Godot: carta activa y recuperándose inaccesible para desplegar pero presente en el ciclo, etiquetas/cuenta atrás, cuatro cursores estables, vuelta a Disponible sin aviso obsoleto, gestos, cancelación, aislamiento de órdenes tácticas y formato vertical. Su fixture de derrota se limita a presentación; la suite de escenario usa pagos, combate y recuperación reales sin escribir HP, esencia, posiciones o temporizadores.

El escenario de pilas sigue utilizando las nueve cartas y los cuatro tipos de pila, ahora rechazando el intento de sustitución del cerdo y comprobando que nunca hay dos auténticas iguales de un jugador. Continúan las regresiones de determinismo a 20 Hz, prioridad manual, curación, reservas, ataques simultáneos y privacidad del Núcleo.

Importación de editor y arranques aprobados:

```text
godot --headless --path . res://scenes/battle_demo.tscn --quit-after 5
godot --headless --path . res://scenes/battle_depth_demo.tscn --quit-after 5
godot --headless --path . res://scenes/battle_stacks_demo.tscn --quit-after 5
godot --headless --path . res://scenes/tactical_demo.tscn --quit-after 5
```

## Validación visual y límites

Abrir `scenes/battle_stacks_demo.tscn` en Godot 4.7.2 y ejecutar **F6**. Desplegar cerdo: la aceptación avanza a jabalí; recorrer tres veces devuelve el cerdo como Desplegada, bloqueado para reinvocar. Tras derrota, muestra Recuperando hasta terminar el contador; después queda Disponible sin recrearse automáticamente. Ni morir ni recuperar avanza el cursor. Probar lo mismo con rival y gestos de arrastre/toque.

El implementador revisó capturas verticales de disponibilidad, actividad y recuperación con combate real. Posteriormente TARS verificó la corrección y el director creativo aceptó el funcionamiento actual de la demo y autorizó integrar. Android físico sigue pendiente. Conservadas las limitaciones de Núcleo oculto, resultado por HP del Núcleo, balance provisional y reloj ante bloqueos largos.

## Eco del Caos — únicamente diseño futuro

Truco aprobado conceptualmente: manifestación temporal aleatoria, funcional o señuelo, inicialmente indistinguible para el rival. Esa invocación especial no es una segunda criatura auténtica. No se ha añadido al catálogo, equipamiento, simulación o demos; no existe excepción al límite actual, aleatoriedad ni sistema de entidades temporales. Los detalles de coste, duración, efectos y observabilidad se diseñarán más adelante bajo las reglas de determinismo y privacidad.
