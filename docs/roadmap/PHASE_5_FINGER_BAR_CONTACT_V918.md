# STK Haven — Fase v9.18: corrección conservadora de orientación de manos y diagnóstico real de separación

**Solo desarrollo y QA de Flutter Android/iOS** en `feat/mobile-lottie-batch1-drafts-20261018`. El repositorio privado `fernando15xvs/STK-Haven` es la fuente. Se copian los cambios a `fernando15xvs/STK-Haven_CI` para un único flujo de GitHub Actions por lote. No modificar `main`, UI web, Supabase, catálogo de 229 ejercicios ni historial.

## Hallazgo que motiva el trabajo

Los modelos v9.17 tienen 55 articulaciones, muñecas que siguen a la barra con error de IK pequeño, y treinta canales animados para falanges. Sin embargo, medir las articulaciones distales de cada dedo contra el cilindro de la barra mostró **grandes separaciones**, hasta muchos centímetros según mano, ejercicio y fotograma. El contacto de muñeca no equivale al contacto de palma o dedos. El término “agarre resuelto” sería incorrecto.

## Implementación

Se añade `calibrate_grip_contact_v918.py`, que trabaja exclusivamente sobre las seis copias GLB no aprobadas del paquete `hand_v917`: tres ejercicios piloto, cada uno con versión high-poly y LOD móvil. Los datos originales de todos los ejercicios permanecen intactos.

El generador añade **dos canales de animación LINEAR de muñeca**, uno por mano, sobre las rotaciones originales. Sus curvas cambian suavemente entre una calibración neutra y una de máxima carga. Las direcciones de corrección dependen del ejercicio y del lado del cuerpo, fueron medidas contra los GLB reales y están limitadas a **18° como máximo** y **2° por clave**. No mueve las articulaciones de muñeca: únicamente reorienta el conjunto de la mano. Tampoco modifica huesos, skin weights, mallas, morph targets, las treinta animaciones previas de falanges, los canales de IK, el banco, la barra o los pies.

**Diferencia crucial:** el nuevo test mide en **121 fotogramas a 30 FPS** la distancia radial de cada una de las *articulaciones distales* de los cinco dedos de ambas manos a la envolvente del eje de la barra de 19 mm. Son **1210 muestras por ejercicio y variante**. Calcula brechas promedio, máxima, mínima con signo y por dedo, compara antes/después y prohíbe:
- una mejora media inferior al 6 %;
- aumento significativo de separación de un dedo;
- penetración del *centro de articulación distal* en más de 3 mm dentro del cilindro de referencia;
- desviación mayor a 1 micrómetro de los centros de muñeca en los 121 fotogramas.

Estos controles no son un detector de penetración de la **malla de la piel**. La articulación distal tampoco es el extremo real de la yema. La medida usa un cilindro ideal y no tiene en cuenta el collar de agarre de radio 22 mm, los nudillos, fricción o ergonomía. Por ello **no se considera que todos los dedos estén tocando realmente la barra**, aunque la métrica mejore y CI termine verde. Las diferencias visibles y las distancias sobrantes quedan documentadas en el reporte de QA para una futura revisión de rig/mano/proporciones.

Se producen:
`apps/app_mobile/build/cc0_master_surface_v7/v8_authoring/detail_bake_v915/torso_v916/hand_v917/contact_v918/`

con seis `ex_*_v918_contact_{mobile|high}_qa.glb` y `contact_gap_v918_report.json` con métricas individualizadas y SHA-256. Los dos GLB de prensa/remo y sentadilla existentes **no se sobreescriben**. `test_cc0_interpolated_motion.py` verifica los seis GLB y sus indicadores de seguridad. `grip_contact_v918_visual_test.dart` valida reproducción, cierres de ciclo y ambos temas/ocho colores con seis capturas Flutter.

## Pendiente antes de una aprobación

El CC0 tiene manos de baja resolución, falanges que no están posicionadas por un IK verdadero de yemas y orientación inicial de mano todavía poco humana. La solución final requiere reorientar y retopologizar la mano, modelar las yemas con proporciones correctas, resolver agarre de palma y dedos sobre el cilindro con colisiones de superficie, corregir movimiento escapulohumeral y revisar postura de los tres ejercicios con un entrenador. También falta medir calidad/temperatura/FPS en Android e iPhone físicos y preparar el master artístico final.

**No publicar:** `approved:false`, `enabled:false`; 229 borradores, 0 aprobados, 0 habilitados. PR #43 abierto; Actions exclusivamente en el repo CI público.
