# STK Haven — Fase 5 v9.17: agarre articulado de manos en tres pilotos (solo QA)

**Alcance:** únicamente el personaje anatómico GLB de Flutter iOS/Android; sin cambios en web, Supabase, main, entrenamiento, catálogo ni animaciones de producción. Fuente privada `fernando15xvs/STK-Haven`; espejo público `fernando15xvs/STK-Haven_CI` para Actions. Rama `feat/mobile-lottie-batch1-drafts-20261018`; PR #43 debe permanecer abierto.

## Problema concreto

Los tres ejercicios piloto (press banca, remo y sentadilla) ya mueven la barra y las muñecas sincronizadas mediante IK, y el modelo CC0 dispone de articulaciones de dedos, pero el agarre de la mano permanece **estático** durante toda la repetición. Ello da un aspecto rígido en un cuerpo supuestamente anatómico, especialmente en la transición de subida/bajada.

## Implementación

Se agrega `animate_hand_grip_v917.py` a los scripts de autoría. No crea ni reemplaza personajes ni mallas. A partir de los tres GLB v9.16 `torso_v916` no aprobados, genera **dos variantes por ejercicio**, alta resolución (revisión) y LOD móvil. Añade 30 canales glTF LINEAR de rotación de los dedos existentes: índice, medio, anular, meñique y pulgar, tres falanges por lado (15 por mano). No se inventan controles nuevos ni dedos por encima de la topología actual.

La amplitud en cada articulación se mantiene por debajo de **7 grados** respecto a la rotación original; sus 41 claves entre 0 y 4 s dibujan una presión suave `sin²(pi*t/4)`, de retorno exacto al inicio. La amplitud se calibra por dedo/segmento y es distinta por ejercicio (press banca > remo > sentadilla), para producir una flexión discreta y evitar saltos. Se rechazan cambios mayores a 1,5 grados entre claves consecutivas.

Importante: **no se altera ninguna animación anterior** de hombro, escápula, codo, muñeca, torso, pie, barra o banco. Tampoco se cambian la topología, el skin, las once regiones musculares, las ocho correcciones ni las posiciones de vértices en reposo. El equipo rígido conserva exactamente sus nodos y mallas.

Los archivos de salida están bajo:
`apps/app_mobile/build/cc0_master_surface_v7/v8_authoring/detail_bake_v915/torso_v916/hand_v917/`

Se generan los seis GLB `ex_*_v917_finger_high_qa.glb` y `ex_*_v917_finger_mobile_qa.glb`, más `finger_kinematics_v917_report.json`, con hashes SHA256, excursión angular, cierre del ciclo, tamaño y estados `approved:false, enabled:false`. Presupuesto de LOD móvil de 1,4 MiB y alta resolución 6 MiB.

### Validación

`test_cc0_interpolated_motion.py` verifica:
- 30 nuevos canales sobre los huesos reales de ambos lados.
- 121 cuadros a 30 FPS para cada ejercicio y ambas resoluciones; igual posición de muñecas, pies, barra, cabeza y pelvis; distancia muñeca-centro de agarre preexistente menor a 5 mm.
- Los dedos se mueven en la parte media de la repetición y los extremos del ciclo cierran.
- No se tocan mallas, posiciones base, material, skin, correctivos o canales de animación antiguos; el modelo nuevo no se considera aprobado.

`hand_grip_v917_visual_test.dart` renderiza el cambio en Flutter, comprueba equipos rígidos, ocho colores y temas claro/oscuro y produce seis PNG de QA dentro del artefacto visual ya existente. La prueba no mide rendimiento físico, solo consistencia de Flutter test runner.

## Pendiente real antes de publicar

Una curva de falanges suavemente flexionadas **no certifica contacto real dedos-barra**, fricción, profundidad de penetración del equipo ni técnica de agarre. La anatomía de manos/antebrazos de la malla CC0 sigue siendo provisional. Faltan esculpido humano de mano/uñas/tendones y ajuste de proporciones antebrazo–codo–hombro con retopología, nuevos materiales/texturas y medición en dispositivos Android/iPhone. La siguiente fase debe incluir controles de intersección de falanges/cilindro y revisión visual a escala de usuario.

**Estado:** 229 ejercicios provisionales, 0/229 animaciones aprobadas, 0/229 habilitadas. La interfaz web permanece fuera de alcance.
