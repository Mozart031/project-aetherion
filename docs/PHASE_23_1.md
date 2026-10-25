# Fase 23.1 — estabilización

Rama `codex/phase-23-1-stabilization`, base `494bd937711f7661c3d7ece23d73f9a142373e79`. Main y su historial se conservan. Implementación autorizada tras auditoría de Argon y revisión de TARS; **entrega para revisión, sin integrar**. La integración requiere autorización expresa del director creativo tras revisión de TARS.

## Reglas ratificadas y alcance

- Orden `attack_target` activa y en posición válida de combate: bloqueo durante cooldown. Persecución lejana: sin bloqueo anticipado.
- Demolición aceptada: bloqueo durante toda su preparación. Cesación efectiva, cancelación aceptada, muerte del atacante o desaparición del objetivo liberan el compromiso.
- No cambiar cooldowns, desplazamiento, daño simultáneo, esencia, estadísticas ni recuperación. Bloquear intercambio no prohíbe movimiento.
- Privados: esencia exacta, recuperación, disponibilidad/equipamiento, órdenes y controles internos de ecología del rival. Públicos: tablero visible y resultados/acciones observables; propiedad de terrenos presentes.
- Eventos privados dirigidos al propietario incluso si muere su unidad; tipos desconocidos denegados por defecto. Núcleo oculto intacto.
- Tres etapas con regresiones. Sin IA, descubrimiento, nuevas cartas, rediseño visual o cambios de TacticalSheet y selección por animaciones. Rival prefijado y demos anteriores conservados.

## Etapa 1 — bloqueo y referencia temporal

Commit inicial `fe47985`; 28 suites pasaron antes de iniciar privacidad. La revisión final añade casos de intenciones rechazadas para evitar falsos bloqueos.

`simulation.gd` separa `_in_combat_position` de `_can_attack`: el primero comprueba posición y capacidad, el segundo mantiene además la condición de cooldown para aplicar daño. La orden dirigida y la preparación de demolición no pierden su compromiso por no poder golpear ese tick.

`get_card_placement` consulta el bloqueo con `tick_count + 1`; `BattleCards.play` revalida en el tick de ejecución. Se conserva el orden de fases: cartas antes de ingestión de órdenes, daño antes de llegadas. Cancelar una orden libera el bloqueo cuando la simulación acepta esa cancelación; no se adelanta su efecto para permitir un intercambio en el mismo lote. Las consultas no mutan el estado ni simulan un tick completo.

La comprobación pura de órdenes pendientes respeta propiedad y rechazo existente de órdenes contradictorias o mezcladas con acciones especiales. Una petición inválida no crea un compromiso ofensivo. No se crean ventanas persistentes nuevas para ataques instantáneos o defensa reactiva; estos mantienen el criterio de disponibilidad de daño, evaluado en el tick correspondiente.

La previsualización no reserva ni garantiza una futura aceptación. Cambios reales de ocupación, esencia, muerte o nuevas órdenes pueden invalidarla; se elimina la diferencia artificial de referencia temporal del bloqueo.

## Etapa 2 — frontera pública y privada

Commit `e5bfb37`; 29 suites aprobadas al cerrar la etapa. Cambios acotados de proyección y metadatos; no se reescriben los controladores.

| Parte de la vista | Contrato |
| --- | --- |
| Jugador propio | Esencia, recuperación, vida y ubicación propia del Núcleo. |
| Jugador rival | Vida del Núcleo como antes; coordenada solo si su estado existente permite conocerla. Sin esencia/recuperación. |
| Cartas, equipamiento, órdenes, ecología | Solo los del observador. |
| Criaturas rivales | ID, propietario, especie, posición, HP y estados observables de refugio/carga. Sin ticks internos, copy_id o control de ecología. |
| Movimiento y acciones visibles | Posiciones y tiempos necesarios para representar desplazamiento/preparación. No objetivos internos, origen explícito/natural ni campos desconocidos de acciones rivales. |
| Construcciones | Identidad, especie/tipo, propietario, casilla, HP y máximo. |
| Terrenos | Terrenos presentes y propietario público; neutral `-1`. Se omiten entradas históricas sin terreno, incluido maizal consumido. |

`PUBLIC_EVENTS` define campos permitidos de despliegues aceptados, ataques, daños, derrotas, curación, movimiento, preparación/fin/cancelación visibles y resultado de partida. No se propagan campos extra como motivos privados u origen de una decisión. `PRIVATE_EVENTS` contiene resultados/rechazos de cartas, recuperación, órdenes, ecología y rechazos de acción/movimiento; exige `player == observer`. Un evento desconocido o privado sin destinatario no se entrega.

Órdenes, ecología y rechazos de acciones/movimientos registran destinatario cuando se generan. No se deduce el propietario consultando unidades vivas al final del tick. Las vistas son copias independientes y la simulación conserva sus eventos completos para lógica/pruebas. El consumidor de estados de la demo de 22 usa la vista de observador.

## Etapa 3 — correcciones menores y regresiones de cierre

- Al recorrer cartas sin borrador vigente se limpia el error obsoleto. Cambiar la pila del borrador lo cancela como antes; recorrer otra pila no borra su error vigente. Confirmaciones en vuelo y aviso global de partida finalizada se conservan. Sin cambiar rotación o gestos.
- Recuperación de construcción usa `building.kind`, no el literal `fence`; mantiene duración y reglas anteriores. La prueba con otro tipo es un fixture, no una carta nueva.
- `queue_summon`, `queue_attack` y `queue_core_attack` ignoran entrada tras `finished`, igual que las demás APIs. No generan eventos, gasto o crecimiento de cola; reiniciar vuelve a habilitar comandos.
- Regresión adicional: intenciones contradictorias, inválidas o ajenas no bloquean un intercambio por un ataque que no será aceptado.
- El rival de demo sigue con cerdo inicial, destino fijo `(4,0)`, valla solicitada en tick 121 y jabalí en 301; pagos y reinicio idénticos. No se introduce un interruptor ni IA en 23.1.

## Archivos modificados

| Archivo | Cambio |
| --- | --- |
| `scripts/simulation.gd` | Bloqueo, referencia temporal, proyección del observador, destinatario de rechazo mixto y guardas finales. |
| `scripts/battle_cards.gd` | Referencia temporal de validación y tipo real de construcción al recuperar. |
| `scripts/tactical_orders.gd`, `scripts/natural_intents.gd` | Destinatarios de eventos privados, sin cambiar decisiones o rutas. |
| `scripts/context_actions.gd`, `scripts/movement.gd` | Destinatario de rechazo; acciones y ejecución de movimiento intactas. |
| `scripts/battle_depth_demo.gd` | Lectura filtrada de eventos propios en la UI. |
| `scripts/battle_stacks_demo.gd` | Limpieza del mensaje obsoleto al recorrer cartas. |
| `tests/attack_lock_smoke.gd`, `tests/observer_privacy_smoke.gd`, `tests/stabilization_smoke.gd` y UID | Nuevas regresiones; las 27 suites previas no se modifican. |
| `GEMINI.md`, `docs/ROADMAP.md`, este documento | Decisiones ratificadas, resultados, límites y validación. |

Escenas, proyecto, catálogo/estadísticas, TacticalSheet, reconocedor de gestos, controles de carta, selección y fórmulas de poses no se modifican. Sin archivos eliminados ni dependencias nuevas; UID conservados.

## Pruebas y resultados reales

Godot `4.7.2.stable.official.ed1daf0bf`: **30/30 suites aprobadas**, las 27 existentes y tres nuevas. Se comprueba código de salida, marcador `PASS:` y ausencia de `SCRIPT ERROR`/`ERROR:`.

| Suite nueva | Cobertura |
| --- | --- |
| `attack_lock_smoke.gd` | Cada tick del cooldown dirigido; preparación manual/natural de demolición; impacto puntual; persecución lejana; cancelación/sustitución, muerte, desaparición y salida de alcance; pureza; instante de disponibilidad y defensa reactiva; intenciones rechazadas/ajenas. |
| `observer_privacy_smoke.gd` | Ambos observadores, cambios privados que no alteran la vista rival, destinatarios reales tras muerte, órdenes/acciones/movimientos rechazados, recuperación, eventos desconocidos y campos extra, efectos públicos, propiedad neutral/propia/rival, sustitución/consumo/reinicio y copias independientes. |
| `stabilization_smoke.gd` | Error obsoleto frente a borrador vigente/confirmación en vuelo; construcción de tipo distinto en fixture; todos los comandos tras timeout y después de reiniciar; economía, refuerzos y ruta de demo conservados. |

Durante la revisión de casos límite se detectó un falso bloqueo por órdenes que luego serían rechazadas; se añadió una regresión que fallaba y se corrigió la consulta sin cambiar la política de ejecución de esas órdenes.

Importación de editor y arranques headless: **4/4 correctos**, `battle_demo.tscn`, `battle_depth_demo.tscn`, `battle_stacks_demo.tscn` y `tactical_demo.tscn`. No equivale a nueva aprobación visual del director creativo ni a prueba en Android físico.

## Pasos de validación para TARS y el director creativo

1. Usar esta rama y Godot 4.7.2. Abrir `scenes/battle_stacks_demo.tscn` y pulsar **F6**; F5 conserva `battle_demo.tscn`.
2. Recorrer una carta sin esencia: debe explicarse la indisponibilidad; al seguir recorriendo, el error anterior no debe quedarse pegado. Iniciar una colocación inválida y recorrer otra pila: el borrador y su motivo siguen vigentes. Cambiar la pila del propio borrador cancela sin coste.
3. Verificar selección, movimiento, vida, acciones contextuales, mantener/ecología, cuatro pilas y reverso informativo existente. Aceptar despliegue rota una vez; cancelar/rechazar no rota. Una auténtica activa o recuperándose no admite duplicado.
4. Sin desplegar unidades, observar el cerdo rival y el flanco; después aparecen valla y jabalí según el guion existente. Reiniciar debe restablecer el escenario.
5. Para los casos exactos de bloqueo y privacidad usar las suites dedicadas: la demo no añade controles de depuración ni revela datos internos para probarlos.

Con `godot` apuntando al ejecutable 4.7.2, desde la raíz:

```text
godot --headless --path . --script res://tests/attack_lock_smoke.gd
godot --headless --path . --script res://tests/observer_privacy_smoke.gd
godot --headless --path . --script res://tests/stabilization_smoke.gd
godot --headless --editor --path . --quit
godot --headless --path . res://scenes/battle_stacks_demo.tscn --quit-after 5
```

Repetir también las 27 suites originales y los otros tres arranques para revisar toda la regresión.

## Limitaciones y trabajo reservado a Fase 24

- La privacidad es el contrato de `get_player_view`, no un aislamiento del objeto de simulación: un futuro rival debe recibir exclusivamente esa proyección, nunca acceso directo a la simulación o comandos humanos pendientes. No impide inferencias a partir de jugadas observables.
- Núcleo sin descubrimiento real, resultado por vida de Núcleos, desempate por fuerza/control pendiente, balance provisional y límite de delta de reloj siguen como antes. No se añaden retiradas/intercambios de criaturas o construcciones inexistentes para demostrar el bloqueo: la corrección se aplica al intercambio de terreno ya disponible.
- Android físico, ergonomía y nueva validación visual de esta rama pendientes. Ventana informativa actual conservada; reverso integrado con animación reservado para una fase visual futura.
- Para Fase 24 se planifica una opción de escenario que desactive solo los productores prefijados del rival —invocación inicial, refuerzos y flanco— por defecto activos en demos antiguas. No desactivar ecología/defensa para eliminar guiones. Ese cambio y la IA no se implementan en 23.1.
- **No integrar esta rama sin revisión de TARS y autorización expresa del director creativo.**
