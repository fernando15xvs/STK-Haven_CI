# STK Haven — Revisión de 229 Lottie (iOS/Android)

## Estado comprobado

- Borradores: **229/229**; aprobaciones editoriales/biomecánicas: **0/229**.
- Pruebas con iPhone físico realizadas y registradas: **0/229**.
- Pruebas con Android físico realizadas y registradas: **0/229**.
- Recursos distribuidos en `pubspec.yaml`: **0/229**.
- El CI #405 resultó 6/6 verde, pero solo verificó compilación y pruebas automáticas; no suplanta QA humano.

## Evidencia generada por el nuevo auditor

Ejecutar desde `apps/app_mobile`:

```bash
python3 tool/exercise_lottie_review.py --output build/lottie_review
```

Se producen `review_matrix.csv`, `summary.json` y 229 archivos `storyboards/<ID>.svg`, cada uno con cinco poses aproximadas (fotogramas 0/15/30/45/60) para detectar ilustraciones ambiguas y corregirlas antes de distribuirlas. No se cambian ejercicios persistentes ni se publican estas imágenes en web o Flutter. El CI público archiva estos informes 7 días.

**Limitación:** los SVG aproximan geométricamente la animación y NO reflejan exactamente la interpolación/antialiasing/reproducción de Lottie en dispositivos. Un CSV generado no supone aprobación.


## Inspección visual provisional de ocho demostraciones

El 20 de octubre de 2026 se inspeccionaron **ocho láminas SVG**, tomando las cinco poses de cada movimiento. Se encontraron los siguientes resultados, que **no constituyen revisión profesional ni aprobación de reproducción móvil**:

| ID | Hallazgo | Acción |
|---|---|---|
| `ex_bench_press` | Se distingue banco y desplazamiento de barra, pero el cuerpo sigue siendo un esquema sencillo | Requiere cotejo técnico y dispositivo |
| `exv2_bird_dog` | No se distinguen con suficiente precisión los cuatro apoyos y su alternancia | Pendiente de rediseño y evaluación |
| `exv2_kettlebell_swing` | En el borrador original la cabeza/carga y el tronco no se leían como una bisagra y un péndulo coherentes | Primera revisión vectorial de silueta, campana, pie de apoyo y extensión de cadera; volver a inspeccionar |
| `exv2_russian_twist` | Silueta inicial parecía erguida en vez de sentada; rotación poco visible | Primera revisión de pelvis en suelo, rodillas, pecho y manos girando; volver a inspeccionar |
| `exv2_ab_wheel_rollout` | El contacto de rodillas y la rueda no eran legibles como rueda abdominal | Primera revisión de rueda circular, apoyo de rodillas, mano y extensión de tronco; volver a inspeccionar |
| `exv2_cable_external_rotation` | No se identifica con claridad el plano de giro del antebrazo y el cable | Pendiente de rediseño y evaluación |
| `exv2_incline_rear_delt_fly` | Banco inclinado y apoyo del pecho poco evidentes en proyección frontal | Pendiente de rediseño y evaluación |
| `exv2_side_plank` | La silueta lateral confunde plancha lateral con plancha general | Pendiente de rediseño y evaluación |

Las modificaciones mencionadas son **borradores correctivos**, no aprobaciones: cualquier error de biomecánica, equipamiento o comprensión en el render de Flutter debe corregirse de nuevo. Después de una segunda selección de 12 láminas (cuatro repetidas de la primera selección), se han visto **16 ejercicios distintos** de forma provisional. Otros **213** siguen sin inspección visual individual. Esta revisión es esquemática y no constituye conformidad biomecánica.


## Segunda inspección visual de doce candidatas — seis bocetos corregidos

Se compararon los fotogramas 0 y 30 de 12 láminas adicionales; cuatro correspondían a la primera muestra. Por tanto son **16 ejercicios distintos inspeccionados provisionalmente**. Entre los nuevos: `exv2_nordic_curl`, `exv2_dead_bug`, `exv2_sissy_squat_assisted`, `exv2_copenhagen_short`, `exv2_copenhagen_long`, `exv2_band_pallof`, `exv2_scapular_pushup` y `exv2_lying_leg_curl_unilateral`.

Se encontraron seis composiciones con interpretaciones dudosas: cuadrupedia no legible (`bird_dog`), apoyo lateral no diferenciado (`side_plank`), banco inclinado oculto (`incline_rear_delt_fly`), plano de rotación del hombro (`cable_external_rotation`), orientación de tumbado (`dead_bug`) y extensión contra resistencia antirotación (`band_pallof`). Se redibujaron para mostrar apoyos, agarres, equipo y articulaciones más claramente y se añadieron verificaciones automatizadas de presencia de elementos anatómicos diferenciados. Cambiaron a **vista lateral** los casos `dead_bug`, `incline_rear_delt_fly` y `band_pallof`, junto con el manifiesto, para representar mejor el movimiento.

**Estado:** seis borradores correctivos preparados para una segunda inspección; no se aprueba ninguna ilustración automáticamente. En especial, los movimientos de rotación externa y antirotación requieren experto en técnica y observación de animación continua, no solo los paneles SVG. Las restantes 213 láminas todavía deben inspeccionarse.


## Tercera pasada: seis ejercicios de alto riesgo corregidos como esquemas

Continúa el proceso de QA provisional en **seis ejercicios ya incluidos en las 16 inspecciones anteriores**, por lo que la cantidad inspeccionada sigue siendo 16/229 y no se contabilizan como seis revisiones adicionales. Esta pasada actualiza el arte de trabajo, no supone aprobación biomecánica:

- `exv2_sissy_squat_assisted`: se distingue apoyo fijo con la mano, proyección de rodillas y tronco sin bisagra en cadera.
- `exv2_copenhagen_short`: rodilla superior sobre banco y pierna inferior en aducción.
- `exv2_copenhagen_long`: tobillo de pierna superior en banco, palanca larga y pierna inferior en aducción.
- `exv2_scapular_pushup`: flexión escapular sin flexión de codos, manos y pies apoyados.
- `exv2_nordic_curl`: anclaje de tobillos y movimiento desde rodillas con tronco-pelvis en bloque.
- `exv2_lying_leg_curl_unilateral`: rodillo sobre tobillo de una pierna, segunda pierna diferenciada y pivote de rodilla.

Se añaden pruebas de regresión para las seis geometrías etiquetadas. **Total de composiciones redibujadas a partir de los primeros bocetos: 15/229**; quedan **214 sin ese redibujo particular** y **213 pendientes de inspección visual individual**. Los 229 siguen siendo ilustraciones esquemáticas de diagnóstico, no personajes anatómicamente ilustrados ni videos.

### Apariencia objetivo en la versión final

El aspecto de los storyboards actuales no es la meta: se necesita arte vectorial **con figura anatómica humana legible** (silueta de torso, brazos, cadera, rodillas, manos y pies diferenciados, idealmente rellenos y sombreados discretos), equipamiento reconocible, trayectorias y puntos de apoyo precisos, secuencia de fase concéntrica/excéntrica y vistas consistentes. Una animación simple de palitos que supera JSON o parser **no se vuelve más realista automáticamente** en Flutter: debe sustituirse o mejorar sus vectores; para casos imposibles con Lottie, considerar un recurso optimizado de calidad equivalente que no sea GIF.

**Puerta de calidad visual:** no convertir ningún `draft` en aprobado solo por técnica de exportación. Se deben valorar manualmente comprensión del ejercicio en los primeros 3 segundos, coherencia corporal a lo largo del movimiento, anatomía/biomecánica verificables y funcionamiento en Flutter nativo. La aplicación sigue en desarrollo personal, por lo que la revisión puede hacerse progresivamente sin publicar activos deficientes.

## Protocolo de revisión por ejercicio

1. Verificar equipo, agarres, cadera, columna, articulaciones, dirección del movimiento, amplitud, alternancia y diferencias unilateral/bilateral con un especialista técnico.
2. Inspeccionar las cinco poses y la animación continua en Flutter. Rechazar las siluetas esquemáticas que no permitan entender el movimiento correctamente.
3. Reproducir en **iPhone físico** y **Android físico**. Comprobar fluidez, tamaño de la app, memoria, reinicio de bucles, pausa, orientación y funcionamiento sin conexión.
4. Verificar `reduceMotion`, alternativas textuales accesibles, fallback cuando el asset falla y licencia comercial documentada.
5. Registrar evidencias y aprobación por ID antes de modificar `approvedMedia` o distribuir archivos.

**Prioridad alta:** bisagras de cadera, press, sentadillas, movimientos unilateral y en polea, rotadores del hombro, core isométrico, progresiones Copenhagen, rueda abdominal, sissy squat y trabajo con equipo guiado.

Los archivos están preparados **para revisión**, no aprobados para publicación.
