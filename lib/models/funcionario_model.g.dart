// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'funcionario_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FuncionarioModelAdapter extends TypeAdapter<FuncionarioModel> {
  @override
  final int typeId = 1;

  @override
  FuncionarioModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FuncionarioModel(
      nome: fields[0] as String,
      cargo: fields[1] as String,
      cpf: fields[2] as String,
      matricula: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, FuncionarioModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.nome)
      ..writeByte(1)
      ..write(obj.cargo)
      ..writeByte(2)
      ..write(obj.cpf)
      ..writeByte(3)
      ..write(obj.matricula);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FuncionarioModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
