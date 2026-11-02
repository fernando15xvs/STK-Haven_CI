# STK Haven — Estándar visual de demostraciones (móvil)

## No confundir borrador con estilo final

Los 229 Lottie son dibujos técnicos iniciales de trazos gruesos, no demostraciones de nivel GIF/vídeo. **El reproductor Lottie no añade calidad visual**: cualquier mejora exige revisar vectores, rig y secuencias. No incorporar la carpeta completa a Flutter únicamente porque el CI sea verde.

## Objetivo visual mínimo (iOS y Android)

- **Figura legible:** cabeza y cuello anatómicos simplificados, torso de volumen, cadera reconocible, segmentos de brazos y piernas con articulaciones coherentes; distinguir cada mano, pie, equipamiento y agarre.
- **Perspectiva consistente:** frontal/lateral/oblicua según se entienda el ejercicio; no mezclar posiciones incompatibles en la misma vista.
- **Movimiento creíble:** articulaciones como pivotes; fases de preparación, concéntrica, control excéntrico y retorno; preservar puntos de apoyo; no animar un agarre fijo ni simular repeticiones en ejercicios isométricos.
- **Equipo:** bancos, mancuernas, placas, barras, cable y poleas, rieles de máquinas suficientemente identificables; distribución de carga y unilateralidad correctas.
- **Técnica y notas:** cues particulares de ejecución, errores habituales y músculos objetivo, revisados por un entrenador competente antes de aprobar.
- **Rendimiento:** recursos vectoriales compactos (ideal Lottie), reproducción fluida offline y respeto por accesibilidad/reducción de movimiento en iOS y Android.
- **Calidad comparable a una demostración corta:** la persona debe entender el movimiento sin descifrar una figura de palitos. Si no es posible, rehacer el dibujo o escoger otra tecnología ligera compatible con móvil. Evitar GIFs pesados.

## Flujo iterativo real

1. Crear y revisar una **guía de estilo anatómica** con 3 ejercicios piloto muy distintos: press de banca, remo y sentadilla.
2. Rediseñar siluetas y rigs, conservando los 229 IDs, las notas técnicas y compatibilidad con Flutter; aprobar muestras visualmente antes de escalar lotes.
3. Extender a los 229 por familias de movimiento, preferiblemente reutilizando esqueletos vectoriales **sin repetir poses erróneas**.
4. Generar storyboards y revisar animación real en ambos sistemas; corregir e indicar por ejercicio `approved` solamente tras QA visual, biomecánico, rendimiento y accesibilidad.

## Estado 2026-10-20

Los 229 archivos de trabajo existen; 15 han recibido redibujo esquemático de QA, 16 se han inspeccionado en forma provisional, 0 están listos como arte final. La revisión física en iPhone y Android sigue pendiente. El producto continúa privado en fase de desarrollo.
