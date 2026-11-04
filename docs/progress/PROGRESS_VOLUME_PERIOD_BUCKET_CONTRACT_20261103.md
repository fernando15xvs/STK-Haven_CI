# Progreso 2.0 — Eje temporal, volumen y legibilidad de gráficos

**Fecha:** 2026-11-03. **Alcance:** DATA-01, GRAF-06 y regresiones relacionadas.
**Fuente de verdad:** historial local de `WorkoutSession`; el gráfico no altera Hive.

## Contrato de volumen (DATA-01)

Las sesiones elegibles se filtran antes por actividad efectiva, `finishedAt`
y el intervalo temporal seleccionado. El cálculo interno sigue en kg y la vista
convierte a la preferencia kg/lb *después* de agrupar. La suma de la tarjeta es
la suma real de todas las sesiones elegibles, sin interpolar datos ausentes.

| Selección | Intervalo | Agrupación | Fecha X de cada punto |
|---|---|---|---|
| 7D | últimos 7 días móviles | Día calendario local | Día de finalización |
| 1M | últimos 30 días móviles | Día calendario local | Día de finalización |
| 3M | últimos 90 días móviles | Semanas de 7 días, ancladas a la primera fecha local del rango | Primer día del bloque |
| 1A | últimos 365 días móviles | Meses calendario | Primer día del mes |

La diferencia X es **tiempo transcurrido real entre las etiquetas de los
puntos**; no se distribuyen puntos equidistantes por índice. Si no hay
entrenamientos en un bloque, **no se crea un punto de cero**. Si existe un
entrenamiento efectivo con volumen cero (por ejemplo, peso corporal sin carga),
ese punto observado sí permanece. Entradas duplicadas del mismo día o bloque
se suman. Registros `NaN`/infinitos no se grafican. El mes o semana de inicio
puede ser parcial y conserva solo los entrenamientos realmente incluidos.
El eje debe comunicar el comienzo del bloque: `Sem. 5 ago` o `ene 2026`;
el tooltip usa `Semana desde el 5 ago 2026` o `Mes de ene 2026`.

## Guía de gráficos coherentes (GRAF-06)

1. **Tipografía y unidades.** Usar `AppTypography` con Outfit declarada en
   Flutter, nunca una tipografía adicional para valores o ejes. Para números
   tabulares usar `FontFeature.tabularFigures()`. Formatear con separador de
   miles español y máximo un decimal; incluir unidad kg/lb según el ajuste.
2. **Color y contraste.** Recuperar texto, fondo y cuadrícula de
   `AppColors.of(context)`, no usar grises fijos ni depender del color como
   único identificador. Probar el texto normal de tooltips y ejes con contraste
   >=4.5:1; elementos grandes >=3:1, claro/oscuro/OLED y los ocho acentos.
3. **Espaciado.** Rodear las tarjetas con `AppSpacing.md` y contenido mínimo
   para el tooltip; reutilizar `ProgressChartStyle.tooltipPadding` y
   `tooltipMaxContentWidth`. Etiquetas de fechas **fuera** del lienzo de
   `fl_chart`, con margen horizontal para puntos extremos.
4. **Escala y cuadrícula.** Convertir las unidades antes de obtener límites Y.
   Reservar margen vertical para máximo/mínimo y curvas constantes; evitar
   `isCurved: true` en series con picos extremos. Cuadrícula tenue con tokens
   semánticos, sin redundancias ni decimales sin unidad.
5. **Interacción.** `fitInsideHorizontally/Vertically: true` en tooltips.
   Tooltip: fecha completa + valor con unidad, y el **período del bloque** si
   está agregado; conservar suficiente área táctil sin capturar gestos ajenos.
6. **Estados.** Sin datos: mensaje `Sin datos en este periodo`, no gráfico
   inventado. Un dato o valor cero: eje con límites finitos, sin división
   por cero. Rango plano: espacio vertical no nulo. Fechas iguales: agrupar
   sesiones del día antes de calcular posiciones.
7. **Semántica y movimiento.** Proveer `Semantics` con rango, máximo, fecha
   y unidades; etiquetas de tendencia legibles sin depender solo del color.
   Respetar `MediaQuery.textScaler`, `reduceMotion`, áreas seguras y layouts
   320/375/390/430 px con escalas 1.0/1.3/1.6.
8. **Validación.** Los tests automatizados comprueban geometría, textos y
   ausencia de excepciones. Esto **no sustituye** las pruebas manuales
   iPhone/Android (QA-05/06), ni verifica por sí solo el toque exacto de cada
   tooltip sobre una pantalla física.

## Casos sintéticos mínimos

- Tres días no consecutivos (6, 10 y 31 oct); intervalo X real.
- Pico 15.912 kg, curva 37,7/37,7, máximo 39 kg, cero y un único punto.
- Dos sesiones en el mismo día: una sola etiqueta, volumen sumado.
- Intervalo 90D: semana anclada al primer día del rango, sin saltos ficticios.
- Intervalo 365D: fin de año, meses discontinuos y peso corporal cero.
- Puntos con fecha igual, fuera de ventana, futuro e importaciones sin actividad.
- Modo claro, oscuro, OLED, ocho acentos, kg/lb, 320/375/390/430 px,
  escalado 1.0/1.3/1.6. **Las pruebas físicas siguen pendientes**.

## Pruebas CI

`packages/core/test/features/progress/application/progress_volume_bucket_contract_test.dart`;
`apps/app_mobile/test/features/progress/progress_chart_readability_test.dart`;
`apps/app_mobile/test/features/progress/progress_chart_viewport_matrix_test.dart`.

El PR se fusiona únicamente si todos los jobs requeridos de
`STK-Haven_CI` están en verde para el snapshot del último SHA.
No se ejecutan Actions en el repositorio privado.
