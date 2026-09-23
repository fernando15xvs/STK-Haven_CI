// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_body_measurement.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveBodyMeasurementAdapter extends TypeAdapter<HiveBodyMeasurement> {
  @override
  final int typeId = 11;

  @override
  HiveBodyMeasurement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveBodyMeasurement(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      weightKg: fields[2] as double?,
      bodyFatPercentage: fields[3] as double?,
      shouldersCm: fields[11] as double?,
      chestCm: fields[4] as double?,
      waistCm: fields[5] as double?,
      hipsCm: fields[12] as double?,
      leftArmCm: fields[6] as double?,
      rightArmCm: fields[7] as double?,
      leftLegCm: fields[8] as double?,
      rightLegCm: fields[9] as double?,
      calvesCm: fields[10] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveBodyMeasurement obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.weightKg)
      ..writeByte(3)
      ..write(obj.bodyFatPercentage)
      ..writeByte(4)
      ..write(obj.chestCm)
      ..writeByte(5)
      ..write(obj.waistCm)
      ..writeByte(6)
      ..write(obj.leftArmCm)
      ..writeByte(7)
      ..write(obj.rightArmCm)
      ..writeByte(8)
      ..write(obj.leftLegCm)
      ..writeByte(9)
      ..write(obj.rightLegCm)
      ..writeByte(10)
      ..write(obj.calvesCm)
      ..writeByte(11)
      ..write(obj.shouldersCm)
      ..writeByte(12)
      ..write(obj.hipsCm);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveBodyMeasurementAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
