# Fase 23 — ajustes surgidos de la prueba jugable

Informe de la entrega `9796ddb` en `codex/phase-23-circular-card-stacks`, sobre corrección `14193bb` y base main `597757d`. El director creativo autorizó sustituir la antigua retención de carta superior por rotación automática tras aceptación y reverso informativo. **Cierre posterior:** TARS revisó favorablemente la entrega y el director creativo aceptó la demo actual y autorizó integrar la Fase 23 en main. Las 27 suites volvieron a pasar antes de fusionar; código integrado idéntico al aprobado, con historial preservado y sin conflictos. Registro en [PHASE_23.md](PHASE_23.md#cierre-de-integración).

## Cambios realizados

- `card_placement_controller.gd`: entrega una aceptación solo si corresponde al jugador, `request_id` y carta del borrador enviado. Limpia el borrador antes de devolverlo: repetir el evento no vuelve a producir una aceptación local. Rechazo permite corregir sin rotación; aceptación del tick final se procesa antes de limpiar por fin de partida.
- `battle_stacks_demo.gd`: consume esa entrega y avanza exclusivamente su categoría. No cambia equipamiento; la usada pasa al final del recorrido circular. Cursores independientes; en longitud uno permanece la misma carta con disponibilidad actualizada. Arrastre, previsualización, envío, rechazo, cancelación, muerte y recuperación no avanzan.
- `card_stack_gesture.gd`, `card_stacks_panel.gd`: izquierda abre reverso, derecha frente. Umbrales configurables vertical 48/horizontal 32 unidades de viewport, predominio 1,3, primer eje fijado. Verticales conservan recorrido/colocación; diagonales ambiguas no ejecutan acciones. Captura de un dedo y filtro de ratón emulado conservados.
- `card_stack_control.gd` y su escena: frente con nombre, coste, disponibilidad y rasgo breve verificado. Solo 12 unidades adicionales de alto en la fila; conserva los cuatro controles y el tablero vertical.
- `card_tactical_sheet.gd`: reverso ampliado, opaco y desplazable sobre parte inferior del tablero; función, acción/instinto, ventaja y desventaja, texto de 14 unidades. Scroll táctil directo, sin depender de emulación de ratón, con captura para impedir fugas al tablero/cartas. Una ficha a la vez, accesos de pila libres; derecha sobre su carta o Cerrar devuelve el frente. Abrir abandona únicamente un borrador sin confirmar, sin cambiar selección ni órdenes. Bloqueo breve de controles durante confirmación conservado.
- `battle_catalog.gd`: textos informativos; no se cambian entradas, costes o reglas. Si falta información, campos «Pendiente de definición» y ningún rasgo inventado. `GEMINI.md`, `ROADMAP.md`, `PHASE_23.md` y el informe anterior reflejan la decisión vigente.

La simulación, movimiento, instintos, acciones especiales, combate y economía no se modifican en esta entrega. Sigue existiendo una auténtica por especie/jugador: activa o recuperándose impide otro despliegue sin gastar. Se conservan cooldowns, esencia, HP, daño, recuperación, reservas y Núcleo oculto. Sin cartas nuevas, dependencias, estadísticas definitivas o 3D. Eco del Caos sigue únicamente como diseño futuro.

## Procedencia de la información táctica

Los textos de `Catalog.TACTICS` describen estas reglas ya implementadas; el combate nunca lee esas descripciones:

| Cartas | Fuente y contenido verificado |
| --- | --- |
| Cerdo / caballo | `natural_intents.gd` y `context_actions.gd`: búsqueda contextual sin orden explícita, barro/maíz, heridas y recuperación de vida; caballo busca con al menos dos HP perdidos y consume una ración. |
| Jabalí / gólem | Mismos controladores: preparar carga para siguiente golpe y demolición contra valla adyacente; preparación, interrupción y cooldown existentes. |
| Maizal / barro | `context_actions.gd`, `terrain_effects.gd`, `battle_cards.gd`: consumo de ración/liberación, curación contextual, entrada lenta para todas las criaturas. |
| Cueva | `context_actions.gd`, `simulation.gd`: preparación de entrada/salida, reducción sin invulnerabilidad, prohibición de ataque dentro y salida por orden explícita. |
| Valla / curación | `battle_cards.gd`, `simulation.gd`: bloqueo de celda, construcción atacable y recuperación por destrucción; curación de propia herida hasta máximo, reutilizable pagando esencia. |

## Pruebas ejecutadas

Godot `4.7.2.stable.official.ed1daf0bf`: **27/27 suites aprobadas**, salida correcta, marcador `PASS:` y ausencia de `SCRIPT ERROR`/`ERROR:`. Incluye todas las 25 suites previas y:

| Suite | Casos |
| --- | --- |
| `card_rotation_smoke.gd` | Avance solo tras aceptación; envío/preview/cancelación/rechazo local y en tick; respuesta duplicada/replay sin segundo gasto o avance; jugador/carta incorrectos; categorías independientes; pila de una carta disponible/no disponible; aceptación en tick final. |
| `card_info_smoke.gd` | Nueve fichas verificadas, fallback pendiente e independencia de diccionarios; GUI izquierda/derecha, diagonal/gesto corto, arriba/abajo desde reverso; sin pausa/gasto/órdenes/selección; aislamiento de toques en ficha; activo/recuperando; batalla continúa y recuperación actualiza estado; texto/scroll y límites 360×800. |

Adaptadas las expectativas antiguas de retención en presentación/escenario. El modelo puro conserva la separación: avanzar exige consumir el resultado en el coordinador, la simulación sola no modifica cursores. El escenario usa las nueve cartas con economía, combate, daño y recuperación reales; verifica en cada tick avance solo por aceptación y equipamiento estable. Las regresiones de auténtica única siguen cubriendo ambos jugadores, rechazo activo/recuperando sin gasto y límite exacto de recuperación.

Problemas detectados y corregidos durante validación: el fondo inicial de la ficha dejaba transparentar el tablero y dificultaba leer; ahora es opaco. La prueba de scroll táctil directo no respondía sin emulación de ratón; se añadió captura nativa limitada al área de texto y se comprobó que desplaza contenido sin rotar ni iniciar colocación. Sin cambios de jugabilidad para resolverlos.

Importación del editor y arranques de `battle_demo.tscn`, `battle_depth_demo.tscn`, `battle_stacks_demo.tscn` y `tactical_demo.tscn`: **4/4 sin errores de scripts**. Ejecución gráfica con capturas de frente/reverso y scroll a 480×900 y 360×800 revisadas por el implementador. Windows avisa de OpenGL y usa ANGLE; el arranque gráfico finaliza correctamente. Las capturas son evidencia local, no activos añadidos al repositorio.

## Revisión visual propuesta

1. Abrir `scenes/battle_stacks_demo.tscn` en Godot 4.7.2, **F6**. F5 sigue en la demo anterior.
2. Desplegar cerdo en una casilla inferior libre: esencia 4→2 y pila pasa a jabalí. Tres gestos abajo vuelven a cerdo; aparece Desplegada y no admite otro ni cobra.
3. Iniciar y cancelar una colocación, o intentar celda ocupada/rival: sin gasto ni avance. Comprobar que las otras tres pilas conservan su cursor.
4. Izquierda sobre cada carta: ficha táctica y combate activo. Leer desplazando el contenido; derecha sobre la carta o Cerrar vuelve al frente. Arriba sigue colocando y abajo recorriendo. Comprobar que consultar no cambia selección ni órdenes de criatura.
5. Tras derrota, volver a la especie: Recuperando y contador; no invocar hasta Disponible. Morir/recuperar no avanza. Valla/Curación son pilas de longitud uno y conservan tipo, con sus restricciones anteriores.

## Limitaciones conservadas tras la aprobación

UI y arte provisionales. La ficha ocupa parte inferior del tablero mientras se consulta; cerrarla restituye visibilidad sin pausa. Umbrales, tamaño de dedo, scroll y rendimiento deben validarse en Android físico. No se genera APK/AAB; no hay exportación Android versionada. Primero validar en editor; los eventos táctiles sintéticos y las capturas de escritorio no certifican una prueba móvil.

Se mantienen las limitaciones documentadas: Núcleo rival sin descubrimiento real, resultado por vida de Núcleos, desempate por fuerza/control pendiente, balance provisional y límite de delta de reloj ante bloqueos largos. Textos informativos requieren mantenimiento si se autorizan cambios posteriores de reglas. La ventana actual queda aceptada; sustituirla por reverso integrado en carta con giro queda para una futura fase visual. Fase 24 no iniciada ni implementada; alcance por planificar aparte.
