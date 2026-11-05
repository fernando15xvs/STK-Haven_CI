# Progreso 2.0 — cifras legibles en resumen muscular (DES parcial)

Fecha: 2026-11-05 · Rama: `fix/progress-muscle-summary-responsive-20261105`.

## Problema observado en código

`_SummaryCard` mostraba «Series directas», «Trabajados» y
«Sin actividad» en tres `Expanded` de igual ancho. En 320 dp
y texto al 160 %, cada columna conservaba aproximadamente un tercio
del espacio, sin adaptación para cantidades reales grandes. El resumen
es informativo: no debe reducir las cifras a un puntaje ni esconder
información para sostener una cuadrícula fija.

## Solución

- `LayoutBuilder` distribuye 1, 2 o 3 columnas en función del ancho
  real, `MediaQuery.textScalerOf` y longitud del número registrado.
  `Wrap` permite que las tarjetas pasen de fila sin forzar su ancho.
- Mantener cifras reales sin topes o abreviaturas; etiquetas completas,
  Outfit de `AppTypography` y dígitos tabulares.
- Compartir `AppSpacing`, `AppRadius` y los colores
  `AppColors.of(context)`; sin nuevas sombras ni decoraciones.
- Pronunciar explícitamente «Series directas: N», «Trabajados: N»
  y «Sin actividad: N» una sola vez por cifra.
- No alterar `MuscleBalanceCalculator`, grupos históricos
  sin clasificar, registros, XP, rutas, backup, Hive ni Supabase.

## Evidencia y límites

`apps/app_mobile/test/muscle_balance_panel_test.dart` incorpora
24 regresiones: 320/375/390/430 dp × 1.0/1.3/1.6 × claro/oscuro
OLED, junto al test integrado ya existente de grupos históricos e
indirectos. Se verifican 3 cifras, ancho disponible, contenido
semántico completo, tipografía y ausencia de RenderFlex overflow.

**Gate:** 7/7 CI SUCCESS en el espejo `STK-Haven_CI/main`
con hashes de archivos modificados idénticos al PR privado.
Un solo PR canónico, sin PR espejo. No cerrar tareas globales DES,
DATA-09 ni GAM-01. QA real de iPhone/Android y IPA final siguen
pendientes.
