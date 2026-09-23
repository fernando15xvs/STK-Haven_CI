import 'package:core/domain/models/preset_program.dart';

final List<PresetProgram> presetPrograms = [
  PresetProgram(
    id: 'prog_fullbody_3',
    version: 1,
    name: 'Full Body (3 Días)',
    description: 'Entrenamiento de cuerpo completo ideal para principiantes o personas con poco tiempo. Enfoque en ejercicios compuestos.',
    level: 'Principiante',
    daysPerWeek: 3,
    durationWeeks: 8,
    routines: [
      const PresetRoutine(
        name: 'Full Body A',
        scheduledDays: [1], // Lunes
        exercises: [
          PresetRoutineExercise(exerciseId: 'ex_squat', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 150),
          PresetRoutineExercise(exerciseId: 'ex_bench_press', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 150),
          PresetRoutineExercise(exerciseId: 'ex_barbell_row', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_lateral_raises', targetSets: 3, targetRepsMin: 12, targetRepsMax: 15, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_barbell_curl', targetSets: 2, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 90),
        ],
      ),
      const PresetRoutine(
        name: 'Full Body B',
        scheduledDays: [3], // Miércoles
        exercises: [
          PresetRoutineExercise(exerciseId: 'ex_rdl', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 150),
          PresetRoutineExercise(exerciseId: 'ex_ohp', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 150),
          PresetRoutineExercise(exerciseId: 'ex_lat_pulldown', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_leg_extension', targetSets: 3, targetRepsMin: 12, targetRepsMax: 15, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_tricep_pushdown', targetSets: 2, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 90),
        ],
      ),
      const PresetRoutine(
        name: 'Full Body C',
        scheduledDays: [5], // Viernes
        exercises: [
          PresetRoutineExercise(exerciseId: 'ex_leg_press', targetSets: 3, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_incline_db_press', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_cable_row', targetSets: 3, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_face_pull', targetSets: 3, targetRepsMin: 12, targetRepsMax: 20, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_db_curl', targetSets: 2, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 90),
        ],
      ),
    ],
  ),

  PresetProgram(
    id: 'prog_fullbody_2',
    version: 1,
    name: 'Full Body (2 Días)',
    description: 'Entrenamiento de cuerpo completo para mantener la forma o para personas con muy poco tiempo. Ideal para combinar con otros deportes.',
    level: 'Principiante',
    daysPerWeek: 2,
    durationWeeks: 8,
    routines: [
      const PresetRoutine(
        name: 'Full Body A',
        scheduledDays: [1], // Lunes
        exercises: [
          PresetRoutineExercise(exerciseId: 'ex_squat', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 150),
          PresetRoutineExercise(exerciseId: 'ex_bench_press', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 150),
          PresetRoutineExercise(exerciseId: 'ex_barbell_row', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_lateral_raises', targetSets: 3, targetRepsMin: 12, targetRepsMax: 15, restSeconds: 90),
        ],
      ),
      const PresetRoutine(
        name: 'Full Body B',
        scheduledDays: [4], // Jueves
        exercises: [
          PresetRoutineExercise(exerciseId: 'ex_rdl', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 150),
          PresetRoutineExercise(exerciseId: 'ex_ohp', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 150),
          PresetRoutineExercise(exerciseId: 'ex_lat_pulldown', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_leg_press', targetSets: 3, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 120),
        ],
      ),
    ],
  ),

  PresetProgram(
    id: 'prog_upper_lower_4',
    version: 1,
    name: 'Upper / Lower (4 Días)',
    description: 'División clásica Torso/Pierna. Excelente equilibrio entre frecuencia y volumen para hipertrofia y fuerza.',
    level: 'Intermedio',
    daysPerWeek: 4,
    durationWeeks: 12,
    routines: [
      const PresetRoutine(
        name: 'Upper A',
        scheduledDays: [1], // Lunes
        exercises: [
          PresetRoutineExercise(exerciseId: 'ex_bench_press', targetSets: 3, targetRepsMin: 6, targetRepsMax: 10, restSeconds: 180),
          PresetRoutineExercise(exerciseId: 'ex_barbell_row', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 150),
          PresetRoutineExercise(exerciseId: 'ex_incline_db_press', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_lat_pulldown', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_lateral_raises', targetSets: 3, targetRepsMin: 12, targetRepsMax: 20, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_db_curl', targetSets: 2, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_tricep_pushdown', targetSets: 2, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 90),
        ],
      ),
      const PresetRoutine(
        name: 'Lower A',
        scheduledDays: [2], // Martes
        exercises: [
          PresetRoutineExercise(exerciseId: 'ex_squat', targetSets: 3, targetRepsMin: 6, targetRepsMax: 10, restSeconds: 180),
          PresetRoutineExercise(exerciseId: 'ex_rdl', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 150),
          PresetRoutineExercise(exerciseId: 'ex_leg_press', targetSets: 3, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_leg_curl', targetSets: 3, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_calf_raise', targetSets: 4, targetRepsMin: 12, targetRepsMax: 20, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_crunch', targetSets: 3, targetRepsMin: 15, targetRepsMax: 25, restSeconds: 60),
        ],
      ),
      const PresetRoutine(
        name: 'Upper B',
        scheduledDays: [4], // Jueves
        exercises: [
          PresetRoutineExercise(exerciseId: 'ex_ohp', targetSets: 3, targetRepsMin: 6, targetRepsMax: 10, restSeconds: 180),
          PresetRoutineExercise(exerciseId: 'ex_pullups', targetSets: 3, targetRepsMin: 6, targetRepsMax: 10, restSeconds: 150),
          PresetRoutineExercise(exerciseId: 'ex_db_shoulder_press', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_cable_row', targetSets: 3, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_face_pull', targetSets: 3, targetRepsMin: 12, targetRepsMax: 20, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_hammer_curl', targetSets: 2, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_overhead_tricep', targetSets: 2, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 90),
        ],
      ),
      const PresetRoutine(
        name: 'Lower B',
        scheduledDays: [5], // Viernes
        exercises: [
          PresetRoutineExercise(exerciseId: 'ex_bulgarian_split_squat', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_hip_thrust', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 150),
          PresetRoutineExercise(exerciseId: 'ex_leg_extension', targetSets: 3, targetRepsMin: 12, targetRepsMax: 15, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_leg_curl', targetSets: 3, targetRepsMin: 12, targetRepsMax: 15, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_calf_raise', targetSets: 4, targetRepsMin: 12, targetRepsMax: 20, restSeconds: 90),
        ],
      ),
    ],
  ),

  PresetProgram(
    id: 'prog_ppl_6',
    version: 1,
    name: 'Push Pull Legs (6 Días)',
    description: 'Máximo volumen y frecuencia. Para usuarios avanzados que pueden recuperarse de entrenar 6 días a la semana.',
    level: 'Avanzado',
    daysPerWeek: 6,
    durationWeeks: 12,
    routines: [
      const PresetRoutine(
        name: 'Push A',
        scheduledDays: [1], // Lunes
        exercises: [
          PresetRoutineExercise(exerciseId: 'ex_bench_press', targetSets: 4, targetRepsMin: 5, targetRepsMax: 8, restSeconds: 180),
          PresetRoutineExercise(exerciseId: 'ex_ohp', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 150),
          PresetRoutineExercise(exerciseId: 'ex_incline_db_press', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_lateral_raises', targetSets: 4, targetRepsMin: 15, targetRepsMax: 20, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_tricep_pushdown', targetSets: 3, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 90),
        ],
      ),
      const PresetRoutine(
        name: 'Pull A',
        scheduledDays: [2], // Martes
        exercises: [
          PresetRoutineExercise(exerciseId: 'ex_barbell_row', targetSets: 4, targetRepsMin: 6, targetRepsMax: 10, restSeconds: 180),
          PresetRoutineExercise(exerciseId: 'ex_lat_pulldown', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_face_pull', targetSets: 3, targetRepsMin: 15, targetRepsMax: 20, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_barbell_curl', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_hammer_curl', targetSets: 2, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 90),
        ],
      ),
      const PresetRoutine(
        name: 'Legs A',
        scheduledDays: [3], // Miércoles
        exercises: [
          PresetRoutineExercise(exerciseId: 'ex_squat', targetSets: 4, targetRepsMin: 5, targetRepsMax: 8, restSeconds: 180),
          PresetRoutineExercise(exerciseId: 'ex_rdl', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 150),
          PresetRoutineExercise(exerciseId: 'ex_leg_press', targetSets: 3, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_calf_raise', targetSets: 4, targetRepsMin: 15, targetRepsMax: 20, restSeconds: 90),
        ],
      ),
      const PresetRoutine(
        name: 'Push B',
        scheduledDays: [4], // Jueves
        exercises: [
          PresetRoutineExercise(exerciseId: 'ex_ohp', targetSets: 4, targetRepsMin: 5, targetRepsMax: 8, restSeconds: 180),
          PresetRoutineExercise(exerciseId: 'ex_incline_db_press', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_chest_flyes', targetSets: 3, targetRepsMin: 12, targetRepsMax: 15, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_lateral_raises', targetSets: 4, targetRepsMin: 15, targetRepsMax: 20, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_overhead_tricep', targetSets: 3, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 90),
        ],
      ),
      const PresetRoutine(
        name: 'Pull B',
        scheduledDays: [5], // Viernes
        exercises: [
          PresetRoutineExercise(exerciseId: 'ex_pullups', targetSets: 4, targetRepsMin: 6, targetRepsMax: 10, restSeconds: 180),
          PresetRoutineExercise(exerciseId: 'ex_cable_row', targetSets: 3, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_reverse_pec_deck', targetSets: 3, targetRepsMin: 12, targetRepsMax: 15, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_db_curl', targetSets: 3, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 90),
        ],
      ),
      const PresetRoutine(
        name: 'Legs B',
        scheduledDays: [6], // Sábado
        exercises: [
          PresetRoutineExercise(exerciseId: 'ex_leg_press', targetSets: 4, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 150),
          PresetRoutineExercise(exerciseId: 'ex_hip_thrust', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 150),
          PresetRoutineExercise(exerciseId: 'ex_leg_extension', targetSets: 3, targetRepsMin: 12, targetRepsMax: 15, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_leg_curl', targetSets: 3, targetRepsMin: 12, targetRepsMax: 15, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_calf_raise', targetSets: 4, targetRepsMin: 15, targetRepsMax: 20, restSeconds: 90),
        ],
      ),
    ],
  ),

  PresetProgram(
    id: 'prog_ppl_3',
    version: 1,
    name: 'Push Pull Legs (3 Días)',
    description: 'División PPL para aquellos que prefieren entrenar menos días. Un grupo muscular por sesión.',
    level: 'Intermedio',
    daysPerWeek: 3,
    durationWeeks: 8,
    routines: [
      const PresetRoutine(
        name: 'Push',
        scheduledDays: [1], // Lunes
        exercises: [
          PresetRoutineExercise(exerciseId: 'ex_bench_press', targetSets: 4, targetRepsMin: 6, targetRepsMax: 10, restSeconds: 180),
          PresetRoutineExercise(exerciseId: 'ex_ohp', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 150),
          PresetRoutineExercise(exerciseId: 'ex_incline_db_press', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_lateral_raises', targetSets: 4, targetRepsMin: 12, targetRepsMax: 20, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_tricep_pushdown', targetSets: 3, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_overhead_tricep', targetSets: 2, targetRepsMin: 12, targetRepsMax: 15, restSeconds: 90),
        ],
      ),
      const PresetRoutine(
        name: 'Pull',
        scheduledDays: [3], // Miércoles
        exercises: [
          PresetRoutineExercise(exerciseId: 'ex_barbell_row', targetSets: 4, targetRepsMin: 6, targetRepsMax: 10, restSeconds: 180),
          PresetRoutineExercise(exerciseId: 'ex_lat_pulldown', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_face_pull', targetSets: 3, targetRepsMin: 12, targetRepsMax: 20, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_barbell_curl', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_hammer_curl', targetSets: 3, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 90),
        ],
      ),
      const PresetRoutine(
        name: 'Legs',
        scheduledDays: [5], // Viernes
        exercises: [
          PresetRoutineExercise(exerciseId: 'ex_squat', targetSets: 4, targetRepsMin: 6, targetRepsMax: 10, restSeconds: 180),
          PresetRoutineExercise(exerciseId: 'ex_rdl', targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, restSeconds: 150),
          PresetRoutineExercise(exerciseId: 'ex_leg_press', targetSets: 3, targetRepsMin: 10, targetRepsMax: 15, restSeconds: 120),
          PresetRoutineExercise(exerciseId: 'ex_leg_extension', targetSets: 3, targetRepsMin: 12, targetRepsMax: 15, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_leg_curl', targetSets: 3, targetRepsMin: 12, targetRepsMax: 15, restSeconds: 90),
          PresetRoutineExercise(exerciseId: 'ex_calf_raise', targetSets: 4, targetRepsMin: 15, targetRepsMax: 20, restSeconds: 90),
        ],
      ),
    ],
  ),
];
