// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TestModelAdapter extends TypeAdapter<TestModel> {
  @override
  final int typeId = 0;

  @override
  TestModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TestModel(
      data: fields[0] as String,
      command: fields[1] as String,
      batteryLevel: fields[2] as int,
      timestamp: fields[3] as DateTime,
      statusCalibracao: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TestModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.data)
      ..writeByte(1)
      ..write(obj.command)
      ..writeByte(2)
      ..write(obj.batteryLevel)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.statusCalibracao);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
