# STK Haven — revisión cinemática de GLB v3.1

Tres pilotos internos: ex_bench_press, ex_barbell_row y ex_squat.

## Implementado
- Cinemática inversa de dos segmentos para ambos brazos: manos en la barra, posición simétrica, codos articulados; la barra y su animación se mueven en el mismo espacio glTF.
- IK planar para muslos y pantorrillas: pies a ras de suelo, orientación estable del calzado, rodillas de sentadilla flexionadas hacia delante y no hacia atrás.
- Bisagra de cadera estable en el remo; descenso de pelvis sincronizado con la barra en sentadilla. El modelo sigue usando la misma estructura glTF de 19 articulaciones.
- Test de interpolación **LINEAR** a intervalos de 50 ms (81 posiciones por ejercicio) que mide deslizamiento de las manos y los pies, desplazamiento anterior de rodillas y cierre del bucle.
- Archivo auditable build/anatomical_3d_glb/motion_contact_audit.json incluido en artefactos visuales del CI público.

## Umbrales automáticos
- Desviación de agarre barra-manos: menos de 12 mm.
- Movimiento de articulación del pie: menos de 12 mm durante 4 segundos.
- Rodilla de sentadilla desplazada hacia delante respecto a cadera en posición profunda más de 25 cm.
- Bucle cerrado y simetría de miembros inferiores.

Estas comprobaciones **no equivalen a validación biomecánica profesional**. No certifican cargas articulares, amplitud, retracción escapular, calzado, postura o anatomía esculpida. La figura todavía es procedural y el render Flutter sigue realizando skinning con CPU; se requieren GPU-native, aprobación visual y mediciones físicas antes de usarla en producción.

Nada de apps/app_web; cero modificaciones al historial; CI solo en STK-Haven_CI y PR #43. 229 draft, 0 approved, 0 enabled.
