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

Las modificaciones mencionadas son **borradores correctivos**, no aprobaciones: cualquier error de biomecánica, equipamiento o comprensión en el render de Flutter debe corregirse de nuevo. El resto de 221 láminas sigue sin inspección visual individual.

## Protocolo de revisión por ejercicio

1. Verificar equipo, agarres, cadera, columna, articulaciones, dirección del movimiento, amplitud, alternancia y diferencias unilateral/bilateral con un especialista técnico.
2. Inspeccionar las cinco poses y la animación continua en Flutter. Rechazar las siluetas esquemáticas que no permitan entender el movimiento correctamente.
3. Reproducir en **iPhone físico** y **Android físico**. Comprobar fluidez, tamaño de la app, memoria, reinicio de bucles, pausa, orientación y funcionamiento sin conexión.
4. Verificar `reduceMotion`, alternativas textuales accesibles, fallback cuando el asset falla y licencia comercial documentada.
5. Registrar evidencias y aprobación por ID antes de modificar `approvedMedia` o distribuir archivos.

**Prioridad alta:** bisagras de cadera, press, sentadillas, movimientos unilateral y en polea, rotadores del hombro, core isométrico, progresiones Copenhagen, rueda abdominal, sissy squat y trabajo con equipo guiado.

Los archivos están preparados **para revisión**, no aprobados para publicación.
