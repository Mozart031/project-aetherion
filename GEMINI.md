# GEMINI.md — Project Aetherion / Isla del Caos

Instrucciones permanentes para Antigravity/Gemini y otros agentes que trabajen en este repositorio. **Leer antes de modificar código.** Este documento contiene objetivos de diseño; no implica que estén implementados.

## Visión

Juego Android vertical en Godot 4.7 y GDScript. Inspiración de experiencia: la mesa viva del episodio *Guerra de cartas* de *Hora de Aventura* y la claridad y acción simultánea de *Clash Royale*. Crear arte, criaturas, nombres y recursos originales; no copiar activos protegidos.

El juego debe sentirse como una **mesa física 3D con terrenos volumétricos y miniaturas vivas**. No convertirlo en ajedrez, juego por turnos ni cuadrícula 2D plana como presentación final.

## Reglas acordadas: no modificar sin aprobación

1. **Tiempo real:** ambos jugadores actúan simultáneamente. La simulación puede operar a 20 ticks/segundo; esto no representa turnos.
2. **Tablero:** 32 espacios, 16 por jugador. La distribución visual aprobada es vertical, **4 columnas × 8 filas**, con el rival arriba y el jugador local abajo. La simulación conserva por ahora sus coordenadas lógicas **8×4**; planificar una transformación reversible entre ambos espacios en presentación, sin modificar todavía la simulación. Separar esta lógica de la representación tridimensional. Los terrenos pueden tener diferentes longitudes.
3. **Núcleo oculto:** cada jugador lo coloca en su territorio; el rival debe descubrirlo y destruirlo. Señal de equilibrio hacia mitad de partida, aún por concretar.
4. **Bloqueo bajo ataque:** no se permite retirar/intercambiar criatura, terreno o construcción mientras sea objetivo de un ataque activo. Se puede jugar en otras zonas.
5. **Recuperación:** las cartas derrotadas por combate o desastre entran en cooldown; después vuelven a estar disponibles, **no reaparecen automáticamente**.
6. **Cuatro pilas de cartas** abajo: criaturas, terrenos, construcciones y trucos; acceso al resto de cartas sin ocultar la batalla.
7. **Esencia provisional:** inicio 4, máximo 8, +1 cada 3 segundos. Parámetros configurables para balance.
8. **Partidas:** objetivo 5–8 minutos, límite de 10 minutos; final con desastres y última resistencia. Desempate previsto: vida del Núcleo, fuerza activa y control territorial.
9. **Desastres:** eventos del mundo con aviso ambiguo 20–30 segundos; erupción rara en avanzado. Terreno devastado queda visible y pierde bonificaciones.
10. **Ecología y personalidad:** jabalí embiste, gólem rompe estructuras, caballo come cultivos, castor repara madera, abeja poliniza, etc. Ventajas y desventajas según entorno.
11. **Despliegue:** acciones contextuales de criaturas (por ejemplo atacar o usar habilidad); diseñar controles táctiles directos.
12. **PvP y progresión:** funciones futuras; no adelantarlas antes de consolidar un prototipo local divertido.

## Dirección artística y herramientas

- Mesa 3D con terrenos que emergen, se dañan y muestran volumen; criaturas expresivas como miniaturas.
- Flow: referencias visuales/animación conceptual. Blender: modelos y animaciones 3D. Godot: juego real. Un video generado no es un modelo jugable.
- Mantener identidad visual consistente, lectura clara de ataques y rendimiento Android.

## Estado del repositorio al redactar este archivo

- `project.godot`: Godot 4.7, renderer GL Compatibility.
- `scenes/main.tscn`: escena principal.
- `scripts/main.gd`: demo `Node2D` con cuadrícula y dos círculos, `auto_attack := true`.
- `scripts/simulation.gd`: `AetherionSimulation`, 8×4, 20 ticks/s, invocación, ataque, esencia, daño, recuperación y fin de partida.
- **Todavía no** hay movimiento completo, tablero 3D, UI final de cartas, animaciones ni red. Verificar el código actual antes de cada tarea: este estado puede cambiar.

## Reglas de ingeniería

1. Separar **simulación determinista** (reglas/estado) de **presentación** (escenas, efectos, entrada).
2. Hacer cambios pequeños, probables y reversibles. No reescribir archivos innecesariamente.
3. No inventar APIs ni declarar una funcionalidad terminada sin probarla en Godot 4.7.
4. No cambiar reglas de diseño por iniciativa propia. Si hay ambigüedad, proponer alternativas y pedir aprobación.
5. Conservar orientación vertical y compatibilidad Android, incluso cuando se pruebe en PC.
6. Excluir `.godot/`, credenciales, tokens y temporales del repositorio. No hacer `push --force` ni borrar trabajo ajeno.
7. No añadir servicios de pago, dependencias externas o plugins sin consentimiento.

## Protocolo de trabajo con TARS y Antigravity

**Antes:** leer este documento, inspeccionar archivos reales, indicar qué se cambiará y qué riesgos existen.

**Durante:** implementar un incremento funcional; distinguir hechos, supuestos y propuestas; respetar las reglas acordadas.

**Después:** registrar el avance en `docs/ROADMAP.md` y comunicar únicamente resultados esenciales y commits. Publicar con commit descriptivo y push los cambios dentro del alcance previamente aprobado una vez superadas las pruebas y la validación correspondiente en Godot. Consultar antes de ampliar el alcance, introducir riesgo significativo, alterar reglas del juego, eliminar archivos o añadir dependencias.

## Colaboración y continuidad

- Codex es el implementador principal; ChatGPT Work apoya tareas extensas; Gemini en Antigravity realiza revisiones técnicas independientes cuando corresponda; TARS supervisa arquitectura y reglas; Godot es el entorno de validación.
- Conservar el trabajo realizado: no reiniciar fases ni repetir incrementos completados. Verificar Git local y remoto antes de sincronizar.
- GitHub es el punto de sincronización con TARS. Mantener `main` estable y utilizar ramas de funcionalidad `codex/` para cambios importantes; integrar únicamente cambios aprobados y validados.
- Trabajar en incrementos pequeños con pruebas automatizadas y validación en Godot 4.7.
- Antes de editar, coordinar los archivos asignados si Gemini tiene una revisión o implementación activa. No editar simultáneamente los mismos archivos que Gemini.
- `GEMINI.md` conserva las reglas; `docs/ROADMAP.md` registra hitos, estado, validación y commits. Los objetivos futuros no autorizan por sí solos su implementación.

## Avance confirmado

- Fase 20.1A completada y publicada en `main`: `5319303d62698a48f1471b69c2b2eb91775ad5b2`. Corrección de la expectativa de HP del jabalí y pruebas de simultaneidad, cooldowns y comandos duplicados; validadas en Godot 4.7.2. Sin cambios en reglas, arquitectura, escenas ni interfaces.
- Fase 20.1B aprobada por el propietario tras pruebas visuales en Godot e integrada en `main` desde `codex/phase-20-1b-selection-health` (commit de funcionalidad `3b2455b8b5f64eadb3e7a0085cd6b9205b8bfa0f`): selección propia por clic/toque, resaltado, barras de vida, coordenadas adaptadas a la ventana y limpieza tras derrota. La simulación y las reglas de combate se conservan; ver validación en `docs/ROADMAP.md`.
- Distribución visual 4×8 aprobada; su transformación desde la lógica 8×4 se planifica para la Fase 20.1C. La demo integrada aún dibuja 8×4. Ver `docs/PHASE_20_1C.md`: propuesta técnica solamente; movimiento y reglas pendientes requieren aprobación antes de implementarse.

## Próxima meta: prototipo interactivo

1. Selección de criatura por clic/toque y resaltado visible.
2. Barras de vida e información básica.
3. Movimiento validado en la simulación (ocupación, límites, reglas claras).
4. Ataques iniciados por el jugador, sin perder simultaneidad.
5. Retroalimentación de daño, derrota y recuperación.
6. Prueba de arranque sin errores en Godot y verificación de reglas del Núcleo.

**Orden de autoridad:** decisiones explícitas recientes del propietario > reglas aprobadas de este archivo > código actual como evidencia del estado implementado > sugerencias del agente. Si el código contradice la visión, señalarlo antes de cambios sustanciales.
