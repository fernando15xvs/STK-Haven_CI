# STK Haven — rediseño de entrenamiento activo (21/11/2026)

**PR canónica:** [STK-Haven #57](https://github.com/fernando15xvs/STK-Haven/pull/57) · **CI:** solo `STK-Haven_CI/main` · **Alcance:** Flutter móvil, UX/UI, sin migraciones ni restauración de datos.

## Decisión visual aprobada

La pantalla de Upper B mostraba descanso demasiado alto, Memoria flotante sobre series, «Acciones» en una segunda fila por serie, guía extensa y un CTA de finalizar visualmente muy pesado. Prioridad: **peso, reps, RIR, completar la serie y siguiente ejercicio**; mantener la estética STK Haven (Outfit, AppColors, AppSpacing, contraste, claro/oscuro/OLED).

## Bloque A — Jerarquía de la pantalla

- [x] Descanso en componente `WorkoutRestControls`, en el flujo normal: cuenta exacta MM:SS, omitir, +15, +30, personalizar. Sin cronómetros duplicados ni barra de progreso ficticia.
- [x] Eliminar acceso flotante `memory_launcher` que ocultaba la tabla. En cada cabecera se muestra acceso contextual a **Memoria del ejercicio**; conserva hoja inferior, último desempeño, copiar serie, entrada rápida, 1RM y deshacer. Identificación por `instanceId`, no por índice mutable.
- [x] En cabecera, tiempo real de sesión más series efectivas completadas/total. Sin sumar calentamiento o aproximación como serie efectiva.
- [x] Compactar cabecera de ejercicio y márgenes; preserva estado expandido/contraído, grupos, superseries, notas, menú y navegación a técnica.
- [x] Botón permanente **Finalizar entrenamiento** y diálogo de sesión parcial siguen intactos; menor margen adicional, sin solapar campos.

## Bloque B — Registro y contexto

- [x] Menú de estado `Pendiente/Omitida/Fallida/Eliminar` dentro de la misma fila de la serie y al lado del check; mantener pulsación larga como alternativa, con confirmación y límites anteriores.
- [x] Check de completado claramente señalado y foco en kg, reps y RIR; estados completados usan un verde más sutil.
- [x] «Anterior» se mantiene como columna en pantallas anchas y como referencia compacta debajo de la serie en las estrechas; **no** eliminar datos ni inventar carga anterior.
- [x] Alinear columnas cuando RIR está desactivado o no aplica a la serie, sin cambiar los valores de RIR.
- [x] Explicar A/E/etc. con tooltip semántico de tipo de serie. Estados omitido/fallido también textuales.
- [x] En ejercicios unilaterales, indicar «Izq.»/«Der.» en la cabecera y botones por lado con nombres completos; desplegar solo los detalles sobre descanso entre lados.
- [x] Mover la sección desplegable «Guía y progresión» **después** de peso, reps, RIR y añadir serie.
- [x] Modo enfoque disponible también por el menú del entrenamiento, con texto explícito.

## Bloque C — Estabilidad y QA

- [x] `Consumer` propio del countdown, evitando reconstruir todos los ejercicios cada segundo. Se mantienen datos inmutables del provider.
- [x] Pruebas nuevas de barra de descanso y acceso contextual a memoria a 320/390/430 dp, texto 100/160/200 %, claro/oscuro, callbacks de +15/+30/personalizar/omitir.
- [x] Contrato de acciones accesibles, hoja de memoria y estructura no flotante.
- [ ] CI principal 7/7 verde **sobre el último SHA del espejo**.
- [ ] QA física iOS/Android: teclado abierto, memoria de cada ejercicio, ordenación, series fallidas/omitidas, unilateral por lados, RIR on/off, 320dp 200 %, app bloqueada, descanso a cero y música externa.
- [ ] QA de firma iOS: el IPA sin firmar no es instalable; mantener Team ID/Bundle ID/entitlements y nunca desinstalar una app con historial en Hive.

## Arquitectura y no regresiones

Archivos clave:

- `apps/app_mobile/lib/features/workout/presentation/active_workout_page_content.dart`
- `apps/app_mobile/lib/features/workout/presentation/widgets/workout_rest_controls.dart`
- `packages/core/lib/features/workout/presentation/widgets/active_workout_memory_overlay.dart`

**No** alterar cálculo de volumen, 1RM, progresión, descansos, notificaciones nativas, timestamps, política de sesiones parciales, modelo Hive, Supabase ni rutas de restauración. Una compilación iOS de GitHub Actions no firmada no prueba comportamiento de audio en dispositivo.
