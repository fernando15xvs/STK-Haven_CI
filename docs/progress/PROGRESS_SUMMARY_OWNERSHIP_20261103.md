# Progreso 2.0 — Propiedad de cada sección de Resumen (UX-01)

**Fecha:** 2026-11-03 · **Alcance:** simplificación de `Progreso > Resumen`.

## Regla de experiencia de usuario

En `Resumen` se muestra exclusivamente una lectura resumida del progreso
observado en el período seleccionado: **volumen total y comparación contra el
período previo**, **tendencia temporal de volumen**, **consistencia (entrenos
por semana + duración media registrada)**, **calendario de actividad real** y
**observaciones justificables derivadas de datos registrados**.

**No duplicar** aquí las tarjetas globales de número de entrenamientos,
series, tiempo y récords ni la lista de últimos seis entrenamientos con
su segundo acceso a detalles. El calendario ya explica cuántas sesiones y
días activos tuvieron evidencia; la consistencia explica ritmo y duración.
La ficha de cada ejercicio es propietaria de sus propias métricas específicas.
El historial de entrenamientos y los detalles individuales siguen accesibles
mediante las pantallas de historial existentes; no se borra ningún entrenamiento
ni se deshabilita el servicio de detalles de sesión.

## Comportamiento conservado

- Misma fuente `progressMetricsProvider`, filtros `7D/1M/3M/1A`,
  `WorkoutHistoryNotifier` y `ProgressInsightCalculator`. No se cambian
  las fórmulas, el recuento de PR ni los datos persistidos.
- `ProgressInsightsPanel` conserva su estado de descartes/restauración.
- `ProgressPage` mantiene sus cuatro pestañas y las rutas de ficha técnica,
  rendimiento, historial individual, músculos y medidas sin navegación circular.
- Se añade encabezado accesible y coherente `TENDENCIA DE VOLUMEN · 1M`,
  usando `AppTypography` y `AppColors` en lugar de grises fijos.
- CI inicial detectó un desbordamiento de 6 px (escala 1.0) y 126 px
  (escala 1.6) en la vista real 320 px. El calendario sustituye la leyenda
  horizontal rígida por un `Wrap` con parejas icono + etiqueta que conservan
  todo el texto. Los tests ahora distinguen fallos iniciales de fallos al
  desplazar el calendario/observaciones; **no se declara solucionado hasta
  validar CI del nuevo SHA**.
- No hay cambios a Hive, Supabase, gamificación, Coach, Motivation, programas
  o datos de entrenamiento.

## Criterios comprobables

`apps/app_mobile/test/features/progress/progress_summary_scope_test.dart`
comprueba 320 px, claro/oscuro OLED, escalas 1.0 y 1.6, persistencia de los
componentes de volumen, tendencia, consistencia, calendario y observaciones;
ausencia de KPI y lista recientes duplicados; y ningún
`tester.takeException()`. El historial global continúa en sus propias rutas,
fuera de Resumen.

La prueba automatizada **no sustituye** la revisión real de VoiceOver,
TalkBack, retorno de navegación ni el recorrido físico iPhone/Android.
Fusionar solo si CI del espejo aprueba 7/7 para el mismo SHA.
