# STK Haven — Fase 5 v9.8: geometría de equipo y contactos en pilotos GLB

**Alcance:** solo generadores y validaciones offline de los tres candidatos móviles (iOS/Android). Sin web, Supabase, entrenamientos ni historial. La fuente sigue siendo el repositorio privado `STK-Haven`; el espejo público `STK-Haven_CI` se usa únicamente para Actions.

## Qué cambia

Se refina `tool/anatomical_3d/retarget_cc0_glb.py` para los **tres modelos de ejercicio preexistentes**: press banca, remo con barra y sentadilla. Su barra de revisión ahora contiene siete secciones de baja densidad, cada una con tapas de superficie y normales orientadas por cara:

1. Barra rígida de 2,2 m (semilargo 1,1 m, radio 19 mm) en el espacio local.
2. Dos guías estrechas de agarre a ±0,50 m; no certifican contacto de dedos, ubicación reglamentaria o agarre específico de todas las personas.
3. Dos collares de unión a las mangas a ±0,835 m.
4. Dos discos de revisión en torno a ±0,90 m, radio 170 mm.

La malla del cuerpo, las 53 articulaciones del candidato de ejercicio, sus pesos, el desplazamiento de barra y los 41 fotogramas clave permanecen sin cambio. Se conservan los materiales/colores STK existentes y las restricciones de archivo móvil GLB **≤850 KiB**. El press conserva el banco estático. Son modelos proxy, **no implementaciones mecánicas de una barra olímpica real o discos calibrados**.

## Evidencia automatizada y límites

- `pilot_motion_quality_v98.py` recibe los **GLB ya generados**, valida ID de ejercicio, licencia/origen CC0, 53 huesos, estado no aprobado/no habilitado, malla de barra con guías/collares/tapas, y banco de prensa presente e inmóvil.
- `test_cc0_interpolated_motion.py` ejecuta la revisión **en 121 instantes por ejercicio a 30 muestras/s** leyendo canales `LINEAR` del GLB real, no los valores teóricos del solucionador. Mide error de manos respecto de extremos de agarre de la barra, desplazamiento de pies respecto de su primera pose, continuidad inicio/fin, velocidad máxima observada de articulaciones, trayecto de barra, diferencias derecha/izquierda y otras magnitudes diagnósticas.
- Solo se hacen cumplir umbrales técnicos geométricos ya establecidos de manos (<5 mm), pies (<5 mm), cierre de ciclo (<0,01 mm), continuidad de velocidad acotada y desplazamiento real de la barra. Distancias aproximadas de rodilla/tobillo, pelvis/banco y barra/pelvis se **reportan**, pero no declaran una repetición correcta.
- `test_retarget_cc0.py` comprueba la existencia de 7 piezas cerradas, sus normales, todos sus índices, ausencia de NaN, límites de material y retención de la licencia y bloqueo de publicación en la versión original y LOD.
- Nuevo informe en los artefactos públicos de CI: `apps/app_mobile/build/cc0_53bone_retarget/three_pilot_motion_quality_v98.json`. Contiene `approved:false`, `enabled:false` y condiciones de revisión pendientes.
- La generación y los tests se ejecutan mediante pasos **ya existentes** del workflow público: `Retarget three CC0 exercises to full GLB and mobile LOD`, `Test 53-bone CC0 retargeting` y `Check actual GLB linear interpolation and planted contacts at 30 FPS`. No se agrega CI al repositorio privado.

## Bloqueos explícitos, no resueltos

- Los tres candidatos de ejercicios están retargeteados sobre el **rig CC0 original de 53 articulaciones**, mientras que el master muscular de 55 articulaciones y ocho morphs tiene por ahora siete patrones **genéricos**. No son intercambiables; esta fase **no hace retarget al master de 55 huesos**.
- Una malla de barra cercana a una mano no demuestra si los dedos realmente agarran la barra. La posición del nodo pelvis por encima del plano del banco no demuestra contacto anatómico del tejido. El GLB carece aún de un sistema completo de detección de colisiones piel-equipo, compresión de tejido, escalas antropométricas, contrapesos y cargas musculares verificadas.
- No existe aprobación profesional de técnica, biomecánica, escultura anatómica, coordinación escapular, pies/rodillas, cadera o zona lumbar, ni revisión de animación en teléfono físico.
- Los 229 borradores del catálogo siguen **0 aprobados y 0 habilitados**. No se importan archivos GLB en `pubspec.yaml`, no se habilitan desde el selector y el PR experimental no se fusiona a `main`.

## Siguiente paso técnico

Tras confirmar el nuevo CI, preparar la transición de los **tres pilotos** a controles de 55 articulaciones sobre el master geométrico y crear constraints de contacto de dedos, barra, banco y suelo verificables en todas las muestras antes de escalar a más movimientos. Capturar evidencia en hardware Android/iPhone y someterla a revisión técnica presencial antes de etiquetar cualquier animación como lista.
