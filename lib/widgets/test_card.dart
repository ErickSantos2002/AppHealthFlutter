import 'package:flutter/material.dart';
import '../models/test_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/historico_provider.dart';
import '../providers/configuracoes_provider.dart';

class TestCard extends ConsumerWidget {
  final TestModel teste;

  const TestCard({super.key, required this.teste});

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
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.2),
              radius: 30,
              child: Icon(statusIcon, color: statusColor, size: 32),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Resultado: ${teste.data}",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: statusColor),
                  ),
                  const SizedBox(height: 4),
                  Text("Data: ${_formatDateTime(teste.timestamp)}", style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  if (ref.watch(configuracoesProvider).exibirStatusCalibracao)
                    Text("Calibração: ${teste.statusCalibracao}", style: TextStyle(fontSize: 14, color: Colors.black)),
                ],
              ),
            ),

            // Botão de Favorito
            IconButton(
              icon: Icon(isFavorito ? Icons.star : Icons.star_border, color: Colors.amber),
              onPressed: () {
                ref.read(historicoProvider.notifier).alternarFavorito(teste);
              },
            ),

            const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.blueAccent),
          ],
        ),
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
