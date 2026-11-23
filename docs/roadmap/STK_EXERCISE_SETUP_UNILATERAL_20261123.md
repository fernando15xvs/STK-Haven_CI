# STK Haven — Configuración de ejercicio: UX y descansos unilaterales (23/11/2026)

**PR canónica #57 (DRAFT)** · Espejo STK-Haven_CI/main solo CI. Cambios aprobados con Outfit, AppTypography, AppColors, AppSpacing y PremiumCard compartidos.

## Funcionalidad
- [x] Configurador modal con X accesible, Cancelar y Guardar fijos. Solo el formulario desplaza; teclado y textos grandes se contemplan sin ocultar las salidas.
- [x] Evitar descartar cambios sin avisar: PopScope + confirmación. Edición y creación preservan la rutina hasta pulsar Guardar.
- [x] Reutilizar PremiumCard, controles y tokens de la app; reducir textos y plegar Ubicación, Preparación y Nota técnica.
- [x] «Series y repeticiones» sin título duplicado; tiempo de descanso entre series formateado y configurable a cero.
- [x] «Trabajo unilateral» con Directo (0 s) y Con pausa; un campo compartido reutilizado en rutina y sesión permite duraciones recomendadas o segundos personalizados 1–600, conservando valores históricos.
- [x] En ejercicio nuevo unilateral, para evitar un segundo contador no solicitado, el descanso posterior a la serie comienza en cero si todavía no fue editado. En rutinas existentes se respetan ambos descansos previos hasta su edición.
- [x] Guardar sigue conservando sets, reps, calentamiento, aproximación, descansos, preferencia de lado, nota técnica y grupo de superserie.
- [x] El motor nunca inicia un segundo descanso automáticamente cuando la última serie unilateral cierra toda la sesión. Mantiene descanso de serie cuando hay trabajo pendiente, y no cambia el comportamiento bilateral heredado.

## Pendiente de validar
- [ ] CI último HEAD 7/7 (Flutter mobile, core, iOS/Android artifacts, Supabase).
- [ ] QA físico iPhone/Android, OLED, 320/390/430dp y texto 100/160/200%.
- [ ] Crear y editar, abrir teclado y cerrar/cancelar sin guardar, guardar con datos anteriores, unilateral directo/con pausa, 0s entre series, última serie y superseries, background/notifications.
- [ ] Comprobar restauración de rutinas antiguas y backups que incluyan tiempos personalizados sin resetear onboarding.

No fusionar PR sin aprobación; no modificar datos Hive/Supabase ni cambiar la firma del build.
