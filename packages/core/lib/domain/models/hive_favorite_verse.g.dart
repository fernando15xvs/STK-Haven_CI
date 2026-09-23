// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_favorite_verse.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveFavoriteVerseAdapter extends TypeAdapter<HiveFavoriteVerse> {
  @override
  final int typeId = 12;

  @override
  HiveFavoriteVerse read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveFavoriteVerse(
      id: fields[0] as String,
      book: fields[1] as String,
      chapter: fields[2] as int,
      verse: fields[3] as int,
      text: fields[4] as String,
      savedAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, HiveFavoriteVerse obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.book)
      ..writeByte(2)
      ..write(obj.chapter)
      ..writeByte(3)
      ..write(obj.verse)
      ..writeByte(4)
      ..write(obj.text)
      ..writeByte(5)
      ..write(obj.savedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveFavoriteVerseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
