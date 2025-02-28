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

  TestModel({
    required this.data,
    required this.command,
    required this.batteryLevel,
    required this.timestamp,
    required this.statusCalibracao, // ✅ Novo campo obrigatório
  });
}
