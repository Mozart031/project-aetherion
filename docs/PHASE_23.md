# Fase 23 — pilas circulares de cartas

**Corrección obligatoria para revisión:** una auténtica por especie y jugador; activa o recuperándose impide una segunda invocación. Las reglas anteriores de tres copias quedan derogadas. Aplicada únicamente en la rama de Fase 23; `main` permanece en `597757d`. Informe de cambios y pruebas en [PHASE_23_UNIQUE_SPECIES_REVIEW.md](PHASE_23_UNIQUE_SPECIES_REVIEW.md).

**Estado actual:** ambos bloques implementados en `codex/phase-23-circular-card-stacks`, desde main integrado y publicado `597757d025b21b83860aec014a016502c28d87f4`. **25 suites y cuatro arranques aprobados en Godot 4.7.2. No integrada en main; pendiente de revisión de TARS y validación visual del director creativo.** Sin estadísticas definitivas ni conversión 3D.

Alcance autorizado por el director creativo: cuatro pilas independientes, gestos abajo/arriba, especie como entrada y una única auténtica por especie/jugador, conservar carta superior tras jugar y colocación provisional por arrastre o selección/toque. La implementación conserva la simulación, economía y combate aprobados.

## Resultado previsto y reglas que se conservan

Cuatro pilas compactas visibles abajo: **Criaturas, Terrenos, Construcciones y Habilidades/trucos**. Cada una recorre las cartas equipadas para esa partida. El tablero vertical y el combate siguen activos a 20 Hz al navegar, previsualizar o cancelar cartas.

Una pila contiene **tipos de carta distintos**, con una sola criatura auténtica por especie y jugador. Ejemplo: `Cerdo → Jabalí → Caballo → Gólem → Cerdo`. El cerdo muestra uno de tres estados excluyentes: Disponible, Desplegada o Recuperando. Mientras esté desplegado o recuperándose no existe otra copia libre para reemplazarlo. Derrotarlo no retira la carta de su pila ni cambia su cursor; solo vuelve a poder invocarse al terminar la recuperación.

Se conservan esencia, costes, restricciones de territorio/ocupación/reservas, bloqueo de intercambios bajo ataque, recuperación individual y protección del Núcleo. Navegar o previsualizar no paga, consume, reserva ni crea entidades. No se añaden criaturas, habilidades, reglas de recuperación o 3D por esta fase.

## Base conservada y variedad real

`battle_catalog.gd` define nueve cartas con ID estable, etiqueta, categoría y coste. La demo ofrece botones de categoría y una fila de tipos. `battle_cards.gd` conserva copias de criaturas (`copy_id`, `unit_id`, `ready_tick`), disponibilidad de terreno/construcción y truco reutilizable. `simulation.gd` valida y ejecuta `queue_play_card` en el tick siguiente; el adaptador reversible convierte entrada visual 4×8 a lógica 8×4.

La Fase 23 incorpora equipamiento por partida y navegación circular. Hay cuatro especies y tres terrenos reales, pero solo una construcción y un truco. Fase 23 puede demostrar variedad real en las dos primeras pilas; las otras dos tendrán longitud uno hasta aprobar más cartas. No crear variantes ficticias ni repetir copias para aparentar variedad.

## Modelo de datos y responsabilidades

| Capa | Responsabilidad implementada | No debe hacer |
| --- | --- | --- |
| Catálogo | Identidad `card_id` (IDs actuales), categoría, coste, etiqueta y modo de objetivo; registro de efectos existentes. | Almacenar cursor, gestos o recuperación de una instancia. |
| Equipamiento de partida | Listas ordenadas de IDs por categoría, validadas y congeladas al iniciar la partida. | Inventar una colección, progresión o límites de mazo no aprobados. |
| `CardStackModel` | Un cursor independiente por categoría y acceso al tipo superior; avance circular determinista. | Tratar copias como entradas, gastar esencia o decidir daño. |
| `BattleCards` / simulación | Un registro auténtico por especie/jugador, disponibilidad, validación pura de colocación y ejecución definitiva en tick. | Mover el cursor al morir/recuperarse o confiar en un resaltado del cliente. |
| Controlador de colocación | Borrador, objetivo visual, cancelación y envío único de intención; espera de aceptación/rechazo. | Modificar economía/posiciones o detener el combate. |
| `CardStackControl` / panel | Gestos, animación del recorrido, coste, disponibilidad y tiempo hasta recuperación. | Duplicar reglas o enviar órdenes tácticas con el mismo toque. |

Contrato orientativo:

```text
loadout[category] = [card_id_0, card_id_1, ...]
cursor[category] = index
top(category) = loadout[category][cursor[category]]
copies[player][card_id][0] = {unit_id, ready_tick}  # único registro auténtico; copy_id=0 por compatibilidad
draft = {request_id, player, category, card_id, cell?, target_id?, state}
```

El borrador fija el ID superior al iniciar el despliegue; no asigna una copia anticipadamente. La simulación solo acepta la orden si el único registro auténtico de esa especie/jugador está disponible. Reiniciar restaura cursores y borradores junto con el estado de partida.

La secuencia circular no se filtra por disponibilidad: una carta agotada sigue visible y se puede pasar manualmente. Una pila vacía muestra su estado y no divide por cero; longitud uno no cambia el tipo al rotar. Ninguna categoría cambia el índice de otra.

## Interacción táctil provisional implementada

Cada pila tiene una zona `Control` propia. Umbral vertical configurable, inicialmente 48 unidades de interfaz, corregido por escala de viewport/DPI; predominio vertical inicial 1,3× respecto al desplazamiento horizontal. Son valores de UX para probar en Android, no reglas de combate. Movimiento corto u horizontal no rota ni despliega. Un gesto puede emitir **una sola intención**, con animación de previsualización antes de comprometerla.

### Deslizar hacia abajo

1. Capturar el dedo que comenzó dentro de la pila y seguir su trayectoria.
2. Al soltar superando el umbral inferior, mover visualmente la carta superior al fondo y avanzar `(index + 1) % size` una sola vez.
3. El siguiente gesto repite el recorrido; después de la última vuelve la primera. Los tipos no disponibles no se saltan.
4. No cambiar esencia, inventario, selección de criatura ni órdenes en curso.

### Deslizar hacia arriba y colocar

1. Superar el umbral superior inicia un borrador de la carta superior actual. Mostrar nombre/coste, previsualización y destinos consultados como válidos. Si no hay copia libre o esencia suficiente, explicar el motivo sin enviar una orden.
2. Gesto rápido provisional: continuar el arrastre hacia el tablero y **soltar sobre un destino válido confirma**. Si el deslizamiento termina antes de llegar al tablero, dejar la colocación preparada para confirmar con un toque posterior. El mismo gesto no se entrega a selección/movimiento/ataque de criaturas.
3. Soltar o tocar un destino inválido no gasta nada; muestra motivo y permite corregir. Volver y soltar sobre la pila de origen, botón «Cancelar» o atrás de Android cancela. La cancelación por sí sola conserva carta, disponibilidad y todos los cursores.
4. Confirmar envía un único comando con `request_id`; pasar a estado «enviando» hasta el tick de respuesta, sin nuevas confirmaciones duplicadas. Se revalidan esencia, copia y destino en ese tick. Un resaltado anterior no garantiza aceptación: el combate sigue cambiando.
5. Aceptación actualiza inventario/efectos desde la simulación. Rechazo no gasta esencia ni consume copia y permite corregir el borrador con explicación. Si ya no existe su objetivo (p. ej. criatura a curar), volver a pedir un objetivo válido.

**Regla confirmada por el director creativo:** después de colocar una carta, esa misma carta permanece arriba. Conservar el índice después de éxito o cancelación; la pila solo cambia mediante el gesto hacia abajo. No introducir rotación automática al jugar, morir o recuperarse una copia, ni robo aleatorio.

Mientras hay borrador, se mantiene la selección táctica anterior si su criatura sigue viva, sin emitir nuevas órdenes de tablero por los toques de colocación. Las órdenes ya aceptadas continúan. Otra pila puede rotarse independientemente; rotar la pila de origen cancela primero su borrador, y después realiza la rotación solicitada. Deslizar arriba en otra pila reemplaza el borrador anterior sin gasto. Durante la breve espera de respuesta se bloquean nuevas confirmaciones para evitar doble despliegue.

## Separación de entrada y autoridad

- Captura exclusiva del índice de dedo desde el inicio del gesto hasta su liberación; otros dedos no confirman ni rotan esa sesión. No interpretar el mismo gesto como dos deslizamientos al invertir dirección.
- Los controles de pilas consumen sus eventos y el controlador de colocación reclama sus toques/arrastres sobre tablero. Los controles tácticos solo reciben entrada no consumida cuando no hay colocación activa. Filtrar ratón emulado tras toque, como en las demos actuales.
- Ratón conserva alternativa de arrastre y clic para PC. Perder foco, reiniciar, cambiar de escena o recibir cancelación del sistema libera captura y cancela el borrador sin gasto.
- Reutilizar la transformación de viewport y `board_coordinates.gd`; nunca adaptar reglas de simulación al desplazamiento del dedo. No incluir ubicación del Núcleo rival en consultas, resaltados, mensajes ni previsualizaciones.
- Cancelar un borrador local sin comando es distinto de deshacer un despliegue ya aceptado. No introducir retirada/intercambio de criaturas para simular una cancelación tardía.

## Disponibilidad y transacción de despliegue

La carta superior muestra etiqueta/tipo, coste y disponibilidad: Desplegada bloquea una segunda invocación; Recuperando bloquea la especie y muestra su tiempo restante; Disponible permite iniciar colocación si alcanza la esencia. No hay varias copias intercambiables de una criatura. El bloqueo se aplica por especie y jugador, no al rival ni a especies distintas. La falta de esencia se distingue de actividad y recuperación.

El tiempo deriva de `max(0, ready_tick - tick) / 20`, actualizado desde el tick observado. No se crea un temporizador independiente. Terreno intercambiado y maizal consumido vuelven disponibles inmediatamente; construcción destruida sigue su recuperación existente; curación sigue reutilizable pagando esencia. No aplicar un cooldown genérico al deslizar o usar cartas.

Refactor acotado implementado: extraer de `BattleCards.play` una consulta pura común `validate_play`, usada por previsualización y ejecución. Devuelve disponibilidad, objetivo normalizado y motivo; nunca descuenta ni asigna copias. La ejecución revalida contra el estado y comandos del tick, aplica una vez y produce aceptación/rechazo correlacionado con `request_id`. Mantener compatibles los comandos de demos/tests anteriores. Pruebas deben garantizar que el refactor no cambia sus resultados.

El equipamiento se pasa a la simulación como configuración de partida: rechazar IDs fuera de catálogo/categoría o no equipados antes de gastar. El cursor es estado de presentación, no RNG ni fase de turno. No exigir una lista de copia por casilla de UI. Para una futura carta basta registrarla en su categoría y equipamiento; una mecánica nueva sí requerirá su controlador de efecto y pruebas, sin reescribir navegación o gestos. Evitar nuevas ramas por nombre de especie en el panel.

## Archivos y componentes

| Archivo | Responsabilidad |
| --- | --- |
| `scripts/battle_catalog.gd` | Metadatos de objetivo/categoría para los efectos actuales, con IDs existentes. |
| `scripts/match_loadout.gd` (nuevo) | Configuración/validación de cartas equipadas y orden por categoría; valores de demo con catálogo actual. |
| `scripts/card_stack_model.gd` (nuevo) | Cursores y navegación circular de tipos, independiente de nodos y economía. |
| `scripts/card_stack_control.gd`, `scenes/card_stack_control.tscn` (nuevos) | Control reutilizable por pila, captura de gestos y presentación compacta. |
| `scripts/card_placement_controller.gd` (nuevo) | Borrador, cancelación, objetivo, consulta y confirmación única. |
| `scripts/card_stacks_panel.gd`, `scripts/card_stack_gesture.gd`, `scripts/card_placement_preview.gd` | Captura GUI, reconocimiento de gesto independiente y dibujo de destinos sin reglas de combate. |
| `scripts/battle_cards.gd`, `scripts/simulation.gd` | Consulta pura compartida, configuración equipada y respuesta correlacionada; conservar inventario/efectos actuales. |
| `scripts/battle_depth_demo.gd`, panel/escena de demo de Fase 23 | Componer cuatro controles de pila con el tablero/controles existentes. Preferir componentes y hooks a seguir duplicando demos por herencia. Conservar escenas previas hasta aprobación. |
| `tests/card_stacks_smoke.gd`, `tests/card_placement_smoke.gd`, `tests/card_stacks_presentation_smoke.gd`, `tests/card_stacks_scenario_smoke.gd` (previstos) | Modelo, transacciones, gestos y batalla integrada. Nombres provisionales. |
| `GEMINI.md`, `docs/ROADMAP.md`, este documento | Registrar decisiones, evidencia y límites reales. |

No se prevén cambios en movimiento, instintos, ataques, terreno, daño ni descubrimiento del Núcleo. La simulación continúa con lógica 8×4 y presentación 4×8.

## Bloques funcionales entregados

**A — Pilas equipadas y despliegue transaccional.** Configuración con catálogo real, modelo circular independiente, consulta compartida con ejecución, confirmación/cancelación y respuesta correlacionada. Inventario y refactor comprobados mediante 21 suites antes de conectar gestos. Commit `858a792`. Sin editor de colección ni nuevas cartas.

**B — Gestos y batalla completa.** Cuatro vistas superiores con inventario separado, captura exclusiva, recorrido abajo, arrastre/armado arriba, previsualización, confirmación/cancelación, filtro de ratón emulado, cambio de foco y feedback de disponibilidad. Batalla integrada y ventanas verticales verificadas; 24 suites aprobadas. Android físico y validación visual de TARS/director creativo pendientes; publicación únicamente en rama de revisión.

Fase 22 se integró primero en `597757d`, preservando el historial y pasando nuevamente sus 19 suites y ambos arranques. Después se creó la rama de Fase 23 desde main sincronizado. El bloque A (equipamiento, modelo y transacciones) quedó validado con 21 suites antes de conectar el bloque B. No integrar Fase 23 sin su propia revisión técnica y validación visual.

## Criterios de aceptación cubiertos

| Área | Casos obligatorios |
| --- | --- |
| Circularidad | Secuencia de cuatro especies reales; N avances vuelven al inicio; independencia de cuatro cursores; listas vacías/de un elemento; tipos indisponibles permanecen navegables. |
| Carta superior tras jugar | Despliegue aceptado conserva exactamente el tipo superior y los cuatro cursores; rechazo/cancelación tampoco rotan. Solo un gesto hacia abajo de esa pila cambia su índice. |
| Tipos y copias | Una especie tiene una entrada y una auténtica por jugador; actividad/derrota/recuperación no rota la pila; un tipo diferente siempre tiene identidad/etiqueta distinta. Configuración futura de catálogo no exige cambios del control. |
| Equipamiento | Solo IDs equipados/categoría válida; orden estable; rechazo de configuración inválida sin partida parcialmente inicializada. Casos futuros con dos construcciones/trucos mediante fixtures, sin añadir cartas de jugabilidad. |
| Gestos | Umbrales, arrastre horizontal, inversión de dirección, un avance por gesto largo, varios dedos, ratón emulado y captura hasta liberar; ausencia de órdenes tácticas accidentales. |
| Cancelación | Antes/durante previsualización, volver a pila, atrás, perder foco, reinicio y cambio de carta: cero gasto/consumo y cursores preservados salvo rotación explícita independiente. |
| Validación | Territorio, ocupación, reservas, restricciones de terreno/refugio/ataque activo, curación solo a propia herida; consultas no mutan y no revelan Núcleos. |
| Economía y recuperación | Preparar/navegar/rechazar no paga; confirmar válido paga una vez; dos confirmaciones no duplican; rechazar una segunda invocación estando activa o recuperándose sin gasto; límite exacto de recuperación; falta de esencia distinta de falta de copia. |
| Estado cambiante | Entre resaltado y tick se ocupa celda, muere objetivo, cambia esencia o disponibilidad: revalidar/rechazar sin consumo; respuesta correlacionada no cierra un borrador distinto. |
| Presentación | Cuatro pilas visibles sin cubrir tablero, lectura de especie/coste/estado, tiempo de recuperación correcto, selección táctica preservada y barra de vida visible; viewport/DPI/orientación vertical. |
| Integración | Recorrer cerdo/jabalí/caballo/gólem, cancelar, desplegar y combatir, perder una criatura, rechazar reemplazo durante recuperación y reinvocarla después, jugar terreno/construcción/truco. Economía real, sin manipular vida/esencia para aprobar el escenario. |
| Regresiones | Repetir las 19 suites de cierre de 22, arranque, determinismo de entradas aceptadas a 20 Hz y privacidad. Gestos solo en cliente; no variar resultados para acompañar animación. |

Pruebas implementadas y ejecutadas en Godot `4.7.2.stable.official.ed1daf0bf`: **25/25 aprobadas**, las 24 suites adaptadas y una nueva suite exhaustiva de auténticas. Eventos táctiles sintéticos recorren la GUI real de un SubViewport; esto no equivale a validación en Android físico.

## Decisiones confirmadas y detalles pendientes

1. **Confirmado:** cuatro pilas independientes; abajo recorre circularmente, arriba inicia colocación; una especie distinta es una entrada y tiene una única auténtica por jugador. Después de colocar, la misma carta permanece arriba; solo el gesto hacia abajo cambia la pila.
2. **Autorizado e implementado provisionalmente:** arrastrar y soltar sobre tablero válido confirma; un deslizamiento corto hacia arriba o un toque en la carta arma para un toque posterior en destino. Ajustable después de pruebas táctiles; cancelar un borrador no gasta.
3. Equipamiento implementado en la demo: todos los tipos actuales, una entrada por tipo con un único registro auténtico por especie de criatura. Sin cuotas, selección de colección o multiplicación de entradas por copia; límites de mazo y más cartas se acuerdan aparte.
4. Limitación conservada: una sola construcción y un solo truco actuales; no añadir efectos nuevos para simular pilas mayores sin aprobación.

Las reglas centrales de pilas, gestos y conservación de carta superior están confirmadas. No convertir los detalles pendientes en reglas definitivas por implementación implícita. El objetivo es variedad de tipos y controles táctiles rápidos conservando la autoridad del jugador y el combate existente. No implementar estadísticas definitivas de vida ni convertir el proyecto a 3D en esta preparación.

## Demo jugable y decisiones técnicas aplicadas

Abrir **`scenes/battle_stacks_demo.tscn` y ejecutar F6**. F5 conserva `battle_demo.tscn`; `battle_depth_demo.tscn` de 22 también se conserva. Desde consola: `godot --path . res://scenes/battle_stacks_demo.tscn`.

- Abajo en una pila: siguiente tipo, con animación breve; no saltar cartas agotadas. Arriba: iniciar colocación y arrastrar al tablero; soltar válido confirma. Toque corto en carta, o deslizamiento arriba sin llegar al tablero, permite tocar después el destino. Ratón admite los mismos arrastres/clics.
- Regresar a la pila tras arrastrar, «Cancelar», Escape, atrás o pérdida de foco cancelan solo la previsualización. No se puede deshacer localmente una orden ya confirmada/enviada; su respuesta llega en el tick. Reiniciar limpia borrador, cursores, captura y solicitudes junto con la simulación.
- Mismo tipo arriba tras éxito/rechazo/cancelación/derrota/recuperación. Tipo agotado sigue navegable; esencia insuficiente, especie desplegada y tiempo de recuperación se muestran por separado. Una construcción o truco de longitud uno conserva su tipo al recorrer.
- Las consultas de colocación son puras y las ejecuta la simulación. Un resaltado puede caducar por combate/ocupación antes del tick: el comando revalida sin pago parcial. IDs monotónicos por jugador y memoria acotada a la última respuesta evitan doble coste/despliegue; respuestas antiguas no cierran un borrador posterior. Los comandos antiguos sin ID siguen funcionando en las demos previas.
- Composición, no otra cadena de herencia: `battle_stacks_demo.gd` combina la vista de 22 con `card_stacks_panel.gd`, controles de carta y `card_placement_preview.gd`. Hooks opcionales de selector/reinicio y señal de tick en la vista compartida conservan el comportamiento anterior por defecto. No se pausa ni se altera combate/movimiento durante navegación.
- Equipamiento por defecto con los nueve tipos existentes; se valida y copia antes del primer tick, se conserva al reiniciar y no se edita durante la batalla. Sin editor de colección ni nuevas cartas. El cursor y el borrador no contienen copias asignadas anticipadamente.
- Captura de un solo dedo: la GUI toma la pulsación de origen y sigue el arrastre fuera de su rectángulo. Se consumen secundarios y ratón emulado. Mientras hay borrador, los toques de colocación no se convierten en órdenes tácticas; la selección previa y sus órdenes continúan. Los controles explícitos de acción abandonan el borrador sin cancelar órdenes aceptadas.

## Pruebas y resultados reales

Además de adaptar las suites anteriores, `authentic_species_smoke.gd` comprueba cerdo, jabalí, caballo y gólem para ambos jugadores: duplicados en el mismo tick, vías directa y de carta, ausencia de cobro, bloqueo activo/recuperación, independencia del rival, límite exacto y reinvocación posterior sin reaparición automática. El escenario y la presentación verifican permanencia en pila y estados Disponible/Desplegada/Recuperando.

| Suite nueva | Evidencia |
| --- | --- |
| `card_stacks_smoke.gd` | Cuatro tipos de criatura, ciclo completo e independencia; vacío/una carta; fixtures de futuros tipos sin nuevas mecánicas; configuración inválida atómica, aislamiento y bloqueo de equipamiento durante partida; jugar no rota. |
| `card_placement_smoke.gd` | Previsualizar/cancelar sin mutación, territorio/ocupación/reservas/curación, pago exacto, confirmación duplicada, cambios de celda/esencia antes del tick, replay/solicitudes antiguas, respuestas antiguas, disponibilidad y Núcleo oculto. |
| `card_stack_gestures_smoke.gd` | Umbral/axis, abajo una vez, arriba/selección, horizontal sin acción, retorno/cancelación, inversión de dirección, liberación agrupada y captura exclusiva. |
| `card_stacks_presentation_smoke.gd` | Entrada por GUI real de SubViewport: circularidad, arriba corto, toque/destino y arrastre directo con toque y ratón; emulación, secundarios, cancelación/foco, disponibilidad sin esencia, selección táctica preservada, reinicio y viewport 360×800. |
| `card_stacks_scenario_smoke.gd` | Nueve cartas reales en cuatro pilas; pagos, daño de combate, curación, demolición, derrota auténtica, rechazo durante recuperación y reinvocación posterior, countdown visible, escenario despejado y cursor estable. Sin escribir vida, posición, esencia ni recuperación para aprobar el escenario. |

Las 25 suites pasan y arrancan sin errores las cuatro demos en Godot 4.7.2; importación del editor y UID generados. Capturas de la nueva demo a 480×900 y 360×800 revisadas por el implementador, con pilas y previsualización separadas del tablero. No se afirma aprobación visual del director creativo ni ejecución en dispositivo Android.

## Límites y revisión pendiente

UI 2D y arte provisionales. Umbral 48, predominio vertical 1,3 y tolerancia de toque 12 en unidades lógicas de viewport; se benefician del escalado de entrada de Godot, pero sensibilidad/DPI, tamaño de dedo y rendimiento requieren Android real. Demos previas y F5 conservados. No se añade PvP, red, historial de solicitudes persistente, nuevas especies, estadísticas definitivas o 3D.

La construcción y el truco tienen una carta real cada uno; las criaturas tienen una auténtica por especie y jugador, sin parámetro para ampliar copias y el terreno/construcción sus restricciones anteriores. Catálogo y equipamiento admiten nuevos tipos sin reescribir las pilas; un efecto nuevo requerirá su regla/controlador y aprobación propia.

Se conservan las limitaciones de 22: Núcleo rival sin descubrimiento real, resultado por vida de Núcleos, falta de desempate por fuerza/control, balance provisional y pérdida de tiempo de pared ante bloqueos largos del frame. **No fusionar esta rama hasta revisión de TARS y validación visual del director creativo.**

## Diseño futuro — Eco del Caos

Carta de truco aprobada conceptualmente: creará una manifestación temporal aleatoria, funcional o señuelo, inicialmente indistinguible para el rival. Esa manifestación especial **no cuenta como una segunda criatura auténtica**. No se implementa en Fase 23: no se añade al catálogo/equipamiento, no hay generación aleatoria, entidades temporales ni excepciones al límite actual. Duración, selección aleatoria, coste, efectos y condiciones de observabilidad requieren diseño posterior sin comprometer el determinismo ni el Núcleo oculto.
