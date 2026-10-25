# Fase 22 — propuesta de dinamismo y profundidad de batalla

**Estado: propuesta pendiente de aprobación de alcance. No implementada.** Base: Fase 21 integrada en `765bc8a72a8d82dbe93f1a4633c13afc24b047ff`, aprobada por TARS y validada visualmente por el propietario. Doce suites y arranque verificados en Godot 4.7.2; la integración conserva el código de jugabilidad aprobado.

## Resultado y forma de entrega

Una batalla de mesa viva: criaturas que expresan su especie y reaccionan a oportunidades locales, mientras el jugador conserva autoridad sobre destinos, ataques y acciones. Sin marcha obligatoria al enemigo. Mantener cuatro especies, tres terrenos y la valla actuales, vista vertical 4×8 y simulación lógica 8×4 a 20 Hz.

Entregar **dos bloques funcionales grandes**, cada uno con escenario integrado, pruebas y documentación. La división permite validar resultados completos, sin pedir aprobación de cada refactor. Crear rama desde `main` solo cuando se apruebe el alcance. No integrar sin revisión de TARS y validación visual del propietario.

## Bloque 1 — ecosistema táctico y autoridad del jugador

Los comportamientos y números siguientes son recomendaciones para aprobar, no reglas ya aceptadas. Reutilizan los efectos de Fase 21, conservando estadísticas y economía.

| Especie | Instinto local propuesto | Consecuencia y límite |
| --- | --- | --- |
| Cerdo | Herido y con habilidad disponible: buscar barro visible hasta 2 pasos y revolcarse. Si no hay oportunidad viable, defensa adyacente. | Cura actual de 1 HP; preparación y cooldown actuales. Prioriza recuperarse cuando puede, pero sigue recibiendo daño. |
| Caballo | Con al menos 2 HP perdidos: buscar maizal propio o neutral hasta 2 pasos y comer. | Recupera hasta 2 HP y consume una ración, conservando la liberación inmediata de la carta consumida. No consume automáticamente cultivos rivales ni gasta una ración por perder solo 1 HP; la acción manual conserva su regla. |
| Jabalí | Ante enemigo adyacente, priorizar al agresor visible más reciente de los últimos 40 ticks. Preparar embestida si está disponible; en otro caso, defenderse. | Preparación actual de 6 ticks, sin evitar daño ni perseguir. Memoria por instancia y desempate estable. No incluir aún el paso extra de represalia. |
| Gólem | Defender posición ante criaturas adyacentes; sin amenaza inmediata, demoler una valla rival adyacente. | Afinidad con construcciones usando preparación, daño y cooldown actuales. No camina por su cuenta hacia vallas lejanas ni ataca construcciones propias. |

Solo actúan sin orden explícita, acción explícita, movimiento comprometido ni refugio solicitado por el jugador. El radio mide **ruta ortogonal real**. La navegación natural permanece en la mitad territorial donde empezó; no cruza la frontera por instinto. Tras la interacción no hay paseo aleatorio, búsqueda de enemigos lejanos ni avance obligatorio.

### Control y prioridad

Recomendación para aprobar: «Ecología» activada en el nuevo escenario y desactivable por criatura. Con los perfiles deshabilitados, conservar la defensa y resultados anteriores.

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

Propuesta para aprobar: **«Ir y actuar»** se aproxima y ejecuta una acción existente: comer, entrar en cueva o demoler una valla. Si desaparece el destino, cancelar con explicación; no buscar otra víctima. Respetar pasos y daño aceptados. Esto evita exigir un clic durante la corta ventana de adyacencia.

No reanudar órdenes antiguas tras demoler por inferencia. Recomiendo dejar «Abrir paso y continuar» fuera del primer alcance: requeriría almacenar y mostrar un destino de continuación como parte de una orden explícita.

## Arquitectura propuesta, sin implementación

| Pieza | Cambio previsto |
| --- | --- |
| `natural_intents.gd` (nuevo) | Perfiles, memoria de amenaza e intenciones de recursos por instancia; no escribe posiciones/daño/esencia. |
| `natural_defense.gd` | Conservar defensa base y compartir selección de objetivos con perfiles. |
| `tactical_orders.gd` | Reutilizar rutas para fuentes explícitas/naturales separadas; nuevos objetivos mantener/ir y actuar tras aprobarlos. |
| `context_actions.gd` | Reutilizar acciones con origen de solicitud explícito/natural; cancelación y liberación coherentes. |
| `simulation.gd` | Arbitrar prioridades por tick, registrar fuente/objetivo de golpes y limpiar por instancia; planificación sin datos de Núcleos ocultos. |
| `battle_feedback.gd` (nuevo) | Animaciones y señales por eventos, con límites de efectos simultáneos; ninguna regla de juego. |
| `battle_demo.gd` y escena | Controles, consultas contextuales y escenario integrado. |

Sin segundo motor de movimiento, otro pathfinder ni dependencias externas. Mantener `movement.gd` y adaptador 4×8. Decisiones en ticks enteros; propuesta técnica: buscar objetivos cada 4 ticks o ante eventos relevantes, conservando defensa/ataques en su frecuencia actual. Orden explícita entra al siguiente tick sin esperar el intervalo natural.

## Aceptación y pruebas propuestas

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

Estas pruebas de Fase 22 están propuestas, **no implementadas ni ejecutadas**. Cada bloque entrega una batalla verificable, no APIs aisladas.

## Decisiones importantes para aprobar

1. Búsqueda natural hasta 2 pasos sin cruzar frontera; umbrales de heridas, recursos propios/neutrales y uso automático de habilidades/cooldowns existentes.
2. Jabalí: último agresor durante 40 ticks y preparación automática; sin persecución ni paso extra de represalia.
3. Gólem: demolición natural adyacente cuando no hay amenaza inmediata.
4. Ecología activada en el nuevo escenario, control por criatura y «Mantener posición» persistente, conservando el «Detener orden» actual.
5. «Ir y actuar» como orden explícita compuesta, sin continuación oculta de objetivos antiguos.

Conservar estadísticas, costes, recuperación por copia, seis ticks de movimiento, barro ×2, cueva y HP de valla. El bonus de demolición frente a valla de cuatro HP sigue siendo provisional: cambiar número de golpes o añadir efectos físicos requiere decisión aparte.

Fuera de alcance: especies/cartas nuevas, cultivos que regeneran automáticamente, descubrimiento del Núcleo, PvP, desastres, construcciones completas, empujes/aturdimientos y 3D definitivo.
