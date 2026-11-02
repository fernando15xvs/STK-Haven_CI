# STK Haven — Fase 5, v9.30: esculpido ligero de nudillos sobre piel real

Estado: candidato 3D **solo QA**, no aprobado, no integrado en el catálogo.

Sobre los tres GLB v9.29 de press de banca, remo y sentadilla, la herramienta sculpt_finger_knuckles_v930.py cambia directamente las posiciones y normales glTF de la malla skinned real. Usa los tres huesos existentes de cada dedo y los pesos de skin para situar volumen localizado sobre las articulaciones interfalángicas. Evita capas o imágenes superpuestas: son vértices de la propia superficie anatómica.

Los desplazamientos son inferiores a 0,68 mm y se limitan mediante escalas descendentes hasta conservar la orientación original de todos los triángulos. Los huecos y penetraciones en la barra se comprueban en nueve instantes utilizando vértices skinned y morph targets, con guardas de regresión de 1,5 mm. Se conservan topología de doce regiones, equipo de gimnasio, rig de 55 articulaciones, 30 canales de dedos, ocho morph targets, animaciones, pesos de skin y materiales. Las normales próximas a vértices modificados se recalculan.

Hay pruebas de creación real de GLB, continuidad de rig y morphs, restricciones geométricas, rechazo de GLB aprobados o doble operación y revisión Flutter en temas claro/oscuro y ocho acentos. Se generan seis capturas Flutter y un informe knuckle_surface_v930_report.json.

Esta iteración NO añade uñas, pliegues complejos de piel, UV profesionales, retopología integral ni un artista 3D. Tampoco certifica movimiento de agarre físicamente correcto, colisión continua entre fotogramas, autocolisión ni una solución completa de IK. No se debe afirmar apariencia profesional acabada.

Los archivos se construyen únicamente en build/.../web_v925/two_joint_v929/knuckle_v930; se mantienen no aprobados y deshabilitados. El repositorio privado fernando15xvs/STK-Haven es fuente única, con espejo CI exclusivo fernando15xvs/STK-Haven_CI, rama feat/mobile-lottie-batch1-drafts-20261018 y PR #43 sin fusionar. No modificar web, Supabase, historial, catálogo, pubspec ni producción. 229 ejercicios en borrador, cero habilitados.
