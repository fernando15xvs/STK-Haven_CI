# Progreso 2.0 — Último e1RM vs mejor e1RM histórico (DATA-04)

**Fecha:** 2026-11-03. Los datos históricos en Hive no se modifican.

## Regla

- **Último e1RM:** estimación de la última sesión efectiva del ejercicio en
  el período seleccionado (7D/1M/3M/1A, o 30/90/Todo en vista enfocada).
  No debe etiquetarse como «PR».
- **Mejor e1RM histórico:** máxima estimación válida con trabajo efectivo
  registrado para el mismo `exerciseId`, sin limitar al filtro actual.
  Se consulta a `ProgressAnalyticsCache` una sola vez por tarjeta visible,
  con `from: null`, para no recorrer repetidamente el historial completo.
  El getter calcula el máximo sobre **todas las sesiones del trend**, no sobre
  puntos de gráfica reducidos: downsampling puede omitir el valor extremo.
- **Presentación:** tarjeta cerrada muestra «Último e1RM»; tarjeta abierta
  presenta «Último e1RM» y, cuando el histórico es mayor por más de 0,005,
  «Mejor e1RM histórico», con su fecha accesible en tooltip.
  Si ambos coinciden, no se duplica una cifra idéntica.
- **Comparaciones:** «ÚLTIMA VS ANTERIOR» sigue comparando *dos sesiones*,
  no el último valor con el mejor histórico. No se inventa un cambio en 30 días
  cuando no existe una referencia dentro de la ventana.
- **Ausencia de evidencia:** una serie sin repeticiones efectivas, sin peso
  válido para el e1RM o sin sesiones devuelve 0 y fecha de máximo nula.
- **Sin efecto colateral:** no hay modificación de PR reales, XP, programas,
  Coach, datos históricos, sincronización o algoritmo estimador.

## Pruebas

- `exercise_progress_calculator_test.dart`: último menor que máximo pasado,
  pico en fecha conocida y estado vacío.
- `progress_unified_exercises_test.dart`: a 320 px el desplegable distingue
  ambas cifras, con la vista enfocada «Todo», sin desbordamiento.
- La auditoría global de 320–430 px, claro/oscuro/OLED, ocho acentos y texto
  1.0/1.3/1.6 permanece sujeta a QA y pruebas físicas.

Este incremento no debe fusionarse hasta que el snapshot en el espejo público
pase todos los trabajos de CI requeridos. **Sin PR en STK-Haven_CI.**
