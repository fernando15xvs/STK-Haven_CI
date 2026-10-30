# STK Haven — Progreso > Músculos: interfaz compacta y filtro único

Fecha: 2026-10-30. Rama: feat/mobile-lottie-batch1-drafts-20261018. Solo Flutter móvil.

## Producto

- Resumen conserva el único selector 7D/1M/3M/1A. Músculos observa el mismo `timeFilterProvider` sin pintar otro selector; muestra la etiqueta actual y explica dónde cambiarla.
- Encabezado y KPIs compactos (series directas, grupos trabajados y sin trabajo), colores semánticos de `AppColors` que abarcan 8 acentos, claro y oscuro.
- Distribución por grupos activos ordenados por series directas, tarjetas expandibles compactas y contribuciones de ejercicios con filas densas; grupos con cero actividad ocultos tras expansión explícita.
- El trabajo indirecto estimado permanece opcional y se mantiene aparte de los conteos directos. Ninguna estadística cambia de fórmula.
- Comparación de semanas completas continúa independiente del período seleccionado, con una explicación visible; auditoría histórica sigue disponible.
- Revisión visual en 320/390 px, texto grande y dispositivos físicos pendiente de aceptación.

Sin cambios en web, Supabase, modelos persistidos, datos históricos, catálogo, ID, `main` ni workflows privados. Validación CI solo desde espejo público.
