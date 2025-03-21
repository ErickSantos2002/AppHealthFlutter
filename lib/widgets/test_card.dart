import 'package:flutter/material.dart';
import '../models/test_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/historico_provider.dart';
import '../providers/configuracoes_provider.dart';

class TestCard extends ConsumerWidget {
  final TestModel teste;
  final Function(TestModel) onTap; // ✅ Callback para abrir detalhes

  const TestCard({super.key, required this.teste, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool aprovado = teste.command == "PASS";
    Color statusColor = aprovado ? Colors.green : Colors.red;
    IconData statusIcon = aprovado ? Icons.check_circle : Icons.cancel;

    bool isFavorito = ref.watch(historicoProvider).testesFavoritos.contains(teste);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          radius: 25,
          child: Icon(statusIcon, color: statusColor, size: 30),
        ),
        title: Text(
          "Resultado: ${teste.command}", // ✅ Apenas resultado
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: statusColor),
        ),
        subtitle: Text(
          "Data: ${_formatDateTime(teste.timestamp)}",
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.blueAccent),
        onTap: () => onTap(teste), // ✅ Chama a função para mostrar detalhes
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.day.toString().padLeft(2, '0')}/"
        "${dateTime.month.toString().padLeft(2, '0')}/"
        "${dateTime.year} "
        "${dateTime.hour.toString().padLeft(2, '0')}:" 
        "${dateTime.minute.toString().padLeft(2, '0')}:" 
        "${dateTime.second.toString().padLeft(2, '0')}";
  }
}
