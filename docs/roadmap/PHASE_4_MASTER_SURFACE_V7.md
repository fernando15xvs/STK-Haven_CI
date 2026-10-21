# STK Haven — Master anatómico v7 (escultura procedural de revisión)

**Alcance:** solo laboratorio de medios móviles Flutter iOS/Android. No web. No publicación de animaciones ni cambio de rutinas, usuario, historial, Supabase o identificadores de 229 ejercicios.

## Qué se ha implementado

El script `apps/app_mobile/tool/anatomical_3d/build_master_surface_v7.py` aplica un segundo detalle **muy sutil** a las superficies ya esculpidas en v2 y corregidas en v6:

- Pectoral mayor, deltoides anterior y posterior, dorsal ancho, romboides y trapecio medio.
- Perfiles bilaterales simétricos y curvas gaussianas suaves extraídas de las regiones semánticas del propio GLB. La geometría se desplaza a lo largo de la normal local mediante máscara triangulada por músculo; se atenúan límites y línea central para evitar discontinuidades.
- Desplazamiento adicional limitado a **1,5 mm por vértice**, y al 10 % de la arista cercana. Todos los triángulos conservan orientación, se recalculan normales, y los buffers `POSITION`/`NORMAL` originales se actualizan *in situ* sin añadir texturas ni vértices.
- **No cambian:** 55 articulaciones, 7 patrones, 8 correctivos morfológicos, 12 grupos de malla, materiales, canales de animación ni pesos de skinning.
- CI comprueba inmutabilidad de los demás accesores, ausencia de inversión de caras, malla válida, 229 ejercicios intactos y archivo GLB de **850 KiB o menos**. Flutter comprueba siete clips y genera capturas reales de tres patrones en claro/oscuro.

## Generación desde apps/app_mobile

```bash
python3 tool/anatomical_3d/build_master_surface_v7.py \
  --input build/cc0_master_surface_v6/stk_master_v6_joint_surface_review.glb \
  --output build/cc0_master_surface_v7
python3 -m unittest discover -s tool/anatomical_3d -p 'test_master_surface_v7.py'
flutter test test/features/exercises/master_surface_v7_visual_test.dart
```

Productos locales: `build/cc0_master_surface_v7/stk_master_v7_surface_preview.glb`, informe JSON y `build/cc0_master_v7_flutter_qa/` para capturas (evidencia CI pública). El GLB **no está en pubspec** ni se sirve a los usuarios.

**Limitaciones explícitas:** este procedimiento no produce músculos individualmente modelados, inserciones tendinosas, fascia, anatomía validada, biomecánica profesional ni render GPU con Z-buffer. Una escultura profesional con rig/deformaciones de producción y una prueba de dispositivo físico siguen siendo necesarias. 229 borradores, **0 aprobados, 0 habilitados**.
