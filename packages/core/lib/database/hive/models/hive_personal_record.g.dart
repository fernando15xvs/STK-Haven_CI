// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_personal_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HivePersonalRecordAdapter extends TypeAdapter<HivePersonalRecord> {
  @override
  final int typeId = 10;

  @override
  HivePersonalRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HivePersonalRecord(
      id: fields[0] as String,
      workoutSessionId: fields[1] as String,
      exerciseId: fields[2] as String,
      exerciseNameSnapshot: fields[3] as String,
      type: fields[4] as HivePRType,
      previousValue: fields[5] as double,
      newValue: fields[6] as double,
      achievedAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, HivePersonalRecord obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.workoutSessionId)
      ..writeByte(2)
      ..write(obj.exerciseId)
      ..writeByte(3)
      ..write(obj.exerciseNameSnapshot)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.previousValue)
      ..writeByte(6)
      ..write(obj.newValue)
      ..writeByte(7)
      ..write(obj.achievedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HivePersonalRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HivePRTypeAdapter extends TypeAdapter<HivePRType> {
  @override
  final int typeId = 9;

  @override
  HivePRType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return HivePRType.maxWeight;
      case 1:
        return HivePRType.estimated1RM;
      case 2:
        return HivePRType.bestSetVolume;
      default:
        return HivePRType.maxWeight;
    }
  }

  @override
  void write(BinaryWriter writer, HivePRType obj) {
    switch (obj) {
      case HivePRType.maxWeight:
        writer.writeByte(0);
        break;
      case HivePRType.estimated1RM:
        writer.writeByte(1);
        break;
      case HivePRType.bestSetVolume:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HivePRTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
