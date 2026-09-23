// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_workout_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveWorkoutSetAdapter extends TypeAdapter<HiveWorkoutSet> {
  @override
  final int typeId = 5;

  @override
  HiveWorkoutSet read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final legacyWarmup = fields[4] as bool? ?? false;
    return HiveWorkoutSet(
      weight: fields[0] as double,
      reps: fields[1] as int,
      completed: fields[2] as bool,
      rir: fields[3] as int?,
      warmup: legacyWarmup,
      restSeconds: fields[5] as int? ?? 0,
      setType: fields[6] as String? ?? (legacyWarmup ? 'warmup' : 'working'),
      leftCompleted: fields[7] as bool? ?? false,
      rightCompleted: fields[8] as bool? ?? false,
      leftWeight: (fields[9] as num?)?.toDouble(),
      leftReps: fields[10] as int?,
      leftRir: fields[11] as int?,
      rightWeight: (fields[12] as num?)?.toDouble(),
      rightReps: fields[13] as int?,
      rightRir: fields[14] as int?,
      sideRestSeconds: fields[15] as int? ?? 60,
    );
  }

  @override
  void write(BinaryWriter writer, HiveWorkoutSet obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.weight)
      ..writeByte(1)
      ..write(obj.reps)
      ..writeByte(2)
      ..write(obj.completed)
      ..writeByte(3)
      ..write(obj.rir)
      ..writeByte(4)
      ..write(obj.warmup)
      ..writeByte(5)
      ..write(obj.restSeconds)
      ..writeByte(6)
      ..write(obj.setType)
      ..writeByte(7)
      ..write(obj.leftCompleted)
      ..writeByte(8)
      ..write(obj.rightCompleted)
      ..writeByte(9)
      ..write(obj.leftWeight)
      ..writeByte(10)
      ..write(obj.leftReps)
      ..writeByte(11)
      ..write(obj.leftRir)
      ..writeByte(12)
      ..write(obj.rightWeight)
      ..writeByte(13)
      ..write(obj.rightReps)
      ..writeByte(14)
      ..write(obj.rightRir)
      ..writeByte(15)
      ..write(obj.sideRestSeconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveWorkoutSetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveWorkoutExerciseAdapter extends TypeAdapter<HiveWorkoutExercise> {
  @override
  final int typeId = 6;

  @override
  HiveWorkoutExercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveWorkoutExercise(
      exerciseId: fields[0] as String,
      sets: (fields[1] as List).cast<HiveWorkoutSet>(),
      notes: fields[2] as String? ?? '',
      exerciseNameSnapshot: fields[3] as String? ?? '',
      muscleGroupSnapshot: fields[4] as String? ?? '',
      unilateral: fields[5] as bool? ?? false,
      unilateralTarget: fields[6] as String? ?? 'other',
      supersetGroupId: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveWorkoutExercise obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.exerciseId)
      ..writeByte(1)
      ..write(obj.sets)
      ..writeByte(2)
      ..write(obj.notes)
      ..writeByte(3)
      ..write(obj.exerciseNameSnapshot)
      ..writeByte(4)
      ..write(obj.muscleGroupSnapshot)
      ..writeByte(5)
      ..write(obj.unilateral)
      ..writeByte(6)
      ..write(obj.unilateralTarget)
      ..writeByte(7)
      ..write(obj.supersetGroupId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveWorkoutExerciseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveWorkoutSessionAdapter extends TypeAdapter<HiveWorkoutSession> {
  @override
  final int typeId = 7;

  @override
  HiveWorkoutSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveWorkoutSession(
      id: fields[0] as String,
      routineId: fields[1] as String?,
      startedAt: fields[2] as DateTime,
      finishedAt: fields[3] as DateTime,
      exercises: (fields[4] as List).cast<HiveWorkoutExercise>(),
      durationSeconds: fields[5] as int,
      notes: fields[6] as String? ?? '',
      routineNameSnapshot: fields[7] as String? ?? '',
      currentRestEndsAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveWorkoutSession obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.routineId)
      ..writeByte(2)
      ..write(obj.startedAt)
      ..writeByte(3)
      ..write(obj.finishedAt)
      ..writeByte(4)
      ..write(obj.exercises)
      ..writeByte(5)
      ..write(obj.durationSeconds)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.routineNameSnapshot)
      ..writeByte(8)
      ..write(obj.currentRestEndsAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveWorkoutSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}