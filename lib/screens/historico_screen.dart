import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/test_model.dart';

class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  late Box<TestModel> testesBox;

  @override
  void initState() {
    super.initState();
    testesBox = Hive.box<TestModel>('testes');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Histórico de Testes")),
      body: ValueListenableBuilder(
        valueListenable: testesBox.listenable(),
        builder: (context, Box<TestModel> box, _) {
          if (box.isEmpty) {
            return const Center(child: Text("Nenhum teste armazenado."));
          }

          return ListView.builder(
            itemCount: box.length,
            itemBuilder: (context, index) {
              final TestModel teste = box.getAt(index)!;
              return _historicoCard(teste, index);
            },
          );
        },
      ),
    );
  }

  // ✅ Widget para exibir os resultados do histórico
  Widget _historicoCard(TestModel teste, int index) {
    return Card(
      elevation: 2,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: ExpansionTile(
        title: Text("Resultado: ${teste.data}", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Data e hora: ${_formatDateTime(teste.timestamp)}"),
        children: [
          ListTile(
            title: Text("Status: ${teste.command}"),
            subtitle: Text("Bateria: ${teste.batteryLevel}%\nStatus da Calibração: ${teste.statusCalibracao}"),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                setState(() {
                  testesBox.deleteAt(index);
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Função para formatar a data e hora corretamente
  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.day.toString().padLeft(2, '0')}/"
        "${dateTime.month.toString().padLeft(2, '0')}/"
        "${dateTime.year} ${dateTime.hour}:${dateTime.minute}:${dateTime.second}";
  }
}
