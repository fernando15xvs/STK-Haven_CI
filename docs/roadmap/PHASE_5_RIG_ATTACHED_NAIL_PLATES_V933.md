# STK Haven v9.33 — diez uñas 3D reales con UV y rig

Se añaden diez placas ungueales tridimensionales cerradas a cada GLB
experimental v9.32. Cada placa contiene 70 vértices y 136 triángulos
(1360 adicionales por personaje), normales, coordenadas TEXCOORD_0 UV
y un material PBR prototipo con queratina aproximada. Los nodos
STK_NAIL_PLATE_[dedo]_[lado] son hijos del hueso distal real _03,
por lo que heredan la animación completa del ejercicio.

La geometría se coloca desde los puntos originales skinned de la
falange, no mediante imágenes estáticas. Se preservan el rig original,
las 12 regiones corporales, el clip, los ocho correctivos, materiales
anteriores y banco/barra. Cambia exclusivamente el GLB derivado QA.

El visor experimental Flutter recibe una excepción estrictamente
aislada para estos diez nuevos nodos cuando el GLB no está aprobado
y lleva nailPlatePrototypeVersion=933. Los otros GLB antiguos mantienen
sus validaciones exactas. Hay pruebas Python de UV, mallas,
jerarquías, versión, animación, dimensiones y rechazo de fuentes
aprobadas, y Flutter renderiza luz/oscuridad con ocho acentos.

**Sin aprobación profesional**: la orientación dorsal estimada no se
ha cotejado con referencia artística, faltan cutículas realistas,
retopología y mapas UV acabados, materiales adecuados, IK completo,
colisión continua y medición física iOS/Android. Las uñas rígidas
pueden cortar piel durante la flexión; prohibido activar producción.
El informe nail_plates_v933_report.json guarda evidencia.

Salida solo a build/.../fold_v931/nail_bed_v932/nail_plates_v933.
Repositorio fuente fernando15xvs/STK-Haven privado, CI en
fernando15xvs/STK-Haven_CI público; rama
feat/mobile-lottie-batch1-drafts-20261018, PR #43 abierto.
Sin cambios app_web, Supabase, historial ni assets de producción.
229 animaciones borrador, cero aprobadas/habilitadas.
