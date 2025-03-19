import 'package:hive/hive.dart';

part 'funcionario_model.g.dart'; // Gera o adaptador automaticamente

@HiveType(typeId: 1) // Tipo único para Hive
class FuncionarioModel extends HiveObject {
  @HiveField(0)
  final String nome;

  @HiveField(1)
  final String cargo;

  @HiveField(2)
  final String cpf;

  @HiveField(3)
  final String matricula;

  FuncionarioModel({
    required this.nome,
    this.cargo = "",
    required this.cpf,
    required this.matricula,
  });
}
