# Incremento 5 — preparación visual y unión de tableros

Estado: prototipo funcional aprobado por TARS tras revisar seis capturas; código auditado por Argon. Rama `codex/phase-24-preparation-join`, base `main` `3145e5260b0086c8132e188da5dd48934f6d7677`. Commit y publicación autorizados para verificación remota. La aprobación no valida el arte definitivo. Merge e Incremento 6 siguen sin autorización.

## Aprobación funcional y acabado artístico pendiente

La revisión de TARS aprueba la composición, los controles y el flujo visual como **prototipo funcional**. La presentación actual utiliza terrenos planos, criaturas simbólicas, construcciones esquemáticas y tarjetas compactas. **No es el arte definitivo de Isla del Caos ni una aprobación de ese acabado.** La dirección artística de mesa física e invocaciones holográficas sigue vigente; no se rediseña ahora el tablero ni se añaden recursos artísticos improvisados.

Se conservan los puntos de sustitución existentes: `preparation_board.gd` representa una vista filtrada sin autoridad sobre la simulación; `preparation_board_layout.gd` centraliza geometría e inversas; el coordinador y las pilas mantienen gestos, solicitudes y validación separados del dibujo. La futura implementación artística podrá sustituir esa representación conservando la frontera de privacidad, los centros visuales e hit tests compartidos, los 32 espacios lógicos y las pruebas. No se introduce ahora una nueva capa, dependencia o conversión a 3D.

En la preparación del commit solo se actualiza documentación. Se conservan sin modificaciones los scripts, escenas y las **37 suites aprobadas** respecto a la entrega auditada; se comprueban sus huellas SHA-256 antes y después del cierre documental.

## Alcance implementado

Escena independiente `scenes/preparation_demo.tscn`, para abrir con F6. F5 continúa en `battle_demo.tscn`; no se modifican escenas, scripts, guiones ni pruebas anteriores.

- Los 16 espacios propios permanecen abajo antes, durante y después de la unión. La mesa rival ocupa arriba sus 16 espacios con una cubierta uniforme, sin representar colocaciones ni actividad privada. Son las mismas 32 secciones lógicas 8×4, con presentación vertical 4×8.
- Se reutilizan las cuatro pilas, sus gestos, las fichas tácticas, el controlador de colocación, el catálogo y el feedback de batalla existentes. Durante los 600 ticks solo se pueden desplegar terrenos y construcciones propios con esencia, disponibilidad y validaciones normales. Criaturas/trucos muestran «Solo combate»; recorrer cartas o consultar una ficha no gasta ni emite órdenes.
- La cuenta regresiva usa `ceil(preparation_remaining_ticks / 20)`: comienza en 30 s, muestra 1 s en tick 599 y cambia a combate en tick 600. No hay reloj de pared ni temporizador paralelo.
- `board_joined` revela y aproxima únicamente la mesa rival. La separación de 0,4 celdas se cierra durante 12 ticks (0,6 segundos provisionales); el territorio propio no se mueve. No se altera daño, esencia, posiciones lógicas, reservas ni control. No es un desastre ni un estado extra de simulación.
- El combate y las colocaciones están disponibles desde tick 601 mientras termina la animación. Las criaturas que cruzan la separación temporal mantienen selección y detección en su centro dibujado, aunque ese punto esté entre rectángulos de celdas.
- Un cambio de disposición cancela el gesto y la colocación todavía no confirmada, sin coste ni rotación. Los resultados enviados se consumen primero: una aceptación del tick 600 conserva pago y rotación única. `request_id`, jugador y carta mantienen la correlación del controlador existente; repetir resultados o `board_joined` no repite efectos de la jugada ni la unión.
- La nueva escena activa la victoria territorial existente, ecología y defensa adyacente ya implementadas; no habilita nuevas especies conquistadoras ni añade IA. El rival de demostración prepara maizal, barro y valla mediante tres órdenes normales, coste total 4. Es una configuración fija de prueba, desactivable, sin refuerzos ni lectura de secretos humanos.

## Componentes y frontera de datos

| Archivo | Responsabilidad |
| --- | --- |
| `scripts/preparation_demo.gd` | Único coordinador con acceso a la simulación: reloj, comandos, consultas propias, consumo de vista y resultados, pilas y cambio de disposición. |
| `scripts/preparation_board.gd` | Dibujo, selección y detección sobre una copia de `get_player_view(local_player)`. No recibe ni consulta una simulación. |
| `scripts/preparation_board_layout.gd` | Geometría pura compartida por dibujo, centros, previsualización e inversas de entrada. Solo se desplaza la mitad rival. |
| `scenes/preparation_demo.tscn` | Composición independiente; no hereda los dibujos de demos que consultan colecciones completas. |

El coordinador consume la vista después de **cada tick**, incluso si un frame resuelve varios; así no pierde el evento de unión. El renderizador y el feedback reciben exclusivamente la vista filtrada. La UI consulta únicamente disponibilidad y colocaciones del jugador local. Antes de la unión no consulta objetivos ni validaciones sobre la mitad sellada; tampoco muestra esencia, disponibilidad, recuperación o equipamiento rivales. No se añaden productores de audio ni señales sonoras de actividad oculta.

La misma transformación de canvas y de mesa anima dibujo, hit tests, selección de criaturas interpoladas y previsualización. Reiniciar limpia selección, gestos, solicitudes locales, efectos, revelación y animación. El runner conserva la cadencia de 20 Hz y el límite de delta de 0,25 s del prototipo anterior.

## Pruebas y comprobaciones

Se añaden tres suites, sin modificar las 34 existentes:

1. `preparation_layout_smoke.gd`: 32 centros únicos, inversas, mitades 16/16, territorio propio fijo, separación no interactiva, fracciones 0/0,5/1, ambas perspectivas y tamaños 320×640, 360×800, 480×900, 720×1280 y 900×480.
2. `preparation_privacy_smoke.gd`: compara la presentación completa de dos escenarios con preparación rival diferente durante los ticks 1–599 y para ambos observadores. Incluye efectos, ausencia de audio, contadores, disponibilidad propia, mensajes, resaltados y hit tests de construcciones. Comprueba revelación pública en 600, privacidad económica posterior, idempotencia, reinicio y replay de todos los ticks a 20/30/120 FPS; un frame que cruza 600 no pierde el evento.
3. `preparation_presentation_smoke.gd`: toques/arrastres reales en SubViewport, terrenos/construcciones, rechazo, cancelación y coste; frontera 599/600/601; petición aceptada en 600 y respuestas repetidas; despliegue y ataque durante la unión; selección de criaturas interpoladas, incluso en la separación entre mesas; transformaciones de canvas, formato estrecho y reinicio.

**Resultados reales en Godot 4.7.2: 37/37 suites aprobadas** (34 anteriores y tres nuevas), importación sin errores y seis arranques correctos: `main`, `tactical_demo`, `battle_demo`, `battle_depth_demo`, `battle_stacks_demo` y `preparation_demo`. Tras añadir el caso de criaturas en la separación temporal se repitió la ejecución completa; la prueba de determinismo se reforzó además con colocaciones pagadas, movimiento y ataque durante la unión y volvió a pasar a 20/30/120 FPS. `git diff --check` sin errores. Se conservan los seis UID legítimos generados por Godot para los scripts nuevos y sus pruebas.

Se han renderizado e inspeccionado capturas de preparación a 480×900 y 360×800, y unión/combate a 360×800, con Godot 4.7.2 y renderer Compatibility/ANGLE. La revisión posterior de TARS de seis capturas aprueba el prototipo funcional; no valida arte definitivo ni sustituye pruebas en Android físico.

## Validación manual para Argon y Dirección Creativa

1. Abrir `scenes/preparation_demo.tscn` y ejecutar F6. F5 conserva su demo anterior.
2. Verificar mesa propia abajo, rival sellada arriba y contador inicial de 30 s. Colocar terrenos y valla con arrastre o selección/toque, comprobando esencia y giro automático tras aceptación.
3. Recorrer las pilas y comprobar que criaturas/truco siguen bloqueados. Intentar colocar arriba y cancelar un arrastre: no se paga ni gira la pila.
4. Al llegar a cero, comprobar revelación y aproximación de la mesa rival, con la propia inmóvil. Desplegar una criatura inmediatamente: el combate no espera al final de la animación.
5. Seleccionar una criatura y ordenar acercarse/atacar la valla rival con el sistema existente. Comprobar que los toques corresponden a lo dibujado y que los terrenos conservan sus secciones.
6. Reiniciar durante la unión y repetir en una ventana estrecha: no deben quedar datos revelados, efectos o gestos anteriores.

## Límites conservados

Sin barra de dominio, presentación de conquista, nuevos costes/estadísticas, cartas multisección jugables, Sol, desastres, nuevas criaturas ni IA estratégica. El rival solo prepara su disposición fija. Android físico, balance, escena de batalla completa y acabado artístico definitivo siguen pendientes. La aprobación recibida corresponde exclusivamente al prototipo funcional. Los bloqueos largos pueden alargar el tiempo de pared por el límite de delta heredado; el contador sigue siendo coherente con los ticks de simulación.

Autorizados el commit y la publicación de esta rama para verificación remota. No hacer merge ni comenzar el Incremento 6 hasta nueva autorización.
