# STK Haven — Inicio, fase 2 · panel diario sin duplicaciones

**Fecha:** 13-11-2026 · **PR única:** [#57](https://github.com/fernando15xvs/STK-Haven/pull/57) en `STK-Haven`.
**CI:** solo en espejo `STK-Haven_CI/main`. Sin integración al `main` privado aún.

## Responsabilidades de pantalla

- **Inicio:** decidir acción de hoy: entrenamiento activo/siguiente/completado, check-in de recuperación, metas rápidas de agua/pasos, estado semanal breve y una notificación de récord o sesión reciente. No presenta gráficos de volumen, series por período ni calendario de siete puntos.
- **Progreso > Resumen:** estadísticas de volumen, consistencia, calendario completo, período y observaciones.
- **Progreso > Ejercicios:** gráficos e1RM/PR/reps/RIR, evolución y fechas, historial por movimiento.
- **Músculos/Medidas:** sin réplica en Inicio; mantienen responsabilidades propias.
- **Historial:** detalle de series y notas no se pierde; navegación por ID.

## Diseño implementado

- [x] Encabezado y tarjeta de entrenamiento primero, sin anteponer mensajes largos.
- [x] Recuperación compacta: estado y recomendación; tendencias históricas por acción existente.
- [x] Programa activo conserva semanas y sesiones efectivas, sin confundir la barra temporal con logros.
- [x] Bienestar compacto: dos tiles con `PremiumCard`, `AppTypography`, `AppColors`,
      `AppSpacing`; apilado a 320 dp / texto ampliado; dos columnas solo con espacio.
- [x] Agua: lectura diaria, meta, barra, +250 y menú +500/+750; ajustes y recordatorios conservados.
- [x] Pasos: lectura diaria, meta, barra y estado de sincronización; ajuste de meta y recordatorios.
- [x] Actividad semanal: texto breve de días activos; acceso directo a Progreso > Resumen.
      Se retira el segundo calendario de siete círculos, no se borra ningún dato.
- [x] Resultados recientes: tarjeta de último entrenamiento compacta, sin duplicar comparación de volumen;
      récord por ID abre rendimiento, sin recrear detalle analítico.
- [x] Mensaje de fe opcional se coloca después del contenido central del día.
- [x] Tests de disposición a 320/390/430 dp, texto 100/160 % y actividad semanal.
- [ ] Ejecutar y validar 7/7 CI en el espejo del snapshot final de fase 2.
- [ ] Verificar paridad de todos los blobs de los cambios de fase 2.
- [ ] Pruebas visuales y lector de pantalla en dispositivos físicos (pendientes).

## Límites

Solo se cambia presentación y composición de Inicio. No alterar sensores,
ciclo de vida, refresh, permisos y recordatorios todavía: optimización de
rendimiento y cambio de fecha corresponden a **fase 3**. No hay cambios en
Supabase/Hive, workouts, PR históricos, física de entrenamiento, Fe, Coach,
Motivation o migraciones. `main` privado queda intacto hasta autorización.
