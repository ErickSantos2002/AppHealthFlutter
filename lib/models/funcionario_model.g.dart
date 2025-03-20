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
      id: fields[0] as String,
      nome: fields[1] as String,
      cargo: fields[2] as String,
      cpf: fields[3] as String?,
      matricula: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FuncionarioModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nome)
      ..writeByte(2)
      ..write(obj.cargo)
      ..writeByte(3)
      ..write(obj.cpf)
      ..writeByte(4)
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
