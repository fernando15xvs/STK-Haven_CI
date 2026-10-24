# STK Haven Fase 5 v9.25: retopología local conforme de palma y pulgar

**Estado:** candidato de QA, no aprobado ni publicado. Solo iOS/Android.

Continúa la v9.24 sobre la geometría real de la palma y la raíz del pulgar:
subdivide hasta 170 aristas por cada mano, reservando hasta 26 por mano para
la eminencia tenar. La selección usa huesos y pesos reales del rig, no puntos
3D inventados. El algoritmo subdivide los triángulos de las 12 regiones con
0, 1, 2 o 3 aristas afectadas, manteniendo la misma posición de los vértices
anteriores. Interpola normales, cuatro influencias máximas y ocho morphs.

Archivos:
- apps/app_mobile/tool/anatomical_3d/refine_palm_thumb_web_v925.py
- apps/app_mobile/test/features/exercises/palm_thumb_web_v925_visual_test.dart
- Pruebas Python extendidas en test_cc0_interpolated_motion.py

Los tres GLB y el informe palm_thumb_topology_v925_report.json se generan en
build/cc0_master_surface_v7/v8_authoring/detail_bake_v915/torso_v916/
hand_v917/contact_v918/skin_v919/hand_v920/topology_v922/palm_v924/web_v925.

Se rechazan triángulos invertidos, T-junctions en aristas seleccionadas,
pesos no normalizados, archivos sobre 1.400 KiB, más de 20.000 triángulos,
candidatos habilitados o segundo proceso sobre el mismo GLB. Se conservan 55
huesos, 30 tracks de dedos, ocho morph targets y equipamiento. Flutter QA
verifica ocho acentos y temas claro/oscuro.

**No es** todavía una mano profesional anatómica, nuevos UV, uñas, pliegues,
tendones, una animación biomecánica aprobada ni un solver contacto dedo-barra.
El trabajo siguiente es corregir el agarre con objetivos de superficie reales,
limitar ROM/articulaciones y revisar imágenes de la malla en dispositivos
iPhone/Android reales con un especialista.

Reglas: STK-Haven privado = fuente principal, STK-Haven_CI público = único
repositorio con CI. Rama feat/mobile-lottie-batch1-drafts-20261018; PR #43
permanece abierto. Sin cambios en web, producción, Supabase, entrenamiento,
IDs, pubspec, catálogo. 229 drafts; 0 aprobados y 0 habilitados.
