# Progreso 2.0 — tarjetas de resumen de medidas (DES-01/05/07/09 parcial)

Fecha: 2026-11-05 · Alcance limitado a `BodyMeasurementSummary`.

## Problema concreto

Las cuatro tarjetas de Peso, Grasa corporal, Cintura/cadera y Altura usaban
altura fija de 119 px, espaciados y radio numéricos aislados, valores en
`FittedBox(scaleDown)` y textos secundarios de una sola línea.
A escala grande, el resultado puede reducir cifras y ocultar información,
aunque los datos originales sean correctos.

## Contrato del cambio

- Usar `AppTypography` (familia Outfit y números tabulares), `AppSpacing`,
  `AppRadius` y colores semánticos `AppColors.of(context)`.
- Las cuatro tarjetas de la misma fila crecen en función de
  `MediaQuery.textScalerOf(context)`: 119 px a 1.0, 215 px a 1.6,
  sin disminuir el tamaño de texto con `FittedBox`.
- Permitir hasta dos líneas para título, cifra y leyenda; conservar la
  distribución 2×2 de `Wrap` y la lectura mediante scroll en tamaños compactos.
- Añadir una descripción semántica unificada por tarjeta que pronuncie
  título, cifra y unidad, más comparación/estado. Si no existe dato,
  pronunciar «Sin registro» en vez de un guion aislado.
- Mantener sin modificación los cálculos, el orden de registros, las unidades,
  el historial, Hive, Supabase, XP, navegación y assets.

## Evidencia exigida

`apps/app_mobile/test/features/progress/body_measurement_summary_test.dart`
cubre datos parciales, kg/lb, ocho acentos claro/oscuro a 320 px y añade
320/390 px × claro/oscuro × escala de texto 1.6, con etiquetas habladas
y `tester.takeException()==null`. La aceptación de merge exige 7/7 jobs
verdes en `STK-Haven_CI/main` con hashes blob idénticos para los archivos
modificados de este PR. No se atribuye al CI una prueba física en iPhone
ni Android. DES-01/05/07/09 global y QA-05 a QA-10 siguen pendientes.
