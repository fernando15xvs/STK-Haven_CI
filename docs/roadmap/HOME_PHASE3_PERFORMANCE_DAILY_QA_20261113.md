# STK Haven — Inicio · Fase 3: rendimiento, fecha y accesibilidad

**13-11-2026 · PR #57 (única, repositorio canónico)** · Mirror exclusivamente para Actions.

## Contratos de funcionamiento

- Inicio se conserva en `IndexedStack`, pero recibe `isVisible` desde la pestaña. Al salir, detiene temporizadores de reloj y pasos; al volver, refresca el estado actual sin recrear tabs ni filtros.
- Al regresar del segundo plano, recupera datos diarios y reinicia los sondeos solo en primer plano.
- El reloj de Inicio consulta una vez por minuto **solo cuando está visible**; reconstruye el encabezado únicamente al cambiar de día o pasar los límites de saludo (12:00 y 18:00).
- El cambio de día actualiza hidratación/pasos y vuelve a obtener recuperación, la próxima rutina del programa y el pasaje diario. No modifica sesiones, PR o métricas históricas.
- Los pasos nunca solicitan el permiso automáticamente al abrir Inicio; «Conectar pasos» activa el permiso mediante acción explícita. La lectura normal usa únicamente acceso concedido previamente.
- Sondeo normal de pasos: 1 minuto; modo ahorro: 5 minutos. En otras pestañas o con la app en segundo plano no hay sondeo.
- Si la lectura del sensor termina después de cambiar de fecha o pestaña, se descarta para impedir atribuir los pasos al día equivocado. Una respuesta tardía no debe generar recordatorios.
- Recordatorios de pasos conservados; evitar reprogramaciones repetitivas mientras se mantiene la meta y respetar un período nuevo aunque el anterior fuera hace menos de 15 minutos.
- La hidratación vuelve a verificar la fecha y reprograma sus recordatorios al regresar o cambiar el día.
- Conservar la información en su lugar correcto: Inicio orientado a hoy, Progreso contiene analíticas y calendario histórico.

## Checklist

- [x] Propagación explícita de visibilidad sin destruir el estado de la pestaña.
- [x] Temporizadores de Inicio y pasos detenidos fuera de pantalla/segundo plano.
- [x] Cambio de día y de horario de saludo, con invalidaciones diarias seguras.
- [x] Permiso del sensor a demanda y descarte de lecturas obsoletas.
- [x] Intervalo extendido en modo ahorro; sincronización de recordatorios regulada.
- [x] Tests puros para medianoche, saludos, visibilidad, intervalos y casos de ahorro.
- [x] Test visual de distribución OLED/acento a 390 dp con escala 1.6; mantener los 320/390/430 dp de fase 2.
- [ ] Ejecutar CI del snapshot fase 3 (Analyze, Core, mobile, anatomía, Edge, Supabase, iOS, Android).
- [ ] Confirmar paridad de todos los blobs cambiados en CI espejo antes de integrar.
- [ ] Verificación física (iPhone/Android) con permiso denegado/concedido, segundo plano, cambio de día y lector de pantalla.
- [ ] Validación visual de los 8 acentos, OLED y modo ahorro en dispositivos reales.
- [ ] Aprobar revisión y fusionar PR #57 exclusivamente en repositorio privado; nunca abrir PR en espejo.

## Límites

No modificar persistencia histórica Hive, migraciones Supabase, Auth, backups,
Coach, Motivation, ejercicio/rutinas, recompensas, o matemáticas de progreso.
La aplicación no obtiene acceso a un sensor sin intervención explícita del usuario.
Las compilaciones CI no sustituyen QA físico.
