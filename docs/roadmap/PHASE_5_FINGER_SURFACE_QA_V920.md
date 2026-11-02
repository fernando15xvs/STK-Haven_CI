# STK Haven — Fase 5 v9.20: relieve acotado de las yemas (solo QA)

**Estado:** candidato de laboratorio **sin aprobación**, no es retopología anatómica definitiva ni sistema de contacto resuelto. Exclusivo de Flutter Android/iOS. Rama `feat/mobile-lottie-batch1-drafts-20261018`; código fuente privado `fernando15xvs/STK-Haven`, espejo público `fernando15xvs/STK-Haven_CI` y Actions **solo** en el público.

## Qué se implementó

Se añade `apps/app_mobile/tool/anatomical_3d/sculpt_finger_pads_v920.py`, que consume **solo** los 3 modelos móviles GLB v9.18 con contacto de muñeca calibrado, marcados `approved:false` y `enabled:false`. No se altera el maestro, los 229 ejercicios ni los otros 226 movimientos.

1. Utiliza las mallas, articulaciones y pesos reales de las falanges distales (`*_03_l/r`) de cada dedo. No inventa posiciones de las yemas ni las arrastra artificialmente hasta tocar la barra.
2. Aplica sobre una **copia** del GLB un alivio radial suavizado con límite geométrico de **0,75 mm**, cerca de las articulaciones distales. La modificación se escala automáticamente si alguna cara cambia de orientación; un candidato sin deformación suficientemente comprobable se rechaza.
3. Actualiza normales **solo de vértices afectados**. Conserva el número y orden de los 4.727 vértices originales y 9.843 triángulos, las doce primitivas, 55 articulaciones, skin weights, jerarquía, matrices de bind, ocho morph targets, canales de animación y equipo.
4. Reejecuta `review_fingertip_mesh_v919.measure` sobre la piel realmente deformada a **121 instantes de 30 FPS** por cada ejercicio, comparando la distancia respecto al eje de barra con la versión v9.18. Rechaza regresiones de holgura positiva media superiores a 2 mm por dedo.
5. Genera únicamente archivos **QA fuera del catálogo** en `build/cc0_master_surface_v7/v8_authoring/detail_bake_v915/torso_v916/hand_v917/contact_v918/skin_v919/hand_v920/`: tres `ex_*_v920_hand_surface_mobile_qa.glb` y `hand_surface_v920_report.json` (SHA-256, cambios, métricas por dedo, estado no aprobado). La carpeta queda bajo el árbol de artefactos de revisión del CI público.
6. Las pruebas Python en `test_cc0_interpolated_motion.py` comprueban el presupuesto de desplazamiento, ausencia de inversión de caras, cambios reales, igualdad estricta de skin, 8 morphs, malla y animaciones, procedencia y rechazo de modelos aprobados o modificaciones repetidas.

## Qué NO hace

**No modifica la topología de la mano ni modela uñas, tendones, palma, presión o geometría artística profesional.** Los pesos distales identifican una región aproximada, no la superficie anatómica exacta de la yema. Una muestra discreta de vértices cerca de un cilindro no demuestra colisión continua de triángulos, ausencia de penetración, contacto de piel ni agarre ergonómico. Un relieve radial tan pequeño no puede arreglar dedos mal orientados; las deformaciones de manos que se ven en el render y el rig de muñeca siguen requiriendo trabajo.

## Próximas puertas

- Inspeccionar `hand_surface_v920_report.json` y vistas de mano en banca, remo y sentadilla; si la malla original presenta dedos desproporcionados, **crear de verdad una nueva topología de mano** con autoría artística y correspondencias UV/skin, no acumular relieves pequeños.
- Resolver los contactos de yemas y palma con la barra, su penetración triángulo-cilindro y el recorrido del equipo durante los 121 cuadros sin afectar el IK de muñeca/pies ni los 8 correctivos.
- Integrar el material aprobado en un visor nativo GLES3/Metal eficiente y validar imágenes/fotogramas físicos en iPhone y Android.
- Revisar técnica con especialista antes de aceptar tres pilotos. Solo posteriormente producir las otras 226 variantes.

**Reglas invariantes:** los 229 Lottie continúan como borradores (0 aprobados / 0 habilitados); nunca se empaqueta el candidato; no hay cambios en `apps/app_web`, `pubspec.yaml`, Supabase, historial ni `main`. El PR público #43 permanece abierto. Una CI verde valida el contrato técnico, **no** aprueba la anatomía ni la publicación.
