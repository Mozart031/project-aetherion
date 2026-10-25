# Fase 23 — pilas circulares de cartas

**Autorización vigente:** Fase 22 integrada y verificada; el director creativo autoriza iniciar 23 en `codex/phase-23-circular-card-stacks` desde main actualizado. Se aprueba provisionalmente arrastrar al tablero o seleccionar y tocar destino. El plan siguiente guía la implementación; se conserva como histórico el estado de propuesta previo. No integrar Fase 23 sin revisión de TARS y aprobación visual propia; sin estadísticas definitivas ni conversión 3D.

**Estado: diseño técnico revisado favorablemente por TARS. Reglas centrales confirmadas por el director creativo; no implementado.** Los requisitos de pilas y gestos proceden de la orden del director creativo; las decisiones técnicas siguientes son propuestas. La Fase 22 permanece en su rama, con revisión técnica favorable y preparación de integración autorizada; pendiente de confirmación definitiva del director creativo. No iniciar implementación completa ni integrar en `main` por el mero hecho de publicar este documento.

## Resultado previsto y reglas que se conservan

Cuatro pilas compactas visibles abajo: **Criaturas, Terrenos, Construcciones y Habilidades/trucos**. Cada una recorre las cartas equipadas para esa partida. El tablero vertical y el combate siguen activos a 20 Hz al navegar, previsualizar o cancelar cartas.

Una pila contiene **tipos de carta distintos**; el contador de copias de un tipo es inventario separado. Ejemplo: `Cerdo → Jabalí → Caballo → Gólem → Cerdo`. El cerdo puede mostrar «1 libre · 1 activa · 1 recuperando» sin convertirse en tres entradas «Cerdo». Derrotar una copia no retira la carta de su pila ni bloquea sus otras copias libres.

Se conservan esencia, costes, restricciones de territorio/ocupación/reservas, bloqueo de intercambios bajo ataque, recuperación individual y protección del Núcleo. Navegar o previsualizar no paga, consume, reserva ni crea entidades. No se añaden criaturas, habilidades, reglas de recuperación o 3D por esta fase.

## Situación actual que debe reemplazar la interfaz

`battle_catalog.gd` define nueve cartas con ID estable, etiqueta, categoría y coste. La demo ofrece botones de categoría y una fila de tipos. `battle_cards.gd` conserva copias de criaturas (`copy_id`, `unit_id`, `ready_tick`), disponibilidad de terreno/construcción y truco reutilizable. `simulation.gd` valida y ejecuta `queue_play_card` en el tick siguiente; el adaptador reversible convierte entrada visual 4×8 a lógica 8×4.

Hoy no existe equipamiento por partida ni navegación circular. Hay cuatro especies y tres terrenos reales, pero solo una construcción y un truco. Fase 23 puede demostrar variedad real en las dos primeras pilas; las otras dos tendrán longitud uno hasta aprobar más cartas. No crear variantes ficticias ni repetir copias para aparentar variedad.

## Modelo de datos y responsabilidades

| Capa | Responsabilidad propuesta | No debe hacer |
| --- | --- | --- |
| Catálogo | Identidad `card_id` (IDs actuales), categoría, coste, etiqueta y modo de objetivo; registro de efectos existentes. | Almacenar cursor, gestos o recuperación de una instancia. |
| Equipamiento de partida | Listas ordenadas de IDs por categoría, validadas y congeladas al iniciar la partida. | Inventar una colección, progresión o límites de mazo no aprobados. |
| `CardStackModel` | Un cursor independiente por categoría y acceso al tipo superior; avance circular determinista. | Tratar copias como entradas, gastar esencia o decidir daño. |
| `BattleCards` / simulación | Inventario por copia, disponibilidad, validación pura de colocación y ejecución definitiva en tick. | Mover el cursor al morir/recuperarse o confiar en un resaltado del cliente. |
| Controlador de colocación | Borrador, objetivo visual, cancelación y envío único de intención; espera de aceptación/rechazo. | Modificar economía/posiciones o detener el combate. |
| `CardStackControl` / panel | Gestos, animación del recorrido, coste, disponibilidad y tiempo hasta recuperación. | Duplicar reglas o enviar órdenes tácticas con el mismo toque. |

Contrato orientativo:

```text
loadout[category] = [card_id_0, card_id_1, ...]
cursor[category] = index
top(category) = loadout[category][cursor[category]]
copies[player][card_id][copy_id] = {unit_id, ready_tick}  # autoridad existente
draft = {request_id, player, category, card_id, cell?, target_id?, state}
```

El borrador fija el ID superior al iniciar el despliegue; no asigna una copia anticipadamente. La simulación elige una copia libre mediante la política determinista existente al aceptar la orden. Reiniciar restaura cursores y borradores junto con el estado de partida.

La secuencia circular no se filtra por disponibilidad: una carta agotada sigue visible y se puede pasar manualmente. Una pila vacía muestra su estado y no divide por cero; longitud uno no cambia el tipo al rotar. Ninguna categoría cambia el índice de otra.

## Interacción táctil propuesta

Cada pila tiene una zona `Control` propia. Umbral vertical configurable, inicialmente 48 unidades de interfaz, corregido por escala de viewport/DPI; predominio vertical inicial 1,3× respecto al desplazamiento horizontal. Son valores de UX para probar en Android, no reglas de combate. Movimiento corto u horizontal no rota ni despliega. Un gesto puede emitir **una sola intención**, con animación de previsualización antes de comprometerla.

### Deslizar hacia abajo

1. Capturar el dedo que comenzó dentro de la pila y seguir su trayectoria.
2. Al soltar superando el umbral inferior, mover visualmente la carta superior al fondo y avanzar `(index + 1) % size` una sola vez.
3. El siguiente gesto repite el recorrido; después de la última vuelve la primera. Los tipos no disponibles no se saltan.
4. No cambiar esencia, inventario, selección de criatura ni órdenes en curso.

### Deslizar hacia arriba y colocar

1. Superar el umbral superior inicia un borrador de la carta superior actual. Mostrar nombre/coste, previsualización y destinos consultados como válidos. Si no hay copia libre o esencia suficiente, explicar el motivo sin enviar una orden.
2. Propuesta de gesto rápido: continuar el arrastre hacia el tablero y **soltar sobre un destino válido confirma**. Si el deslizamiento termina antes de llegar al tablero, dejar la colocación preparada para confirmar con un toque posterior. El mismo gesto no se entrega a selección/movimiento/ataque de criaturas.
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

La vista superior muestra etiqueta/tipo, coste y por separado copias libres, activas y en recuperación. Si hay copia libre y esencia suficiente, se permite iniciar colocación aunque otra copia se recupere. Si todas se recuperan, desaturar y mostrar el menor tiempo pendiente; si todas están activas, indicar «Todas desplegadas», sin inventar un tiempo. Falta de esencia es un estado diferente de recuperación.

El tiempo deriva de `max(0, ready_tick - tick) / 20`, actualizado desde el tick observado. No se crea un temporizador independiente. Terreno intercambiado y maizal consumido vuelven disponibles inmediatamente; construcción destruida sigue su recuperación existente; curación sigue reutilizable pagando esencia. No aplicar un cooldown genérico al deslizar o usar cartas.

Propuesta de refactor acotado: extraer de `BattleCards.play` una consulta pura común `validate_play`, usada por previsualización y ejecución. Devuelve disponibilidad, objetivo normalizado y motivo; nunca descuenta ni asigna copias. La ejecución revalida contra el estado y comandos del tick, aplica una vez y produce aceptación/rechazo correlacionado con `request_id`. Mantener compatibles los comandos de demos/tests anteriores. Pruebas deben garantizar que el refactor no cambia sus resultados.

El equipamiento se pasa a la simulación como configuración de partida: rechazar IDs fuera de catálogo/categoría o no equipados antes de gastar. El cursor es estado de presentación, no RNG ni fase de turno. No exigir una lista de copia por casilla de UI. Para una futura carta basta registrarla en su categoría y equipamiento; una mecánica nueva sí requerirá su controlador de efecto y pruebas, sin reescribir navegación o gestos. Evitar nuevas ramas por nombre de especie en el panel.

## Archivos previstos, sin modificaciones de implementación todavía

| Archivo | Cambio propuesto |
| --- | --- |
| `scripts/battle_catalog.gd` | Metadatos de objetivo/categoría para los efectos actuales, con IDs existentes. |
| `scripts/match_loadout.gd` (nuevo) | Configuración/validación de cartas equipadas y orden por categoría; valores de demo con catálogo actual. |
| `scripts/card_stack_model.gd` (nuevo) | Cursores y navegación circular de tipos, independiente de nodos y economía. |
| `scripts/card_stack_control.gd`, `scenes/card_stack_control.tscn` (nuevos) | Control reutilizable por pila, captura de gestos y presentación compacta. |
| `scripts/card_placement_controller.gd` (nuevo) | Borrador, cancelación, objetivo, consulta y confirmación única. |
| `scripts/battle_cards.gd`, `scripts/simulation.gd` | Consulta pura compartida, configuración equipada y respuesta correlacionada; conservar inventario/efectos actuales. |
| `scripts/battle_depth_demo.gd`, panel/escena de demo de Fase 23 | Componer cuatro controles de pila con el tablero/controles existentes. Preferir componentes y hooks a seguir duplicando demos por herencia. Conservar escenas previas hasta aprobación. |
| `tests/card_stacks_smoke.gd`, `tests/card_placement_smoke.gd`, `tests/card_stacks_presentation_smoke.gd`, `tests/card_stacks_scenario_smoke.gd` (previstos) | Modelo, transacciones, gestos y batalla integrada. Nombres provisionales. |
| `GEMINI.md`, `docs/ROADMAP.md`, este documento | Registrar decisiones, evidencia y límites reales. |

No se prevén cambios en movimiento, instintos, ataques, terreno, daño ni descubrimiento del Núcleo. La simulación continúa con lógica 8×4 y presentación 4×8.

## Plan de implementación en dos bloques funcionales

**A — Pilas equipadas y despliegue transaccional.** Configuración con catálogo real; modelo circular independiente; cuatro vistas superiores mostrando inventario separado; consulta de colocación compartida con ejecución; confirmación/cancelación y correlación de respuesta. Escenario integrado para recorrer especies/terrenos y jugar cartas conservando economía. Verificar el inventario y el refactor antes de ampliar gestos. Sin editor de colección ni nuevas cartas.

**B — Gestos Android y batalla completa.** Captura exclusiva, recorrido abajo, arrastre/armado arriba, previsualización, confirmación/cancelación, ratón emulado, cambio de foco y feedback de disponibilidad. Validar que navegar y desplegar no interrumpe órdenes existentes ni produce ataques/movimientos accidentales. Revisar ventanas verticales y dispositivo Android real; repetir regresiones y publicar la rama para revisión.

Tras revisión de TARS y autorización del propietario, integrar primero Fase 22 mediante el procedimiento seguro y repetir pruebas. Solo entonces crear una rama `codex/phase-23-circular-card-stacks` desde `main` actualizado. Ninguna de esas integraciones está autorizada por este plan. No integrar Fase 23 sin su propia revisión técnica y validación visual.

## Criterios de aceptación y pruebas propuestas

| Área | Casos obligatorios |
| --- | --- |
| Circularidad | Secuencia de cuatro especies reales; N avances vuelven al inicio; independencia de cuatro cursores; listas vacías/de un elemento; tipos indisponibles permanecen navegables. |
| Carta superior tras jugar | Despliegue aceptado conserva exactamente el tipo superior y los cuatro cursores; rechazo/cancelación tampoco rotan. Solo un gesto hacia abajo de esa pila cambia su índice. |
| Tipos y copias | Un tipo con tres copias ocupa una entrada; derrota/recuperación por copia no rota la pila; un tipo diferente siempre tiene identidad/etiqueta distinta. Configuración futura de catálogo no exige cambios del control. |
| Equipamiento | Solo IDs equipados/categoría válida; orden estable; rechazo de configuración inválida sin partida parcialmente inicializada. Casos futuros con dos construcciones/trucos mediante fixtures, sin añadir cartas de jugabilidad. |
| Gestos | Umbrales, arrastre horizontal, inversión de dirección, un avance por gesto largo, varios dedos, ratón emulado y captura hasta liberar; ausencia de órdenes tácticas accidentales. |
| Cancelación | Antes/durante previsualización, volver a pila, atrás, perder foco, reinicio y cambio de carta: cero gasto/consumo y cursores preservados salvo rotación explícita independiente. |
| Validación | Territorio, ocupación, reservas, restricciones de terreno/refugio/ataque activo, curación solo a propia herida; consultas no mutan y no revelan Núcleos. |
| Economía y recuperación | Preparar/navegar/rechazar no paga; confirmar válido paga una vez; dos confirmaciones no duplican; copias libres siguen utilizables mientras otra se recupera; límite exacto de recuperación; falta de esencia distinta de falta de copia. |
| Estado cambiante | Entre resaltado y tick se ocupa celda, muere objetivo, cambia esencia o disponibilidad: revalidar/rechazar sin consumo; respuesta correlacionada no cierra un borrador distinto. |
| Presentación | Cuatro pilas visibles sin cubrir tablero, lectura de especie/coste/estado, tiempo de recuperación correcto, selección táctica preservada y barra de vida visible; viewport/DPI/orientación vertical. |
| Integración | Recorrer cerdo/jabalí/caballo/gólem, cancelar, desplegar y combatir, perder una copia y usar otra, esperar recuperación, jugar terreno/construcción/truco. Economía real, sin manipular vida/esencia para aprobar el escenario. |
| Regresiones | Repetir las 19 suites de cierre de 22, arranque, determinismo de entradas aceptadas a 20 Hz y privacidad. Gestos solo en cliente; no variar resultados para acompañar animación. |

Las pruebas de Fase 23 son **propuestas, aún no escritas ni ejecutadas**. Comprobar en Godot 4.7.2 y separar eventos táctiles sintéticos de pruebas Android reales.

## Decisiones confirmadas y detalles pendientes

1. **Confirmado:** cuatro pilas independientes; abajo recorre circularmente, arriba inicia colocación; una especie distinta es una entrada y sus copias son inventario separado. Después de colocar, la misma carta permanece arriba; solo el gesto hacia abajo cambia la pila.
2. Confirmar el gesto rápido propuesto: soltar sobre tablero válido confirma; terminar el deslizamiento cerca de la pila arma para un toque posterior. Cancelación explícita siempre sin gasto.
3. Equipamiento inicial de demo: todos los tipos actuales, una entrada por tipo con sus copias existentes. Sin cuotas, selección de colección o multiplicación de entradas por copia; límites de mazo y más cartas se acuerdan aparte.
4. Admitir la limitación real de una sola construcción y un solo truco actuales; no añadir efectos nuevos para simular pilas mayores sin aprobación.

Las reglas centrales de pilas, gestos y conservación de carta superior están confirmadas. No convertir los detalles pendientes en reglas definitivas por implementación implícita. El objetivo es variedad de tipos y controles táctiles rápidos conservando la autoridad del jugador y el combate existente. No implementar estadísticas definitivas de vida ni convertir el proyecto a 3D en esta preparación.
