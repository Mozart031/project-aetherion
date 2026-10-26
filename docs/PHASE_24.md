# Fase 24 — batalla completa por dominio territorial

**Estado: documentación actualizada; sin implementación ni rama de Fase 24.** Base: Fase 23.1 integrada en main en `0795d76`, versión de funcionalidad `3fc4827`. Las decisiones de dominio, identidad visual, Sol y desastres indicadas abajo están acordadas como diseño. Los detalles pendientes y la arquitectura propuesta requieren revisión; este documento no autoriza programarlos.

## Objetivo y límites

Una batalla completa y dinámica contra un rival del juego, centrada en conquistar y conservar territorio. **El dominio territorial sustituye el enfoque de victoria por descubrir/destruir el Núcleo.** La barra representa control del tablero, no probabilidad de victoria. El papel futuro del Núcleo no se redefine aquí; sus datos/código y privacidad actuales permanecen como legado compatible, sin exigir nuevas mecánicas de descubrimiento para esta fase.

Se conservan 20 Hz, combate simultáneo, movimiento y reservas, esencia y costes de cartas existentes, auténtica única por especie/jugador, recuperación individual, cuatro pilas y prioridad de órdenes explícitas. Las reglas nuevas de conquista, resistencia, restauración y Sol no deben recibir valores de balance inventados.

Las exclusiones anteriores de desastres, cartas nuevas e interfaz de resultado se sustituyen únicamente por el diseño ahora acordado: desastres/última resistencia, Sol y tres trucos diferentes, barra/bordes/presión territorial y presentación final. No se inventan los trucos que faltan ni se programa ninguno. Sin torres emergentes, Eco del Caos, nuevas criaturas, estadísticas definitivas, red, 3D o rediseño general. Ventana informativa provisional aceptada; giro integrado en carta reservado para una fase visual futura. Distinguir normales/clasificatorias no autoriza implementar PvP, red o matchmaking.

## Reglas de dominio acordadas

| Área | Decisión aprobada |
| --- | --- |
| Dominio compartido | Una barra muestra los porcentajes de control territorial de ambos jugadores. Fórmula, pesos, denominador y umbral de victoria pendientes. |
| Identidad | Amatista `#AA65F5` y oro arcano `#E5C65D`. Los terrenos mantienen sus colores naturales; bordes luminosos discretos indican su controlador. No decidir aquí la asignación fija de color a índices de jugador. |
| Conquista | Atravesar no conquista. Un territorio indefenso admite ocupación rápida; uno defendido exige superar su resistencia. El control persiste cuando la criatura se marcha. «Rápida» no fija un número de ticks. |
| Simultaneidad | Ambos jugadores pueden atacar, defender, restaurar, conquistar y usar cartas mientras continúan otras acciones. No introducir turnos globales ni pausar combate para ocupar. |
| Daño y devastación | Dañar no conquista. El terreno devastado conserva su controlador hasta que el rival actúe para conquistarlo. Separar pérdida de recurso, estado ecológico y transferencia de control. |
| Sol | Cada jugador equipa tres trucos diferentes. Sol revela aleatoriamente una de esas tres cartas rivales, sin desactivarla ni cambiar su disponibilidad. No revela automáticamente el resto del equipamiento o su recuperación. |
| Desastres por modo | En normales pueden aparecer de forma impredecible; en clasificatorias el desastre principal se reserva para la fase final. No se fijan frecuencia, probabilidades, tipos o eventos menores de clasificatorias. |
| Efectos del desastre | Puede dañar recursos, criaturas y defensas, pero nunca cambia automáticamente el controlador territorial. |
| Última resistencia | El desastre final abre una fase jugable con oportunidades de remontada; su activación no es por sí sola el final de partida. |
| Resultado y presión | Al resolverse la partida, la barra se desplaza al centro y presenta victoria o derrota. Dominio elevado produce presión visual sutil, sin bonificaciones de combate implícitas. Umbral visual por concretar. |

## Decisiones pendientes: no tratarlas como reglas implementables

- Umbral y tiempo de mantenimiento para victoria anticipada; interrupciones y qué sucede con condiciones simultáneas de victoria.
- Duración máxima y duración/activación de última resistencia. Los 12000 ticks actuales, los diez minutos y la meta histórica 5–8 minutos no se ratifican como valores de esta nueva modalidad.
- Porcentajes en terrenos de diferente tamaño: qué superficie puntúa, ponderación, denominador, territorio neutral/no asignado, zonas disputadas, solapamientos y distribución inicial. No asumir 50/50 ni normalizar solo lo conquistado sin aprobación.
- Resolución de empates. No reutilizar vida del Núcleo como desempate por inercia.
- Detalles de ocupación y defensas: qué cuenta como indefenso/defendido, resistencia, alcance/posición para ocupar, costes si los hubiera, progreso/interrupción, recuperación de resistencia y conflictos simultáneos. Llegar o eliminar una defensa no debe convertirse por defecto en captura automática.
- Relación entre control conquistado y regiones legales de despliegue/consumo de recursos. No cambiar silenciosamente las restricciones actuales de invocación o el comportamiento del caballo por cambiar el controlador.
- Restauración: qué se restaura, quién puede hacerlo y sus requisitos/tiempos/efectos. La capacidad simultánea está acordada; no existen aún parámetros aprobados para implementarla.
- Sol: ubicación en el equipamiento —si forma parte de los tres trucos o tiene otro acceso—, coste/reutilización, elección entre cartas ya reveladas/no reveladas, duración del conocimiento y destinatarios de notificaciones. Los otros trucos necesarios requieren diseño; no rellenar el catálogo con efectos inventados.
- Desastres: calendario por modo, avisos, selección, áreas/efectos y forma concreta de crear oportunidades de remontada. No añadir multiplicadores, conquistas gratuitas o ayuda oculta al perdedor.

Estos puntos son dependencias de diseño: una propuesta técnica no los convierte en aprobados.

## Decisión aprobada — interacción desde cualquier posición válida

El jugador puede emitir una orden de interacción compatible desde cualquier posición válida de su criatura. La simulación dirige el desplazamiento y ejecuta automáticamente la acción al llegar a la posición requerida, sin solicitar una segunda confirmación.

| Interacción existente | Posición de ejecución que se conserva |
| --- | --- |
| Entrar en una cueva | Llegar a la celda de cueva y completar la preparación de entrada existente. |
| Comer maíz con caballo compatible y herido | Llegar al maizal, completar la acción existente y consumir la ración. |
| Revolcarse con cerdo compatible y herido | Llegar al barro y ejecutar la acción existente. |
| Demoler una construcción rival con gólem | Aproximarse a una celda adyacente válida y ejecutar la demolición existente. No entrar en una construcción que bloquea movimiento. |
| Atacar criatura/construcción | Mantener aproximación y alcance adyacente de la orden dirigida existente. |

«Cualquier posición válida» elimina la exigencia de estar ya junto al recurso para emitir la orden; no elimina compatibilidad, heridas requeridas, propiedad cuando corresponda, rutas, obstáculos, reservas, cooldowns, salida de refugio o reglas de combate. Esta tabla conserva acciones ya existentes. Las nuevas acciones de conquista/restauración se diseñan aparte; no se deducen aquí habilidades de reparar o capturar construcciones.

Una sola orden aceptada conserva el objetivo y la acción hasta ejecutarse, cancelarse/reemplazarse válidamente o perder su objetivo. La preparación no es una segunda confirmación. No se ejecuta automáticamente una habilidad distinta por llegar cerca de un objeto sin haber recibido esa orden.

## Base real que se reutiliza

- `queue_act_at`, `TacticalOrders` con `act_at`, `ContextActions.plan/start` y la interfaz «Ir y actuar» ya permiten varios desplazamientos con ejecución automática al llegar. `context_orders_smoke.gd` cubre maíz distante, demolición desde lejos, cueva y pérdida de recurso. No reiniciar esta implementación.
- Conservar ruta ortogonal y ocupación/reservas, preparación/cooldowns, daño simultáneo y estado `blocked`. Si no hay ruta, la orden explícita mantiene su prioridad y no provoca teletransporte; podrá avanzar al abrirse una ruta, o el jugador podrá cambiarla/detenerla, como ahora.
- Si el recurso o construcción desaparece, terminar con motivo comprensible sin reactivar órdenes antiguas; completar un paso ya comprometido y conservar daño aceptado. Si cambia la disponibilidad de la acción durante el trayecto, revalidar con las reglas existentes. No crear costes o reintentos con beneficios gratuitos.
- El objetivo del primer bloque es consolidar acceso contextual y verificar casos límite, incluidos órdenes durante movimiento y refugio, ejecución una vez, espera de cooldown y cancelación. El gesto concreto de entrada debe aprovechar los controles actuales sin rediseño general ni añadir confirmación al llegar.

## Estado del resto de la partida

| Sistema | Base disponible y trabajo pendiente |
| --- | --- |
| Economía/cartas | Esencia y costes actuales; cuatro pilas, rotación por aceptación, auténtica única y recuperación. Reutilizar sin cambios de balance. |
| Combate/ecología | Ataques dirigidos y simultáneos, acciones con preparación, perfiles naturales, mantener/ecología por instancia. La estrategia rival es una capa distinta. |
| Privacidad | 23.1 filtra estado/eventos por observador y publica propiedad de terrenos presentes. IA solo recibe su vista; no estado crudo ni cola humana pendiente. |
| Rival actual | Invocación inicial y refuerzos/ruta prefijados, pagados. Falta un controlador de decisiones. |
| Territorio | `terrain_owners` registra autoría/propiedad de cartas de terreno presentes y participa en disponibilidad/ecología. No existe conquista ni un controlador persistente de todo el territorio. |
| Terrenos y defensas | Terrenos por celda con tipo; vallas con HP. No hay un modelo general de tamaño variable, resistencia territorial, devastación o restauración. |
| Trucos | Solo Curación en catálogo. Las pilas/equipamiento admiten más entradas, pero no hay Sol ni validación de exactamente tres trucos diferentes para la nueva modalidad. |
| Núcleo/final legado | Posición/HP y privacidad conservados. `_check_end` sigue terminando por HP de Núcleo o 12000 ticks: incompatible como política final de la modalidad territorial. No está cambiado por esta documentación. |
| Desastres/presentación | No hay director de desastres, última resistencia jugable ni barra funcional de dominio/resultado; se planifican, no se declaran implementados. |

## Arquitectura propuesta

- **Coordinador de partida:** configuración de modalidad, preparación, batalla, última resistencia cuando corresponda, resultado y reinicio. Un único reloj de 20 Hz; ninguna acción concede un turno exclusivo. Los instantes de transición esperan definición de duración/condiciones.
- **Controlador rival determinista:** recibe una copia de `get_player_view(rival)` del último tick resuelto y devuelve intenciones. Selecciona cartas equipadas/disponibles, posiciones y objetivos observables. La simulación revalida y cobra por las mismas vías que al humano.
- **Órdenes contextuales compartidas:** el humano y el rival utilizan `queue_act_at`, destinos y objetivos existentes; no escriben vida, posiciones, reservas o esencia. IDs de solicitudes por jugador, sin duplicar una jugada aceptada.
- **Control territorial persistente:** registro separado de la criatura presente, del terreno/recurso consumible y de la carta que lo produjo. Su controlador solo cambia mediante una conquista válida. Dañar, devastar, consumir recursos o mover criaturas no deben borrar el control por compartir un diccionario. La representación de regiones/huellas permitirá tamaños diferentes sin fijar todavía pesos de puntuación.
- **Conquista y resistencia:** intenciones validadas por simulación y progreso en ticks, después de aprobar reglas. Reutilizar rutas/reservas para llegar, sin convertir `move_arrived` en captura. La resolución de disputas debe ser determinista según la política que se apruebe, sin copiar automáticamente la regla de conflictos de movimiento.
- **Dominio y victoria:** política de modalidad independiente del final legado de Núcleo; fórmula/umbral/tiempo solo tras aprobación. Producir una proyección pública de control y resultado. Conservar las demos previas con sus reglas; no borrar el Núcleo ni inventarle un papel nuevo.
- **Sol y conocimiento:** efecto específico de carta y conocimiento autorizado por observador. Una revelación amplía solo la identidad correspondiente, sin entregar equipamiento completo, esencia o disponibilidad. Aleatoriedad con estado/semilla controlados por simulación para reproducir partidas; no exponer ese estado a la IA rival ni usar azar dependiente del frame.
- **Desastres deterministas:** calendario/selección autoritativos parametrizados por modo una vez definidos. Impredecibles para jugadores no significa no reproducibles: usar ticks y azar reproducible, no reloj de pared. Los eventos de desastre nunca escriben directamente el controlador territorial. Evaluar cambios de control solo por conquistas válidas y mantener simultaneidad de acciones supervivientes.
- **Escena de partida integrada:** tablero/pilas/feedback actuales, barra compartida amatista/oro arcano y bordes discretos sobre colores naturales. La simulación decide porcentajes y resultado; la UI solo anima presión y desplazamiento final de barra, sin decidir ganadores ni modificar reglas.

Archivos existentes que habrá que evaluar en una futura implementación: `simulation.gd`, `battle_cards.gd`, `match_loadout.gd`, `battle_catalog.gd`, `terrain_effects.gd`, `tactical_orders.gd`, `context_actions.gd`, `natural_intents.gd`, `main.gd`, demos/composición/feedback, pruebas y documentación. Componentes propuestos: coordinador, control/resistencia territorial, política de dominio/victoria, conocimiento de cartas, desastres y rival. Ninguno creado ahora. Extraer solo los puntos necesarios y mantener las regresiones de modos antiguos.

## Rival honesto y presión táctica

Propuesta: elegir despliegues según esencia propia, rutas y situación pública; conservar territorio, defender zonas amenazadas y ordenar conquistas válidas o recuperación de posiciones. Utilizar curación, cuevas e interacciones compatibles. No perseguir un Núcleo como objetivo de victoria ni conocer secretos del adversario. Sol solo permite reaccionar a lo efectivamente revelado, no leer todo el equipamiento. No obligar a todas las criaturas a avanzar ni sustituir sus instintos por una marcha permanente.

Mantener objetivos para evitar oscilaciones; reconsiderar ante muerte, bloqueo o desaparición de recurso. Cadencia en ticks y desempates deterministas, sin ventajas económicas ni cambios ocultos de estadísticas. No reaccionar a órdenes humanas aún sin resolver. La dificultad y agresividad se ajustarán por comportamiento tras revisión, sin inventar valores definitivos.

Añadir en la futura partida una opción que desactive exclusivamente los productores prefijados —cerdo inicial, valla/jabalí y flanco—, activa por defecto en demos anteriores. No apagar ecología/defensa para quitar esos guiones. Impedir que guion e IA manden simultáneamente sobre el mismo rival.

## Flujo propuesto, sin fijar duraciones

Preparación de equipamiento/configuración inicial → batalla territorial continua → victoria anticipada si se cumplen las condiciones por definir, o última resistencia jugable cuando corresponda → resolución con la política aprobada → presentación central de victoria/derrota y reinicio.

La activación del desastre final no decide el ganador ni cambia propietarios. Las oportunidades de remontada deben surgir del juego y del diseño de efectos aprobado, no de adjudicar territorio automáticamente. Empates y reglas de cierre necesitan definición antes de completar este flujo. La asignación inicial de control y las regiones legales de despliegue siguen pendientes; las dos mitades actuales no constituyen por sí mismas una fórmula de dominio.

## Incompatibilidades técnicas detectadas

| Código actual | Riesgo / adaptación propuesta |
| --- | --- |
| `_check_end`, `core_hp`, `MATCH_LIMIT_TICKS` | Final y empate basados en Núcleo; no pueden decidir la modalidad territorial. Proponer política por modo cuando se definan condiciones, sin alterar ahora el legado. |
| `terrain_owners` usado por `BattleCards.state` y búsqueda de maíz | Sobrescribirlo al conquistar alteraría disponibilidad de cartas y ecología. Separar control territorial de autoría/propiedad del recurso; acordar interacciones, no mezclarlas accidentalmente. |
| Consumo de maíz elimina `terrain.cells[cell]`; vista publica propietarios solo de terrenos presentes | Vincular dominio a ese mapa haría desaparecer territorio al consumir/retirar un recurso. Registrar control sobre la región persistente y proyectarlo aparte, también si está devastada. |
| `owns_cell` fija regiones de invocación por mitad inicial | No representa conquista dinámica. Decidir si el control modifica despliegue; no sustituir esta validación por el nuevo propietario sin aprobación. |
| Terrenos unitarios por celda, sin resistencia/estado/huella de tamaño | Hace falta representar superficie y condición ecológica sin doble contabilización; fórmula de porcentajes y defensas pendiente. |
| Catálogo con un solo truco; `MatchLoadout` no exige tres | Tres trucos diferentes no son jugables hoy. Diseñar las cartas faltantes y la validación de la nueva modalidad sin romper demos con un truco. No crear nombres/efectos de relleno. |
| Todos los trucos se validan como curación de unidad propia y ejecutan curación | Añadir Sol como simple entrada de catálogo lo convertiría erróneamente en curación. Prever efecto/objetivo propios; costes y reutilización pendientes. |
| Equipamiento rival privado y eventos desconocidos denegados desde 23.1 | Sol necesita una excepción explícita de conocimiento, limitada a la identidad revelada y destinatarios aprobados, sin debilitar el resto del contrato. |
| No hay azar autoritativo, desastres o restauración territorial | Planificar estado reproducible y transiciones por tick; no incorporar temporizadores aleatorios de UI ni daño/control como una sola operación. |

Estas son necesidades futuras, no fallos nuevos que autoricen modificar código durante esta actualización documental.

## Bloques funcionales propuestos y pruebas

Orden propuesto de bloques grandes; iniciar cada uno requiere autorización y definición de sus dependencias, no valores inventados para poder avanzar:

1. **Dominio e interacción jugable.** Tras definir ocupación/resistencia y cálculo de control: capa persistente, conquistas explícitas, órdenes desde lejos sin segunda confirmación y barra/bordes. Reutilizar `act_at`, reservas y combate. Pruebas: atravesar no captura; control persiste al marcharse; indefenso/defendido según reglas aprobadas; daño o consumo no conquista; áreas y porcentajes; conflictos simultáneos, cancelación, obstáculos y prioridad manual.
2. **Rival territorial y tres trucos/Sol.** Tras definir cartas faltantes y efecto operativo de Sol: controlador sobre la vista de 23.1 y economía real, equipamiento de tres IDs distintos, conocimiento limitado de la revelación y aleatoriedad reproducible. Pruebas: no duplicar auténticas ni gastar de más, guion e IA excluyentes, objetivos/rutas cambiantes, tres trucos distintos, Sol no desactiva ni cambia disponibilidad, no filtra secretos adicionales; mismo estado/semilla/órdenes produce mismo resultado.
3. **Desastres, última resistencia y cierre integrado.** Tras definir parámetros por modo y victoria/empate: daños a recursos/criaturas/defensas, restauración y conquista simultáneas según reglas acordadas, última resistencia jugable y resultado central. Pruebas: desastres y devastación jamás cambian control por sí solos; capturar después sí puede; normales y clasificatorias respetan su calendario aprobado; destrucción de defensa no concede control gratis; las demás acciones continúan; fin/empate/reinicio y ausencia de órdenes después del resultado.

En cada bloque mantener las **30 suites de referencia de 23.1** para los modos existentes y añadir pruebas de la modalidad territorial, sin reescribir expectativas antiguas para encubrir regresiones. Replays a distintos FPS y partidas completas con victoria/derrota por reglas de dominio aprobadas, no HP del Núcleo ni resultados forzados editando estado. Validación en Godot 4.7.2, revisión de TARS y prueba personal de jugabilidad antes de integrar una futura rama; Android físico sigue siendo independiente. Nada de esto se ejecuta o implementa por esta actualización de documentación.

## Autorización

Están acordadas las reglas descritas como aprobadas, incluida interacción remota, dominio, identidad visual, Sol y diseño de desastres/última resistencia. Umbrales, tiempos, fórmulas, empates, defensas/ocupación y demás detalles enumerados como pendientes no están aprobados. Arquitectura y bloques son propuestas para revisión. **Solo documentación: no modificar código ni iniciar implementación hasta autorización posterior.**
