# QA sintético — Gráficos de Progreso (2026-11-02)

Esta ficha documenta AUD-04 y los casos originales observados en seis capturas
aportadas en la conversación. **No subir imágenes reales ni datos privados.**
El objetivo es reproducir sin datos personales y evitar regresiones visibles.

## Síntomas y expectativa

| Caso | Datos de prueba | Resultado exigido |
| --- | --- | --- |
| Tooltip oscuro | 2026-10-10: 15912 kg de volumen | «10 oct 2026» y «15.912 kg» con texto/fondo >=4.5:1, no gris sobre gris |
| Pico extremo | 6 oct 3000, 10 oct 15912, 31 oct 2500 kg | Pico visible, sin overshoot, tooltip dentro de tarjeta |
| Eje temporal | 6, 10 y 31 oct | Diferencias X de 4 y 21 días, no intervalos idénticos |
| Fecha extrema recortada | 6 oct / 31 oct | Ambas fechas completas fuera del área del gráfico, en 320 px |
| e1RM último vs máximo | 24, 37.7, 39, 37.7 kg | Máximo y último no se confunden ni quedan cortados |
| lb vs kg | 25, 37.7, 39 kg; convertir a lb | Límites y puntos calculados en la **misma unidad** |
| Curva constante | 37.7, 37.7 kg | minY < 37.7 < maxY; sin división por cero |
| Un punto / volumen cero | 2026-10-31: 0 kg | Estado definido y sin excepción de gráfico |
| Contraste | 8 acentos, claro/oscuro, opción OLED | Tooltip y etiquetas legibles según tokens del tema |
| Texto ampliado | textScale 1.0, 1.3 y 1.6; anchos 320/375/390/430 | Sin recorte en fechas, unidades, valores seleccionados |
| Historias / parciales | fin parcial, 252m de media | Auditar fórmula; no corregir datos sin evidencia |

## Alcance de la primera entrega

- Reutilizar `ProgressChartStyle` (Outfit, AppColors, contrastes y formato común).
- Reservar margen al primer y último punto, con fechas fuera del canvas de fl_chart.
- Validar geometría con fechas reales, vacío/flat/pico, kg/lb y temas.
- **Fuera de alcance**: rediseño de Inicio, duplicaciones, agrupación semanal/mensual
  por período, 30 días de e1RM y cambios de datos persistidos. Siguen pendientes.

## Comandos de prueba en el espejo CI

Desde la raíz del workspace:

```bash
flutter pub get --enforce-lockfile
flutter analyze --no-fatal-infos
cd apps/app_mobile
flutter test test/features/progress/progress_chart_readability_test.dart
```

Pruebas físicas de iPhone/Android: pendientes hasta ejecución manual con dispositivo.
