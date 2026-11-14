# STK Haven — Ajustes finales de Inicio y Entrenar

**Fecha:** 13-11-2026  
**Estado:** PLAN APROBADO PARA DOCUMENTAR; **implementación NO iniciada** en este bloque.  
**PR única:** [#57](https://github.com/fernando15xvs/STK-Haven/pull/57) · rama `fix/home-phase1-data-navigation-20261113`.  
**CI:** solamente `fernando15xvs/STK-Haven_CI/main`; sin PR espejo, sin merge.  
**Base auditada:** `7b3838b66a92aadd0f71963306db11554f1af862` (código); última ejecución anterior `43520485700` 7/7 verde.  
**Motivo:** capturas de iPhone de 13 de noviembre: diferencia de altura Agua/Pasos, mensaje invisible al final, STK Motivation fijo en Entrenar y siete días sin configurar que confunden programación de rutina con programa.

## Reglas no negociables

1. **Inicio = estado de hoy:** mantener el resumen de entrenamiento (activo, planificado o finalizado) en Inicio. No trasladar ese hero a Entrenar ni duplicarlo allí.
2. **Entrenar = gestión:** el programa activo (horario/rotación), sus rutinas, plantillas y sesiones manuales se administran aquí; Progreso conserva históricos y gráficas.
3. **Motivation = botón +:** quitar **todo** el footer `MotivationMiniPlayer` de Entrenar, tanto launcher vacío como mini-player en reproducción. El playback global, archivos, playlists y controles en el módulo Motivation siguen intactos.
4. **Fe opt-in:** el mensaje se muestra solo si `faithEnabled && settings.showDailyVerse`. No forzar activación ni crear una segunda fuente de versículos.
5. **Diseño unificado:** `AppTypography` Outfit con pesos legibles, `AppColors`, `AppSpacing`, `PremiumCard`, mismos radios, bordes y jerarquía visual. Ningún nuevo color fijo ni tipografía local.
6. **Datos protegidos:** conservar `Routine.scheduledDays` como programación **opcional e independiente**, por compatibilidad; `TrainingProgram` controla semana fija, continua o flexible si está activo. No borrar horarios existentes, historial, medios ni editar Supabase/Hive para cambios de presentación.

## Diagnóstico basado en código (sin cambios de app)

| Pantalla | Evidencia | Diagnóstico |
| --- | --- | --- |
| Inicio | `dashboard_page.dart:200–282` | `_DailyMessageCard` está después de Actividad y Novedades, por eso queda fuera de la primera vista; `_ActiveProgramCard` legacy puede interponerse entre Recuperación y Bienestar. |
| Bienestar | `home_wellness_layout.dart:19–41` | El Row ya usa dos `Expanded` de igual ancho, pero `crossAxisAlignment.start` no iguala alturas. Agua y Pasos tienen pie de contenido distinto. |
| Agua/Pasos | `hydration_widget.dart:226–329`, `daily_steps_widget.dart:359–456` | Agua presenta +250 ml/menú; Pasos presenta estado del sensor y botón conectar si es necesario. No deben ocultarse por buscar simetría. |
| Mensaje | `dashboard_page.dart:336–447` | Versículo completo + `ContextualPassageDetails` ocupa altura elevada. Ya existe navegación a `DailyVersePage` para leer todo. |
| Entrenar | `routines_page.dart:40–154` | `MotivationMiniPlayer(showLauncherWhenEmpty: true)` se coloca **fuera de la lista**, justo encima de barra inferior, y produce el chip que estorba. |
| Mis rutinas | `routines_page.dart:682–842` | La card genera L–D desde `routine.scheduledDays` y lista 3 nombres truncados. La programación real del plan está en `activeTrainingProgramProvider` / `ProgramScheduleProjector`. |
| Datos de rutina | `routine.dart`, `training_program.dart`, `workout_session.dart` | Hay IDs de rutina, ejercicios, músculos y `WorkoutSession.routineId/finishedAt/durationSeconds` para metadatos reales; **no hay duración prevista universal ni es correcto inventarla**. |

## Bloque A — Inicio: jerarquía y bienestar

- [ ] **A1. Igualdad visual de Agua y Pasos.** Mantener ambas columnas exactamente al 50 % del espacio disponible en modo horizontal y darles **igual altura renderizada** sin imponer una altura rígida que rompa el texto al 200 %. Usar restricciones de fila estirada y estructura interna homogénea: encabezado, valor, meta, barra y **zona inferior con espacio flexible**. Conservar CTA +250, menú, estado de sensor, permisos y conectar pasos; accesibilidad y scroll intactos.
- [ ] **A2. Responsive.** En 320 dp o texto grande mantener disposición vertical ya prevista; en 390/430 dp con texto normal dejar dos cards equilibradas. Al apilar, permitir altura natural en cada card; no exigir mismas alturas si eso genera espacio muerto o overflow. Revisar números de 5–7 cifras, objetivos largos, sin permiso, dispositivo no disponible y 0 %/100 % de meta.
- [ ] **A3. Orden aprobado de Inicio (alternativa A):** `Tu entrenamiento → Recuperación de hoy → Mensaje de hoy (si opt-in) → Bienestar → Actividad → Novedades`. Garantizar que una card legacy de programa no se interponga; si es redundante con el resumen de entrenamiento, retirar **solo la vista redundante**, sin borrar estado/datos de programas.
- [ ] **A4. Mensaje compacto.** Máximo de **2–3 líneas de texto de versículo** con elipsis, etiqueta «Mensaje de hoy», referencia y acción accesible **«Leer completo»** que abre la pantalla de pasaje existente. Sin incrustar `ContextualPassageDetails` expandido en el dashboard; lectura completa/capítulo permanecen disponibles en `DailyVersePage` / lector bíblico. La acción también funciona con teclado/VoiceOver.
- [ ] **A5. Estados y privacidad.** Respetar `dailyVerseProvider` (cargando, error, reintentar y contenido), `faithEnabled` y `showDailyVerse`, cambio de fecha y tema, sin nuevos listeners/timers ni consultas innecesarias.
- [ ] **Gate A:** pruebas de disposición y orden, tarjetas a altura idéntica en horizontal, acciones y opt-in; CI espejo 7/7 antes de pasar a B.

### Resultado visual esperado Inicio

1. Tu entrenamiento: intacto (iniciar / continuar / finalizado).
2. Recuperación: intacta.
3. **Mensaje de hoy:** una card compacta con pasaje recortado, referencia, «Leer completo»; no ocupar toda la pantalla.
4. Bienestar: Agua | Pasos, **ancho y altura iguales en dos columnas**.
5. Actividad; luego Novedades.

## Bloque B — Entrenar: foco y tarjetas de Mis rutinas

- [ ] **B1. Retirar footer STK Motivation.** Eliminar el `MotivationMiniPlayer` en `RoutinesPage` (y su import innecesario); no crear otro launcher, botón ni duplicado en Entrenar. El audio/video que ya se reproduce **no debe detenerse ni reiniciarse** al navegar: el reproductor vive en `MotivationPlayback`, fuera de la vista eliminada. Acceso directo mediante «+ → Motivation»; si hay media activa, allí se pueden gestionar sus controles.
- [ ] **B2. Quitar L/M/X/J/V/S/D de cada card.** Eliminar la visualización de 7 chips y su espacio. **No tocar** `Routine.scheduledDays`, el editor opcional de rutina ni el plan semanal de modo libre: los datos existentes siguen disponibles para quienes los usen. El programa activo siempre prevalece para el calendario oficial.
- [ ] **B3. Tarjeta sobria y precisa.** Presentar nombre, «N ejercicios», uno o dos grupos musculares/enfoques **derivados de los ejercicios vinculados y sus músculos reales** (solo si hay información), y estado real de vinculación: «En: {programa activo}» si `active.routineIds` contiene ID; de lo contrario «Rutina guardada» / «Libre», sin falsos días asignados. Respetar nombres largos y datos faltantes.
- [ ] **B4. Última ejecución real y duración.** Mostrar «Última vez: …» **solo** si existe sesión finalizada con `WorkoutSession.routineId == Routine.id`; usar fecha local `finishedAt.toLocal()`. Si falta ID histórico, omitir (no asociar por nombre). Duración como **«Habitual: ~N min»** solo con sesiones históricas suficientes y `durationSeconds` válido; si no hay evidencia, no inventar minutos ni inflar la tarjeta. Estos metadatos son secundarios, no estadísticas de Progreso.
- [ ] **B5. Acciones.** Mantener un CTA primario «Iniciar», menú editar/notas/duplicar/eliminar, acceso a plantillas, plan rápido y gestión avanzada. Igualar alturas/márgenes según contenido razonable, no forzar a que nombres o notas largos corten botones. Conservar accesibilidad y estado vacío.
- [ ] **B6. Separación programa vs rutina libre.** Si aporta claridad y sin duplicar tarjetas, mostrar un estado/etiqueta de pertenencia en cada rutina; no mostrar el mismo calendario en tres sitios. El gestor `Mi programa` conserva agenda, rotación y días; iniciar una rutina manual no cambia indebidamente la programación.
- [ ] **Gate B:** no footer Motivation en Entrenar con o sin audio; no círculos de días; metadatos respaldados por datos reales; los modos fijo/continuo/flexible y sesiones libres siguen bien; CI 7/7.

## Bloque C — coherencia visual, regresiones y QA

- [ ] **C1. Pantallas:** widget/layout tests a 320, 390, 430 dp × escalas 100, 160 y 200 %, claro/oscuro/OLED y ocho acentos. En horizontal, verificar **alto exacto igual** para Agua/Pasos; en vertical, sin overflow ni CTA tapados.
- [ ] **C2. Inicio:** orden A3, pasajes muy largos, loading/error, texto ampliado, cambio de fecha, Fe apagada o versículo oculto; lector y «Leer completo» navegables. El entrenamiento completado/activo no se desplaza a Entrenar.
- [ ] **C3. Entrenar:** ninguna ruta a Motivation repetida, reproducción continua y sin duplicar `AudioPlayer`, rutinas en programa activo/pausado/libres, tres modos de programación, sin historial y con historial; nombres de ejercicios/músculos ausentes; acciones CRUD y confirmación.
- [ ] **C4. Rendimiento y seguridad:** evitar recomputar agregados de historial por card en cada rebuild; derivaciones memorizadas o precomputadas si es necesario. No cambiar persistencia, permisos, REST, Hive, audio ni sincronización.
- [ ] **C5. Accesibilidad real:** VoiceOver/TalkBack, contraste, orden de foco, zonas táctiles >=44dp cuando correspondan, textos completos accesibles, teclado, reducir movimiento; no depender de chips colorizados.
- [ ] **C6. CI y paridad:** `flutter analyze`, tests Core/mobile, iOS, Android, Supabase y gates espejo **7/7**, SHA de blobs principales/espejo iguales, PR #57 abierta/draft sin fusionar.
- [ ] **C7. QA físico:** iPhone/Android y navegador cuando aplique; guardar modelo/OS/capturas y diferencias, no marcar verificaciones físicas como hechas por CI verde.
- [ ] **C8. Sin IPA nuevo hasta que la implementación pase gates**, excepto petición expresa del usuario.

## Secuencia de implementación propuesta

1. **A1–A5** (composición Inicio) → tests → mirror CI.
2. **B1–B6** (quitar duplicación y enriquecer tarjetas de rutina) → tests → mirror CI.
3. **C1–C8** (QA transversal y paridad) → últimas correcciones → mirror 7/7.

No crear PRs nuevas. Nunca fusionar la #57 sin autorización explícita. **Este commit es exclusivamente documentación: ninguna línea funcional de Flutter ha sido modificada.**
