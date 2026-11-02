# STK Haven — motor anatómico 3D móvil experimental (2026-10-20)

## Código añadido
- apps/app_mobile/tool/anatomical_3d/rigged_anatomy_engine.dart: verdadero
  espacio tridimensional, mallas trianguladas en profundidad, rig articulado
  con cinemática inversa de dos segmentos (IK) y geometría del equipo.
- Tres IDs conservados: ex_bench_press, ex_barbell_row, ex_squat.
- Músculos primarios y secundarios diferenciados y teñidos según el
  acento elegido con AppColors.primary; 8 acentos × modo claro/oscuro.
- Perspectiva, sombreado simple, triángulos ordenados por profundidad
  y un Canvas.drawVertices por fotograma; sin GIF, WebView ni red.
- apps/app_mobile/tool/anatomical_3d/rigged_anatomy_preview.dart:
  reproducción de 4 segundos, pausa, movimiento reducido y órbita por arrastre.
  Solo vista interna de revisión, fuera del flujo normal de ejercicios.
- apps/app_mobile/test/features/exercises/rigged_anatomy_3d_test.dart:
  articulaciones, agarres, pies fijos, longitudes del IK, profundidad de malla,
  16 apariencias, capturas en Flutter y reduced motion.

## Qué NO significa esta entrega
El rig está formado por volúmenes anatómicos simplificados (mallas 3D
procedimentales). No es la escultura humana hiperrealista de la referencia
aprobada, no tiene piel continua ni skin weights, ni PBR o z-buffer acelerado.
El ordenamiento de triángulos puede producir oclusiones incorrectas.
Las prestaciones en teléfonos reales y la biomecánica no están certificadas.

Para alcanzar la imagen de referencia hacen falta modelado profesional,
topología continua, armature + skin weights, materialización de músculos y
exportación glTF/GLB, junto con una evaluación de render móvil acelerado.
El rig actual puede servir como prototipo de cinemática, no convierte
automáticamente dibujos bidimensionales en personajes fotorealistas.

## Restricciones de calidad
- Solo GitHub Actions en STK-Haven_CI, PR #43, nunca en STK-Haven privado.
- Los 229 Lottie draft originales siguen 0 approved / 0 enabled.
- No cambiar apps/app_web, el historial de entrenamientos ni Supabase.
- No promover las nuevas vistas 3D al bundle ni al catálogo hasta aprobación.
- CI revisa la geometría y pintura real Flutter; dispositivos físicos,
  rendimiento, naturalidad de animaciones y validación humana pendientes.
