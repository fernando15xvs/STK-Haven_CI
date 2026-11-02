# STK Haven — Fase 5 v9.22: refinamiento topológico local de yemas

**Estado:** candidato 3D de laboratorio, fuente privada `fernando15xvs/STK-Haven`, espejo público `fernando15xvs/STK-Haven_CI`; PR #43 abierto, rama `feat/mobile-lottie-batch1-drafts-20261018`. Solo Flutter iOS/Android. **No aprobado y no habilitado.**

## Qué cambia respecto a v9.21

La auditoría v9.21 detectaba posibles intersecciones de triángulos reales pero no modificaba mallas. La v9.22 **sí modifica los índices y crea nuevos vértices en las regiones de yemas**, sin superponer un segundo modelo ni falsear el contacto. Se genera mediante `apps/app_mobile/tool/anatomical_3d/refine_fingertip_topology_v922.py`.

- Parte de los tres GLB v9.20 móviles (press banca, remo con barra y sentadilla). Selecciona las caras de la malla real adyacentes a los diez grupos de influencia distal.
- Divide aristas compartidas mediante un único vértice medio; triangula conformemente también las caras adyacentes en otras primitivas, evitando grietas/T-junctions entre regiones. Mantiene los 12 materiales anatómicos y las primitivas originales.
- La nueva geometría preserva los 4.727 vértices originales; añade vértices intermedios para elevar densidad **solo** donde la superficie del dedo lo requiere. Un curvado de máximo **0,45 mm** puede redondear bordes y se aplana si cambia la orientación de las caras.
- Calcula normals y pesos de hasta cuatro articulaciones para cada vértice nuevo, normaliza pesos y conserva los 55 huesos originales, matrices de bind, animación glTF, ocho morphs (interpolados en los vértices añadidos) y objetos de equipamiento.
- Actualiza los accessor/bufferViews existentes mediante reemplazos binarios alineados, sin duplicar toda la skin. Se conserva el formato glTF 2.0 y se aplica límite de 1.400 KiB por GLB móvil de revisión.
- El CI comprueba por pruebas Python las cuatro variantes de cara (0–3 aristas divididas), preservación de índices/primeros vértices/skin/animación/morphs, número de triángulos realmente aumentado, selección acotada, presupuesto, rechazando fuentes aprobadas o retopología aplicada dos veces.
- Flutter carga los GLB refinados en modo offline QA, comprueba equipo, ambos temas y ocho colores, y genera seis capturas de press banca, remo y sentadilla en `build/cc0_master_v7_flutter_qa`.

Las salidas se guardan **solo** bajo `build/cc0_master_surface_v7/v8_authoring/detail_bake_v915/torso_v916/hand_v917/contact_v918/skin_v919/hand_v920/topology_v922/`: tres `*_v922_fingertip_mesh_mobile_qa.glb` y `fingertip_topology_v922_report.json`. No se agregan assets a `pubspec.yaml`, no se toca el catálogo.

## Limitaciones importantes

Se trata de **subdivisión selectiva del mesh real**, no una nueva mano humana escultórica o anatómicamente correcta. La retopología **completa** de palma, articulaciones, uñas, proporciones de los dedos y UV necesita autoría y revisión artística profesional. La deformación de dedos respecto a la barra todavía usa los clips previos de agarre; **no se ha integrado IK de contacto de yemas ni detección continua de colisión**. Que los glTFs cumplan tests o CI verde no demuestra corrección anatómica ni técnica de ejercicios.

Los 229 ejercicios continúan **229 borradores / 0 aprobados / 0 habilitados**. Sin modificaciones de `apps/app_web`, `main`, historia de entrenamiento, Supabase, usuarios, notificaciones ni despliegues. No GIF. GitHub Actions exclusivamente en el repositorio público.

## Puertas de la próxima fase

1. Medir en el reporte y capturas el aumento real de polígonos, la suavidad superficial y el coste de renderizado; revisar los dedos frente a la barra y al banco en poses intermedias.
2. Crear malla anatómica original de mano con palma, pulgar oponente, uñas, pliegues y proporciones correctas, transferir skinning/morphs, UV y LOD con procedencia de arte.
3. Resolver la cinemática de 30 articulaciones de dedos a un objetivo de contacto de superficie real, sin perforar el cilindro, con restricciones de rango articular, y revisar con profesional.
4. Pruebas en hardware físico Android/iPhone: calidad, FPS, memoria, thermal y batería. Aprobar inicialmente los tres pilotos y **solo después** ampliar los 226 ejercicios restantes.
