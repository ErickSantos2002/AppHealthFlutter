import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

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

  @HiveField(8)
  final String? deviceName; // 📌 Nome do dispositivo utilizado

    TestModel({
      required this.timestamp,
      required this.command,
      required this.statusCalibracao,
      required this.batteryLevel,
      this.funcionarioId,
      required this.funcionarioNome,
      this.photoPath,
      this.isFavorito = false, // ✅ Padrão inicial: não favorito
      this.deviceName,
    });

  // 📌 Método para atualizar campos específicos
  TestModel copyWith({
    String? funcionarioId,
    String? funcionarioNome,
    String? photoPath,
    String? deviceName,
  }) {
    return TestModel(
      timestamp: timestamp,
      command: command,
      statusCalibracao: statusCalibracao,
      batteryLevel: batteryLevel,
      funcionarioId: funcionarioId ?? this.funcionarioId,
      funcionarioNome: funcionarioNome ?? this.funcionarioNome,
      photoPath: photoPath ?? this.photoPath,
      deviceName: deviceName ?? this.deviceName,
    );
  }
  TestModel applyFavorito(bool favorito) {
    return TestModel(
      timestamp: timestamp,
      command: command,
      statusCalibracao: statusCalibracao,
      batteryLevel: batteryLevel,
      funcionarioId: funcionarioId,
      funcionarioNome: funcionarioNome,
      photoPath: photoPath,
      deviceName: deviceName,
      isFavorito: favorito,
    );
  }
}
extension UnidadeHelper on TestModel {
  String getUnidadeFormatada() {
    final resultado = command.trim();
    final unidade = resultado.split(" ").length > 1 ? resultado.split(" ")[1] : "";
    return unidade;
  }
}
extension TestModelHelper on TestModel {
  Color getCorPorResultado(double tolerancia) {
    final valorStr = command.toUpperCase().trim();

    // Se for PASS
    if (valorStr.contains("PASS")) return Colors.green.shade700;

    // Se for 0.000 ou valor numérico
    final valorLimpo = valorStr.split(" ").first.replaceAll(",", "."); // remove unidade
    final valor = double.tryParse(valorLimpo) ?? -1;

    if (valor == 0.0) return const Color(0xFF00C853);
    if (valor > 0 && valor < tolerancia) return const Color(0xFFFFC107);
    if (valor >= tolerancia || valorStr.contains("FAIL")) return const Color(0xFFD50000);

    return Colors.grey;
  }

  bool isAcimaDaTolerancia(double tolerancia) {
    final valorStr = command.toUpperCase().trim();

    if (valorStr.contains("PASS")) return false;

    final valorLimpo = valorStr.split(" ").first.replaceAll(",", ".");
    final valor = double.tryParse(valorLimpo) ?? -1;

    return valor > 0.0;
  }
}

