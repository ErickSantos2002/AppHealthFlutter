import 'package:flutter/material.dart';
import '../models/test_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
class TestCard extends ConsumerWidget {
  final TestModel teste;
  final Function(TestModel)? onTap; // ✅ Callback para abrir detalhes
  final VoidCallback? onFavoriteToggle; // ✅ Adicionando o parâmetro correto
  final double tolerancia;

  const TestCard({
    Key? key,
    required this.teste,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.tolerancia, // ✅ Adicionado aqui
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final corStatus = teste.getCorPorResultado(tolerancia);
    return Card(
      color: corStatus.withOpacity(0.2), // fundo sutil baseado no status
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
        onTap: onTap != null ? () => onTap!(teste) : null,
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
