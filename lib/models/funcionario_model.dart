import 'package:hive/hive.dart';

part 'funcionario_model.g.dart'; // Gera o adaptador automaticamente

@HiveType(typeId: 1) // Tipo único para Hive
class FuncionarioModel extends HiveObject {
  @HiveField(0)
  final String id; // 🔹 Adicionando ID único

  @HiveField(1)
  final String nome;

  @HiveField(2)
  final String cargo;

  @HiveField(3)
  final String? cpf; // 🔹 Agora CPF é opcional

  @HiveField(4)
  final String? matricula; // 🔹 Agora Matrícula é opcional

  @HiveField(5)
  final String? informacao1;

  @HiveField(6)
  final String? informacao2;

  FuncionarioModel({
    required this.id,
    required this.nome,
    this.cargo = "",
    this.cpf,
    this.matricula,
    this.informacao1,
    this.informacao2,
  });

  /// 🔄 Método para criar um novo funcionário com um ID único
  factory FuncionarioModel.novoFuncionario({
    required String nome,
    String cargo = "",
    String? cpf,
    String? matricula,
    String? informacao1,
    String? informacao2,
  }) {
    return FuncionarioModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nome: nome,
      cargo: cargo,
      cpf: cpf,
      matricula: matricula,
      informacao1: informacao1,
      informacao2: informacao2,
    );
  }
}
