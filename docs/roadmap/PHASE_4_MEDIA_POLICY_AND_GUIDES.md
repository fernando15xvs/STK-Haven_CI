# STK Haven — Fase 4: animaciones Lottie y guías de ejercicios

**18 de octubre de 2026 — Decisión corregida:** priorizar **Lottie JSON vectorial** frente a GIFs, por tamaño, fluidez y control de reproducción. El roadmap original ya decía «No usar GIF pesado por defecto»; la primera entrega de Fase 4 había introducido por error una ruta de GIF. Este documento la sustituye.

## Estrategia de medios

- **Primera opción: Lottie** (JSON vectorial, offline y empaquetado) para un movimiento exacto que pueda representarse con calidad anatómica y biomecánica suficiente. Cada demostración corresponde a un ID de ejercicio, equipo, lateralidad y variante específicos.
- **Poster PNG/WebP** como alternativa estática, con los mismos permisos de distribución y una guía textual accesible.
- **Vídeo corto optimizado (opcional futuro)** únicamente cuando un movimiento humano complejo no pueda representarse fielmente en Lottie. Evaluar tamaño y rendimiento antes de habilitarlo; no implementar automáticamente.
- **No se admitirán GIFs** de ejercicios en el registro de medios. Evitar descargas remotas, animaciones genéricas o mostrar variantes diferentes de la elegida.

## Implementación actual

- `ExerciseDemonstrationLibrary`: 43 guías detalladas con preparación, ejecución y errores. Los demás presets reciben su propia técnica, y los ejercicios personalizados mantienen sus instrucciones.
- `ExerciseDemonstrationCard`: reproduce `Lottie.asset` (versión Flutter compatible fijada en `pubspec.yaml`) solo si existe un medio autorizado; pausar/reanudar, `FrameRate.composition`, fallback textual ante fallos.
- `MediaQuery.disableAnimationsOf`, `SettingsState.reduceMotion` y modo ahorro impiden reproducir movimiento. La ficha conserva los tres pasos incluso sin medios.
- `approvedMedia` permanece **vacío**. Todavía no hay ninguna animación producida/contratada/revisada. No afirmar lo contrario.
- El paquete Lottie utiliza una licencia propia distinta de los derechos de autor de **cada archivo de animación**. Una dependencia de software de código abierto no autoriza a redistribuir animaciones ajenas.

## Validación ANTES de incorporar el primer recurso Lottie

1. **Correspondencia exacta:** vincular a `Exercise.id`; verificar ejecución visual, perspectiva, agarre, equipo y variante. Una elevación lateral no puede ilustrar una elevación frontal.
2. **Derechos trazables:** permiso escrito, fuente, autor, condiciones comerciales, modificación, distribución offline, vigencia y atribución; excluir assets extraídos de apps ajenas o copiados de imágenes de referencia.
3. **Revisión técnica:** un entrenador o especialista comprueba recorrido, control corporal y que ninguna trayectoria visual cause errores.
4. **Formato y peso:** preferir formas vectoriales simples, sin imágenes pesadas incrustadas en JSON; comprimir y medir tanto tamaño empaquetado como CPU/RAM/frecuencia de dibujo.
5. **Manifest local:** almacenar archivos únicamente dentro de `apps/app_mobile/assets/exercise_media/`, declararlos en `pubspec.yaml` cuando existan físicamente, y registrarlos en `approvedMedia` con autor/permiso/atribución. Solo formatos `.json`, `.png` y `.webp`.
6. **Accesibilidad:** modo de movimiento reducido, pausa, guías equivalentes, contraste, lector de pantalla, sin destellos y fallback offline sin bloquear la app.
7. **Cobertura:** empezar por 30–40 ejercicios comunes (press de banca, jalones, remo, elevaciones, sentadilla, peso muerto rumano, curl femoral, hip thrust y core); ampliar gradualmente solo cuando el recurso real coincida con el movimiento.

## Plan de producción iOS y Android

El inventario de **229 IDs sin duplicados**, agrupados en cuatro lotes exactos de
**40 + 60 + 70 + 59**, está en
[`PHASE_4_LOTTIE_229_IOS_ANDROID_PRODUCTION_PLAN.md`](PHASE_4_LOTTIE_229_IOS_ANDROID_PRODUCTION_PLAN.md).

**Exclusión de web:** no implementar medios Lottie en `apps/app_web`;
el reproductor, los JSON de animación y el manifiesto de assets pertenecen
únicamente a `apps/app_mobile` (iOS/Android). La planificación no implica
que ya existan archivos animados: **0/229 recursos completados**.

## Pendiente

- Producir/revisar derechos y anatomía de animaciones específicas, cargar recursos locales reales y medir peso final de Android/iOS.
- Opcionalmente evaluar MP4/WebM optimizado para técnicas imposibles de representar con precisión en Lottie.
- Pruebas físicas y de restauración reservadas para QA final del roadmap, antes de producción.

**Persistencia:** no se modifican `Exercise`, `HiveExercise`, sesiones, series, récords, favoritos, preferencias ni registros históricos. Los medios usan IDs independientes y guías de solo lectura.
