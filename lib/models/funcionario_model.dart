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

  FuncionarioModel({
    required this.id, // 🔹 Agora precisamos de um ID
    required this.nome,
    this.cargo = "",
    this.cpf, // 🔹 Opcional
    this.matricula, // 🔹 Opcional
  });

  /// 🔄 Método para criar um novo funcionário com um ID único
  factory FuncionarioModel.novoFuncionario({required String nome, String cargo = "", String? cpf, String? matricula}) {
    return FuncionarioModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // 🔹 Gera um ID único baseado no tempo
      nome: nome,
      cargo: cargo,
      cpf: cpf,
      matricula: matricula,
    );
  }
}
