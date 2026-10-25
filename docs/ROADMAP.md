# Hoja de ruta — Project Aetherion / Isla del Caos

Documento de continuidad y avance. Las reglas aprobadas se mantienen en [GEMINI.md](../GEMINI.md). Esta hoja de ruta registra únicamente el alcance comunicado; no asigna fases ni fechas a objetivos todavía sin concretar.

## Hitos y estado

| Hito | Alcance | Estado y evidencia |
| --- | --- | --- |
| Fase 20: base de simulación | Tablero 8×4, simulación a 20 Hz, invocación, esencia, combate, recuperación y final provisional. | Base implementada en `cfe2cdd849028c395eb093bd801e5a1cafc106b7`. Limitaciones en [PHASE_20.md](PHASE_20.md). |
| Fase 20.1A: regresiones de combate | Corregir HP esperado del jabalí; probar ataques y derrotas simultáneas, cooldowns y comandos duplicados. | Completada y publicada en `main` en `5319303d62698a48f1471b69c2b2eb91775ad5b2`, incluyendo `GEMINI.md`. Pruebas headless aprobadas en Godot 4.7.2. |
| Sincronización documental | Incorporar la metodología de colaboración y esta hoja de ruta; confirmar Git y conservar el trabajo existente. | Documentación actualizada; base local y remota confirmada en `5319303` y suite aprobada en Godot 4.7.2. El commit y la confirmación de publicación se comunican al entregar; no se incluye código de la Fase 20.1B. |
| Fase 20.1B: selección y vida | Selección de criaturas y barras de vida, conservando las reglas de combate. | Próximo objetivo; no iniciada. Primero confirmar el repositorio actualizado. |

## Objetivos posteriores ya registrados

Movimiento validado en la simulación, ataques iniciados por el jugador y retroalimentación de daño, derrota y recuperación forman parte de la meta de prototipo interactivo de `GEMINI.md`. Su desglose, orden y reglas pendientes deben acordarse antes de implementarlos; no forman parte de la Fase 20.1B.

La presentación final sigue siendo una mesa física 3D con terrenos volumétricos y miniaturas vivas. La demo 2D actual es provisional. PvP y progresión siguen siendo futuros.

## Método de entrega y coordinación

1. Leer `GEMINI.md`, verificar el estado local y remoto y delimitar el incremento sin repetir trabajo terminado.
2. Codex implementa; ChatGPT Work apoya tareas extensas; Gemini revisa independientemente cuando corresponda; TARS supervisa arquitectura y reglas. Coordinar archivos antes de editar cuando Gemini esté trabajando; evitar ediciones simultáneas sobre los mismos archivos.
3. Mantener `main` estable. Usar ramas de funcionalidad `codex/` para cambios importantes e integrar solo trabajo aprobado y validado.
4. Hacer incrementos pequeños, con pruebas automatizadas y validación en Godot 4.7. Registrar resultados y limitaciones reales.
5. Publicar mediante commit descriptivo y push el alcance previamente aprobado. Consultar cambios de alcance o riesgo significativo, alteraciones de reglas, eliminaciones de archivos y nuevas dependencias.
6. Actualizar el estado de los hitos y comunicar únicamente los resultados esenciales y los commits. GitHub es el punto de sincronización con TARS.

## Validación de referencia

Ejecutar con Godot 4.7, usando la ruta del ejecutable si no está en `PATH`:

```text
godot --headless --path . --script res://tests/simulation_smoke.gd
```

La suite conserva las comprobaciones de invocación y esencia e incluye daño simultáneo, derrotas mutuas en ambos órdenes de comandos, límites exactos de cooldown y duplicados sin daño adicional ni ejecución diferida. No representa una validación de interfaz o de Android.

## Decisiones pendientes fuera del incremento actual

- Reglas de movimiento, conflictos de ocupación e interacción con ataques.
- Duración y alcance del bloqueo bajo ataque, sin reinterpretar la regla aprobada.
- Descubrimiento del Núcleo y restricciones correspondientes.
- Identidad de cartas y recuperación cuando existen varias criaturas de la misma especie.

Estos pendientes no autorizan cambios de mecánicas durante la sincronización documental ni la Fase 20.1B.
