# STK Haven — Fase 5 v9.31: pliegues articulares sobre piel real

**Experimento QA, NO aprobado ni integrado en producción.**

Después de v9.30, se añade un relieve anatómico muy limitado a las
transiciones interfalángicas de los diez dedos de los tres pilotos
(ex_bench_press, ex_barbell_row y ex_squat).

La herramienta sculpt_finger_folds_v931.py usa la posición original
de los huesos falángicos 01/02/03, sus pesos de skin, los vértices de
la única malla atlas GLB y un pequeño perfil de depresión y reborde,
de amplitud máxima **0,38 mm**. No añade overlays ni objetos falsos.

La posición y las normales reales pueden cambiar, pero se conservan
esqueleto 55-bone, poses, rotaciones de 30 tracks, ocho morph targets,
weights, bind matrices, 12 regiones, equipamiento y winding de caras.
La topología compartida no se incrementa; el efecto solo aparece
donde ya existen vértices que admitan ese relieve.

La candidata se compara contra v9.30 durante **241 fotogramas a 60 Hz**
con skinning y morph targets reales frente a la barra animada.
Si aparecen regresiones de signed distance o gap mayores a
0,65 mm, nuevas penetraciones profundas observadas, o no puede
preservarse la orientación de triángulos, el GLB emitido mantiene la
geometría v9.30 y reporta el motivo y los vértices editados **igual a 0**.
Una revisión que no encuentre regresiones en 241 muestras **no prueba**
la seguridad entre esas muestras ni certifica el contacto de triángulos
interiores.

Se añaden pruebas Python de origen/aprobación, integridad de materiales,
animación, morphs y rig, y seis capturas reales Flutter para
claro/oscuro, ocho acentos de prueba y tres ejercicios. Los resultados
solo se generan en build/.../two_joint_v929/knuckle_v930/fold_v931;
no entran en los assets de la app ni en el catálogo.

Quedan pendientes: anatomía detallada validada por artista, uñas,
UV/LOD profesionales, IK de contacto completa, autocolisión,
medición de GPU/CPU en dispositivos Android/iPhone y aprobación humana.
229 animaciones continúan en borrador; cero aprobadas y habilitadas.

Repositorio privado fernando15xvs/STK-Haven = fuente principal,
repo público fernando15xvs/STK-Haven_CI = CI exclusivo, rama
feat/mobile-lottie-batch1-drafts-20261018, PR #43 sin merge.
Sin cambios en web, Supabase, historial, catálogo ni pubspec.
