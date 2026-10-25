# STK Haven — Fase 5 v9.40: geometría real de gemelos y sóleo

Para avanzar desde los detalles de las manos al cuerpo completo,
v9.40 esculpe dos cabezas aproximadas del gastrocnemio
(medial y lateral) y el sóleo en AMBAS pantorrillas,
partiendo de los verdaderos huesos calf/foot y pesos del
rig de 55 articulaciones. El modelo sigue siendo CC0 y la
anatomía son perfiles artísticos, NO topología de músculos
aislados, inserciones médicas ni certificación biomecánica.

Los perfiles se aplican directamente a los POSITION y NORMAL
del cuerpo skinned móvil (no un GIF, sprite o relieve en HTML),
con profundidad ≤1,65 mm. Se impide la inversión de
triángulos, se limitan cambios de normales a 9° y no se
modifica ningún canal de movimiento, 8 correctivos morph,
piel, material, UV, placa ungueal, cutícula, equipo ni
estructura de nodos. Cada ejercicio piloto conserva la
misma disposición y 12 primitivas anatómicas.

Artefactos QA: tres
*_v940_lower_leg_anatomy_mobile_qa.glb
y lower_leg_contours_v940_report.json bajo
build/.../left_thumb_angle_v938/cuticles_v939/lower_leg_v940.
Pruebas Python de geometría, invariantes, cuarentena y
Flutter modo claro/oscuro, ocho colores y captura visual
en todos los pilotos.

Pendientes antes de llamar al personaje profesional:
retopología anatómica manual del torso, tendones/inserciones,
músculos faciales, forma de manos y piel, material PBR texturado,
compatibilidad de runtime GPU mixto con rig y equipos, IK
completo de cada ejercicio, pruebas iOS/Android físicas y
229 animaciones reales aprobadas. Este trabajo no los sustituye.

Proyecto en desarrollo; repositorio privado
fernando15xvs/STK-Haven como fuente única, público
fernando15xvs/STK-Haven_CI solo CI en la rama
feat/mobile-lottie-batch1-drafts-20261018 (PR #43).
No cambios en apps/app_web, Supabase, pubspec,
datos de producción, historial o ejercicios activos.
229 borradores, cero aprobados.
