# Fase 22 — verificación final para revisión de TARS

**Nota de continuidad:** este informe registra la validación histórica de 22. La corrección posterior de Fase 23 sustituye la antigua regla de múltiples copias por una auténtica por especie/jugador; las pruebas de unicidad y recuperación vigentes están en [PHASE_23_UNIQUE_SPECIES_REVIEW.md](PHASE_23_UNIQUE_SPECIES_REVIEW.md). No autoriza duplicados actuales ni modifica por sí sola main.

**Estado actual: integrada en main desde `fe82be9`, con autorización oficial del director creativo posterior a la revisión favorable de TARS.** Merge sin conflictos, preservando historial y sin cambios adicionales de jugabilidad. Se repitieron las 19 suites y los dos arranques sobre el resultado de integración: todos aprobados en Godot 4.7.2. Las secciones siguientes conservan el registro de revisión/preparación previo; sus esperas de autorización quedaron satisfechas por esta decisión. Las limitaciones de Núcleo, balance, resultado/reloj y pruebas Android permanecen.

Fecha: 2026-10-25. Rama: `codex/phase-22-battle-depth`. Implementación revisada: `2cda47250c334671e54d4cb9a311c0b3b6b28997`; base `main`/`origin/main`: `1c740d6`. Estado inicial limpio y remoto comprobado.

**Resultado técnico favorable con las limitaciones siguientes. No constituye autorización de integración.** El director creativo comunicó una prueba manual positiva de despliegue, selección, ataque dirigido, recuperación ecológica del cerdo y disponibilidad/recuperación de copias, indicando expresamente que no era aprobación completa. Actualización posterior: TARS comunicó revisión técnica favorable del informe y reconoció las 19 pruebas y limitaciones. Solo la preparación de integración está autorizada; falta confirmación definitiva del director creativo.

## Los ocho puntos solicitados

| Punto | Resultado verificado | Evidencia y alcance |
| --- | --- | --- |
| Prioridad manual | Correcta en los casos probados. | Ataque dirigido sustituye una intención natural ya iniciada, libera su recurso, acaba el paso comprometido y se aproxima/ataca sin reanudar la cura. Las suites anteriores cubren órdenes bloqueadas, cambios de destino, preparación interrumpida, refugio y daño aceptado. |
| Mantener posición | Persiste e impide nuevos viajes autónomos. | Termina el paso aceptado antes de detenerse; permite defensa adyacente estacionaria. No equivale a «Detener», que permite volver a instintos. |
| Ecología individual | Control independiente por criatura. | La prueba actual usa cerdo y caballo auténticos distintos: desactivar uno no afecta la recuperación/orden del otro. Se eliminó el fixture antiguo con dos copias propias de una especie. |
| Ir y actuar | Acción correcta al llegar y al quedar disponible. | Cerdo/barro, caballo/maizal, cueva/entrada/salida y gólem/valla. No empieza durante el viaje ni antes del cooldown; consumo de maíz y cantidades de cura conservados. Si desaparece el recurso, termina y respeta el paso comprometido. |
| Recuperación de auténtica | Bloqueo de esa especie/jugador hasta el tick exacto. | Cerdo derrotado en tick 2: carta bloqueada hasta tick 241 inclusive; vuelve a ser desplegable pagando esencia en tick 242. No se permiten copias 1/2 como reemplazo; otras especies y el rival siguen independientes. |
| Cerdo, barro y contrajuego | Cura y desplazamiento acotados; persecución eficaz en el caso probado. | Jabalí fresco con ataque dirigido derrota al cerdo en tick 37, después de dos pasos naturales hacia barro y una cura de 1 HP. Sin cambiar vida, posiciones o esencia en ese combate. Prueba separada: cerdo herido en barro cura exactamente 1 por acción, respeta 60 ticks entre preparaciones, nunca supera 4 HP y descansa al quedar sano. |
| Resultado y 20 Hz | Consistentes con el prototipo actual; resultado final de diseño incompleto. | Replay mediante `_process` real de la escena a 20/30/120 FPS: mismas vistas/eventos por tick. Se comprueban límite exacto de 12000 ticks, victoria por vida del Núcleo, derrota mutua/empate y estado congelado después del final. Ver límites abajo. |
| Regresiones y arranque | 19 suites aprobadas en Godot 4.7.2. | Las 18 publicadas y la nueva `phase22_closure_smoke.gd`; arranque de la demo de F5 y de la escena de Fase 22, más importación del editor. Sin errores de scripts. |

## Curación y evasión: qué demuestra la prueba

El barro no concede inmunidad, cambia el daño ni teletransporta al cerdo. Moverse conserva origen ocupado y destino reservado; entrar en barro dura 12 ticks. Se acepta daño contra el origen lógico mientras se mueve y se resuelven bajas antes de llegadas y curaciones. Buscar barro sigue limitado a dos pasos reales y a la mitad territorial inicial. No hay paseo de evasión al quedar sano.

Revolcarse mantiene las reglas aprobadas: preparación de 6 ticks, 1 HP, máximo 4 HP y cooldown de 60 ticks desde el inicio de la acción. La curación es **repetible a lo largo del combate**, no tiene un límite total de usos aprobado. Que un cerdo sobreviva y derrote a un jabalí previamente herido no demuestra por sí solo un error. La persecución dirigida, el daño durante movimiento y el daño suficiente antes de la siguiente cura proporcionan contrajuego comprobado; no se afirma equilibrio universal entre todas las combinaciones de terreno, obstáculos y heridas.

Cambiar radio, curación, consumo de barro, cooldown, daño o comportamiento de retirada sería balance/jugabilidad y requiere aprobación. No se aplicaron esos cambios. Recomendación para TARS: revisar la presión de combate alrededor de barro con los parámetros actuales antes de considerar cualquier ajuste.

## Resultado de partida y reloj: límites reales

1. `simulation.gd::_check_end` compara exclusivamente vida de los Núcleos cuando alguno llega a cero o al alcanzar 12000 ticks (600 segundos simulados). Igualdad produce `winner = -1`. Fuerza activa/control territorial y desastres de la visión futura **no están implementados** como desempate. No se ha introducido un desempate nuevo.
2. El Núcleo rival continúa oculto y no tiene mecánica real de descubrimiento. Vaciar el escenario produce el mensaje de escenario despejado, **no una victoria de partida contra el Núcleo**. Las pruebas de resultados usan fixtures de vida/tiempo, no descubren el Núcleo durante la demo.
3. La escena mantiene pasos fijos de 0,05 segundos con acumulador. El límite anterior de `delta` a 0,25 segundos evita una acumulación masiva después de un bloqueo: un frame de un segundo procesa cinco ticks, no veinte. Conserva consistencia de pasos pero pierde tiempo de pared durante pausas/bloqueos largos. No es todavía un reloj de red ni validación de rendimiento Android.

TARS reconoció estas limitaciones en su revisión técnica favorable. Se conservan documentadas y no se han corregido mediante cambios de reglas; la aprobación definitiva de integración corresponde al director creativo. Android real, balance y validación visual final de los controles siguen pendientes.

## Pruebas ejecutadas

Motor verificado: `4.7.2.stable.official.ed1daf0bf`. Se ejecutaron todos los archivos `tests/*_smoke.gd`, comprobando código de salida, presencia de `PASS:` y ausencia de `SCRIPT ERROR`/`ERROR:`. Resultado: **19/19**.

- Base y regresiones: `board_coordinates`, `presentation`, `simulation`, `movement`, `movement_presentation`, `tactical_orders`, `tactical_presentation`, `ecology`, `context_actions`, `battle_systems`, `battle_presentation`, `battle_scenario`.
- Fase 22 inicial: `natural_intents`, `context_orders`, `battle_feedback`, `battle_depth_presentation`, `battle_depth_determinism`, `battle_depth_scenario`.
- Cierre: [phase22_closure_smoke.gd](../tests/phase22_closure_smoke.gd), con controles de especies distintas, ataque manual sobre viaje natural, llegada/cooldown contextual, recuperación exacta con pagos reales, persecución del cerdo, cadencia de cura, resultados y acumulador real de la escena.

Arranques/importación:

```text
godot --headless --path . --quit-after 5
godot --headless --path . res://scenes/battle_depth_demo.tscn --quit-after 5
godot --headless --editor --path . --quit
```

La suite nueva utiliza fixtures señalados para heridas, cooldown y límites de resultado; los casos de recuperación por derrota y persecución usan cartas, esencia y daño reales. En su primera ejecución, una espera del test de reactivación de ecología era insuficiente: se ajustó el test a la cadencia existente de hasta cuatro ticks de decisión más seis de preparación. No se cambió el motor para acomodar el test.

## Cambios de esta revisión

- Nueva suite de cierre y su UID.
- Este informe y enlaces/estado de continuidad en `docs/PHASE_22.md`, `docs/ROADMAP.md` y `GEMINI.md`.
- Propuesta de Fase 23 en `docs/PHASE_23.md`, sin implementación.
- **Sin cambios de jugabilidad, escenas, parámetros o dependencias. Sin integración en main.** El código jugable sigue siendo el de `2cda472`.

Revisión técnica de TARS completada favorablemente. Paso siguiente: esperar confirmación definitiva del director creativo antes de fusionar. Fase 23 se trabajará después, bajo autorización de inicio, en rama nueva desde main actualizado con pruebas y revisión visual.

## Preparación de integración confirmada

Tras la autorización para preparar la integración, se comprobó Git local/remoto: rama limpia y sincronizada en `e8e7c08`; `main` y `origin/main` en `1c740d6`. `git merge-base --is-ancestor origin/main HEAD` devuelve 0 y la divergencia es `0 / 2`: main es ancestro de la rama, por lo que la integración del estado comprobado no requiere resolver conflictos. Esta preparación solo añade documentación, sin cambiar el código de jugabilidad revisado.

Se repitieron **19/19 suites** y los arranques de `battle_demo.tscn` y `battle_depth_demo.tscn` en Godot `4.7.2.stable.official.ed1daf0bf`, sin errores de scripts. Se conservan las limitaciones de Núcleo, resultado/reloj, balance y Android descritas arriba, así como las estadísticas provisionales. No se convierte a 3D.

Procedimiento pendiente, **solo después de confirmación definitiva del director creativo**: actualizar referencias remotas, comprobar de nuevo limpieza/UID y base de main, integrar preservando el historial de la rama, ejecutar regresiones/arranque sobre el resultado y publicar main. Si la base cambia, recalcular conflictos y validación antes de integrar. No se ha ejecutado ningún merge ni movido main durante esta preparación. No se crea todavía la rama de Fase 23.
