import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/test_model.dart';
import '../models/funcionario_model.dart';
import 'package:hive/hive.dart';

class TestCard extends ConsumerWidget {
  final TestModel teste;
  final Function(TestModel)? onTap;
  final VoidCallback? onFavoriteToggle;
  final double tolerancia;

  const TestCard({
    super.key,
    required this.teste,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.tolerancia,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final corStatus = teste.getCorPorResultado(tolerancia);
    final funcionariosBox = Hive.box<FuncionarioModel>('funcionarios');

    final funcionario = funcionariosBox.values.firstWhere(
      (f) => f.id == teste.funcionarioId,
      orElse: () => FuncionarioModel(
        id: "visitante",
        nome: teste.funcionarioNome,
      ),
    );

    return Card(
      color: corStatus.withOpacity(0.2),
      child: ListTile(
        title: Text("Resultado: ${teste.command}"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Data: ${_formatDateTime(teste.timestamp)}"),
            const SizedBox(height: 4),
            Text("Funcionário: ${funcionario.nome}"),
            //if (funcionario.cargo.isNotEmpty)
            //  Text("Cargo: ${funcionario.cargo}"),
            //if ((funcionario.cpf ?? "").isNotEmpty)
            //  Text("CPF: ${funcionario.cpf}"),
            //if ((funcionario.matricula ?? "").isNotEmpty)
            //  Text("Matrícula: ${funcionario.matricula}"),
            //if ((funcionario.informacao1 ?? "").isNotEmpty)
            //  Text("Informação 1: ${funcionario.informacao1}"),
            //if ((funcionario.informacao2 ?? "").isNotEmpty)
            //  Text("Informação 2: ${funcionario.informacao2}"),
          ],
        ),
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
