# STK Haven — Inicio: versículo primero y navegación sin duplicados
**Aprobado:** 23/11/2026 · PR canónica: #57 (DRAFT) · Espejo `STK-Haven_CI/main` solo para Actions.

## Diseño aprobado
1. Saludo y fecha; versículo inmediatamente después si Fe y el ajuste de reflexión diaria están activos. Vista previa de **hasta cuatro líneas**, con referencia bíblica separada abajo. Al pulsar se abre el mismo lector de reflexión, sin sustituir texto bíblico ni alterar la preferencia de Fe.
2. Sin entrenamiento activo, no hay «Tu entrenamiento», «Ir a Entrenar» ni hero de próxima sesión en Inicio: la pestaña inferior ya navega a Entrenar. Con sesión activa, solamente la fila «Continuar» abre la sesión existente (mismo ID), respetando su estado de revisión.
3. Sección propia «RECUPERACIÓN» para el check-in existente y su estado correcto (pendiente, activo, completado o guardado); no cambiar escalas, persistencia ni historial.
4. «BIENESTAR» mantiene Agua, Pasos, permisos y metas; el acceso a nutrición se llama «Nutrición», con la ruta anterior intacta.
5. «ACTIVIDAD SEMANAL» tiene una única cabecera y la tarjeta compacta «Resumen de tus sesiones», con un conteo calculado del historial real y acceso directo a Progreso. Se conservan «Finalizado hoy», notas, últimas sesiones y récords.

## Checklist
- [x] Reorganizar Inicio y limitar la reflexión a cuatro líneas + referencia separada.
- [x] Eliminar `home_open_train` y callbacks redundantes `onOpenTrain` del dashboard, wrapper y shell; mantener pestaña Entrenar intacta.
- [x] Check-in bajo Recuperación y enlace Nutrición inequívoco.
- [x] Resumen de actividad compacto, totalmente pulsable y accesible, sin métricas inventadas.
- [x] Actualizar contratos de Home, Entrenar y navegación a Progreso.
- [ ] CI del nuevo HEAD: **7/7 verde** en espejo; el CI anterior no valida este cambio.
- [ ] QA real iPhone/Android: claro/oscuro/OLED, 320/390/430 dp, escala 100/160/200%, VoiceOver/TalkBack, versículo largo/corto, Fe desactivada, sesión activa/inactiva.
- [ ] Confirmar recuperación de la misma sesión al volver desde Inicio, reproducción de música, temporizador y actualización sin pérdida de datos.

**No se cambian:** Hive, Supabase, IDs de entrenamiento, historial, planes, permisos ni onboarding. No fusionar #57 sin autorización.
