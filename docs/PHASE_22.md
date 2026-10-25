# Fase 22 — dinamismo y profundidad de batalla

**Estado: ambos bloques autorizados por TARS y Dirección Creativa e implementados en `codex/phase-22-battle-depth`, desde `main` `1c740d6`. Revisión técnica de TARS favorable; preparación de integración autorizada. No integrados: falta confirmación definitiva del director creativo.** Base: Fase 21 integrada en `765bc8a72a8d82dbe93f1a4633c13afc24b047ff`. Se mantienen estadísticas, economía y resolución simultánea aprobadas.

**Actualización de cierre:** Dirección Creativa comunicó prueba manual positiva, sin aprobación completa. [Informe final de verificación](PHASE_22_FINAL_REVIEW.md): 19 suites, dos arranques e importación aprobados en Godot 4.7.2; nueva suite de cierre y documentación, sin cambios al código jugable de `2cda472`. Se explicitan límites de resultado de partida, reloj ante bloqueos y balance. TARS revisó favorablemente el cierre; no integrar hasta la autorización final del director creativo. Fase 23 solo tiene [diseño técnico](PHASE_23.md), sin implementación.

## Resultado y forma de entrega

Una batalla de mesa viva: criaturas que expresan su especie y reaccionan a oportunidades locales, mientras el jugador conserva autoridad sobre destinos, ataques y acciones. Sin marcha obligatoria al enemigo. Mantener cuatro especies, tres terrenos y la valla actuales, vista vertical 4×8 y simulación lógica 8×4 a 20 Hz.

Entrega de **dos bloques funcionales grandes** en una rama desde `main`, con escenario integrado, pruebas y documentación. El bloque de simulación pasó las doce suites anteriores y dos nuevas antes de conectar presentación. No integrar sin revisión de TARS y validación visual del propietario.

## Bloque 1 — ecosistema táctico y autoridad del jugador

Los comportamientos y números siguientes están aprobados provisionalmente e implementados. Reutilizan los efectos de Fase 21, conservando estadísticas y economía.

| Especie | Instinto local propuesto | Consecuencia y límite |
| --- | --- | --- |
| Cerdo | Herido y con habilidad disponible: buscar barro visible hasta 2 pasos y revolcarse. Si no hay oportunidad viable, defensa adyacente. | Cura actual de 1 HP; preparación y cooldown actuales. Prioriza recuperarse cuando puede, pero sigue recibiendo daño. |
| Caballo | Con al menos 2 HP perdidos: buscar maizal propio o neutral hasta 2 pasos y comer. | Recupera hasta 2 HP y consume una ración, conservando la liberación inmediata de la carta consumida. No consume automáticamente cultivos rivales ni gasta una ración por perder solo 1 HP; la acción manual conserva su regla. |
| Jabalí | Ante enemigo adyacente, priorizar al agresor visible más reciente de los últimos 40 ticks. Preparar embestida si está disponible; en otro caso, defenderse. | Preparación actual de 6 ticks, sin evitar daño ni perseguir. Memoria por instancia y desempate estable. No incluir aún el paso extra de represalia. |
| Gólem | Defender posición ante criaturas adyacentes; sin amenaza inmediata, demoler una valla rival adyacente. | Afinidad con construcciones usando preparación, daño y cooldown actuales. No camina por su cuenta hacia vallas lejanas ni ataca construcciones propias. |

Solo actúan sin orden explícita, acción explícita, movimiento comprometido ni refugio solicitado por el jugador. El radio mide **ruta ortogonal real**. La navegación natural permanece en la mitad territorial donde empezó; no cruza la frontera por instinto. Tras la interacción no hay paseo aleatorio, búsqueda de enemigos lejanos ni avance obligatorio.

### Control y prioridad

«Ecología» activada en el nuevo escenario y desactivable por criatura. Con los perfiles deshabilitados, conservar la defensa y resultados anteriores.

Prioridad de decisión: intención explícita válida del jugador, sea orden o acción, por encima de cualquier objetivo natural. Conservar reemplazos y rechazo de comandos explícitos contradictorios como en Fase 21. Una orden bloqueada conserva prioridad. Una nueva intención explícita cancela intención/preparación natural y libera su recurso; ninguna cancela daño aceptado ni el paso ya iniciado, que termina antes de cambiar de destino. Mantener la regla actual de no devolver el cooldown gastado por una preparación iniciada.

Agregar **«Mantener posición»** como orden explícita persistente: termina el paso actual, impide nuevos desplazamientos/interacciones naturales y permite solo defensa adyacente autorizada. «Detener orden» conserva la cancelación actual; no redefinirlo para suprimir permanentemente instintos sin aprobación. La interfaz distinguirá ambas acciones.

### Interacciones encadenadas

- Valla corta acceso a recursos; destruirla abre paso y replantea rutas reales. El jugador coordina gólem y otras criaturas.
- Caballos compiten por maizales de una ración; consumirlos cambia objetivos y disponibilidad. Sin regeneración automática del cultivo.
- Barro permite recuperación al cerdo, pero entrar sigue siendo lento: importa dónde y cuándo moverse.
- Cueva conserva entrada/salida explícitas. Los perfiles no sacan al ocupante ni le dan invulnerabilidad.
- Copias de la misma especie deciden según su propio daño, posición y amenaza; ningún estado se comparte globalmente por especie.

Reservar **intenciones** de recurso para evitar que dos criaturas naturales reclamen la misma ración. Recomendación técnica: solicitud más antigua y luego ID, sin azar. No son reservas físicas: una orden del jugador prevalece y los conflictos de movimiento siguen rechazándose como ahora. Liberar intención al morir, recibir otra orden, consumir/perder recurso o completar la interacción. Si alguien sigue ocupando barro, otros esperan o buscan alternativa; no empujarlo ni obligarlo a salir.

Escenario integrado: recursos en ambos flancos, paso corto con barro, otro bloqueado por valla y refugio accesible. Ambos bandos usan la misma economía y reglas; los objetivos explícitos rivales siguen guionizados, sin estratega omnisciente.

## Bloque 2 — impacto, lectura y órdenes rápidas

### Respuesta visual ligada a eventos

- Identidad 2D provisional y orientación por especie; señales distintas para embestida, demolición, comer y revolcarse. Sin modelos 3D definitivos.
- Golpe direccional, impacto, destello de daño, barras legibles y transición breve de derrota. Animación de desplazamiento y aviso de ruta/obstáculo.
- Preparación, cancelación y cooldown reconocibles; estados entrando/refugiado/saliendo claros.
- Mostrar explicaciones como «Instinto: busca barro», «Maizal ocupado» y «Objetivo perdido» junto a la criatura seleccionada; nada de códigos internos.

El daño normal sigue resolviéndose en el tick aceptado. Una animación posterior no puede retrasarlo, cancelarlo ni añadir empuje, aturdimiento o invulnerabilidad. Anticipación con efecto mecánico solo en preparaciones existentes. Selección, miniatura y barra comparten la posición visual aparente durante animaciones.

### Órdenes contextuales

Consulta pura en simulación para acciones disponibles y motivo de indisponibilidad; la interfaz no duplica reglas. Tocar recurso ofrece su acción, rival conserva ataque dirigido y suelo conserva navegación. Mantener posición/desactivar ecología accesibles sin tapar la batalla.

**«Ir y actuar»** se aproxima y ejecuta una acción existente: revolcarse, comer, entrar en cueva o demoler una valla; también admite preparación local y salida explícita. Si desaparece el destino, cancelar con explicación; no buscar otra víctima. Respetar pasos y daño aceptados. Esto evita exigir un clic durante la corta ventana de adyacencia.

No reanudar órdenes antiguas tras demoler por inferencia. Recomiendo dejar «Abrir paso y continuar» fuera del primer alcance: requeriría almacenar y mostrar un destino de continuación como parte de una orden explícita.

## Arquitectura implementada

| Pieza | Cambio previsto |
| --- | --- |
| `natural_intents.gd` (nuevo) | Perfiles, memoria de amenaza e intenciones de recursos por instancia; no escribe posiciones/daño/esencia. |
| `natural_defense.gd` | Conservar defensa base y compartir selección de objetivos con perfiles. |
| `tactical_orders.gd` | Reutilizar rutas para fuentes explícitas/naturales separadas; nuevos objetivos mantener/ir y actuar tras aprobarlos. |
| `context_actions.gd` | Reutilizar acciones con origen de solicitud explícito/natural; cancelación y liberación coherentes. |
| `simulation.gd` | Arbitrar prioridades por tick, registrar fuente/objetivo de golpes y limpiar por instancia; planificación sin datos de Núcleos ocultos. |
| `battle_feedback.gd` (nuevo) | Animaciones y señales por eventos, con límites de efectos simultáneos; ninguna regla de juego. |
| `battle_depth_demo.gd` y nueva escena | Controles, consultas contextuales y escenario integrado; `battle_demo.gd` solo añade hooks con comportamiento anterior por defecto. F5 conserva la demo aprobada. |

Sin segundo motor de movimiento, otro pathfinder ni dependencias externas. Se mantienen `movement.gd` y adaptador 4×8. Decisiones en ticks enteros: buscar objetivos cada 4 ticks o ante cambios públicos de unidades/terrenos/construcciones, conservando defensa/ataques en su frecuencia actual. Orden explícita entra al siguiente tick sin esperar el intervalo natural. Reintento tras ruta natural bloqueada: 20 ticks configurables; no roba prioridad a una orden explícita.

## Criterios de aceptación

- Repetir las 12 suites de Fase 21; con perfiles desactivados conservar resultados y economía.
- Especie: elegibilidad, radio, frontera, prioridades, ausencia de marcha, habilidad en cooldown, muerte en preparación y cancelación por jugador.
- Instancia: copias de una especie con objetivos/recuperación distintos, sin estado compartido.
- Recursos: dos solicitantes, consumo por otra orden, liberación por muerte/orden, barro ocupado y maizal propio/neutral/rival.
- Autoridad: orden bloqueada no cede al instinto; mantener persiste; refugio no se abandona; no borrar paso/daño aceptado al cambiar de objetivo.
- Determinismo: mismo registro de entradas con distintos FPS produce estados/eventos iguales; invertir comandos donde se promete independencia de orden.
- Privacidad: cambiar Núcleo rival oculto no cambia rutas, decisiones, explicaciones ni eventos observables de ecología.
- Presentación: preparación/impacto/cancelación alineados, efectos limitados, selección durante animación, ventana estrecha y toque sin duplicación.
- Batalla completa con economía real: abrir acceso, disputar recurso, recuperar criatura, mantener posición y sustituir instinto con orden explícita. Sin manipular vida, posiciones o esencia para pasar el test.
- Godot 4.7.2: suites, arranque y revisión visual. Medir rendimiento y probar Android real antes de afirmar validación de dispositivo.

Resultados ejecutados y límites de validación registrados abajo; la aprobación visual del propietario sigue pendiente.

## Decisiones importantes aprobadas para este prototipo

1. Búsqueda natural hasta 2 pasos sin cruzar frontera; umbrales de heridas, recursos propios/neutrales y uso automático de habilidades/cooldowns existentes.
2. Jabalí: último agresor durante 40 ticks y preparación automática; sin persecución ni paso extra de represalia.
3. Gólem: demolición natural adyacente cuando no hay amenaza inmediata.
4. Ecología activada en el nuevo escenario, control por criatura y «Mantener posición» persistente, conservando el «Detener orden» actual.
5. «Ir y actuar» como orden explícita compuesta, sin continuación oculta de objetivos antiguos.

Conservar estadísticas, costes, recuperación por copia, seis ticks de movimiento, barro ×2, cueva y HP de valla. El bonus de demolición frente a valla de cuatro HP sigue siendo provisional: cambiar número de golpes o añadir efectos físicos requiere decisión aparte.

Fuera de alcance: especies/cartas nuevas, cultivos que regeneran automáticamente, descubrimiento del Núcleo, PvP, desastres, construcciones completas, empujes/aturdimientos y 3D definitivo.

## Presentación y dirección artística aprobadas

Destino artístico: **mesa física tridimensional + criaturas, construcciones y ecosistemas invocados como hologramas mágicos a todo color**. Conservar colores originales, transparencia ligera, fantasía cartoon y orientación vertical. Invocaciones emergentes desde el suelo; construcciones y terrenos holográficos diferenciados de la mesa física.

Esta entrega conserva recursos 2D provisionales. Las figuras de cerdo, jabalí, caballo y gólem tienen siluetas/colores distintos y poses de movimiento, revolcarse, comer, preparar embestida y demoler. La ligera transparencia es una referencia provisional, no un shader holográfico terminado. No sustituye la demo anterior ni implementa 3D definitivo.

`attack_accepted` describe cada golpe aceptado con emisor, receptor, especie, fuente, posición, acción y daño. No retrasa el daño. `battle_feedback.gd` consume exclusivamente la vista de observador: genera poses, destellos, trazas, impacto, aparición y transición de derrota. Puede sustituirse por un renderizador 3D sin introducir reglas en los efectos. Máximo 64 efectos y una memoria por actor vivo; los efectos expiran, las entradas del mismo tick no se duplican y el reinicio limpia todo. La barra de vida y selección usan el mismo centro aparente que la figura durante movimiento y embestida.

Interfaz futura **solo documentada**: nombres/avatares en las esquinas superiores; debajo, barra horizontal de dominio PvP que desplaza la ventaja contraria, sin afirmar una probabilidad estadística de victoria. Cuatro categorías inferiores —criaturas, terrenos, construcciones y habilidades/trucos— con una pila accesible bajo cada principal. El tablero domina la composición. No se implementan todavía estas pilas definitivas, barra PvP, avatares ni PvP real.

## Escena de revisión y controles

Abrir `scenes/battle_depth_demo.tscn` en Godot 4.7.2 y ejecutar **F6**. **F5 sigue abriendo `scenes/battle_demo.tscn` de Fase 21**. Desde consola: `godot --path . res://scenes/battle_depth_demo.tscn`.

- Cartas, selección, navegación, atacar rivales y vallas conservan los gestos anteriores.
- **Mantener:** orden persistente; termina el paso comprometido y defiende adyacentes sin iniciar viajes naturales. **Detener:** cancela orden/preparación y vuelve a permitir ecología.
- **Ecología sí/no:** estado independiente de la copia seleccionada. Desactivar perfiles conserva defensa adyacente básica; no deja a la criatura indefensa ni cancela órdenes del jugador.
- **Ir y actuar:** activar y tocar recurso o valla compatible. Consulta pura de simulación, aproxima y ejecuta; si hay cooldown espera, si se pierde el recurso termina con explicación. Otro toque en el botón cancela el modo; jugar carta también lo cancela.
- Información del seleccionado explica instinto, orden, refugio o recurso ocupado. Ruta explícita amarilla, natural verde; destino bloqueado marcado en rojo. Preparación, cooldown, daño, recuperación de copia y derrota tienen señales separadas.

Recursos en ambos flancos, barro frontal y cueva local. Un cerdo rival recibe una orden guionizada al flanco; el otro conserva su posición. Los refuerzos de valla y jabalí pagan la misma esencia que antes. No hay estratega rival ni marcha universal. Prueba rápida: desplegar cerdo en el barro de la fila local junto a la frontera para observar heridas/recuperación; usar caballo herido con maizal; desplegar gólem para abrir una valla con «Ir y actuar». Los instintos sanos descansan, no viajan para animar artificialmente el escenario.

## Verificación realizada en Godot 4.7.2

**18 suites aprobadas**, sin errores de scripts: las 12 previas (`board_coordinates`, `presentation`, `simulation`, `movement`, `movement_presentation`, `tactical_orders`, `tactical_presentation`, `ecology`, `context_actions`, `battle_systems`, `battle_presentation`, `battle_scenario`) y estas seis nuevas. Todos los archivos terminan en `_smoke.gd` dentro de `tests/`.

| Suite nueva | Evidencia comprobada |
| --- | --- |
| `natural_intents_smoke` | Cuatro perfiles, heridas/cooldowns/descanso, recursos propios/neutrales/rivales, radio de ruta, frontera, copias y competencia, liberación por orden/muerte, refugio, autoridad de orden bloqueada, toggle por propietario, memoria de agresor, Núcleo oculto. Daño letal en trayecto natural y cancelación de preparación sin curar ni devolver cooldown. |
| `context_orders_smoke` | Consultas puras con control de propietario, ir/comer/demoler/refugiarse/salir, pérdida de recurso durante paso comprometido, mantener y bloqueo del intercambio de terreno bajo ataque de un defensor en mantener. |
| `battle_feedback_smoke` | Eventos de observador sin mutación, impacto direccional, poses distintas, fantasma de derrota sin unidad viva, límite y caducidad de efectos, deduplicación y reinicio. |
| `battle_depth_presentation_smoke` | Toque, cartas, mantener/toggle, ir y actuar, refugio, selección en centro animado, independencia de render, reinicio y ventana vertical estrecha; F5 anterior conservado. |
| `battle_depth_determinism_smoke` | Replay de estados/eventos a 20/30/120 FPS y conflictos simultáneos con entradas invertidas. |
| `battle_depth_scenario_smoke` | Batalla integrada con economía real, sin escribir vida/posición/esencia: heridas en combate, recuperación natural, intervención para mantener y gólem pagado que abre acceso con ir y demoler. Sin daño ni descubrimiento del Núcleo. |

Importación de editor y arranque de escenas comprobados. Capturas renderizadas en formatos verticales 480×900 y 360×800 revisadas por el implementador, sin solapamiento de tablero y controles. El controlador gráfico local utiliza la alternativa ANGLE indicada por Godot. Esto no constituye aprobación visual del propietario ni una prueba en Android.

## Límites y revisión pendiente

- Parámetros naturales configurables (`radius=2`, `decision_interval=4`, `threat_ticks=40`, `blocked_retry_ticks=20`); ecología desactivada por defecto en la simulación para conservar demos/suites anteriores, activada solo en la nueva escena. Defensa básica tiene su configuración separada.
- El terreno inicial del escenario es neutral; las cartas jugadas conservan propiedad/disponibilidad y economía anteriores. Los tests unitarios usan fixtures de heridas/posición donde se indica; el escenario integrado no utiliza esas alteraciones.
- No hay cultivo regenerativo, movimiento sin propósito, salida automática del barro, continuación oculta tras demolición ni selección estratégica de objetivos distantes. Un recurso ocupado se espera o se elige otro; los conflictos físicos siguen rechazando todas las solicitudes en disputa.
- Sin cambios en `movement.gd`, estadísticas, daños, esencia, recuperación por copia, cueva ni descubrimiento del Núcleo. «Mantener» participa en la comprobación existente de ataque activo para no permitir intercambios que la defensa anterior bloqueaba.
- Revisión técnica de TARS favorable. Pendientes: confirmación definitiva del director creativo, tacto/rendimiento en Android real y balance de perfiles. Conservar estadísticas provisionales y limitaciones del Núcleo. No integrar en `main` hasta recibir aprobación definitiva.
