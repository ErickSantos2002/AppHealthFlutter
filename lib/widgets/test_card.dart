import 'package:flutter/material.dart';
import '../models/test_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/historico_provider.dart';
import '../providers/configuracoes_provider.dart';

class TestCard extends ConsumerWidget {
  final TestModel teste;
  final Function(TestModel)? onTap; // ✅ Callback para abrir detalhes
  final VoidCallback? onFavoriteToggle; // ✅ Adicionando o parâmetro correto

  const TestCard({
    Key? key,
    required this.teste,
    this.onTap,
    this.onFavoriteToggle, // ✅ Recebendo o callback
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text("Resultado: ${teste.command}"),
        subtitle: Text("Data: ${_formatDateTime(teste.timestamp)}"),
        trailing: IconButton(
          icon: Icon(
            teste.isFavorito ? Icons.star : Icons.star_border,
            color: teste.isFavorito ? Colors.amber : Colors.grey,
          ),
          onPressed: onFavoriteToggle,
        ),
        onTap: onTap != null ? () => onTap!(teste) : null, // ✅ Verifica se `onTap` está definido antes de chamar
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
