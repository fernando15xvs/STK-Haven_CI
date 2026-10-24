# STK Haven — Fase 5, v9.29: búsqueda de agarre con dos articulaciones

Estado: candidato de investigación / QA, no aprobado y no habilitado.

Este bloque introduce un primer ajuste multiarticulación del dedo. Sobre los
tres GLB v9.25 originales se buscan pares de falanges de cada dedo entre
segmentos 1, 2 y 3. Se ensayan cambios locales de +1,5 y -1,5 grados en
ambas articulaciones. Hay 12 combinaciones por dedo y el sistema considera
diez dedos de las dos manos, sin cambiar muñecas ni huesos del cuerpo.

El objetivo utiliza los vértices auténticos de piel transformados por el
rig con 55 huesos y ocho morphs, y distancia firmada respecto al cilindro
finito real de la barra animada. Primero evalúa a los tiempos 1, 2 y 3 s,
respetando el límite existente de 12 grados aproximados desde el reposo.
Luego interpola y comprueba **241 muestras a 60 Hz durante los cuatro
segundos**. El filtro prohíbe cualquier nueva regresión observada
mayor de 0,5 mm, incremento de penetraciones profundas y falta de una
mejora media de acercamiento suficiente.

Si fallan las pruebas combinadas, todos los cambios candidatos se
descartan y el archivo final mantiene las rotaciones originales v9.25.
Si no existe ninguna corrección aceptable, el archivo tampoco modifica
las pistas de animación. Se registra en el informe de QA el número de
correcciones propuestas y retenidas; cero cambios no debe presentarse como
un éxito visual o de cinemática inversa.

Archivos:
- apps/app_mobile/tool/anatomical_3d/optimize_two_joint_grip_v929.py
- apps/app_mobile/test/features/exercises/two_joint_grip_v929_visual_test.dart
- Nuevas pruebas en test_cc0_interpolated_motion.py
- Salidas privadas de build: web_v925/two_joint_v929, tres GLB de QA
  y two_joint_grip_v929_report.json.

Es una **búsqueda discreta experimental de dos articulaciones**,
NO una cinemática inversa completa con objetivos físicos de mano,
ángulos anatómicos validados ni cálculo continuo de colisiones de
triángulos. Faltan arte profesional real (huesos, pliegues y uñas),
UV/LOD, revisión por biomecánica y pruebas físicas iPhone/Android.

Repositorio privado fernando15xvs/STK-Haven = fuente principal.
Repositorio público fernando15xvs/STK-Haven_CI = CI exclusivo.
Rama feat/mobile-lottie-batch1-drafts-20261018, PR #43 abierto.
Sin cambios web, Supabase, historial, catálogo, pubspec, activos productivos
ni workflows privados. 229 drafts, cero aprobados y habilitados.
