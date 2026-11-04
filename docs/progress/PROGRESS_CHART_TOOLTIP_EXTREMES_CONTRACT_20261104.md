# Progreso 2.0 — Tooltips y límites de gráficos (GRAF-02 / GRAF-04)

**Fecha:** 2026-11-04 · **Ámbito:** gráfico de volumen de Resumen y
gráfico e1RM independiente para ejercicios. Sin cambios en cálculos,
persistencia, datos históricos ni PR/gamificación.

## Contrato visual y de selección

- Ambos gráficos reutilizan `ProgressChartStyle` para la familia Outfit,
  colores semánticos del tema, fondo del tooltip, padding y ancho máximo.
  Los decimales y separadores siguen la configuración española; cada tooltip
  presenta **fecha completa, valor y kg/lb**. Nunca se muestra `15912.0`
  sin unidad.
- Cuando una persona toca un dato, ambos gráficos dibujan un **punto
  circular delimitado** y una **guía vertical discontinua** con colores del
  tema, sin introducir verdes o grises fijos. La guía sigue siendo
  distinguible del resto de la curva, incluso en OLED.
- El tooltip conserva `fitInsideHorizontally/Vertically` y el mismo ancho
  máximo de contenido. Se define explícitamente su separación de 14 dp
  respecto del punto seleccionado; no se dibuja la cifra sobre la marca.
- Los puntos de los extremos mantienen padding lateral y los límites Y se
  calculan de las magnitudes **ya convertidas** a kg/lb. Los valores planos
  se dibujan en un intervalo vertical no nulo.
- En e1RM, las fechas inicial/final pueden ocupar dos líneas separadas con
  `Expanded`, evitando cortar «31 oct» en 320 px y texto al 160 %.
  Debajo del gráfico se presenta un resumen pequeño pero permanente
  **Mín. / Máx.**, con formato español y unidad, distribuido con `Wrap`
  (sin desbordar en kg/lb). Esto permite leer el pico **39 kg** sin
  tener que taparlo con un dedo, y no afirma que sea un récord absoluto.
- Los lectores de pantalla reciben fechas, último e1RM, mínimo y máximo
  *mostrados*. No se interpreta un dato estimado como diagnóstico.

## Pruebas

`apps/app_mobile/test/features/progress/progress_chart_touch_extremes_test.dart`
comprueba el comportamiento de ambos gráficos a 320/390 px, texto 100 % /
160 %, claro y oscuro OLED; comprueba guías, puntos seleccionados,
contenido y formato de tooltip de puntos primero/intermedio/último,
márgenes y ajuste a los límites, y que extremos 37,7/39 kg o valores
iguales quedan visibles sin `RenderFlex` ni otras excepciones.
`progress_chart_viewport_matrix_test.dart`,
`progress_chart_readability_test.dart` y
`progress_tooltip_semantics_test.dart` siguen verificando los 8 acentos,
320/375/390/430, lb/kg, clipping horizontal y contraste >=4,5:1.

**Criterio de merge:** analizar y ejecutar pruebas Core/UI y compilaciones
Android/iOS en el espejo público, con 7/7 trabajos obligatorios en verde y
SHA idénticos de todos los archivos de este PR. Ningún PR en el espejo.
Aun con CI verde, pruebas reales VoiceOver/TalkBack y dispositivos físicos
permanecen pendientes: QA-05/06/07 y GRAF-02/04 no deben confundirse con
validación física.
