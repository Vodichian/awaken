// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_adapters.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class ComputerAdapter extends TypeAdapter<Computer> {
  @override
  final typeId = 0;

  @override
  Computer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Computer(
      name: fields[0] as String,
      macAddress: fields[1] as String,
      broadcastAddress: fields[2] as String,
      color: (fields[3] as num?)?.toInt(),
      wanIpAddress: fields[4] as String?,
      notes: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Computer obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.macAddress)
      ..writeByte(2)
      ..write(obj.broadcastAddress)
      ..writeByte(3)
      ..write(obj.color)
      ..writeByte(4)
      ..write(obj.wanIpAddress)
      ..writeByte(5)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComputerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
