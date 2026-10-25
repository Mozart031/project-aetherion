# Fase 21 — Primera batalla jugable

Rama: `codex/phase-21-first-playable-battle`, desde `main` en `ab75787` (Fase 20.2 verificada visualmente e integrada). Incremento implementado para revisión de TARS y validación visual del propietario. **No fusionar en main sin aprobación.**

## Escenario integrado y controles

F5 abre `scenes/battle_demo.tscn`, ventana provisional vertical de 480×900. Se conservan las demos anteriores. La mesa 3D sigue siendo la dirección final; este incremento usa gráficos 2D provisionales.

1. Elegir uno de los cuatro espacios inferiores: criatura, terreno, construcción o truco. La fila de opciones permite acceder a todas las cartas sin tapar la batalla.
2. Elegir carta y tocar una celda propia; la curación requiere tocar una criatura propia herida. La esencia se descuenta solo al aceptar la simulación. La carta seleccionada se desarma al enviar el intento; un rechazo muestra el motivo sin gastar esencia.
3. Sin carta armada, tocar criatura propia para seleccionarla; celda para destino lejano; rival o valla enemiga para ataque dirigido. Las rutas y el objetivo se resaltan. Nadie tiene una marcha obligatoria hacia el enemigo.
4. Acción contextual: cerdo en barro, caballo en maizal, preparación del jabalí o gólem adyacente a valla enemiga. Refugio permite entrar/salir de una cueva; una orden de movimiento/ataque también tramita la salida.
5. Detener cancela el objetivo respetando el paso comprometido; Reiniciar restaura escena, cartas y recursos.

El jugador empieza con cuatro de esencia y sin criaturas impuestas. Hay maizal, cueva y barro neutrales de escenario. Dos cerdos rivales estacionarios se despliegan usando sus cuatro de esencia. Refuerzos de escenario fijos, pagados con su regeneración normal: intento de valla a partir del tick 121 y jabalí en la frontera a partir del 301. No hay planificación enemiga avanzada ni órdenes de avance. Si la celda está ocupada o reservada, el intento se rechaza sin desplazar unidades ni gastar recursos.

Al despejar unidades y construcción rivales se muestra «Escenario despejado». Es un objetivo local de prueba, no una nueva regla de victoria por Núcleo. La partida conserva su límite y desempate provisionales anteriores.

## Parámetros provisionales

| Criatura | HP | Ataque | Armadura | Esencia | Intervalo de ataque | Recuperación por derrota |
| --- | --- | --- | --- | --- | --- | --- |
| Cerdo | 4 | 1 | 0 | 2 | 40 ticks | 240 ticks |
| Jabalí | 3 | 3 | 1 | 3 | 36 ticks | 240 ticks |
| Caballo | 4 | 2 | 0 | 3 | 40 ticks | 240 ticks |
| Gólem | 6 | 4 | 2 | 4 | 56 ticks | 320 ticks |

Jabalí y gólem conservan sus estadísticas. Costes y estadísticas son datos provisionales en `battle_catalog.gd`/`simulation.gd`; no son balance definitivo. Desplazamiento base sigue en 6 ticks y entrada en barro ×2, sin coste de esencia.

## Copias, disponibilidad, reutilización y recuperación

Corrección explícita del propietario: **no hay prohibición global por especie**. Por defecto, tres copias configurables por especie y jugador (`cards.copies_per_species`, aplicado al reiniciar). Cada despliegue recibe un ID de unidad nuevo y una copia con vida, posición, órdenes, acciones y estado independientes.

- Una copia activa no está disponible; otra copia libre de su misma especie sí puede desplegarse pagando esencia y respetando ocupación.
- Una derrota inicia únicamente la recuperación de esa copia. `players[player].recovering` ahora se indexa por ID de instancia, con `kind`, `copy_id` y `ready_tick`; dejó de ser un temporizador global por especie. Las regresiones se adaptaron a esta corrección aprobada.
- Al expirar, la copia vuelve a estar disponible sin reaparecer sola. Se muestran cantidades libres y temporizadores de recuperación en la interfaz. Dos derrotas de la misma especie pueden tener fechas diferentes.
- Terrenos: una carta activa por tipo/jugador en este prototipo. El intercambio normal libera de inmediato la anterior, sin derrota ni recuperación. El maizal consumido vuelve disponible inmediatamente. Los terrenos neutrales de escenario no ocupan copias del jugador.
- Construcción: una valla activa por jugador; destruirla por combate inicia 120 ticks configurables (`construction_recovery_ticks`). No se añade retirada/intercambio de construcciones a la interfaz.
- Truco de curación: reutilizable pagando dos de esencia, sin cooldown artificial; recupera hasta dos HP y no se acepta en objetivos sanos o enemigos.

No se aplica una recuperación genérica de 60 ticks después de jugar terrenos, construcciones o trucos. Recuperación por derrota, disponibilidad de copias y reutilización son conceptos separados.

## Terrenos y consecuencias visibles

- **Maizal**, coste 1: una ración. El caballo herido prepara «Comer» durante 6 ticks; al completarse recupera hasta 2 HP y desaparece el cultivo. No se trata como derrota del terreno.
- **Barro**, coste 1: conserva entrada lenta ×2 para todas las criaturas. El cerdo herido puede revolcarse; tras 6 ticks recupera 1 HP. Se muestran preparación, efecto y mensaje; el barro permanece.
- **Cueva**, coste 2: estado real de refugio con entrada y salida de 6 ticks. No es invisibilidad ni simple armadura pasiva: requiere entrar, impide atacar dentro y muestra un arco de refugio. Reduce en 1 cada golpe, conservando mínimo 1 de daño, por lo que no da invulnerabilidad. Una orden explícita programa salida y después ejecuta el objetivo; no se secuestra el control del jugador. Entrar/salir no usa el cooldown de habilidad, para evitar encierros. No se puede intercambiar la cueva bajo un ocupante refugiado.

Terrenos se despliegan/intercambian solo en territorio propio. Intercambiar un terreno que ocupa un objetivo bajo ataque aceptable ese tick se rechaza; no se usa el cooldown entero como bloqueo. Desplazarse sigue siendo distinto de retirar/intercambiar. No hay nuevos mecanismos de descubrimiento.

## Acciones contextuales y combate

`context_actions.gd` administra preparaciones explícitas, independiente de `tactical_orders.gd`, `movement.gd` y `natural_defense.gd`.

- Preparación inicial de 6 ticks, configurable. Habilidades de especie con cooldown propio de 60 ticks, configurable; no consumen esencia. Solo se aceptan curaciones especiales si falta vida y existe el terreno adecuado.
- **Jabalí**: prepara una embestida, señalada con aro naranja. Su siguiente golpe aceptado contra criatura/construcción causa +1 daño y consume la preparación. No se convierte en avance obligatorio ni se inventa un desplazamiento que atraviese reservas.
- **Gólem**: demolición requiere una valla enemiga adyacente y ataque listo; prepara el impacto y aplica ataque normal +2 a la construcción, respetando cooldown normal y daño simultáneo. No es eliminación instantánea desde la interfaz.
- **Valla**, coste 2, 4 HP: bloquea movimiento, rutas e invocación sobre su celda. Cualquier criatura atacante puede recibir una orden para aproximarse y atacarla. El gólem tiene su acción explícita adicional.
- Otra orden explícita válida interrumpe una preparación sin ejecutar el efecto; el cooldown ya iniciado se conserva. Preparación impide atacar o iniciar pasos técnicos, pero no recibir daño.
- Orden de destino y especial contradictorios recibidos para una misma criatura en el mismo tick se rechazan ambos, independientemente del orden de llegada. Duplicados iguales se agrupan.
- Se evalúa daño de criaturas y construcciones en el mismo lote. Un impacto de demolición ya aceptado sigue llegando aunque el gólem muera ese tick. Preparaciones de unidades ya derrotadas no completan curaciones ni efectos posteriores.
- Defensa natural solo si no hay orden ni acción explícita, ni movimiento ni refugio activo. No anula acciones especiales, navegación o ataques dirigidos.

La valla de cuatro HP puede caer con un golpe normal del gólem; el bonus de demolición es provisional y no pretende demostrar balance definitivo. No se cambió su vida o el ataque del gólem sin consulta para hacer artificialmente necesaria la habilidad.

## Arquitectura y observabilidad

| Archivo | Responsabilidad |
| --- | --- |
| `battle_catalog.gd` | Cuatro categorías, cartas, nombres y costes provisionales. |
| `battle_cards.gd` | Copias, disponibilidad, pago, despliegue, terreno intercambiado y construcciones. |
| `context_actions.gd` | Preparaciones, interrupciones, refugio y efectos de especie. |
| `simulation.gd` | Autoridad: comandos, validación, daño simultáneo, recuperación por instancia y vista filtrada. |
| `battle_demo.gd` / `battle_demo.tscn` | Escenario, interfaz, órdenes y retroalimentación visual; sin escribir vida, posiciones o esencia. |
| `main.gd` | Vista compartida y punto de consumo de eventos después de cada tick, para no perder daño/acciones entre frames. |

Eventos de daño, curación, acciones, despliegue, derrota y recuperación alimentan texto flotante, anillos de preparación y estados de cartas. Miniaturas, selección y barras siguen la interpolación. Se conservan copias de estado de presentación para no modificar la autoridad mediante un snapshot.

## Validación real

Doce suites automatizadas aprobadas en Godot 4.7.2: las ocho existentes de 20.2, `context_actions_smoke.gd`, `battle_systems_smoke.gd`, `battle_presentation_smoke.gd` y `battle_scenario_smoke.gd`.

- Sistemas: múltiples copias activas, recuperación independiente y fechas diferentes, disponibilidad durante derrota de otra copia, falta de esencia, límites y ocupación, intercambio sin recuperación, consumo de maizal, curación reutilizable, refugio/entrada/salida/daño mínimo, vallas/reservas/demolición, muerte durante impacto y Núcleos ocultos.
- Acciones: preparación exacta, cooldown, efecto sobre el tablero, cancelación, prioridad y conflictos deterministas.
- Presentación: cuatro espacios, acceso a las cuatro criaturas, envío de órdenes en lugar de escrituras de estado, despliegue, esencia, acciones, feedback conservado entre ticks, recuperación visible, ventana vertical estrecha y reinicio.
- Escenario completo: se despeja la batalla mediante despliegue, navegación, ataques dirigidos, demolición, barro y curación con la economía real. El test solo envía entradas de jugador; no modifica vida, esencia ni posiciones para ganar.

Comandos:

```text
godot --headless --path . --script res://tests/context_actions_smoke.gd
godot --headless --path . --script res://tests/battle_systems_smoke.gd
godot --headless --path . --script res://tests/battle_presentation_smoke.gd
godot --headless --path . --script res://tests/battle_scenario_smoke.gd
```

Repetir también las ocho suites listadas en `PHASE_20_2.md`, arranque con `--quit-after 5` e importación con `--headless --editor --quit`. Se revisó una captura real de Godot con render GL Compatibility/ANGLE en ventana 480×900 para comprobar tablero, tarjetas y controles. Esta revisión del implementador no sustituye validación visual del propietario ni prueba táctil Android.

## Límites pendientes

- Primera batalla de escenario, sin colección compleja, PvP, 3D final ni IA avanzada. No define personalidades ecológicas completas de cada especie.
- Núcleo rival sigue oculto; no se descubre por movimiento o consultas. El estado descubierto solo se usa en fixtures. Despejar el escenario no declara victoria por destrucción del Núcleo.
- No hay retirada ni intercambio de criaturas/construcciones en la interfaz. Ocupación y rutas conservan restricciones anteriores; un bloqueo permanente requiere otra orden.
- El sistema de especies antiguas y las escenas de pruebas se conservan; las cartas de esta escena se limitan a las cuatro solicitadas.
- Costes, estadísticas, cantidades de copias, preparación y recuperación son provisionales; ajustes de jugabilidad significativos requieren consulta. Refugio y disponibilidad siguen las correcciones explícitas del propietario.
- Pendientes revisión de TARS, validación visual del propietario y toque real Android. No integrar esta fase todavía.
