# STK Haven — Fase 5 v9.13: anatomía master 55 / 11 regiones

**Ámbito:** solo scripts y tests de animación 3D de Flutter iOS/Android. No modifica app web, historial de entrenamientos, Supabase, IDs, `main` ni `pubspec.yaml`. La fuente canónica es `fernando15xvs/STK-Haven`, el público `fernando15xvs/STK-Haven_CI` es un espejo exclusivamente de CI.

## Avance real

`apps/app_mobile/tool/anatomical_3d/build_master_anatomy_v8.py` toma el GLB de master CC0 v7 original (55 huesos, 7 clips, 8 morphs, 12 submallas anatómicas) y **crea una versión alternativa** con una capa adicional de volumen muscular **anatómicamente orientada pero todavía procedural**. En lugar de las seis regiones volumétricas del paso v7, añade relieve **en las once regiones existentes**, individualizando el perfil de:

- pectoral mayor, deltoides anterior y posterior y tríceps;
- dorsal ancho, romboides y trapecio medio;
- cuádriceps, glúteo mayor, isquiosurales y aductor mayor.

Los músculos de los dos lados se modelan con perfiles anisotrópicos separados y suavizados sobre la propia conectividad superficial. Los perfiles de pectoral, dorsal, cuádriceps y glúteo contienen modulación de volumen adicional que evita introducir surcos abruptos. El relieve está restringido a **4 mm de desplazamiento adicional por vértice** como máximo teórico y, además, al **14 % de la longitud de la arista vecina más corta**; respeta la línea media, recalcúla normales y rechaza triángulos invertidos.

**Verificación local realizada sobre GLB reales de CI #513:** 4.727 vértices base, 9.843 triángulos, 1.585 vértices con cambio superior a 0,04 mm, desplazamiento máximo ~3,02 mm, once regiones afectadas, master ~830 KiB (menor de 850 KiB). Ninguna cifra demuestra un aspecto profesional ni una malla anatómica certificada; son métricas de modificación geométrica. El aspecto visible debe revisarse en capturas nuevas.

Los tres GLB con barra/banco v9.10 reciben **la misma superficie v8** exclusivamente si la geometría neutral sigue siendo numéricamente la del master de origen. Los scripts rechazan un origen distinto en vez de alterar silenciosamente un personaje incompatible. Se conservan exactamente las matrices de huesos, jerarquía, animaciones IK, 8 morph targets, regiones musculares y elementos rígidos del equipo. Todos siguen marcados `approved:false`, `enabled:false`.

Salida *offline* en `apps/app_mobile/build/cc0_master_surface_v7/v8_authoring/`:
- `stk_master_v8_anatomy_preview.glb`
- `ex_bench_press_master55_v8_sculpt_qa.glb`
- `ex_barbell_row_master55_v8_sculpt_qa.glb`
- `ex_squat_master55_v8_sculpt_qa.glb`
- `master_anatomy_v913_report.json` (SHA-256 de cada modelo y métricas).

`test_cc0_interpolated_motion.py` crea estos archivos desde fuentes previas **dentro de su paso ya existente de CI**, con tests para geometría, estado deshabilitado, protección de procedencia, preservación exacta de canales/skin/morph, mismos modelos en tres ejercicios, límites de tamaño y línea media intacta.

`master_anatomy_v913_visual_test.dart` abre el nuevo master y los tres pilotos en el Flutter test runner, compara proyección v7-v8 en cinco movimientos y cuatro instantes, comprueba banco y barra y 8 acentos en temas claro/oscuro. Produce cuatro capturas nuevas `v913_...png` dentro del directorio de evidencia visual previamente subido por el CI público.

## Lo que NO se ha conseguido todavía

No existe una reconstrucción de alta definición de huesos, tendones, músculo estriado con inserciones precisas o piel fisiológica. Faltan separación de los haces del serrato/oblicuos/abdomen y detalles de mano/dedos. Las once regiones son una segmentación aproximada de la malla CC0, no un atlas de músculos certificados. La mejora adicional es deliberadamente pequeña para no romper el LOD de 4.727 vértices.

Las tres demostraciones siguen siendo **provisionales**, sin aprobación por entrenador/anatomista ni medición de cuadros reales presentados en Android/iPhone, batería, temperatura y Z-buffer bajo carga. Tampoco se habilitan las otras 226 animaciones.

## Puertas siguientes

1. Confirmar CI de v9.13 en seis trabajos; revisar las cuatro nuevas capturas contra v7 y el objetivo visual profesional mostrado por el usuario. Si la mejora no es suficiente, debe reemplazarse la malla LOD por **un master anatómico de arte de mayor calidad**, con retopología y normal maps en vez de seguir añadiendo relieves milimétricos.
2. Validar el rig del nuevo master desde vistas frontal, dorsal, lateral y 3/4, flexiones extremas y 8 colores en ambos modos.
3. Preparar LOD múltiple de autoría → entrega móvil, y luego revisión profesional de los tres pilotos y dispositivos físicos.
4. Solo después expandir por lotes a los **229 ejercicios** y activar los aprobados.

**Estado de publicación:** 229 borradores, **0 aprobados**, **0 habilitados**.
