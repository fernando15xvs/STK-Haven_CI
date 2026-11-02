# STK Haven v9.39 — cutículas tridimensionales experimentales

Los tres pilotos anatómicos poseen ahora 10 pliegues proximales de
piel sobre las uñas, en geometría glTF REAL: malla sellada de
40 vértices y 76 triángulos por dedo, materiales PBR diferenciados
de queratina y piel, normales y TEXCOORD_0 UV. Cada pliegue toma
su perfil del borde proximal REAL de la uña LOD v9.36 y se coloca
como hijo de la placa ungueal del rig, heredando los movimientos
de los 55 huesos y los ajustes de pulgares v9.37/v9.38.

Se preservan íntegramente el modelo corporal y sus 8 morph
targets, clips, UV de uñas, equipos, geometría y materiales
anteriores. El visor Flutter solo reconoce este prototipo
cuando la versión interna es cuticleFoldGeometryVersion=939,
manteniendo comprobación estricta de 10 uñas, 10 cutículas y
materiales/nodos de padre. No se habilitan activos productivos
ni cambian los 229 registros en borrador.

La geometría añadida es **un experimento**, no una cutícula
biológicamente fiel: al heredar el hueso de la uña se puede
separar de la piel animada, y no hay rig/skin independiente
del eponiquio, texturas finales ni modelado manual de tejidos.
La proximidad está comprobada frente a los vértices de uñas
en reposo, NO contra todos los triángulos de piel bajo movimiento.
Faltan contacto IK, validación de colisión continua, benchmark
físico de teléfonos y revisión de artista anatómico.

Salida solamente QA en
build/.../thumb_fit_v937/left_thumb_angle_v938/cuticles_v939
con 3 GLB derivados y un informe cuticle_folds_v939_report.json.
Pruebas Python y Flutter en ambos temas y 8 acentos.

Repositorios: privado fernando15xvs/STK-Haven fuente;
público fernando15xvs/STK-Haven_CI únicamente CI.
Rama feat/mobile-lottie-batch1-drafts-20261018,
PR #43 permanece sin fusionar. No tocar app_web,
Supabase, pubspec, historial ni media de producción.
