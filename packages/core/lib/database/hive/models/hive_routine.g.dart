// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_routine.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveRoutineExerciseAdapter extends TypeAdapter<HiveRoutineExercise> {
  @override
  final int typeId = 3;

  @override
  HiveRoutineExercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveRoutineExercise(
      exerciseId: fields[0] as String,
      order: fields[1] as int,
      targetSets: fields[2] as int,
      targetRepsMin: fields[3] as int,
      targetRepsMax: fields[4] as int,
      restSeconds: fields[5] as int,
      warmupSets: fields[6] as int? ?? 0,
      approachSets: fields[7] as int? ?? 0,
      unilateral: fields[8] as bool? ?? false,
      unilateralTarget: fields[9] as String? ?? 'other',
      supersetGroupId: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveRoutineExercise obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.exerciseId)
      ..writeByte(1)
      ..write(obj.order)
      ..writeByte(2)
      ..write(obj.targetSets)
      ..writeByte(3)
      ..write(obj.targetRepsMin)
      ..writeByte(4)
      ..write(obj.targetRepsMax)
      ..writeByte(5)
      ..write(obj.restSeconds)
      ..writeByte(6)
      ..write(obj.warmupSets)
      ..writeByte(7)
      ..write(obj.approachSets)
      ..writeByte(8)
      ..write(obj.unilateral)
      ..writeByte(9)
      ..write(obj.unilateralTarget)
      ..writeByte(10)
      ..write(obj.supersetGroupId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveRoutineExerciseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveRoutineAdapter extends TypeAdapter<HiveRoutine> {
  @override
  final int typeId = 4;

  @override
  HiveRoutine read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveRoutine(
      id: fields[0] as String,
      name: fields[1] as String,
      scheduledDays: (fields[2] as List).cast<int>(),
      exercises: (fields[3] as List).cast<HiveRoutineExercise>(),
      createdAt: fields[4] as DateTime,
      notes: fields[5] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, HiveRoutine obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.scheduledDays)
      ..writeByte(3)
      ..write(obj.exercises)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveRoutineAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
