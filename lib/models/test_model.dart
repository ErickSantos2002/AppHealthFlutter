import 'package:hive/hive.dart';

part 'test_model.g.dart'; // Gera o adaptador automaticamente

@HiveType(typeId: 0)
class TestModel extends HiveObject {
  @HiveField(0)
  final String data;

  @HiveField(1)
  final String command;

  @HiveField(2)
  final int batteryLevel;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4) // ✅ Adicionando um novo campo no Hive
  final String statusCalibracao;

  @HiveField(5) // 🔹 Adicionando o ID do funcionário
  final String? funcionarioId; 

  TestModel({
    required this.timestamp,
    required this.data,
    required this.command,
    required this.batteryLevel,
    required this.statusCalibracao,
    this.funcionarioId, // 🔹 Campo opcional para funcionário
  });

  // Método para atualizar funcionário no teste
  TestModel copyWith({String? funcionarioId}) {
    return TestModel(
      timestamp: timestamp,
      data: data,
      command: command,
      batteryLevel: batteryLevel,
      statusCalibracao: statusCalibracao,
      funcionarioId: funcionarioId ?? this.funcionarioId,
    );
  }
}