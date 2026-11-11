# STK Haven — Plan cerrado de 229 animaciones Lottie (solo iOS y Android)

**Alcance:** `apps/app_mobile` para Android e iOS. **Queda expresamente excluida `apps/app_web`: no agregar dependencias, assets, rutas, interfaces ni loaders de Lottie en la web.**

**Estado real al redactar:** 229 ejercicios registrados, componente Flutter `Lottie.asset` disponible en la app móvil, **0/229 archivos Lottie terminados o integrados**. Este documento es planificación de producción, no evidencia de animaciones existentes.

## Convención y requisitos

- Una animación por `Exercise.id`, con archivo `assets/exercise_media/lottie/<exerciseId>.json` dentro de `apps/app_mobile/`. Los `ex_*` históricos nunca se renombran; `exv2_*` quedan invariables.
- Preferencia: Lottie JSON vectorial, arte original o licenciado para redistribución comercial. Sin GIFs. Si una mecánica no puede ilustrarse fielmente con Lottie, revisar caso antes de producir vídeo corto optimizado **solo móvil**.
- Para cada ID documentar equipo, variante, agarre, bilateral/unilateral, postura, plano de cámara y trayectoria; **no reutilizar un rig con una ejecución incorrecta**. El rig es una base de diseño, no un sustituto de revisión por ejercicio.
- Recomendación editorial: 3–5 segundos, 1–2 repeticiones en bucle, sin fondo pesado ni textos incrustados. Son objetivos de diseño, no resultados medidos. Mantener archivos sin bitmaps embebidos cuando sea posible.
- Soportar pausa/reanudar, reducción de movimiento, modo ahorro, fallo de asset y guía técnica alternativa accesible; no iniciar 229 animaciones simultáneas ni precargarlas al splash.
- La animación se habilita en `approvedMedia` **solo después** de existir el JSON en repo, validar biomecánica, registrar autor y derechos, declarar asset en el `pubspec.yaml` de la app móvil y pasar tests. Un asset pendiente nunca se marca completado.
- Antes de producción: medir tamaño de app, memoria, FPS, CPU y consumo en Android/iOS en QA final. No se modificarán datos históricos, series, récords o rutinas.

## Sistema de rigs compartidos (bases reutilizables, variantes revisadas)

1. Empuje horizontal y aperturas de pecho
2. Empuje vertical, elevaciones y rotaciones de hombro
3. Tracción vertical (jalones, dominadas y pullover)
4. Tracción horizontal (remo con máquina, barra, mancuernas y control escapular)
5. Flexión y extensión de codo / antebrazos
6. Sentadilla, zancada y dominancia de rodilla
7. Bisagra y extensión de cadera
8. Curl de rodilla, aductores/abductores y glúteo medio
9. Tobillo, sóleo, gemelos y tibial anterior
10. Flexión de tronco, antirotación, planchas y estabilidad / serrato

El enfoque de rig no autoriza reutilizar la misma animación para variantes materialmente distintas. Cada JSON final conserva su `exerciseId`.

## Proceso por lotes y puertas de calidad

| Lote | Ejercicios | Acumulado | Criterio de liberación |
|---|---:|---:|---|
| 1 — Básicos frecuentes | 40 | 40/229 | Primeros recursos originales, guías sincronizadas y reproducción móvil |
| 2 — Comunes y presets históricos restantes | 60 | 100/229 | Variantes adicionales con equipo y unilateralidad verificados |
| 3 — Variantes y grupos musculares ampliados | 70 | 170/229 | Familias de patrones, movilidad y control escapular correctamente ilustradas |
| 4 — Especializados y cierre | 59 | 229/229 | Cobertura completa y checklist de coincidencia de todos los IDs |

**Estados permitidos:** pendiente → dibujo/rig → revisión técnica → revisión de derechos → optimización → integrado en móvil → tests automáticos → QA físico final. El conteo «integrados» empieza en cero.

## Lote 1 — 40 animaciones

| # | Exercise ID | Ejercicio | Rig/familia | Estado |
|---:|---|---|---|---|
| 1 | `ex_bench_press` | Press de Banca | Histórico | Pendiente |
| 2 | `ex_incline_db_press` | Press Inclinado c/M | Histórico | Pendiente |
| 3 | `exv2_flat_db_press` | Press plano con mancuernas | horizontalPush | Pendiente |
| 4 | `exv2_incline_barbell_press` | Press inclinado con barra 30° | horizontalPush | Pendiente |
| 5 | `exv2_flat_machine_press` | Press horizontal guiado en máquina | horizontalPush | Pendiente |
| 6 | `exv2_pushup` | Flexiones de brazos | horizontalPush | Pendiente |
| 7 | `ex_lat_pulldown` | Jalón al Pecho | Histórico | Pendiente |
| 8 | `ex_pullups` | Dominadas | Histórico | Pendiente |
| 9 | `ex_barbell_row` | Remo con Barra | Histórico | Pendiente |
| 10 | `ex_cable_row` | Remo en Polea Baja | Histórico | Pendiente |
| 11 | `exv2_single_arm_pulldown` | Jalón unilateral de rodillas | verticalPull | Pendiente |
| 12 | `exv2_chest_supported_db_row` | Remo con apoyo de pecho y mancuernas | horizontalPull | Pendiente |
| 13 | `exv2_single_arm_db_row` | Remo unilateral con mancuerna en banco | horizontalPull | Pendiente |
| 14 | `ex_face_pull` | Face Pull | Histórico | Pendiente |
| 15 | `ex_ohp` | Press Militar | Histórico | Pendiente |
| 16 | `ex_lateral_raises` | Elevaciones Laterales | Histórico | Pendiente |
| 17 | `exv2_arnold_press` | Press Arnold con mancuernas | shoulder | Pendiente |
| 18 | `exv2_seated_db_lateral_raise` | Elevación lateral sentado | shoulder | Pendiente |
| 19 | `exv2_single_arm_rear_cable_fly` | Elevación posterior unilateral en polea | shoulder | Pendiente |
| 20 | `exv2_scapular_pushup` | Flexiones escapulares | scapular | Pendiente |
| 21 | `ex_barbell_curl` | Curl con Barra | Histórico | Pendiente |
| 22 | `ex_hammer_curl` | Curl Martillo | Histórico | Pendiente |
| 23 | `ex_tricep_pushdown` | Extensiones de Tríceps | Histórico | Pendiente |
| 24 | `exv2_ez_bar_curl` | Curl con barra EZ | arms | Pendiente |
| 25 | `exv2_rope_pushdown` | Extensión tríceps con cuerda en polea | arms | Pendiente |
| 26 | `exv2_rope_hammer_curl` | Curl martillo con cuerda | arms | Pendiente |
| 27 | `ex_squat` | Sentadilla Libre | Histórico | Pendiente |
| 28 | `ex_leg_press` | Prensa Inclinada | Histórico | Pendiente |
| 29 | `ex_leg_extension` | Extensiones de Cuádriceps | Histórico | Pendiente |
| 30 | `ex_leg_curl` | Curl Femoral | Histórico | Pendiente |
| 31 | `ex_hip_thrust` | Hip Thrust | Histórico | Pendiente |
| 32 | `ex_rdl` | Peso Muerto Rumano | Histórico | Pendiente |
| 33 | `exv2_front_squat` | Sentadilla frontal con barra | squatLunge | Pendiente |
| 34 | `exv2_goblet_squat` | Sentadilla goblet | squatLunge | Pendiente |
| 35 | `exv2_db_rdl` | Peso muerto rumano con mancuernas | hipHinge | Pendiente |
| 36 | `exv2_machine_hip_thrust` | Hip thrust en máquina | hipControl | Pendiente |
| 37 | `exv2_nordic_curl` | Curl nórdico asistido | kneeFlexion | Pendiente |
| 38 | `ex_calf_raise` | Elevación de Gemelos | Histórico | Pendiente |
| 39 | `ex_crunch` | Crunches | Histórico | Pendiente |
| 40 | `exv2_pallof_press` | Press Pallof en polea | core | Pendiente |

## Lote 2 — 60 animaciones

| # | Exercise ID | Ejercicio | Rig/familia | Estado |
|---:|---|---|---|---|
| 1 | `ex_chest_flyes` | Aperturas en Máquina | Histórico | Pendiente |
| 2 | `ex_cable_crossover` | Cruces en Polea | Histórico | Pendiente |
| 3 | `ex_peck_deck` | Peck Deck | Histórico | Pendiente |
| 4 | `ex_hammer_press` | Press Hammer | Histórico | Pendiente |
| 5 | `ex_high_pulley_fly` | Fly en Polea Alta | Histórico | Pendiente |
| 6 | `ex_kelso_shrugs` | Kelso Shrugs | Histórico | Pendiente |
| 7 | `ex_machine_unilateral_row` | Remo Unilateral Máquina | Histórico | Pendiente |
| 8 | `ex_t_bar_row` | Remo en T | Histórico | Pendiente |
| 9 | `ex_neutral_pulldown` | Jalón Pecho Agarre Neutro | Histórico | Pendiente |
| 10 | `ex_db_shoulder_press` | Press de Hombros c/M | Histórico | Pendiente |
| 11 | `ex_reverse_pec_deck` | Pájaros en Máquina | Histórico | Pendiente |
| 12 | `ex_machine_lateral_raises` | Elevaciones Laterales M. | Histórico | Pendiente |
| 13 | `ex_cable_rear_delt` | Elevaciones Posteriores P. | Histórico | Pendiente |
| 14 | `ex_db_curl` | Curl Alterno c/M | Histórico | Pendiente |
| 15 | `ex_incline_db_curl` | Curl Inclinado 65° | Histórico | Pendiente |
| 16 | `ex_low_pulley_curl` | Curl en Polea Baja | Histórico | Pendiente |
| 17 | `ex_unilateral_scott_hammer` | Curl Martillo Scott Uni. | Histórico | Pendiente |
| 18 | `ex_overhead_tricep` | Extensión Sobre la Cabeza | Histórico | Pendiente |
| 19 | `ex_dips` | Fondos en Paralelas | Histórico | Pendiente |
| 20 | `ex_v_bar_pushdown` | Extensiones con Barra V | Histórico | Pendiente |
| 21 | `ex_french_press` | Press Francés | Histórico | Pendiente |
| 22 | `ex_machine_dips` | Fondos en Máquina | Histórico | Pendiente |
| 23 | `ex_bulgarian_split_squat` | Sentadilla Búlgara | Histórico | Pendiente |
| 24 | `ex_pendulum_squat` | Sentadilla Pendular | Histórico | Pendiente |
| 25 | `ex_adductor` | Aductor en Máquina | Histórico | Pendiente |
| 26 | `ex_lying_leg_curl` | Curl Femoral Acostado | Histórico | Pendiente |
| 27 | `ex_seated_leg_curl` | Curl Femoral Sentado | Histórico | Pendiente |
| 28 | `ex_standing_leg_curl` | Curl Femoral Parado | Histórico | Pendiente |
| 29 | `ex_abductor` | Abductor en Máquina | Histórico | Pendiente |
| 30 | `exv2_incline_smith_press` | Press inclinado en Smith | horizontalPush | Pendiente |
| 31 | `exv2_chinup` | Dominadas supinas | verticalPull | Pendiente |
| 32 | `exv2_chest_supported_machine_row` | Remo convergente con apoyo de pecho | horizontalPull | Pendiente |
| 33 | `exv2_band_pull_apart` | Aperturas de banda a la altura del pecho | scapular | Pendiente |
| 34 | `exv2_roman_chair_back_extension` | Extensiones de espalda en banco romano | hipHinge | Pendiente |
| 35 | `exv2_seated_barbell_ohp` | Press militar sentado con barra | shoulder | Pendiente |
| 36 | `exv2_preacher_bar_curl` | Curl Scott con barra EZ | arms | Pendiente |
| 37 | `exv2_wrist_curl_seated` | Curl de muñeca supino sentado | gripCarry | Pendiente |
| 38 | `exv2_smith_squat` | Sentadilla en Smith | squatLunge | Pendiente |
| 39 | `exv2_glute_ham_raise` | Elevación glúteo-isquios en banco GHD | kneeFlexion | Pendiente |
| 40 | `exv2_barbell_glute_bridge` | Puente de glúteos con barra desde el suelo | hipControl | Pendiente |
| 41 | `exv2_standing_calf_raise` | Gemelos de pie en máquina | ankle | Pendiente |
| 42 | `exv2_cable_crunch` | Crunch abdominal arrodillado en polea | core | Pendiente |
| 43 | `exv2_incline_machine_press` | Press inclinado convergente en máquina | horizontalPush | Pendiente |
| 44 | `exv2_assisted_pullup` | Dominadas asistidas en máquina | verticalPull | Pendiente |
| 45 | `exv2_meadows_row` | Remo Meadows a un brazo | horizontalPull | Pendiente |
| 46 | `exv2_scapular_row` | Remo escapular con pecho apoyado | scapular | Pendiente |
| 47 | `exv2_cable_pullthrough` | Pull through en polea | hipHinge | Pendiente |
| 48 | `exv2_landmine_shoulder_press` | Press de hombro en landmine | shoulder | Pendiente |
| 49 | `exv2_preacher_machine_curl` | Curl Scott en máquina | arms | Pendiente |
| 50 | `exv2_reverse_wrist_curl` | Curl inverso de muñeca sentado | gripCarry | Pendiente |
| 51 | `exv2_hack_squat` | Sentadilla hack en máquina | squatLunge | Pendiente |
| 52 | `exv2_swiss_ball_leg_curl` | Curl femoral con fitball | kneeFlexion | Pendiente |
| 53 | `exv2_smith_hip_thrust` | Hip thrust en Smith | hipControl | Pendiente |
| 54 | `exv2_seated_calf_raise` | Sóleo sentado en máquina | ankle | Pendiente |
| 55 | `exv2_machine_crunch` | Crunch sentado en máquina | core | Pendiente |
| 56 | `exv2_decline_barbell_press` | Press declinado con barra | horizontalPush | Pendiente |
| 57 | `exv2_band_pullup` | Dominadas asistidas con banda | verticalPull | Pendiente |
| 58 | `exv2_landmine_row` | Remo landmine bilateral | horizontalPull | Pendiente |
| 59 | `exv2_cable_scapular_retraction` | Retracción escapular en polea | scapular | Pendiente |
| 60 | `exv2_reverse_hyper` | Extensión inversa de cadera en banco | hipHinge | Pendiente |

## Lote 3 — 70 animaciones

| # | Exercise ID | Ejercicio | Rig/familia | Estado |
|---:|---|---|---|---|
| 1 | `exv2_machine_shoulder_press` | Press de hombro en máquina convergente | shoulder | Pendiente |
| 2 | `exv2_spider_curl` | Curl araña con mancuernas | arms | Pendiente |
| 3 | `exv2_wrist_roller` | Rodillo de muñeca | gripCarry | Pendiente |
| 4 | `exv2_belt_squat` | Sentadilla con cinturón lastrado | squatLunge | Pendiente |
| 5 | `exv2_slider_leg_curl` | Curl femoral deslizando talones | kneeFlexion | Pendiente |
| 6 | `exv2_single_leg_hip_thrust` | Hip thrust unilateral | hipControl | Pendiente |
| 7 | `exv2_smith_calf_raise` | Gemelos de pie en Smith | ankle | Pendiente |
| 8 | `exv2_reverse_crunch` | Crunch inverso en colchoneta | core | Pendiente |
| 9 | `exv2_decline_db_press` | Press declinado con mancuernas | horizontalPush | Pendiente |
| 10 | `exv2_wide_pulldown` | Jalón al pecho agarre amplio | verticalPull | Pendiente |
| 11 | `exv2_low_cable_single_arm_row` | Remo sentado unilateral en polea baja | horizontalPull | Pendiente |
| 12 | `exv2_barbell_shrug` | Encogimientos con barra | scapular | Pendiente |
| 13 | `exv2_good_morning` | Buenos días con barra | hipHinge | Pendiente |
| 14 | `exv2_lean_away_lateral_raise` | Elevación lateral inclinado con polea | shoulder | Pendiente |
| 15 | `exv2_bayesian_curl` | Curl bayesiano unilateral en polea | arms | Pendiente |
| 16 | `exv2_hammer_pronation` | Pronación de antebrazo con martillo | gripCarry | Pendiente |
| 17 | `exv2_horizontal_leg_press` | Prensa horizontal en máquina | squatLunge | Pendiente |
| 18 | `exv2_cable_leg_curl` | Curl femoral de pie en polea | kneeFlexion | Pendiente |
| 19 | `exv2_cable_glute_kickback` | Patada de glúteo en polea | hipControl | Pendiente |
| 20 | `exv2_single_leg_db_calf` | Gemelo unilateral con mancuerna | ankle | Pendiente |
| 21 | `exv2_hanging_knee_raise` | Elevación de rodillas colgado | core | Pendiente |
| 22 | `exv2_incline_pushup` | Flexiones con manos elevadas | horizontalPush | Pendiente |
| 23 | `exv2_supine_pulldown` | Jalón supino cerrado | verticalPull | Pendiente |
| 24 | `exv2_inverted_row` | Remo invertido en barra | horizontalPull | Pendiente |
| 25 | `exv2_db_shrug` | Encogimientos con mancuernas | scapular | Pendiente |
| 26 | `exv2_single_leg_rdl` | Peso muerto rumano unilateral | hipHinge | Pendiente |
| 27 | `exv2_behind_body_cable_lateral` | Elevación lateral en polea desde atrás | shoulder | Pendiente |
| 28 | `exv2_incline_alternating_curl` | Curl alterno inclinado en banco | arms | Pendiente |
| 29 | `exv2_hammer_supination` | Supinación de antebrazo con martillo | gripCarry | Pendiente |
| 30 | `exv2_unilateral_leg_press` | Prensa unilateral | squatLunge | Pendiente |
| 31 | `exv2_lying_leg_curl_unilateral` | Curl femoral acostado unilateral | kneeFlexion | Pendiente |
| 32 | `exv2_machine_glute_kickback` | Patada de glúteo en máquina | hipControl | Pendiente |
| 33 | `exv2_leg_press_calf_raise` | Gemelos en prensa | ankle | Pendiente |
| 34 | `exv2_captains_chair_raise` | Elevación de rodillas en silla romana | core | Pendiente |
| 35 | `exv2_decline_pushup` | Flexiones con pies elevados | horizontalPush | Pendiente |
| 36 | `exv2_straight_arm_pulldown` | Pullover de pie con brazos rectos | verticalPull | Pendiente |
| 37 | `exv2_cable_shrug` | Encogimientos en polea baja | scapular | Pendiente |
| 38 | `exv2_smith_rdl` | Peso muerto rumano en Smith | hipHinge | Pendiente |
| 39 | `exv2_front_plate_raise` | Elevación frontal con disco | shoulder | Pendiente |
| 40 | `exv2_standing_cable_curl` | Curl de bíceps con barra en polea | arms | Pendiente |
| 41 | `exv2_farmer_carry` | Paseo del granjero con mancuernas | gripCarry | Pendiente |
| 42 | `exv2_step_up` | Subida a banco con mancuernas | squatLunge | Pendiente |
| 43 | `exv2_seated_leg_curl_unilateral` | Curl femoral sentado unilateral | kneeFlexion | Pendiente |
| 44 | `exv2_stepback_cable_glute` | Extensión de cadera de pie con polea | hipControl | Pendiente |
| 45 | `exv2_donkey_calf_raise` | Elevaciones de talón tipo burro | ankle | Pendiente |
| 46 | `exv2_decline_crunch` | Crunch en banco declinado | core | Pendiente |
| 47 | `exv2_flat_db_fly` | Aperturas planas con mancuernas | horizontalPush | Pendiente |
| 48 | `exv2_machine_pullover` | Pullover en máquina | verticalPull | Pendiente |
| 49 | `exv2_prone_y_raise` | Elevación en Y sobre banco inclinado | scapular | Pendiente |
| 50 | `exv2_stiff_leg_deadlift` | Peso muerto piernas semirrígidas | hipHinge | Pendiente |
| 51 | `exv2_front_cable_raise` | Elevación frontal unilateral en polea | shoulder | Pendiente |
| 52 | `exv2_high_cable_curl` | Curl de bíceps doble polea alta | arms | Pendiente |
| 53 | `exv2_dead_hang` | Suspensión pasiva de barra | gripCarry | Pendiente |
| 54 | `exv2_reverse_lunge` | Zancada hacia atrás con mancuernas | squatLunge | Pendiente |
| 55 | `exv2_frog_pumps` | Puentes de glúteo con plantas juntas | hipControl | Pendiente |
| 56 | `exv2_bent_knee_calf_raise` | Gemelos con rodillas flexionadas | ankle | Pendiente |
| 57 | `exv2_weighted_crunch` | Crunch con disco sobre pecho | core | Pendiente |
| 58 | `exv2_low_to_high_fly` | Aperturas en polea de abajo arriba | horizontalPush | Pendiente |
| 59 | `exv2_db_pullover` | Pullover con mancuerna | verticalPull | Pendiente |
| 60 | `exv2_prone_t_raise` | Elevación en T sobre banco inclinado | scapular | Pendiente |
| 61 | `exv2_sumo_deadlift` | Peso muerto sumo | hipHinge | Pendiente |
| 62 | `exv2_incline_rear_delt_fly` | Pájaros con mancuernas en banco inclinado | shoulder | Pendiente |
| 63 | `exv2_concentration_curl` | Curl concentración sentado | arms | Pendiente |
| 64 | `exv2_plate_pinch` | Pinza de discos | gripCarry | Pendiente |
| 65 | `exv2_walking_lunge` | Zancadas caminando con mancuernas | squatLunge | Pendiente |
| 66 | `exv2_side_lying_hip_abduction` | Abducción de cadera acostado lateral | hipControl | Pendiente |
| 67 | `exv2_single_leg_seated_calf` | Sóleo unilateral sentado | ankle | Pendiente |
| 68 | `exv2_dead_bug` | Dead bug alternando brazos y piernas | core | Pendiente |
| 69 | `exv2_mid_cable_fly` | Aperturas en polea a altura media | horizontalPush | Pendiente |
| 70 | `exv2_neutral_machine_pulldown` | Jalón neutro convergente en máquina | verticalPull | Pendiente |

## Lote 4 — 59 animaciones

| # | Exercise ID | Ejercicio | Rig/familia | Estado |
|---:|---|---|---|---|
| 1 | `exv2_wall_slide` | Deslizamiento de brazos en pared | scapular | Pendiente |
| 2 | `exv2_kettlebell_swing` | Balanceo de pesa rusa | hipHinge | Pendiente |
| 3 | `exv2_bent_over_rear_delt_raise` | Elevación posterior inclinado de pie | shoulder | Pendiente |
| 4 | `exv2_supinated_single_cable_curl` | Curl supino unilateral en polea baja | arms | Pendiente |
| 5 | `exv2_suitcase_carry` | Paseo con peso a un lado | gripCarry | Pendiente |
| 6 | `exv2_sissy_squat_assisted` | Sentadilla sissy asistida | squatLunge | Pendiente |
| 7 | `exv2_cable_hip_abduction` | Abducción unilateral en polea baja | hipControl | Pendiente |
| 8 | `exv2_tibialis_wall_raise` | Elevación de puntas contra pared | ankle | Pendiente |
| 9 | `exv2_bird_dog` | Bird dog cuadrupedia | core | Pendiente |
| 10 | `exv2_unilateral_cable_press` | Press de pecho unilateral en polea | horizontalPush | Pendiente |
| 11 | `exv2_serratus_punch` | Golpe de serrato con mancuerna tumbado | scapular | Pendiente |
| 12 | `exv2_wide_rope_face_pull` | Face pull con cuerda y rotación externa | shoulder | Pendiente |
| 13 | `exv2_cross_body_hammer_curl` | Curl martillo cruzado | arms | Pendiente |
| 14 | `exv2_spanish_squat` | Sentadilla española con banda | squatLunge | Pendiente |
| 15 | `exv2_band_lateral_walk` | Caminata lateral con minibanda | hipControl | Pendiente |
| 16 | `exv2_tibialis_machine` | Tibial anterior en máquina | ankle | Pendiente |
| 17 | `exv2_hollow_hold` | Hollow hold | core | Pendiente |
| 18 | `exv2_close_grip_bench` | Press banca agarre cerrado | horizontalPush | Pendiente |
| 19 | `exv2_serratus_cable_punch` | Empuje de serrato unilateral en polea | scapular | Pendiente |
| 20 | `exv2_cable_external_rotation` | Rotación externa de hombro en polea | shoulder | Pendiente |
| 21 | `exv2_reverse_ez_curl` | Curl inverso con barra EZ | arms | Pendiente |
| 22 | `exv2_leg_extension_unilateral` | Extensión de cuádriceps unilateral | squatLunge | Pendiente |
| 23 | `exv2_monster_walk` | Caminata diagonal con minibanda | hipControl | Pendiente |
| 24 | `exv2_band_dorsiflexion` | Dorsiflexión con banda elástica | ankle | Pendiente |
| 25 | `exv2_ab_wheel_rollout` | Rueda abdominal desde rodillas | core | Pendiente |
| 26 | `exv2_diamond_pushup` | Flexión diamante | horizontalPush | Pendiente |
| 27 | `exv2_band_external_rotation` | Rotación externa con banda | shoulder | Pendiente |
| 28 | `exv2_preacher_hammer_curl` | Curl martillo Scott bilateral | arms | Pendiente |
| 29 | `exv2_sumo_goblet_squat` | Sentadilla sumo con mancuerna | squatLunge | Pendiente |
| 30 | `exv2_standing_machine_abduction` | Abducción de cadera de pie en máquina | hipControl | Pendiente |
| 31 | `exv2_forearm_plank` | Plancha sobre antebrazos | core | Pendiente |
| 32 | `exv2_side_lying_external_rotation` | Rotación externa tumbado de lado | shoulder | Pendiente |
| 33 | `exv2_straight_bar_pushdown` | Extensión tríceps con barra recta | arms | Pendiente |
| 34 | `exv2_clamshell` | Clamshell con minibanda | hipControl | Pendiente |
| 35 | `exv2_high_plank` | Plancha alta | core | Pendiente |
| 36 | `exv2_cable_internal_rotation` | Rotación interna de hombro en polea | shoulder | Pendiente |
| 37 | `exv2_reverse_grip_pushdown` | Extensión tríceps agarre supino en polea | arms | Pendiente |
| 38 | `exv2_cable_hip_adduction` | Aducción unilateral de cadera en polea | hipControl | Pendiente |
| 39 | `exv2_band_pallof` | Press Pallof con banda | core | Pendiente |
| 40 | `exv2_band_internal_rotation` | Rotación interna con banda | shoulder | Pendiente |
| 41 | `exv2_single_arm_pushdown` | Extensión tríceps unilateral en polea | arms | Pendiente |
| 42 | `exv2_side_lying_adduction` | Aducción lateral acostado | hipControl | Pendiente |
| 43 | `exv2_side_plank` | Plancha lateral | core | Pendiente |
| 44 | `exv2_scaption_raise` | Elevación escapular en plano de escápula | shoulder | Pendiente |
| 45 | `exv2_overhead_rope_triceps` | Extensión tríceps sobre cabeza con cuerda | arms | Pendiente |
| 46 | `exv2_copenhagen_short` | Plancha Copenhagen de palanca corta | hipControl | Pendiente |
| 47 | `exv2_side_plank_hip_lift` | Elevación de cadera en plancha lateral | core | Pendiente |
| 48 | `exv2_one_arm_overhead_cable` | Extensión tríceps overhead unilateral en polea | arms | Pendiente |
| 49 | `exv2_copenhagen_long` | Plancha Copenhagen de palanca larga | hipControl | Pendiente |
| 50 | `exv2_cable_woodchop_high_low` | Woodchopper en polea alta a baja | core | Pendiente |
| 51 | `exv2_single_db_overhead_triceps` | Extensión tríceps overhead con mancuerna a una mano | arms | Pendiente |
| 52 | `exv2_standing_cable_knee_drive` | Elevación de rodilla con polea | hipControl | Pendiente |
| 53 | `exv2_cable_woodchop_low_high` | Woodchopper en polea baja a alta | core | Pendiente |
| 54 | `exv2_lying_db_triceps` | Press francés tumbado con mancuernas | arms | Pendiente |
| 55 | `exv2_band_marching` | Marcha contra minibanda | hipControl | Pendiente |
| 56 | `exv2_russian_twist` | Giro ruso sentado sin carga | core | Pendiente |
| 57 | `exv2_kickback_db` | Patada de tríceps con mancuerna | arms | Pendiente |
| 58 | `exv2_seated_knee_raise` | Elevación de rodillas sentado | hipControl | Pendiente |
| 59 | `exv2_triceps_machine_extension` | Extensión de tríceps en máquina sentado | arms | Pendiente |

## Verificación de cobertura

- Inventario extraído del catálogo de fuente: **49 IDs históricos + 180 IDs curados = 229 únicos**.
- Lote 1: 40; lote 2: 60; lote 3: 70; lote 4: 59. Total y unión: **229/229**, sin duplicados ni ausencias.
- Para cada entrega de código generar una comprobación que enumere todos los IDs del catálogo y compare el registro de animaciones con los archivos existentes en `apps/app_mobile/assets/exercise_media/lottie/`.
- No añadir nada a `apps/app_web/pubspec.yaml`, archivos web, rutas web ni assets de web.
- CI Flutter Android/iOS, Core y móvil tras cada integración; acciones solo en `STK-Haven_CI`. Las pruebas físicas se realizarán cuando finalice el roadmap, como acordado.

**Importante:** este inventario no crea animaciones, no obtiene derechos de terceros ni demuestra que el movimiento haya sido validado. Las animaciones deben producirse y revisarse progresivamente para cubrir todas las entradas.
