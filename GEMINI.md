# GEMINI.md — Project Aetherion / Isla del Caos

Instrucciones permanentes para Antigravity/Gemini y otros agentes que trabajen en este repositorio. **Leer antes de modificar código.** Este documento contiene objetivos de diseño; no implica que estén implementados.

## Visión

Juego Android vertical en Godot 4.7 y GDScript. Inspiración de experiencia: la mesa viva del episodio *Guerra de cartas* de *Hora de Aventura* y la claridad y acción simultánea de *Clash Royale*. Crear arte, criaturas, nombres y recursos originales; no copiar activos protegidos.

El juego debe sentirse como una **mesa física 3D con criaturas, construcciones y ecosistemas invocados como hologramas mágicos a todo color**, con transparencia ligera y estilo cartoon fantástico. Conservar los colores originales de las criaturas. Los terrenos invocados se distinguen de la superficie física; las cartas hacen emerger sus invocaciones desde el suelo. No convertirlo en ajedrez, juego por turnos ni cuadrícula 2D plana como presentación final.

## Reglas acordadas: no modificar sin aprobación

1. **Tiempo real:** ambos jugadores actúan simultáneamente. La simulación puede operar a 20 ticks/segundo; esto no representa turnos.
2. **Tablero:** 32 espacios, 16 por jugador. La distribución visual aprobada es vertical, **4 columnas × 8 filas**, con el rival arriba y el jugador local abajo. La simulación conserva por ahora sus coordenadas lógicas **8×4**; utilizar una transformación reversible entre ambos espacios en presentación, sin modificar la simulación para rotar la vista. Separar esta lógica de la representación tridimensional. Los terrenos pueden tener diferentes longitudes.
3. **Núcleo oculto:** cada jugador lo coloca en su territorio; el rival debe descubrirlo y destruirlo. Señal de equilibrio hacia mitad de partida, aún por concretar.
4. **Bloqueo bajo ataque:** no se permite retirar/intercambiar criatura, terreno o construcción mientras sea objetivo de un ataque activo. Se puede jugar en otras zonas.
5. **Recuperación por copia:** una carta derrotada por combate o desastre entra individualmente en cooldown; después vuelve disponible, **no reaparece automáticamente**. Múltiples criaturas de la misma especie tienen identidad y estado independientes; la derrota de una no bloquea a las otras. Distinguir recuperación, disponibilidad de copias y reutilización. Intercambios normales y uso de cartas no son automáticamente derrotas ni inician recuperación.
6. **Cuatro pilas de cartas** abajo: criaturas, terrenos, construcciones y trucos; acceso al resto de cartas sin ocultar la batalla.
7. **Esencia provisional:** inicio 4, máximo 8, +1 cada 3 segundos. Parámetros configurables para balance.
8. **Partidas:** objetivo 5–8 minutos, límite de 10 minutos; final con desastres y última resistencia. Desempate previsto: vida del Núcleo, fuerza activa y control territorial.
9. **Desastres:** eventos del mundo con aviso ambiguo 20–30 segundos; erupción rara en avanzado. Terreno devastado queda visible y pierde bonificaciones.
10. **Ecología y personalidad:** jabalí embiste, gólem rompe estructuras, caballo come cultivos, castor repara madera, abeja poliniza, etc. Ventajas y desventajas según entorno.
11. **Despliegue:** acciones contextuales de criaturas (por ejemplo atacar o usar habilidad); diseñar controles táctiles directos.
12. **PvP y progresión:** funciones futuras; no adelantarlas antes de consolidar un prototipo local divertido.

## Dirección artística y herramientas

- Mesa física 3D e invocaciones holográficas expresivas de criaturas, terrenos y construcciones que emergen desde el suelo. Esta dirección artística está aprobada; el 3D definitivo no forma parte de la Fase 22.
- Interfaz futura documentada: nombres/avatares en las esquinas superiores, barra horizontal de dominio PvP debajo (no probabilidad de victoria), cuatro categorías inferiores con sus pilas accesibles. El tablero conserva el protagonismo. Sin PvP real ni interfaz definitiva en Fase 22.
- Flow: referencias visuales/animación conceptual. Blender: modelos y animaciones 3D. Godot: juego real. Un video generado no es un modelo jugable.
- Mantener identidad visual consistente, lectura clara de ataques y rendimiento Android.

## Estado del repositorio al redactar este archivo

- `project.godot`: Godot 4.7, renderer GL Compatibility.
- `scenes/battle_demo.tscn`: escena integrada de Fase 21 aprobada y activa en `main`. Se conservan las escenas anteriores.
- `scripts/main.gd`: vista compartida `Node2D` y demo técnica anterior; las demos de 20.2 y 21 desactivan su productor técnico de ataques automáticos y usan reglas de simulación.
- `scripts/simulation.gd`: `AetherionSimulation`, 8×4, 20 ticks/s, invocación, ataque, esencia, daño, recuperación y fin de partida.
- `main` incluye la prueba técnica de movimiento básico aprobada visualmente, descrita abajo. Todavía no hay tablero 3D, UI final de cartas, animaciones de personajes ni red. Verificar el código actual antes de cada tarea: este estado puede cambiar.

## Reglas de ingeniería

1. Separar **simulación determinista** (reglas/estado) de **presentación** (escenas, efectos, entrada).
2. Entregar bloques funcionales completos e integrados, con cambios internos comprobables y reversibles. No reescribir archivos innecesariamente ni fragmentar la entrega en mecánicas desconectadas.
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
- Trabajar en bloques funcionales grandes, con pruebas automatizadas durante el desarrollo y validación en Godot 4.7.
- Antes de editar, coordinar los archivos asignados si Gemini tiene una revisión o implementación activa. No editar simultáneamente los mismos archivos que Gemini.
- `GEMINI.md` conserva las reglas; `docs/ROADMAP.md` registra hitos, estado, validación y commits. Los objetivos futuros no autorizan por sí solos su implementación.

## Avance confirmado

- Fase 20.1A completada y publicada en `main`: `5319303d62698a48f1471b69c2b2eb91775ad5b2`. Corrección de la expectativa de HP del jabalí y pruebas de simultaneidad, cooldowns y comandos duplicados; validadas en Godot 4.7.2. Sin cambios en reglas, arquitectura, escenas ni interfaces.
- Fase 20.1B aprobada por el propietario tras pruebas visuales en Godot e integrada en `main` desde `codex/phase-20-1b-selection-health` (commit de funcionalidad `3b2455b8b5f64eadb3e7a0085cd6b9205b8bfa0f`): selección propia por clic/toque, resaltado, barras de vida, coordenadas adaptadas a la ventana y limpieza tras derrota. La simulación y las reglas de combate se conservan; ver validación en `docs/ROADMAP.md`.
- Primera parte de la Fase 20.1C aprobada por el propietario e integrada en `main` desde `codex/phase-20-1c-vertical-board`, commit de funcionalidad `d529b93c5f2b4d910d3c11b2bb52fe9b888e6e78`: adaptador reversible de lógica 8×4 a vista 4×8 para dibujo y selección, rival arriba y jugador local abajo. Pruebas de coordenadas, presentación, combate y arranque repetidas y aprobadas en Godot 4.7.2. UID locales conservados e incorporados al control de versiones. Sin cambios de simulación ni movimiento implementado.

## Movimiento básico aprobado e integrado

- Prueba técnica manual de un paso ortogonal libre: **6 ticks por paso** (0,3 segundos a 20 Hz), origen ocupado y destino reservado durante el trayecto.
- Sin coste de esencia; entrada permitida al territorio rival; rechazo determinista de conflictos; movimiento independiente del cooldown de ataque.
- El movimiento no puede cancelar daño ya aceptado. Proteger Núcleos ocultos frente a filtraciones por consultas, resaltados o ataques.
- Mantener separados ejecución de movimiento, futuros comportamientos naturales y órdenes especiales. Sin IA autónoma, rutas largas ni habilidades en este incremento.
- El control manual de una casilla es exclusivamente una prueba técnica: el diseño final permitirá ordenar destinos sin controlar cada paso.
- Implementación revisada por TARS y aprobada visualmente por el propietario: selección y desplazamiento a celda vecina comprobados en Godot. Integrada en `main` desde `codex/phase-20-1c-basic-movement`, commit de funcionalidad `487a6b3be304b3d5c42408878b3561ee0b177e12`. Cinco suites automatizadas y arranque repetidos con éxito en Godot 4.7.2; integración sin conflictos ni cambios de jugabilidad adicionales. Ver reglas exactas y pruebas en `docs/PHASE_20_1C.md`.
- Conservar el combate instantáneo: evaluar ataques en la celda lógica de origen, aplicar daño simultáneo y derrotas antes de confirmar llegadas. No introducir ventanas de ataque activo ni bloquear desplazamiento por cooldown. No se añaden funciones de retirada/intercambio.
- Decisión adicional del propietario: mantener oculto el Núcleo rival en el prototipo; rechazar ataques mientras no esté descubierto. El estado descubierto se prueba únicamente con fixtures. No implementar aún una mecánica de descubrimiento ni revelar al entrar en su celda.

## Próxima meta: prototipo interactivo

Fase 21 integrada en `765bc8a72a8d82dbe93f1a4633c13afc24b047ff` tras aprobación de TARS y validación visual del propietario. Los dos bloques de Fase 22 «Dinamismo y profundidad de batalla» fueron autorizados por TARS y Dirección Creativa y están implementados en `codex/phase-22-battle-depth`, desde `main` `1c740d6`. **No integrados en main; pendientes de revisión de TARS y validación visual del propietario.** Reglas y validación real en `docs/PHASE_22.md`.

Reglas provisionales aprobadas para 22: cerdo herido busca barro hasta dos pasos reales; caballo con dos HP perdidos busca maizal propio/neutral hasta dos pasos; rutas naturales no cruzan la mitad territorial de inicio. Jabalí prepara la embestida existente ante rival adyacente y prioriza al último agresor de hasta 40 ticks; gólem defiende contra criaturas adyacentes y, sin amenaza, demuele una valla rival adyacente. Sin persecución natural, azar ni paseo sin propósito. Intenciones de recursos con prioridad de solicitud y desempate por ID. Tras recuperarse descansan; no desalojar automáticamente barro ocupado.

«Mantener posición» es persistente: acaba el paso comprometido y permite solo defensa estacionaria adyacente. «Detener» cancela la orden y permite otra vez instintos. Ecología configurable por instancia; desactivarla conserva la defensa básica anterior. «Ir y actuar» aproxima y ejecuta una acción existente, esperando su cooldown, sin reanudar destinos antiguos. Las órdenes explícitas, incluso bloqueadas, y el refugio prevalecen; cancelar preparación no devuelve cooldown ni cancela un paso o daño aceptado. Sin cambios de estadísticas, esencia, recuperación, daño o descubrimiento del Núcleo.

Nueva escena: `scenes/battle_depth_demo.tscn` (abrir y ejecutar **F6**). F5 conserva `battle_demo.tscn`. `battle_feedback.gd` consume solo eventos/vistas de observador y genera poses/efectos limitados, preparado para un futuro renderizador holográfico; no tiene autoridad sobre la simulación. Dieciocho suites pasan en Godot 4.7.2 (doce previas y seis nuevas). Capturas revisadas por el implementador; Android real, balance y aprobación visual del propietario pendientes.

La Fase 21 «Primera batalla jugable» fue aprobada por TARS y por el propietario tras validación visual en Godot e integrada en `main` desde `codex/phase-21-first-playable-battle`, commit de funcionalidad `2607c60587e7f8f46499539bed22d926158fd6ee` (base `ab75787`). Cuatro espacios de cartas, cerdo/jabalí/caballo/gólem, maizal/cueva/barro, valla y curación provisional; órdenes contextuales y acciones con preparación/efectos visibles. Doce suites y escenario completo con economía real aprobados en Godot 4.7.2. Las doce suites y el arranque se repitieron con éxito antes de la integración, sin conflictos ni cambios adicionales de jugabilidad. Ver `docs/PHASE_21.md` para reglas exactas, pruebas y límites.

Correcciones explícitas del propietario para 21: tres copias configurables por especie, varias activas simultáneamente, recuperación por instancia; ningún cooldown genérico de 60 ticks tras usar terrenos/construcciones/trucos; valla destruida recupera en 120 ticks configurables; curación reutilizable pagando esencia; intercambio normal y maizal consumido liberan disponibilidad inmediatamente. Cueva con entrada/salida de seis ticks, daño recibido reducido en uno con mínimo uno, sin atacar dentro ni invulnerabilidad; una orden explícita permite salir. Acciones de especie con preparación y consecuencias observables, separadas de instintos y navegación. Mantener prioridad explícita y Núcleo oculto; sin 3D final, PvP ni IA avanzada.

La Fase 20.2 fue verificada visualmente por el propietario e integrada en `main` desde `codex/phase-20-2-tactical-combat`, commit `e4aa4198c1497b8e1f051cab840a343cd97b37e7`: Entrega A de destinos lejanos y ataques dirigidos (`dcd7c52`), con siete suites y arranque aprobados antes de iniciar B. Entrega B provisional aprobada e implementada: defensa solo adyacente sin perseguir ni interrumpir órdenes/desplazamientos; menor ID como desempate técnico, no personalidad definitiva; barro duplica la entrada (6 a 12 ticks), sin daño ni esencia. Configurables `natural_defense.enabled`, `terrain.mud_multiplier` y duración base; ejecución de movimiento, órdenes explícitas y comportamiento natural separados. Ocho suites y arranque aprobados en Godot 4.7.2. F5 abre la demo táctica con defensa y barro; la demo original se conserva. Ver `docs/PHASE_20_2.md`. Integración realizada tras confirmación visual del propietario y ocho suites más arranque aprobados nuevamente en Godot 4.7.2. No añadir IA avanzada, habilidades, nuevas criaturas ni descubrimiento real del Núcleo.

1. Selección de criatura por clic/toque y resaltado visible.
2. Barras de vida e información básica.
3. Movimiento validado en la simulación (ocupación, límites, reglas claras).
4. Ataques iniciados por el jugador, sin perder simultaneidad.
5. Retroalimentación de daño, derrota y recuperación.
6. Prueba de arranque sin errores en Godot y verificación de reglas del Núcleo.

**Orden de autoridad:** decisiones explícitas recientes del propietario > reglas aprobadas de este archivo > código actual como evidencia del estado implementado > sugerencias del agente. Si el código contradice la visión, señalarlo antes de cambios sustanciales.
