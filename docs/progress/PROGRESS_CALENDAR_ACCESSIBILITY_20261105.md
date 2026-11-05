# Progreso 2.0 — calendario legible y accesible (DES-01/03/07/09 parcial)

Fecha: 2026-11-05. Rama: `fix/progress-calendar-accessible-grid-20261105`.
Alcance: `CalendarHeatmapCard` de Progreso > Resumen.

## Defecto y solución acotada

Los siete encabezados del calendario eran solo letras `L M X J V S D`,
y cada día ocupaba una fila fija de 18 dp dentro de una altura fija
de 126 dp. Al elevar el tamaño de texto, el espacio para el glifo
podía ser insuficiente. El color `textDisabled` se usaba para texto
informativo de los días de la semana.

- Mantener los glifos visuales, pero ofrecer `Lunes` hasta `Domingo`
  como nombres completos para lectores de pantalla.
- Usar `AppColors.textSecondary` (no `textDisabled`) para los
  encabezados informativos, manteniendo Outfit de `AppTypography`.
- Escalar el tamaño de celda de 18 dp hasta como máximo 36 dp con
  `MediaQuery.textScalerOf(context)`; el alto del grid es siete filas
  de ese tamaño. Los cuadros de color y su significado no cambian.
- Alinear los días fuera de período y los encabezados al mismo paso;
  preservar desplazamiento horizontal cuando hay muchas semanas.
- No cambiar fechas, zonas horarias, unidades, conteos de días activos,
  sesiones, puntuaciones, reglas de inclusión, datos Hive, Supabase,
  pantalla de Historial, Coach ni Motivation.

## Aceptación

`calendar_heatmap_accessibility_test.dart` prueba 320px,
claro/oscuro OLED, escala 1.0/1.6, nombre hablado completo de cada
día y conteos reales: un día con dos sesiones sigue teniendo dos
sesiones y los vacíos no reciben entrenamiento inventado. Mantener
`progress_summary_scope_test.dart` y las pruebas previas.

Exigir 7/7 trabajos CI obligatorios en el espejo
`STK-Haven_CI/main` y paridad exacta de hashes de archivos cambiados
antes de integrar un solo PR canónico en `STK-Haven`.
No marcar DES-01/03/07/09 ni QA de dispositivos como finalizados:
requieren auditoría completa y pruebas físicas iOS/Android.
