// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_exercise.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveExerciseAdapter extends TypeAdapter<HiveExercise> {
  @override
  final int typeId = 8;

  @override
  HiveExercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveExercise(
      id: fields[0] as String,
      name: fields[1] as String,
      muscleGroup: fields[2] as String,
      secondaryMuscles: (fields[3] as List).cast<String>(),
      equipment: fields[4] as String,
      instructions: fields[5] as String,
      media: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, HiveExercise obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.muscleGroup)
      ..writeByte(3)
      ..write(obj.secondaryMuscles)
      ..writeByte(4)
      ..write(obj.equipment)
      ..writeByte(5)
      ..write(obj.instructions)
      ..writeByte(6)
      ..write(obj.media);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveExerciseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
