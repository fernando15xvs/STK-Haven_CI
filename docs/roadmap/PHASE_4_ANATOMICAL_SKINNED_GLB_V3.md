# STK Haven · Primera etapa de malla anatómica 3D con skinning (v3)

**Estado:** experimento técnico, NO aprobado visualmente, NO habilitado en Flutter.

## Implementación
- Script reproducible sin dependencias externas: `apps/app_mobile/tool/anatomical_3d/build_anatomical_glb.py`.
- Tres archivos glTF 2.0 binarios (.glb), completamente offline, con IDs `ex_bench_press`, `ex_barbell_row` y `ex_squat`; se generan en `apps/app_mobile/build/anatomical_3d_glb/` durante el CI público.
- 19 huesos, `skin` con `inverseBindMatrices`, pesos `JOINTS_0` y `WEIGHTS_0`, mezclas suaves en torso y extremidades, animación de 4 segundos (rotaciones de articulaciones + traslado de barra/pelvis), materiales por músculo y separación del equipamiento rígido.
- Materiales con roles `STK_PRIMARY` y `STK_SECONDARY`; el código Flutter `anatomical_glb_staging.dart` verifica el GLB binario y define los cambios de color sin copiar assets para 16 variantes de apariencia.
- `test_anatomical_glb.py` y `anatomical_glb_staging_test.dart` verifican estructura, límites de tamaño, determinismo, huesos, cierre del bucle, pesos, IDs y contrato visual.
- Se guarda solo código y evidencia en el artefacto de GitHub Actions del espejo público: **no** se añaden estos GLB al `pubspec.yaml` ni al flujo de selección.
- Los 229 borradores originales se conservan con 0 aprobados y 0 habilitados.

## Advertencias imprescindibles
- La malla contiene un torso continuo y extremidades ponderadas; son **volúmenes musculares procedimentales**, no una escultura anatómica profesional. No asegura biomecánica correcta ni apariencia 3D hiperrealista.
- El lector Flutter actual solo **analiza y valida** GLB y proporciona roles de materiales; **no reproduce ni dibuja todavía GLB**. Falta seleccionar y probar en iOS/Android un renderizador acelerado compatible con skinning.
- El prototipo no ha superado revisión biomecánica, aprobación artística, ni pruebas físicas de FPS, memoria, GPU y batería.
- El código matemático usa secuencias orientativas, no datos certificados de captura de movimiento; revisar especialmente agarres, pies, barra, hombros y trayectorias antes de animar en producción.

## Próximo incremento
Integrar un motor móvil GLB verdaderamente acelerado, validar el skinning con capturas en el emulador y reemplazar la malla procedural por una escultura anatómica profesional con topología y pesos revisados. Solo tras su aprobación extender a los otros 226 ejercicios.

**Restricciones:** no GIF, no `apps/app_web`, no borrar historia, nunca ejecutar GitHub Actions en privado; privado fuente de verdad, espejo público solo CI.
