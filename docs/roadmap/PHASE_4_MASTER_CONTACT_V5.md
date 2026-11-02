# STK Haven — contact-constrained master v5 (experimental QA)

Derived from the same public-domain 55-joint humanoid CC0 v4; seven motion families preserved, as well as all eight glTF corrective morph drivers and 11 named muscle regions. The joint channels now solve two-link arm/leg inverse kinematics against explicit hand or foot targets across 41 keyframes per 4-second cycle.

- Bilateral overhead and left/right unilateral reaches target wrists above head.
- Bilateral curl has explicit wrist destinations in front of chest.
- Squat and hip hinge translate pelvis and plant both foot-joint supports.
- Lunge moves feet into a split stance during transition, then keeps them planted at peak. No gait mechanics are simulated.
- Flat foot orientation is preserved using orientation compensation.
- A separate animated GLB bar proxy follows the midpoint of both wrists in the overhead clip. It is NOT actual finger-to-bar collision or exercise equipment delivered to the app.

The automated test samples 121 frames per clip at 30Hz from real exported glTF rotation and translation samplers and permits at most 18 mm foot/hand deviation between keyframes. Reported exact keyframe IK contact does NOT prove biomechanical correctness. A coach must assess joint angles, equipment contact, shoulder biomechanics, and foot support.

There is no native GPU or physical-device FPS/battery validation. Only public mirror GitHub Actions runs CI; source copied to both branches. This phase never modifies apps/app_web, Supabase, workout history, pubspec.yaml or the production exercise assets. PR 43 unmerged. 229 drafts / 0 approved / 0 enabled.

## v5.1 — controles de cintura escapular activos (21 oct 2026)

- Los pivotes `stk_scapula_control_l/r` del maestro CC0 de 55 huesos participan en los patrones de alcance bilateral y unilateral mediante rotaciones Z firmadas de hasta ±6°, inferiores al límite del rig de ±20°.
- Cada pivote se mueve **antes** de resolver el IK del brazo para conservar el destino de muñeca. El lado contrario de un alcance unilateral sigue en reposo; los otros cuatro patrones tampoco animan estos controles.
- Una prueba automatizada inspecciona los canales glTF exportados, cierre del bucle, amplitud, independencia bilateral y estado de no aprobación. La auditoría previa de 121 fotogramas continúa verificando contacto de manos y pies.
- **Límite:** estos controles pivotan la clavícula, no son escápulas con geometría propia; la secuencia no certifica el ritmo escapulohumeral, la anatomía o la técnica. Solo material de revisión interna; 229 borradores, 0 aprobados, 0 habilitados.

## v5.2 — correctivos musculares ligados a IK (21 oct 2026)

- Los ocho *shape keys* (cintura escapular, codo, cadera y rodilla, ambos lados) se calculan ahora desde las rotaciones reales de los huesos resueltos por IK, relativas a la postura inicial del propio clip. Se eliminan conductores heredados de los movimientos v3 que ya no coincidían con la pose.
- El cálculo usa diferencia angular entre cuaterniones y amplitudes artísticas conservadoras. No estima hipertrofia, tensiones articulares ni biomecánica clínica.
- Se reutilizan in situ los búferes glTF SCALAR existentes (41×8 por clip), sin duplicar datos ni aumentar por ellos el tamaño de descarga. Los 55 huesos, siete clips y ocho correctivos conservan sus IDs.
- Se añaden pruebas Python de sincronización por fotograma, independencia unilateral, límites y bucles, más una prueba Flutter para comparar los siete GLB renderizados con y sin correctivos.
- No aprobado ni habilitado en producción. 229 borradores, 0 aprobados; sin web, Supabase ni cambios al historial.
