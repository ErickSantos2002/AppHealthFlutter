import 'package:hive/hive.dart';

part 'test_model.g.dart'; // Gera o adaptador automaticamente

@HiveType(typeId: 0)
class TestModel extends HiveObject {
  @HiveField(0)
  final DateTime timestamp; // 📌 Data e Hora do Teste

  @HiveField(1)
  final String command; // 📌 Resultado do Teste (Ex: "PASS", "FALHA")

  @HiveField(2)
  final String statusCalibracao; // 📌 Status da Calibração

  @HiveField(3)
  final int batteryLevel; // 📌 Nível de Bateria no Momento do Teste

  @HiveField(4)
  final String? funcionarioId; // 📌 ID do Funcionário (null para Visitante)

  @HiveField(5)
  final String funcionarioNome; // 📌 Nome do Funcionário ou "Visitante"

  @HiveField(6)
  final String? photoPath; // 📌 Caminho da Foto Tirada

  @HiveField(7)
  bool isFavorito; // ✅ Adicionando a propriedade para favorito

    TestModel({
      required this.timestamp,
      required this.command,
      required this.statusCalibracao,
      required this.batteryLevel,
      this.funcionarioId,
      required this.funcionarioNome,
      this.photoPath,
      this.isFavorito = false, // ✅ Padrão inicial: não favorito
    });

  // 📌 Método para atualizar campos específicos
  TestModel copyWith({
    String? funcionarioId,
    String? funcionarioNome,
    String? photoPath,
  }) {
    return TestModel(
      timestamp: timestamp,
      command: command,
      statusCalibracao: statusCalibracao,
      batteryLevel: batteryLevel,
      funcionarioId: funcionarioId ?? this.funcionarioId,
      funcionarioNome: funcionarioNome ?? this.funcionarioNome,
      photoPath: photoPath ?? this.photoPath,
    );
  }
}
