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
      timestamp: fields[0] as DateTime,
      command: fields[1] as String,
      statusCalibracao: fields[2] as String,
      batteryLevel: fields[3] as int,
      funcionarioId: fields[4] as String?,
      funcionarioNome: fields[5] as String,
      photoPath: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TestModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.timestamp)
      ..writeByte(1)
      ..write(obj.command)
      ..writeByte(2)
      ..write(obj.statusCalibracao)
      ..writeByte(3)
      ..write(obj.batteryLevel)
      ..writeByte(4)
      ..write(obj.funcionarioId)
      ..writeByte(5)
      ..write(obj.funcionarioNome)
      ..writeByte(6)
      ..write(obj.photoPath);
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
