# Progreso 2.0 — etiquetas de medidas: contraste y tipografía

**Fecha:** 2026-11-04 · **Bloque:** auditoría localizada DES-01 / DES-03 / DES-04.

## Problema concreto

Las etiquetas superpuestas a la silueta anatómica de medidas empleaban
`TextStyle(fontSize:10/12)` y colores fijos (blanco, azul-negro y fondo
oscuro codificado), mientras que la app debe compartir **Outfit** y la
paleta temática. La altura de 42 dp tampoco escalaba con texto al 160 %,
arriesgando números desbordados o etiquetas contiguas superpuestas.

## Corrección

- Encabezados de etiqueta: `AppTypography.labelSmall` (Outfit). Cifras
  en cm: `AppTypography.bodySmall`, `FontFeature.tabularFigures()`.
- Fondo no seleccionado: `AppColors.surfaceHigh`, etiqueta
  `textPrimary` y cifra `primary`. Seleccionado: fondo `primary`
  y ambos textos `onPrimary`. Sin colores fijos de texto.
- Borde y radio proceden de `AppColors.surfaceBorder` y
  `AppRadius.sm_`. Espacios con `AppSpacing`. La imagen anatómica
  original y sus ilustraciones no se tocan.
- Etiquetas de dos filas aumentan de altura con `MediaQuery.textScalerOf`
  y el lienzo se adapta a la altura mínima necesaria para evitar
  solapamiento entre etiquetas del mismo lado a 320 px y 160 %.
- Semántica íntegra por métrica: nombre y valor completo en cm para
  usuarios de lector de pantalla, incluso cuando el nombre visual
  necesita puntos suspensivos.

## Regresiones

`progress_measurement_badge_theme_test.dart`: los **ocho acentos**,
tema claro/oscuro OLED, ancho 320 px y texto al 160 %. Verifica que
nombres y valores usen Outfit y tokens de tamaño, cifras tabulares,
contraste matemático >=4,5:1 entre texto y fondo seleccionado/no
seleccionado, ausencia de desbordes, y separación física entre etiquetas.
Además hay una comprobación de navegación al detalle de la medida a
390 px. Se conservan los tests previos de silueta y activos PNG reales.

No se modifican las imágenes PNG, medidas/historial, cálculo de
perímetros, persistencia ni navegación a otras pantallas. Este PR
avanza **parte de DES-01/03/04**; las tareas globales permanecen abiertas
hasta su auditoría completa y QA de dispositivos. Requiere CI 7/7 con
igualdad SHA frente al espejo antes de fusionar.
