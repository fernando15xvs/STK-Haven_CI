# STK Haven — Plan de producción Lottie 229/229 (exclusivo iOS y Android)

**Fecha:** 18 de octubre de 2026  
**Estado:** cobertura fijada. **Borradores vectoriales originales: 229/229 (lotes 1–4 completos como borradores: 40 + 60 + 70 + 59); aprobados y distribuidos: 0/229.**

## Plataforma y alcance (decisión del usuario)

- **iOS y Android solamente:** reproducir animaciones mediante `apps/app_mobile` y el paquete `lottie` ya integrado en Flutter.
- **Web excluida:** no añadir Lottie, animaciones, pantallas multimedia, `pubspec` ni assets a `apps/app_web`. Los datos comunes de ejercicios del paquete `core` no son una autorización para renderizar Lottie en web.
- **229 IDs exactos y estables:** los 49 ejercicios `ex_*` y los 180 `exv2_*`, cada uno **una animación propia**. Un rig compartido no implica usar un JSON incorrecto para variantes de equipo o posición.
- **Sin GIFs:** Lottie JSON vectorial de primera elección. Si la técnica no puede representarse correctamente en vector, revisar caso por caso una alternativa optimizada **solo móvil**.
- **Sin cambios de historial:** ni modelos persistidos, series, PRs, rutinas, favoritos ni respaldos deben alterarse para incorporar recursos.
- **No confundir plan con implementación:** los nombres de archivos son destinos previstos, no archivos ya creados. Ninguna fila está aprobada y `approvedMedia` seguirá vacío hasta existir material válido.

## Producción de borradores — lote 1 completo (40/40)

Cuarenta composiciones Lottie JSON vectoriales **originales y distintas** en `apps/app_mobile/assets/exercise_media/lottie/` (solo iOS/Android):

- `ex_bench_press.json` — Press de banca · lateral.
- `ex_incline_db_press.json` — Press inclinado con mancuernas · lateral.
- `exv2_flat_db_press.json` — Press plano con mancuernas · lateral.
- `ex_lat_pulldown.json` — Jalón al pecho · frontal.
- `ex_pullups.json` — Dominadas · frontal.
- `ex_barbell_row.json` — Remo con barra · lateral.
- `ex_cable_row.json` — Remo en polea baja · lateral.
- `ex_ohp.json` — Press militar · frontal.
- `ex_lateral_raises.json` — Elevaciones laterales · frontal.
- `ex_squat.json` — Sentadilla con barra · lateral.
- `exv2_incline_barbell_press.json` — Press inclinado con barra a 30°; movimiento de barra en eje vertical · vista lateral.
- `exv2_flat_machine_press.json` — Press de pecho sentado en máquina: brazo, palanca y manillar · vista lateral.
- `exv2_pushup.json` — Flexiones: plancha, codos y descenso del torso con manos ancladas · vista lateral.
- `exv2_single_arm_pulldown.json` — Jalón unilateral arrodillado: mano de trabajo, polea y cable · vista lateral.
- `exv2_chest_supported_db_row.json` — Remo con pecho apoyado en banco inclinado y dos mancuernas · vista lateral.
- `exv2_single_arm_db_row.json` — Remo unilateral con mano apoyada en banco y mancuerna libre · vista lateral.
- `ex_face_pull.json` — Face Pull bilateral en cuerda: codos abiertos hacia rostro · vista frontal.
- `exv2_arnold_press.json` — Press Arnold sentado: brazos y cargas desde frente hasta arriba · vista frontal.
- `exv2_seated_db_lateral_raise.json` — Elevaciones laterales con ambas mancuernas, sentado en banco · vista frontal.
- `exv2_single_arm_rear_cable_fly.json` — Apertura posterior unilateral en polea con brazo libre estabilizado · vista frontal.
- `exv2_scapular_pushup.json` — Flexión escapular en plancha, sin flexionar los codos · vista lateral.
- `ex_barbell_curl.json` — Curl de bíceps con barra recta · vista frontal.
- `ex_hammer_curl.json` — Curl con dos mancuernas en agarre neutro · vista frontal.
- `ex_tricep_pushdown.json` — Extensión de codos en polea alta con barra · vista frontal.
- `exv2_ez_bar_curl.json` — Curl con barra EZ y agarres angulados · vista frontal.
- `exv2_rope_pushdown.json` — Extensión de tríceps con cuerda en polea alta · vista frontal.
- `exv2_rope_hammer_curl.json` — Curl martillo con cuerda en polea baja · vista frontal.
- `ex_leg_press.json` — Prensa inclinada de piernas en máquina · vista lateral.
- `ex_leg_extension.json` — Extensión de rodilla sentado en máquina · vista lateral.
- `ex_leg_curl.json` — Curl femoral tumbado con rodillo · vista lateral.
- `ex_hip_thrust.json` — Elevación de cadera apoyada sobre banco · vista lateral.
- `ex_rdl.json` — Bisagra de cadera con barra · vista lateral.
- `exv2_front_squat.json` — Sentadilla frontal con barra en rack · vista frontal.
- `exv2_goblet_squat.json` — Sentadilla goblet con carga frente al pecho · vista frontal.
- `exv2_db_rdl.json` — Bisagra de cadera con dos mancuernas · vista lateral.
- `exv2_machine_hip_thrust.json` — Elevación de cadera en máquina · vista lateral.
- `exv2_nordic_curl.json` — Curl nórdico asistido con tobillos sujetos · vista lateral.
- `ex_calf_raise.json` — Elevación de talones de pie sobre plataforma · vista lateral.
- `ex_crunch.json` — Flexión abdominal de tronco en colchoneta · vista lateral.
- `exv2_pallof_press.json` — Press antirotación con polea lateral · vista frontal.

Todas incluyen keyframes de movimiento sin imágenes raster incrustadas, identificador propio y vista específica. Son **borradores de producción, no demostraciones biomecánicas aprobadas**. Revisar perspectiva, postura, agarre, recorrido, coherencia de equipo, visualización real en dispositivos y accesibilidad.

El manifiesto registra exactamente 40 `draft` con `approved: false` y 189 `pending`. `approvedMedia` permanece vacío, y la carpeta de animaciones **no** está declarada como recurso en `pubspec.yaml`: ninguna se distribuye todavía a usuarios. Las pruebas físicas siguen reservadas al cierre del roadmap, pero ninguna será aprobada sin revisión técnica y tests oportunos.

## Corrección de compatibilidad del decodificador móvil

El CI #392 detectó un problema real de formato en los 40 primeros JSON: los
elementos vectoriales `sh`/`st`/`el`/`fl` estaban en el nivel superior de
`layers[].shapes[]`, y Lottie 3.3.3 no los abría. Se comprobó en CI #393
que el mismo recurso de press de banca sí se decodificaba al encerrar cada
conjunto vectorial en `ty: gr` con `it` y transformación `ty: tr`.

Las 40 composiciones del lote 1 se han normalizado a esta estructura.
El test `mobile_lottie_production_plan_test.dart` exige la estructura agrupada
y decodifica **cada archivo mediante `LottieComposition.fromBytes`**.
La compilación iOS/Android, la verificación biomecánica y los ensayos físicos
siguen siendo requisitos de publicación. **Ningún recurso se aprueba por el
simple hecho de que el decodificador lo abra.**

### Continuación del lote 2 — 40/60 borradores

Se han creado 40 composiciones originales de variantes de agarre, soporte,
máquina, ejecución unilateral y posiciones corporales. Las diez más recientes
son abductor y aductor en máquina, curl Scott en máquina, hip thrust Smith,
crunch en máquina, press landmine, press inclinado en máquina, sentadilla hack,
gemelos sentado y remo escapular. Todos poseen ID propio, grupo vectorial
y keyframes específicos de la variante.

El siguiente grupo de diez incluye curl inverso de muñeca, pull-through,
dominadas asistidas, curl con fitball, Meadows row, cruce de poleas, fondos,
curl inclinado, remo unilateral y reverse pec deck. Son borradores de técnica,
no dibujos validados biomecánicamente.

El CI #396 comprobó con el decodificador Flutter los primeros 50 borradores
(pruebas móviles y Analyze/Core en verde); el test se amplió a los 80 borradores actuales
y requiere una nueva ejecución CI. Las pruebas reales en dispositivos,
la revisión biomecánica y la accesibilidad continúan pendientes.

No declarar `approved` ni añadir los assets a `pubspec.yaml` hasta
superar todas las puertas de revisión y tener medios correctos.

## Pipeline para cada ejercicio

1. Diseñar un storyboard y una figura/rig propio adaptado a ese movimiento y su equipo (barra, mancuernas, polea, máquina, banda o corporal).
2. Crear Lottie JSON original, con una o dos repeticiones y un bucle fluido, sin fotografías ni bitmaps incrustados pesados.
3. Contrastar vista, postura, amplitud, lateralidad y técnica con las notas del ejercicio; hacer revisión biomecánica adecuada antes de declararlo apto.
4. Revisar licencia comercial/distribución offline, titular y atribución; documentar el origen. Ningún asset externo sin permiso verificable.
5. Registrar el archivo real en `apps/app_mobile/assets/exercise_media/lottie/<exerciseId>.json` y añadirlo al paquete **móvil**, no al web.
6. Ejecutar pruebas de carga, reproducción, pausa, `reduceMotion`, fallback sin red, Flutter Analyze y CI espejo; reservar pruebas físicas finales de iOS/Android al cierre del roadmap.
7. Solamente después de todas las revisiones, incluirlo en `ExerciseDemonstrationLibrary.approvedMedia` y marcarlo `approved` en el manifiesto.

**Manifiesto fuente de seguimiento:** `apps/app_mobile/tool/exercise_lottie_batches.json`. Cada fila tiene `id`, `name`, `family`, `status: pending`, `approved: false` y ruta local **prevista**. No se descarga nada automáticamente.

## Producción en cuatro lotes

| Lote | Ejercicios | Acumulado | Plataforma | Estado |
|---|---:|---:|---|---|
| 1 · movimientos esenciales | 40 | 40/229 | iOS + Android | 40 borradores, 0 aprobados |
| 2 · variantes frecuentes | 60 | 100/229 | iOS + Android | 40 borradores, 0 aprobados |
| 3 · ampliación anatómica | 70 | 170/229 | iOS + Android | 0 aprobados |
| 4 · restantes y cobertura completa | 59 | 229/229 | iOS + Android | 0 aprobados |

### Lote 1 — 40 ejercicios

- [ ] 01. `ex_bench_press` — Press de Banca · **borrador Lottie (sin aprobación)**
- [ ] 02. `ex_incline_db_press` — Press Inclinado c/M · **borrador Lottie (sin aprobación)**
- [ ] 03. `exv2_flat_db_press` — Press plano con mancuernas · **borrador Lottie (sin aprobación)**
- [ ] 04. `exv2_incline_barbell_press` — Press inclinado con barra 30° · **borrador Lottie (sin aprobación)**
- [ ] 05. `exv2_flat_machine_press` — Press horizontal guiado en máquina · **borrador Lottie (sin aprobación)**
- [ ] 06. `exv2_pushup` — Flexiones de brazos · **borrador Lottie (sin aprobación)**
- [ ] 07. `ex_lat_pulldown` — Jalón al Pecho · **borrador Lottie (sin aprobación)**
- [ ] 08. `ex_pullups` — Dominadas · **borrador Lottie (sin aprobación)**
- [ ] 09. `ex_barbell_row` — Remo con Barra · **borrador Lottie (sin aprobación)**
- [ ] 10. `ex_cable_row` — Remo en Polea Baja · **borrador Lottie (sin aprobación)**
- [ ] 11. `exv2_single_arm_pulldown` — Jalón unilateral de rodillas · **borrador Lottie (sin aprobación)**
- [ ] 12. `exv2_chest_supported_db_row` — Remo con apoyo de pecho y mancuernas · **borrador Lottie (sin aprobación)**
- [ ] 13. `exv2_single_arm_db_row` — Remo unilateral con mancuerna en banco · **borrador Lottie (sin aprobación)**
- [ ] 14. `ex_face_pull` — Face Pull · **borrador Lottie (sin aprobación)**
- [ ] 15. `ex_ohp` — Press Militar · **borrador Lottie (sin aprobación)**
- [ ] 16. `ex_lateral_raises` — Elevaciones Laterales · **borrador Lottie (sin aprobación)**
- [ ] 17. `exv2_arnold_press` — Press Arnold con mancuernas · **borrador Lottie (sin aprobación)**
- [ ] 18. `exv2_seated_db_lateral_raise` — Elevación lateral sentado · **borrador Lottie (sin aprobación)**
- [ ] 19. `exv2_single_arm_rear_cable_fly` — Elevación posterior unilateral en polea · **borrador Lottie (sin aprobación)**
- [ ] 20. `exv2_scapular_pushup` — Flexiones escapulares · **borrador Lottie (sin aprobación)**
- [ ] 21. `ex_barbell_curl` — Curl con Barra · **borrador Lottie (sin aprobación)**
- [ ] 22. `ex_hammer_curl` — Curl Martillo · **borrador Lottie (sin aprobación)**
- [ ] 23. `ex_tricep_pushdown` — Extensiones de Tríceps · **borrador Lottie (sin aprobación)**
- [ ] 24. `exv2_ez_bar_curl` — Curl con barra EZ · **borrador Lottie (sin aprobación)**
- [ ] 25. `exv2_rope_pushdown` — Extensión tríceps con cuerda en polea · **borrador Lottie (sin aprobación)**
- [ ] 26. `exv2_rope_hammer_curl` — Curl martillo con cuerda · **borrador Lottie (sin aprobación)**
- [ ] 27. `ex_squat` — Sentadilla Libre · **borrador Lottie (sin aprobación)**
- [ ] 28. `ex_leg_press` — Prensa Inclinada · **borrador Lottie (sin aprobación)**
- [ ] 29. `ex_leg_extension` — Extensiones de Cuádriceps · **borrador Lottie (sin aprobación)**
- [ ] 30. `ex_leg_curl` — Curl Femoral · **borrador Lottie (sin aprobación)**
- [ ] 31. `ex_hip_thrust` — Hip Thrust · **borrador Lottie (sin aprobación)**
- [ ] 32. `ex_rdl` — Peso Muerto Rumano · **borrador Lottie (sin aprobación)**
- [ ] 33. `exv2_front_squat` — Sentadilla frontal con barra · **borrador Lottie (sin aprobación)**
- [ ] 34. `exv2_goblet_squat` — Sentadilla goblet · **borrador Lottie (sin aprobación)**
- [ ] 35. `exv2_db_rdl` — Peso muerto rumano con mancuernas · **borrador Lottie (sin aprobación)**
- [ ] 36. `exv2_machine_hip_thrust` — Hip thrust en máquina · **borrador Lottie (sin aprobación)**
- [ ] 37. `exv2_nordic_curl` — Curl nórdico asistido · **borrador Lottie (sin aprobación)**
- [ ] 38. `ex_calf_raise` — Elevación de Gemelos · **borrador Lottie (sin aprobación)**
- [ ] 39. `ex_crunch` — Crunches · **borrador Lottie (sin aprobación)**
- [ ] 40. `exv2_pallof_press` — Press Pallof en polea · **borrador Lottie (sin aprobación)**

### Lote 2 — 60 ejercicios

**Estado:** 60/60 JSON de borrador creados; las casillas quedan pendientes hasta revisión técnica y aprobación para distribución.

- [ ] 01. `exv2_preacher_bar_curl` — Curl Scott con barra EZ · **borrador Lottie (sin aprobación)**
- [ ] 02. `exv2_barbell_glute_bridge` — Puente de glúteos con barra desde el suelo · **borrador Lottie (sin aprobación)**
- [ ] 03. `exv2_cable_crunch` — Crunch abdominal arrodillado en polea · **borrador Lottie (sin aprobación)**
- [ ] 04. `exv2_seated_barbell_ohp` — Press militar sentado con barra · **borrador Lottie (sin aprobación)**
- [ ] 05. `exv2_incline_smith_press` — Press inclinado en Smith · **borrador Lottie (sin aprobación)**
- [ ] 06. `exv2_smith_squat` — Sentadilla en Smith · **borrador Lottie (sin aprobación)**
- [ ] 07. `exv2_standing_calf_raise` — Gemelos de pie en máquina · **borrador Lottie (sin aprobación)**
- [ ] 08. `exv2_band_pull_apart` — Aperturas de banda a la altura del pecho · **borrador Lottie (sin aprobación)**
- [ ] 09. `exv2_wrist_curl_seated` — Curl de muñeca supino sentado · **borrador Lottie (sin aprobación)**
- [ ] 10. `exv2_roman_chair_back_extension` — Extensiones de espalda en banco romano · **borrador Lottie (sin aprobación)**
- [ ] 11. `exv2_chinup` — Dominadas supinas · **borrador Lottie (sin aprobación)**
- [ ] 12. `exv2_glute_ham_raise` — Elevación glúteo-isquios en banco GHD · **borrador Lottie (sin aprobación)**
- [ ] 13. `exv2_chest_supported_machine_row` — Remo convergente con apoyo de pecho · **borrador Lottie (sin aprobación)**
- [ ] 14. `ex_chest_flyes` — Aperturas en Máquina · **borrador Lottie (sin aprobación)**
- [ ] 15. `ex_overhead_tricep` — Extensión Sobre la Cabeza · **borrador Lottie (sin aprobación)**
- [ ] 16. `ex_db_curl` — Curl Alterno c/M · **borrador Lottie (sin aprobación)**
- [ ] 17. `ex_kelso_shrugs` — Kelso Shrugs · **borrador Lottie (sin aprobación)**
- [ ] 18. `ex_db_shoulder_press` — Press de Hombros c/M · **borrador Lottie (sin aprobación)**
- [ ] 19. `ex_lying_leg_curl` — Curl Femoral Acostado · **borrador Lottie (sin aprobación)**
- [ ] 20. `ex_bulgarian_split_squat` — Sentadilla Búlgara · **borrador Lottie (sin aprobación)**
- [ ] 21. `ex_abductor` — Abductor en Máquina · **borrador Lottie (sin aprobación)**
- [ ] 22. `ex_adductor` — Aductor en Máquina · **borrador Lottie (sin aprobación)**
- [ ] 23. `exv2_preacher_machine_curl` — Curl Scott en máquina · **borrador Lottie (sin aprobación)**
- [ ] 24. `exv2_smith_hip_thrust` — Hip thrust en Smith · **borrador Lottie (sin aprobación)**
- [ ] 25. `exv2_machine_crunch` — Crunch sentado en máquina · **borrador Lottie (sin aprobación)**
- [ ] 26. `exv2_landmine_shoulder_press` — Press de hombro en landmine · **borrador Lottie (sin aprobación)**
- [ ] 27. `exv2_incline_machine_press` — Press inclinado convergente en máquina · **borrador Lottie (sin aprobación)**
- [ ] 28. `exv2_hack_squat` — Sentadilla hack en máquina · **borrador Lottie (sin aprobación)**
- [ ] 29. `exv2_seated_calf_raise` — Sóleo sentado en máquina · **borrador Lottie (sin aprobación)**
- [ ] 30. `exv2_scapular_row` — Remo escapular con pecho apoyado · **borrador Lottie (sin aprobación)**
- [ ] 31. `exv2_reverse_wrist_curl` — Curl inverso de muñeca sentado · **borrador Lottie (sin aprobación)**
- [ ] 32. `exv2_cable_pullthrough` — Pull through en polea · **borrador Lottie (sin aprobación)**
- [ ] 33. `exv2_assisted_pullup` — Dominadas asistidas en máquina · **borrador Lottie (sin aprobación)**
- [ ] 34. `exv2_swiss_ball_leg_curl` — Curl femoral con fitball · **borrador Lottie (sin aprobación)**
- [ ] 35. `exv2_meadows_row` — Remo Meadows a un brazo · **borrador Lottie (sin aprobación)**
- [ ] 36. `ex_cable_crossover` — Cruces en Polea · **borrador Lottie (sin aprobación)**
- [ ] 37. `ex_dips` — Fondos en Paralelas · **borrador Lottie (sin aprobación)**
- [ ] 38. `ex_incline_db_curl` — Curl Inclinado 65° · **borrador Lottie (sin aprobación)**
- [ ] 39. `ex_machine_unilateral_row` — Remo Unilateral Máquina · **borrador Lottie (sin aprobación)**
- [ ] 40. `ex_reverse_pec_deck` — Pájaros en Máquina · **borrador Lottie (sin aprobación)**
- [ ] 41. `ex_seated_leg_curl` — Curl Femoral Sentado
- [ ] 42. `ex_pendulum_squat` — Sentadilla Pendular
- [ ] 43. `exv2_spider_curl` — Curl araña con mancuernas
- [ ] 44. `exv2_single_leg_hip_thrust` — Hip thrust unilateral
- [ ] 45. `exv2_reverse_crunch` — Crunch inverso en colchoneta
- [ ] 46. `exv2_machine_shoulder_press` — Press de hombro en máquina convergente
- [ ] 47. `exv2_decline_barbell_press` — Press declinado con barra
- [ ] 48. `exv2_belt_squat` — Sentadilla con cinturón lastrado
- [ ] 49. `exv2_smith_calf_raise` — Gemelos de pie en Smith
- [ ] 50. `exv2_cable_scapular_retraction` — Retracción escapular en polea
- [ ] 51. `exv2_wrist_roller` — Rodillo de muñeca
- [ ] 52. `exv2_reverse_hyper` — Extensión inversa de cadera en banco
- [ ] 53. `exv2_band_pullup` — Dominadas asistidas con banda
- [ ] 54. `exv2_slider_leg_curl` — Curl femoral deslizando talones
- [ ] 55. `exv2_landmine_row` — Remo landmine bilateral
- [ ] 56. `ex_peck_deck` — Peck Deck
- [ ] 57. `ex_v_bar_pushdown` — Extensiones con Barra V
- [ ] 58. `ex_low_pulley_curl` — Curl en Polea Baja
- [ ] 59. `ex_t_bar_row` — Remo en T
- [ ] 60. `ex_machine_lateral_raises` — Elevaciones Laterales M.

### Lote 3 — 70 ejercicios

- [ ] 01. `ex_standing_leg_curl` — Curl Femoral Parado
- [ ] 02. `exv2_bayesian_curl` — Curl bayesiano unilateral en polea
- [ ] 03. `exv2_cable_glute_kickback` — Patada de glúteo en polea
- [ ] 04. `exv2_hanging_knee_raise` — Elevación de rodillas colgado
- [ ] 05. `exv2_lean_away_lateral_raise` — Elevación lateral inclinado con polea
- [ ] 06. `exv2_decline_db_press` — Press declinado con mancuernas
- [ ] 07. `exv2_horizontal_leg_press` — Prensa horizontal en máquina
- [ ] 08. `exv2_single_leg_db_calf` — Gemelo unilateral con mancuerna
- [ ] 09. `exv2_barbell_shrug` — Encogimientos con barra
- [ ] 10. `exv2_hammer_pronation` — Pronación de antebrazo con martillo
- [ ] 11. `exv2_good_morning` — Buenos días con barra
- [ ] 12. `exv2_wide_pulldown` — Jalón al pecho agarre amplio
- [ ] 13. `exv2_cable_leg_curl` — Curl femoral de pie en polea
- [ ] 14. `exv2_low_cable_single_arm_row` — Remo sentado unilateral en polea baja
- [ ] 15. `ex_hammer_press` — Press Hammer
- [ ] 16. `ex_french_press` — Press Francés
- [ ] 17. `ex_unilateral_scott_hammer` — Curl Martillo Scott Uni.
- [ ] 18. `ex_neutral_pulldown` — Jalón Pecho Agarre Neutro
- [ ] 19. `ex_cable_rear_delt` — Elevaciones Posteriores P.
- [ ] 20. `exv2_incline_alternating_curl` — Curl alterno inclinado en banco
- [ ] 21. `exv2_machine_glute_kickback` — Patada de glúteo en máquina
- [ ] 22. `exv2_captains_chair_raise` — Elevación de rodillas en silla romana
- [ ] 23. `exv2_behind_body_cable_lateral` — Elevación lateral en polea desde atrás
- [ ] 24. `exv2_incline_pushup` — Flexiones con manos elevadas
- [ ] 25. `exv2_unilateral_leg_press` — Prensa unilateral
- [ ] 26. `exv2_leg_press_calf_raise` — Gemelos en prensa
- [ ] 27. `exv2_db_shrug` — Encogimientos con mancuernas
- [ ] 28. `exv2_hammer_supination` — Supinación de antebrazo con martillo
- [ ] 29. `exv2_single_leg_rdl` — Peso muerto rumano unilateral
- [ ] 30. `exv2_supine_pulldown` — Jalón supino cerrado
- [ ] 31. `exv2_lying_leg_curl_unilateral` — Curl femoral acostado unilateral
- [ ] 32. `exv2_inverted_row` — Remo invertido en barra
- [ ] 33. `ex_high_pulley_fly` — Fly en Polea Alta
- [ ] 34. `ex_machine_dips` — Fondos en Máquina
- [ ] 35. `exv2_standing_cable_curl` — Curl de bíceps con barra en polea
- [ ] 36. `exv2_stepback_cable_glute` — Extensión de cadera de pie con polea
- [ ] 37. `exv2_decline_crunch` — Crunch en banco declinado
- [ ] 38. `exv2_front_plate_raise` — Elevación frontal con disco
- [ ] 39. `exv2_decline_pushup` — Flexiones con pies elevados
- [ ] 40. `exv2_step_up` — Subida a banco con mancuernas
- [ ] 41. `exv2_donkey_calf_raise` — Elevaciones de talón tipo burro
- [ ] 42. `exv2_cable_shrug` — Encogimientos en polea baja
- [ ] 43. `exv2_farmer_carry` — Paseo del granjero con mancuernas
- [ ] 44. `exv2_smith_rdl` — Peso muerto rumano en Smith
- [ ] 45. `exv2_straight_arm_pulldown` — Pullover de pie con brazos rectos
- [ ] 46. `exv2_seated_leg_curl_unilateral` — Curl femoral sentado unilateral
- [ ] 47. `exv2_high_cable_curl` — Curl de bíceps doble polea alta
- [ ] 48. `exv2_frog_pumps` — Puentes de glúteo con plantas juntas
- [ ] 49. `exv2_weighted_crunch` — Crunch con disco sobre pecho
- [ ] 50. `exv2_front_cable_raise` — Elevación frontal unilateral en polea
- [ ] 51. `exv2_flat_db_fly` — Aperturas planas con mancuernas
- [ ] 52. `exv2_reverse_lunge` — Zancada hacia atrás con mancuernas
- [ ] 53. `exv2_bent_knee_calf_raise` — Gemelos con rodillas flexionadas
- [ ] 54. `exv2_prone_y_raise` — Elevación en Y sobre banco inclinado
- [ ] 55. `exv2_dead_hang` — Suspensión pasiva de barra
- [ ] 56. `exv2_stiff_leg_deadlift` — Peso muerto piernas semirrígidas
- [ ] 57. `exv2_machine_pullover` — Pullover en máquina
- [ ] 58. `exv2_concentration_curl` — Curl concentración sentado
- [ ] 59. `exv2_side_lying_hip_abduction` — Abducción de cadera acostado lateral
- [ ] 60. `exv2_dead_bug` — Dead bug alternando brazos y piernas
- [ ] 61. `exv2_incline_rear_delt_fly` — Pájaros con mancuernas en banco inclinado
- [ ] 62. `exv2_low_to_high_fly` — Aperturas en polea de abajo arriba
- [ ] 63. `exv2_walking_lunge` — Zancadas caminando con mancuernas
- [ ] 64. `exv2_single_leg_seated_calf` — Sóleo unilateral sentado
- [ ] 65. `exv2_prone_t_raise` — Elevación en T sobre banco inclinado
- [ ] 66. `exv2_plate_pinch` — Pinza de discos
- [ ] 67. `exv2_sumo_deadlift` — Peso muerto sumo
- [ ] 68. `exv2_db_pullover` — Pullover con mancuerna
- [ ] 69. `exv2_supinated_single_cable_curl` — Curl supino unilateral en polea baja
- [ ] 70. `exv2_cable_hip_abduction` — Abducción unilateral en polea baja

### Lote 4 — 59 ejercicios

- [ ] 01. `exv2_bird_dog` — Bird dog cuadrupedia
- [ ] 02. `exv2_bent_over_rear_delt_raise` — Elevación posterior inclinado de pie
- [ ] 03. `exv2_mid_cable_fly` — Aperturas en polea a altura media
- [ ] 04. `exv2_sissy_squat_assisted` — Sentadilla sissy asistida
- [ ] 05. `exv2_tibialis_wall_raise` — Elevación de puntas contra pared
- [ ] 06. `exv2_wall_slide` — Deslizamiento de brazos en pared
- [ ] 07. `exv2_suitcase_carry` — Paseo con peso a un lado
- [ ] 08. `exv2_kettlebell_swing` — Balanceo de pesa rusa
- [ ] 09. `exv2_neutral_machine_pulldown` — Jalón neutro convergente en máquina
- [ ] 10. `exv2_cross_body_hammer_curl` — Curl martillo cruzado
- [ ] 11. `exv2_band_lateral_walk` — Caminata lateral con minibanda
- [ ] 12. `exv2_hollow_hold` — Hollow hold
- [ ] 13. `exv2_wide_rope_face_pull` — Face pull con cuerda y rotación externa
- [ ] 14. `exv2_unilateral_cable_press` — Press de pecho unilateral en polea
- [ ] 15. `exv2_spanish_squat` — Sentadilla española con banda
- [ ] 16. `exv2_tibialis_machine` — Tibial anterior en máquina
- [ ] 17. `exv2_serratus_punch` — Golpe de serrato con mancuerna tumbado
- [ ] 18. `exv2_reverse_ez_curl` — Curl inverso con barra EZ
- [ ] 19. `exv2_monster_walk` — Caminata diagonal con minibanda
- [ ] 20. `exv2_ab_wheel_rollout` — Rueda abdominal desde rodillas
- [ ] 21. `exv2_cable_external_rotation` — Rotación externa de hombro en polea
- [ ] 22. `exv2_close_grip_bench` — Press banca agarre cerrado
- [ ] 23. `exv2_leg_extension_unilateral` — Extensión de cuádriceps unilateral
- [ ] 24. `exv2_band_dorsiflexion` — Dorsiflexión con banda elástica
- [ ] 25. `exv2_serratus_cable_punch` — Empuje de serrato unilateral en polea
- [ ] 26. `exv2_preacher_hammer_curl` — Curl martillo Scott bilateral
- [ ] 27. `exv2_standing_machine_abduction` — Abducción de cadera de pie en máquina
- [ ] 28. `exv2_forearm_plank` — Plancha sobre antebrazos
- [ ] 29. `exv2_band_external_rotation` — Rotación externa con banda
- [ ] 30. `exv2_diamond_pushup` — Flexión diamante
- [ ] 31. `exv2_sumo_goblet_squat` — Sentadilla sumo con mancuerna
- [ ] 32. `exv2_straight_bar_pushdown` — Extensión tríceps con barra recta
- [ ] 33. `exv2_clamshell` — Clamshell con minibanda
- [ ] 34. `exv2_high_plank` — Plancha alta
- [ ] 35. `exv2_side_lying_external_rotation` — Rotación externa tumbado de lado
- [ ] 36. `exv2_reverse_grip_pushdown` — Extensión tríceps agarre supino en polea
- [ ] 37. `exv2_cable_hip_adduction` — Aducción unilateral de cadera en polea
- [ ] 38. `exv2_band_pallof` — Press Pallof con banda
- [ ] 39. `exv2_cable_internal_rotation` — Rotación interna de hombro en polea
- [ ] 40. `exv2_single_arm_pushdown` — Extensión tríceps unilateral en polea
- [ ] 41. `exv2_side_lying_adduction` — Aducción lateral acostado
- [ ] 42. `exv2_side_plank` — Plancha lateral
- [ ] 43. `exv2_band_internal_rotation` — Rotación interna con banda
- [ ] 44. `exv2_overhead_rope_triceps` — Extensión tríceps sobre cabeza con cuerda
- [ ] 45. `exv2_copenhagen_short` — Plancha Copenhagen de palanca corta
- [ ] 46. `exv2_side_plank_hip_lift` — Elevación de cadera en plancha lateral
- [ ] 47. `exv2_scaption_raise` — Elevación escapular en plano de escápula
- [ ] 48. `exv2_one_arm_overhead_cable` — Extensión tríceps overhead unilateral en polea
- [ ] 49. `exv2_copenhagen_long` — Plancha Copenhagen de palanca larga
- [ ] 50. `exv2_cable_woodchop_high_low` — Woodchopper en polea alta a baja
- [ ] 51. `exv2_single_db_overhead_triceps` — Extensión tríceps overhead con mancuerna a una mano
- [ ] 52. `exv2_standing_cable_knee_drive` — Elevación de rodilla con polea
- [ ] 53. `exv2_cable_woodchop_low_high` — Woodchopper en polea baja a alta
- [ ] 54. `exv2_lying_db_triceps` — Press francés tumbado con mancuernas
- [ ] 55. `exv2_band_marching` — Marcha contra minibanda
- [ ] 56. `exv2_russian_twist` — Giro ruso sentado sin carga
- [ ] 57. `exv2_kickback_db` — Patada de tríceps con mancuerna
- [ ] 58. `exv2_seated_knee_raise` — Elevación de rodillas sentado
- [ ] 59. `exv2_triceps_machine_extension` — Extensión de tríceps en máquina sentado

## Producción de borradores — lote 2 completo (60/60)

Se añadieron 20 composiciones originales adicionales a las 40 ya existentes del lote 2 (100 borradores en total). Se trata exclusivamente de borradores vectoriales no aprobados, sin assets empaquetados en la app.

- `ex_seated_leg_curl.json` — Muslos apoyados en asiento; flexión de rodilla desplaza rodillo tibial hacia atrás.
- `ex_pendulum_squat.json` — Sentadilla pendular con espalda soportada y pies en plataforma: desciende cadera y flexiona rodillas.
- `exv2_spider_curl.json` — Curl araña: pecho apoyado en banco inclinado y brazo colgando, flexiona solo antebrazo.
- `exv2_single_leg_hip_thrust.json` — Hip thrust unilateral con espalda alta en banco, pie de apoyo fijo y pierna contraria elevada.
- `exv2_reverse_crunch.json` — Crunch inverso en suelo: acercar pelvis hacia tórax sin balancear piernas.
- `exv2_machine_shoulder_press.json` — Press de hombros en máquina convergente: manillares ascienden guiados desde los hombros.
- `exv2_decline_barbell_press.json` — Press declinado con barra: apoyo cabeza más bajo que cadera, barra sobre el pecho y recorrido vertical controlado.
- `exv2_belt_squat.json` — Sentadilla con cinturón de carga suspendida; torso erguido y cadera desciende con pies fijos.
- `exv2_smith_calf_raise.json` — Elevación de talones en Smith con barra sobre trapecios, rodillas casi extendidas y puntas apoyadas.
- `exv2_cable_scapular_retraction.json` — Retracción escapular en polea con codos casi extendidos: omóplatos retroceden sin flexión de codos significativa.
- `exv2_wrist_roller.json` — Rodillo de muñeca a la altura de brazos extendidos, giro alternado del cilindro y cuerda con pesa.
- `exv2_reverse_hyper.json` — Hiperextensión inversa en banco: pelvis apoyada y piernas ascienden mediante extensión de cadera.
- `exv2_band_pullup.json` — Dominadas asistidas con banda anclada a barra superior y extendida hasta el pie de apoyo.
- `exv2_slider_leg_curl.json` — Curl femoral con deslizadores: tumbado supino, eleva caderas y acerca talones con deslizamiento.
- `exv2_landmine_row.json` — Remo landmine bilateral: bisagra de cadera y tirón del manillar desde abajo hacia torso.
- `ex_peck_deck.json` — Pec deck: brazos apoyados en almohadillas, convergen delante del pecho sin extender codos.
- `ex_v_bar_pushdown.json` — Tríceps con manillar V en polea alta: codos pegados al torso y extensión de antebrazos.
- `ex_low_pulley_curl.json` — Curl en polea baja: codos casi inmóviles, manos suben y barra mantiene tensión de cable.
- `ex_t_bar_row.json` — Remo con barra T: tronco inclinado, escápulas estables y extremos cargados ascienden hacia abdomen.
- `ex_machine_lateral_raises.json` — Elevación lateral en máquina sentado: almohadillas empujadas por codos sin subir trapecios.

La validez del JSON y las comprobaciones automatizadas **no sustituyen una revisión técnica del movimiento**; cada recurso continúa con `approved: false` hasta inspección biomecánica, revisión visual y pruebas físicas.

## Lote 3 — primeras 20 composiciones en borrador (iOS/Android)

Se crearon 20 representaciones vectoriales diferentes para los primeros 20 IDs del lote 3. Cada una describe su equipo, postura y recorrido, pero **su técnica aún no ha sido aprobada por revisión biomecánica ni por inspección física**. Por ello no se distribuye ninguna en `pubspec.yaml` ni se agrega a `approvedMedia`.

- `ex_standing_leg_curl.json` · lateral — Curl femoral de pie: muslo estable, tobillo asciende hacia glúteo sobre rodillo.
- `exv2_bayesian_curl.json` · lateral — Curl bayesiano unilateral: cable bajo por detrás, flexión de codo sin balancear.
- `exv2_cable_glute_kickback.json` · lateral — Patada de glúteo polea baja: cadera extiende pierna hacia atrás y tronco queda fijo.
- `exv2_hanging_knee_raise.json` · frontal — Elevación de rodillas colgado: ambas rodillas se acercan al abdomen.
- `exv2_lean_away_lateral_raise.json` · frontal — Elevación lateral inclinada: brazo libre eleva carga lateral con polea.
- `exv2_decline_db_press.json` · lateral — Press declinado con mancuernas: cabeza baja, dos cargas ascienden desde pecho.
- `exv2_horizontal_leg_press.json` · lateral — Prensa horizontal: rodillas extienden empujando plataforma vertical.
- `exv2_single_leg_db_calf.json` · frontal — Gemelo unilateral con mancuerna: talón asciende sobre step con antepié apoyado.
- `exv2_barbell_shrug.json` · frontal — Encogimiento con barra: hombros se elevan sin flexionar brazos.
- `exv2_hammer_pronation.json` · frontal — Pronación de antebrazo con martillo: mano gira con codo fijo en mesa.
- `exv2_good_morning.json` · lateral — Buenos días con barra: bisagra de cadera e inclinación de torso.
- `exv2_wide_pulldown.json` · frontal — Jalón al pecho con agarre amplio: barra desciende delante de la cabeza.
- `exv2_cable_leg_curl.json` · lateral — Curl femoral de pie polea: tobillera conectada a cable bajo.
- `exv2_low_cable_single_arm_row.json` · lateral — Remo unilateral sentado a polea baja: codo retrocede con torso estable.
- `ex_hammer_press.json` · lateral — Press Hammer de pecho: palanca guiada empuja manillar al frente.
- `ex_french_press.json` · lateral — Press francés tumbado: codos flexionan y barra EZ desciende cerca de cabeza.
- `ex_unilateral_scott_hammer.json` · lateral — Curl martillo Scott unilateral: brazo sobre banco predicador.
- `ex_neutral_pulldown.json` · frontal — Jalón al pecho agarre neutro: manillares paralelos descienden delante de torso.
- `ex_cable_rear_delt.json` · frontal — Apertura posterior en polea: codos casi extendidos abren brazos hacia lados.
- `exv2_incline_alternating_curl.json` · lateral — Curl alterno inclinado: un antebrazo se flexiona con espalda sobre banco.

Estado actual de Fase 4: **140 borradores / 229 objetivos; 0 aprobados**. La licencia y revisión editorial de cada ilustración se deben registrar antes de su aprobación.

## Lote 3 — siguientes 20 composiciones en borrador (40/70)

Segundo grupo de variantes propias del tercer lote; la postura, el equipo y la trayectoria están descritos en cada composición, pero **no constituyen demostraciones aprobadas**. Cada dibujo requiere revisión visual, biomecánica, derechos, y pruebas de reproducción en iOS y Android antes de incluirse en el paquete final.

- `exv2_machine_glute_kickback.json` · lateral — Patada de glúteo guiada en máquina con tronco apoyado y pierna que retrocede.
- `exv2_captains_chair_raise.json` · frontal — Elevación de rodillas con antebrazos en silla romana y torso estable.
- `exv2_behind_body_cable_lateral.json` · frontal — Elevación lateral unilateral con cable desde detrás del cuerpo.
- `exv2_incline_pushup.json` · lateral — Flexiones con manos sobre banco elevado y plancha corporal.
- `exv2_unilateral_leg_press.json` · lateral — Prensa de piernas con un solo pie empujando plataforma horizontal.
- `exv2_leg_press_calf_raise.json` · lateral — Gemelos en prensa con rodillas estables y movimiento de tobillos.
- `exv2_db_shrug.json` · frontal — Encogimientos escapulares con dos mancuernas y brazos extendidos.
- `exv2_hammer_supination.json` · frontal — Supinación de antebrazo con martillo y codo apoyado.
- `exv2_single_leg_rdl.json` · lateral — Peso muerto rumano unilateral con bisagra de cadera y pierna posterior extendida.
- `exv2_supine_pulldown.json` · frontal — Jalón al pecho con agarre supino cerrado, barra delante de la cara.
- `exv2_lying_leg_curl_unilateral.json` · lateral — Curl femoral unilateral en banco prono con rodillo tobillo.
- `exv2_inverted_row.json` · lateral — Remo invertido con talones apoyados y pecho asciende a barra.
- `ex_high_pulley_fly.json` · frontal — Aperturas para pecho con poleas altas y cierre convergente.
- `ex_machine_dips.json` · frontal — Fondos en máquina sentada, palancas empujadas por extensión de codos.
- `exv2_standing_cable_curl.json` · frontal — Curl con barra recta en polea baja y codos estables.
- `exv2_stepback_cable_glute.json` · lateral — Extensión de cadera con polea y paso atrás de una pierna.
- `exv2_decline_crunch.json` · lateral — Crunch en banco declinado, pies sujetos y flexión abdominal.
- `exv2_front_plate_raise.json` · lateral — Elevación frontal de disco hasta la altura del hombro.
- `exv2_decline_pushup.json` · lateral — Flexiones con pies sobre banco elevado y manos ancladas en suelo.
- `exv2_step_up.json` · lateral — Subida a banco con mancuernas apoyando pie entero sobre step.

## Lote 3 completo — 70/70 borradores vectoriales para móvil

Se produjeron las últimas 30 composiciones del lote 3, una por cada ID estable. Las posturas, las herramientas y los movimientos se modelaron por variante, incluidas las posiciones isométricas (suspensión pasiva y pinza de discos), donde el bucle representa cambios sutiles en vez de una repetición inexistente. **No es una aprobación técnica:** el cumplimiento biomecánico, claridad visual, derechos documentados y ensayos físicos siguen pendientes.

- `exv2_donkey_calf_raise.json` · lateral — Gemelo tipo burro con cadera flexionada y talón en ascenso.
- `exv2_cable_shrug.json` · frontal — Encogimiento de hombros con cable bajo y codos extendidos.
- `exv2_farmer_carry.json` · frontal — Paseo del granjero con cargas bilaterales y marcha controlada.
- `exv2_smith_rdl.json` · lateral — Bisagra de cadera con barra Smith próxima a tibias.
- `exv2_straight_arm_pulldown.json` · lateral — Jalón de brazos casi rectos desde polea alta hacia muslos.
- `exv2_seated_leg_curl_unilateral.json` · lateral — Curl de isquios sentado con una sola tibia activa.
- `exv2_high_cable_curl.json` · frontal — Curl de bíceps bilateral con poleas altas.
- `exv2_frog_pumps.json` · lateral — Puente de glúteos en suelo con plantas juntas y rodillas abiertas.
- `exv2_weighted_crunch.json` · lateral — Crunch supino con disco en pecho y pelvis fija.
- `exv2_front_cable_raise.json` · lateral — Elevación frontal a una mano desde polea baja.
- `exv2_flat_db_fly.json` · lateral — Aperturas en banco plano con mancuernas y codos suaves.
- `exv2_reverse_lunge.json` · lateral — Zancada atrás con mancuernas y torso alto.
- `exv2_bent_knee_calf_raise.json` · lateral — Gemelo con rodilla flexionada y talón que asciende.
- `exv2_prone_y_raise.json` · frontal — Elevación de brazos en Y sobre banco inclinado.
- `exv2_dead_hang.json` · frontal — Suspensión pasiva isométrica con manos ancladas a barra.
- `exv2_stiff_leg_deadlift.json` · lateral — Peso muerto de piernas semirrígidas con espalda neutra.
- `exv2_machine_pullover.json` · lateral — Pullover en máquina sentado con trayectoria guiada del hombro.
- `exv2_concentration_curl.json` · frontal — Curl de concentración con codo apoyado en muslo.
- `exv2_side_lying_hip_abduction.json` · frontal — Abducción de pierna superior acostado de lado.
- `exv2_dead_bug.json` · frontal — Dead bug con extensiones contralaterales y pelvis estable.
- `exv2_incline_rear_delt_fly.json` · frontal — Aperturas de deltoides posterior sobre banco inclinado.
- `exv2_low_to_high_fly.json` · frontal — Aperturas en polea baja hacia pecho superior.
- `exv2_walking_lunge.json` · lateral — Zancadas caminando con mancuernas y paso alterno.
- `exv2_single_leg_seated_calf.json` · lateral — Elevación unilateral de sóleo sentado con rodilla flexionada.
- `exv2_prone_t_raise.json` · frontal — Elevación de brazos en T sobre banco inclinado.
- `exv2_plate_pinch.json` · frontal — Sujeción isométrica de disco mediante pinza de dedos.
- `exv2_sumo_deadlift.json` · frontal — Peso muerto sumo con pies abiertos y barra próxima al cuerpo.
- `exv2_db_pullover.json` · lateral — Pullover tumbado con mancuerna desde atrás de cabeza.
- `exv2_supinated_single_cable_curl.json` · lateral — Curl unilateral supino en polea baja.
- `exv2_cable_hip_abduction.json` · frontal — Abducción unilateral de cadera con cable bajo en tobillo.

**Estado acumulado:** 229/229 composiciones en borrador (100 % de cobertura documental, 0 aprobadas). El lote 4 está creado, pendiente de validación técnica. `approvedMedia` sigue vacío y estos assets no se distribuyen en `pubspec.yaml`.

## Lote 4 completo — 59/59 borradores exclusivos de iOS/Android

Los 59 presets finales ahora tienen un JSON Lottie vectorial original específico del ejercicio: coordenadas y trayectorias independientes, equipos y posiciones de partida adaptados. Cada recurso usa lienzo 512 × 512, 30 fps, 90 cuadros, sin imágenes internas, sin GIF y bucle retornando al cuadro inicial. Las posturas estáticas representan como máximo respiración o pequeños ajustes, no repeticiones inexistentes.

**Advertencia de calidad:** son ilustraciones vectoriales programáticas **en fase de borrador**; pasar un decodificador o tener distinta geometría **no demuestra** biomecánica correcta, claridad comparable a video ni aceptación comercial. Cada una requiere examen biomecánico individual, comprobación visual de posturas/equipo, derechos de distribución, pruebas en iPhone y Android, accesibilidad, reducción de movimiento y fallback offline. Ningún asset está autorizado para publicación ni añadido al bundle de Flutter.

- `exv2_bird_dog.json` · lateral — Bird dog cuadrupedia (borrador sin aprobar).
- `exv2_bent_over_rear_delt_raise.json` · lateral — Elevación posterior inclinado de pie (borrador sin aprobar).
- `exv2_mid_cable_fly.json` · frontal — Aperturas en polea a altura media (borrador sin aprobar).
- `exv2_sissy_squat_assisted.json` · lateral — Sentadilla sissy asistida (borrador sin aprobar).
- `exv2_tibialis_wall_raise.json` · lateral — Elevación de puntas contra pared (borrador sin aprobar).
- `exv2_wall_slide.json` · frontal — Deslizamiento de brazos en pared (borrador sin aprobar).
- `exv2_suitcase_carry.json` · frontal — Paseo con peso a un lado (borrador sin aprobar).
- `exv2_kettlebell_swing.json` · lateral — Balanceo de pesa rusa (borrador sin aprobar).
- `exv2_neutral_machine_pulldown.json` · frontal — Jalón neutro convergente en máquina (borrador sin aprobar).
- `exv2_cross_body_hammer_curl.json` · frontal — Curl martillo cruzado (borrador sin aprobar).
- `exv2_band_lateral_walk.json` · frontal — Caminata lateral con minibanda (borrador sin aprobar).
- `exv2_hollow_hold.json` · lateral — Hollow hold (borrador sin aprobar).
- `exv2_wide_rope_face_pull.json` · frontal — Face pull con cuerda y rotación externa (borrador sin aprobar).
- `exv2_unilateral_cable_press.json` · lateral — Press de pecho unilateral en polea (borrador sin aprobar).
- `exv2_spanish_squat.json` · lateral — Sentadilla española con banda (borrador sin aprobar).
- `exv2_tibialis_machine.json` · lateral — Tibial anterior en máquina (borrador sin aprobar).
- `exv2_serratus_punch.json` · lateral — Golpe de serrato con mancuerna tumbado (borrador sin aprobar).
- `exv2_reverse_ez_curl.json` · frontal — Curl inverso con barra EZ (borrador sin aprobar).
- `exv2_monster_walk.json` · frontal — Caminata diagonal con minibanda (borrador sin aprobar).
- `exv2_ab_wheel_rollout.json` · lateral — Rueda abdominal desde rodillas (borrador sin aprobar).
- `exv2_cable_external_rotation.json` · frontal — Rotación externa de hombro en polea (borrador sin aprobar).
- `exv2_close_grip_bench.json` · lateral — Press banca agarre cerrado (borrador sin aprobar).
- `exv2_leg_extension_unilateral.json` · lateral — Extensión de cuádriceps unilateral (borrador sin aprobar).
- `exv2_band_dorsiflexion.json` · lateral — Dorsiflexión con banda elástica (borrador sin aprobar).
- `exv2_serratus_cable_punch.json` · lateral — Empuje de serrato unilateral en polea (borrador sin aprobar).
- `exv2_preacher_hammer_curl.json` · lateral — Curl martillo Scott bilateral (borrador sin aprobar).
- `exv2_standing_machine_abduction.json` · frontal — Abducción de cadera de pie en máquina (borrador sin aprobar).
- `exv2_forearm_plank.json` · lateral — Plancha sobre antebrazos (borrador sin aprobar).
- `exv2_band_external_rotation.json` · frontal — Rotación externa con banda (borrador sin aprobar).
- `exv2_diamond_pushup.json` · lateral — Flexión diamante (borrador sin aprobar).
- `exv2_sumo_goblet_squat.json` · frontal — Sentadilla sumo con mancuerna (borrador sin aprobar).
- `exv2_straight_bar_pushdown.json` · frontal — Extensión tríceps con barra recta (borrador sin aprobar).
- `exv2_clamshell.json` · lateral — Clamshell con minibanda (borrador sin aprobar).
- `exv2_high_plank.json` · lateral — Plancha alta (borrador sin aprobar).
- `exv2_side_lying_external_rotation.json` · lateral — Rotación externa tumbado de lado (borrador sin aprobar).
- `exv2_reverse_grip_pushdown.json` · frontal — Extensión tríceps agarre supino en polea (borrador sin aprobar).
- `exv2_cable_hip_adduction.json` · frontal — Aducción unilateral de cadera en polea (borrador sin aprobar).
- `exv2_band_pallof.json` · frontal — Press Pallof con banda (borrador sin aprobar).
- `exv2_cable_internal_rotation.json` · frontal — Rotación interna de hombro en polea (borrador sin aprobar).
- `exv2_single_arm_pushdown.json` · lateral — Extensión tríceps unilateral en polea (borrador sin aprobar).
- `exv2_side_lying_adduction.json` · lateral — Aducción lateral acostado (borrador sin aprobar).
- `exv2_side_plank.json` · lateral — Plancha lateral (borrador sin aprobar).
- `exv2_band_internal_rotation.json` · frontal — Rotación interna con banda (borrador sin aprobar).
- `exv2_overhead_rope_triceps.json` · lateral — Extensión tríceps sobre cabeza con cuerda (borrador sin aprobar).
- `exv2_copenhagen_short.json` · lateral — Plancha Copenhagen de palanca corta (borrador sin aprobar).
- `exv2_side_plank_hip_lift.json` · lateral — Elevación de cadera en plancha lateral (borrador sin aprobar).
- `exv2_scaption_raise.json` · frontal — Elevación escapular en plano de escápula (borrador sin aprobar).
- `exv2_one_arm_overhead_cable.json` · lateral — Extensión tríceps overhead unilateral en polea (borrador sin aprobar).
- `exv2_copenhagen_long.json` · lateral — Plancha Copenhagen de palanca larga (borrador sin aprobar).
- `exv2_cable_woodchop_high_low.json` · frontal — Woodchopper en polea alta a baja (borrador sin aprobar).
- `exv2_single_db_overhead_triceps.json` · lateral — Extensión tríceps overhead con mancuerna a una mano (borrador sin aprobar).
- `exv2_standing_cable_knee_drive.json` · lateral — Elevación de rodilla con polea (borrador sin aprobar).
- `exv2_cable_woodchop_low_high.json` · frontal — Woodchopper en polea baja a alta (borrador sin aprobar).
- `exv2_lying_db_triceps.json` · lateral — Press francés tumbado con mancuernas (borrador sin aprobar).
- `exv2_band_marching.json` · frontal — Marcha contra minibanda (borrador sin aprobar).
- `exv2_russian_twist.json` · frontal — Giro ruso sentado sin carga (borrador sin aprobar).
- `exv2_kickback_db.json` · lateral — Patada de tríceps con mancuerna (borrador sin aprobar).
- `exv2_seated_knee_raise.json` · lateral — Elevación de rodillas sentado (borrador sin aprobar).
- `exv2_triceps_machine_extension.json` · lateral — Extensión de tríceps en máquina sentado (borrador sin aprobar).

**Cobertura total de borradores: 229/229. Animaciones aprobadas/distribuidas: 0/229.**

## Reglas para detener una animación antes de aprobarla

- El dibujo no refleja correctamente el ejercicio, la trayectoria o su equipo.
- El movimiento se confunde con otra variante, independientemente de compartir rig.
- El JSON es demasiado pesado por imágenes internas o produce problemas de rendimiento.
- Faltan derechos de distribución comercial o un autor/atribución verificable.
- No funciona pausa, `reduceMotion`, fallback offline o el texto técnico equivalente.
- La animación se está incorporando a `apps/app_web` por error.

## Estado y seguimiento

- **Producción actual:** 229 borradores de 229 objetivos (40 + 60 + 70 + 59), 0 pendientes de creación; 0 Lotties aprobados o distribuidos.
- **Hitos de borradores:** 10/40, 20/40 y 40/40 alcanzados para el lote 1. **El lote 1 está completo solo como borrador**, no como recurso listo para la app. **El lote 2 tiene 60/60 borradores terminados** y **el lote 3 tiene 70/70 y el lote 4 tiene 59/59 borradores terminados** y continúa pendiente la revisión visual/biomecánica de cada composición. Restan revisión biomecánica/visual, derechos, ensayos de reproducción, accesibilidad y aprobación antes de empaquetar. No confundir un JSON existente con una animación lista para distribuir.
- **Restricción permanente de alcance:** `apps/app_mobile` iOS/Android únicamente, ningún cambio multimedia a `apps/app_web`.
