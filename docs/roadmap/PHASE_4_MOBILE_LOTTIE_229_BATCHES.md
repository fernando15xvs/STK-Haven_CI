# STK Haven — Plan de producción Lottie 229/229 (exclusivo iOS y Android)

**Fecha:** 18 de octubre de 2026  
**Estado:** cobertura fijada. **Borradores vectoriales originales: 10/229 (10/40 del lote 1); aprobados y distribuidos: 0/229.**

## Plataforma y alcance (decisión del usuario)

- **iOS y Android solamente:** reproducir animaciones mediante `apps/app_mobile` y el paquete `lottie` ya integrado en Flutter.
- **Web excluida:** no añadir Lottie, animaciones, pantallas multimedia, `pubspec` ni assets a `apps/app_web`. Los datos comunes de ejercicios del paquete `core` no son una autorización para renderizar Lottie en web.
- **229 IDs exactos y estables:** los 49 ejercicios `ex_*` y los 180 `exv2_*`, cada uno **una animación propia**. Un rig compartido no implica usar un JSON incorrecto para variantes de equipo o posición.
- **Sin GIFs:** Lottie JSON vectorial de primera elección. Si la técnica no puede representarse correctamente en vector, revisar caso por caso una alternativa optimizada **solo móvil**.
- **Sin cambios de historial:** ni modelos persistidos, series, PRs, rutinas, favoritos ni respaldos deben alterarse para incorporar recursos.
- **No confundir plan con implementación:** los nombres de archivos son destinos previstos, no archivos ya creados. Ninguna fila está aprobada y `approvedMedia` seguirá vacío hasta existir material válido.

## Inicio de producción — primer hito de 10 borradores

Diez composiciones Lottie JSON vectoriales **originales y distintas** en `apps/app_mobile/assets/exercise_media/lottie/` (solo iOS/Android):

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

Todas incluyen keyframes de movimiento sin imágenes raster incrustadas, identificador propio y vista específica. Son **borradores de producción, no demostraciones biomecánicas aprobadas**. Revisar perspectiva, postura, agarre, recorrido, coherencia de equipo, visualización real en dispositivos y accesibilidad.

El manifiesto registra exactamente 10 `draft` con `approved: false` y 219 `pending`. `approvedMedia` permanece vacío, y la carpeta de animaciones **no** está declarada como recurso en `pubspec.yaml`: ninguna se distribuye todavía a usuarios. Las pruebas físicas siguen reservadas al cierre del roadmap, pero ninguna será aprobada sin revisión técnica y tests oportunos.

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
| 1 · movimientos esenciales | 40 | 40/229 | iOS + Android | 10 borradores, 0 aprobados |
| 2 · variantes frecuentes | 60 | 100/229 | iOS + Android | 0 aprobados |
| 3 · ampliación anatómica | 70 | 170/229 | iOS + Android | 0 aprobados |
| 4 · restantes y cobertura completa | 59 | 229/229 | iOS + Android | 0 aprobados |

### Lote 1 — 40 ejercicios

- [ ] 01. `ex_bench_press` — Press de Banca · **borrador Lottie (sin aprobación)**
- [ ] 02. `ex_incline_db_press` — Press Inclinado c/M · **borrador Lottie (sin aprobación)**
- [ ] 03. `exv2_flat_db_press` — Press plano con mancuernas · **borrador Lottie (sin aprobación)**
- [ ] 04. `exv2_incline_barbell_press` — Press inclinado con barra 30°
- [ ] 05. `exv2_flat_machine_press` — Press horizontal guiado en máquina
- [ ] 06. `exv2_pushup` — Flexiones de brazos
- [ ] 07. `ex_lat_pulldown` — Jalón al Pecho · **borrador Lottie (sin aprobación)**
- [ ] 08. `ex_pullups` — Dominadas · **borrador Lottie (sin aprobación)**
- [ ] 09. `ex_barbell_row` — Remo con Barra · **borrador Lottie (sin aprobación)**
- [ ] 10. `ex_cable_row` — Remo en Polea Baja · **borrador Lottie (sin aprobación)**
- [ ] 11. `exv2_single_arm_pulldown` — Jalón unilateral de rodillas
- [ ] 12. `exv2_chest_supported_db_row` — Remo con apoyo de pecho y mancuernas
- [ ] 13. `exv2_single_arm_db_row` — Remo unilateral con mancuerna en banco
- [ ] 14. `ex_face_pull` — Face Pull
- [ ] 15. `ex_ohp` — Press Militar · **borrador Lottie (sin aprobación)**
- [ ] 16. `ex_lateral_raises` — Elevaciones Laterales · **borrador Lottie (sin aprobación)**
- [ ] 17. `exv2_arnold_press` — Press Arnold con mancuernas
- [ ] 18. `exv2_seated_db_lateral_raise` — Elevación lateral sentado
- [ ] 19. `exv2_single_arm_rear_cable_fly` — Elevación posterior unilateral en polea
- [ ] 20. `exv2_scapular_pushup` — Flexiones escapulares
- [ ] 21. `ex_barbell_curl` — Curl con Barra
- [ ] 22. `ex_hammer_curl` — Curl Martillo
- [ ] 23. `ex_tricep_pushdown` — Extensiones de Tríceps
- [ ] 24. `exv2_ez_bar_curl` — Curl con barra EZ
- [ ] 25. `exv2_rope_pushdown` — Extensión tríceps con cuerda en polea
- [ ] 26. `exv2_rope_hammer_curl` — Curl martillo con cuerda
- [ ] 27. `ex_squat` — Sentadilla Libre · **borrador Lottie (sin aprobación)**
- [ ] 28. `ex_leg_press` — Prensa Inclinada
- [ ] 29. `ex_leg_extension` — Extensiones de Cuádriceps
- [ ] 30. `ex_leg_curl` — Curl Femoral
- [ ] 31. `ex_hip_thrust` — Hip Thrust
- [ ] 32. `ex_rdl` — Peso Muerto Rumano
- [ ] 33. `exv2_front_squat` — Sentadilla frontal con barra
- [ ] 34. `exv2_goblet_squat` — Sentadilla goblet
- [ ] 35. `exv2_db_rdl` — Peso muerto rumano con mancuernas
- [ ] 36. `exv2_machine_hip_thrust` — Hip thrust en máquina
- [ ] 37. `exv2_nordic_curl` — Curl nórdico asistido
- [ ] 38. `ex_calf_raise` — Elevación de Gemelos
- [ ] 39. `ex_crunch` — Crunches
- [ ] 40. `exv2_pallof_press` — Press Pallof en polea

### Lote 2 — 60 ejercicios

- [ ] 01. `exv2_preacher_bar_curl` — Curl Scott con barra EZ
- [ ] 02. `exv2_barbell_glute_bridge` — Puente de glúteos con barra desde el suelo
- [ ] 03. `exv2_cable_crunch` — Crunch abdominal arrodillado en polea
- [ ] 04. `exv2_seated_barbell_ohp` — Press militar sentado con barra
- [ ] 05. `exv2_incline_smith_press` — Press inclinado en Smith
- [ ] 06. `exv2_smith_squat` — Sentadilla en Smith
- [ ] 07. `exv2_standing_calf_raise` — Gemelos de pie en máquina
- [ ] 08. `exv2_band_pull_apart` — Aperturas de banda a la altura del pecho
- [ ] 09. `exv2_wrist_curl_seated` — Curl de muñeca supino sentado
- [ ] 10. `exv2_roman_chair_back_extension` — Extensiones de espalda en banco romano
- [ ] 11. `exv2_chinup` — Dominadas supinas
- [ ] 12. `exv2_glute_ham_raise` — Elevación glúteo-isquios en banco GHD
- [ ] 13. `exv2_chest_supported_machine_row` — Remo convergente con apoyo de pecho
- [ ] 14. `ex_chest_flyes` — Aperturas en Máquina
- [ ] 15. `ex_overhead_tricep` — Extensión Sobre la Cabeza
- [ ] 16. `ex_db_curl` — Curl Alterno c/M
- [ ] 17. `ex_kelso_shrugs` — Kelso Shrugs
- [ ] 18. `ex_db_shoulder_press` — Press de Hombros c/M
- [ ] 19. `ex_lying_leg_curl` — Curl Femoral Acostado
- [ ] 20. `ex_bulgarian_split_squat` — Sentadilla Búlgara
- [ ] 21. `ex_abductor` — Abductor en Máquina
- [ ] 22. `ex_adductor` — Aductor en Máquina
- [ ] 23. `exv2_preacher_machine_curl` — Curl Scott en máquina
- [ ] 24. `exv2_smith_hip_thrust` — Hip thrust en Smith
- [ ] 25. `exv2_machine_crunch` — Crunch sentado en máquina
- [ ] 26. `exv2_landmine_shoulder_press` — Press de hombro en landmine
- [ ] 27. `exv2_incline_machine_press` — Press inclinado convergente en máquina
- [ ] 28. `exv2_hack_squat` — Sentadilla hack en máquina
- [ ] 29. `exv2_seated_calf_raise` — Sóleo sentado en máquina
- [ ] 30. `exv2_scapular_row` — Remo escapular con pecho apoyado
- [ ] 31. `exv2_reverse_wrist_curl` — Curl inverso de muñeca sentado
- [ ] 32. `exv2_cable_pullthrough` — Pull through en polea
- [ ] 33. `exv2_assisted_pullup` — Dominadas asistidas en máquina
- [ ] 34. `exv2_swiss_ball_leg_curl` — Curl femoral con fitball
- [ ] 35. `exv2_meadows_row` — Remo Meadows a un brazo
- [ ] 36. `ex_cable_crossover` — Cruces en Polea
- [ ] 37. `ex_dips` — Fondos en Paralelas
- [ ] 38. `ex_incline_db_curl` — Curl Inclinado 65°
- [ ] 39. `ex_machine_unilateral_row` — Remo Unilateral Máquina
- [ ] 40. `ex_reverse_pec_deck` — Pájaros en Máquina
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

## Reglas para detener una animación antes de aprobarla

- El dibujo no refleja correctamente el ejercicio, la trayectoria o su equipo.
- El movimiento se confunde con otra variante, independientemente de compartir rig.
- El JSON es demasiado pesado por imágenes internas o produce problemas de rendimiento.
- Faltan derechos de distribución comercial o un autor/atribución verificable.
- No funciona pausa, `reduceMotion`, fallback offline o el texto técnico equivalente.
- La animación se está incorporando a `apps/app_web` por error.

## Estado y seguimiento

- **Producción actual:** 0 Lotties listos; 229 programados.
- **Primer hito:** producir y revisar 10 de los 40 del lote 1, luego 20 y finalmente 40; no marcar un lote como finalizado con recursos falsos.
- **Restricción permanente de alcance:** `apps/app_mobile` iOS/Android únicamente, ningún cambio multimedia a `apps/app_web`.
