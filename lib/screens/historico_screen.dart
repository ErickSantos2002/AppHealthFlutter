import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/test_model.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';

class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  late Box<TestModel> testesBox;
  String filtroStatus = "Todos"; // "PASS", "Normal" ou "Todos"
  double bateriaMinima = 0; // Filtro por nível de bateria
  DateTime? filtroData; // Filtro por data

  @override
  void initState() {
    super.initState();
    testesBox = Hive.box<TestModel>('testes');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Duas abas: Testes e Gráficos
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Histórico de Testes"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list), text: "Testes"),
              Tab(icon: Icon(Icons.pie_chart), text: "Gráficos"),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _exportarCSV(_filtrarTestes()),
              tooltip: "Exportar CSV",
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildTestesTab(), // Aba de Testes
            _buildGraficosTab(), // Aba de Gráficos
          ],
        ),
      ),
    );
  }

  // ✅ Aba dos Testes com lista, filtros e gráfico de barras
  Widget _buildTestesTab() {
    List<TestModel> testesFiltrados = _filtrarTestes();
    Map<String, int> testesPorDia = _calcularTestesPorDia(testesFiltrados);

    return Column(
      children: [
        _buildFiltros(), // Filtros no topo
        _buildGraficoBarras(testesPorDia), // Gráfico de barras na aba Testes
        Expanded(
          child: testesFiltrados.isEmpty
              ? const Center(child: Text("Nenhum teste armazenado.", style: TextStyle(fontSize: 16)))
              : ListView.separated(
                  itemCount: testesFiltrados.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1),
                  itemBuilder: (context, index) {
                    final TestModel teste = testesFiltrados[index];
                    return _historicoListTile(teste);
                  },
                ),
        ),
      ],
    );
  }

  // ✅ Aba dos Gráficos (Apenas o gráfico de Pizza)
  Widget _buildGraficosTab() {
    List<TestModel> testes = testesBox.values.toList();
    if (testes.isEmpty) {
      return const Center(child: Text("Nenhum dado para exibir gráficos."));
    }

    int passCount = testes.where((t) => t.command == "PASS").length;
    int normalCount = testes.length - passCount;

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        children: [
          const Text("Proporção de Testes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(value: passCount.toDouble(), color: Colors.green, title: "PASS", radius: 50),
                  PieChartSectionData(value: normalCount.toDouble(), color: Colors.red, title: "Normal", radius: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ UI para os filtros
  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Filtro por status
              DropdownButton<String>(
                value: filtroStatus,
                items: ["Todos", "PASS", "Normal"].map((status) {
                  return DropdownMenuItem(value: status, child: Text(status));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    filtroStatus = value!;
                  });
                },
              ),

              // Filtro por data
              IconButton(
                icon: const Icon(Icons.date_range),
                onPressed: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );

                  if (pickedDate != null) {
                    setState(() {
                      filtroData = pickedDate;
                    });
                  }
                },
              ),
            ],
          ),

          // Filtro por nível de bateria
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Bateria mínima:"),
              Slider(
                value: bateriaMinima,
                min: 0,
                max: 100,
                divisions: 10,
                label: "${bateriaMinima.toInt()}%",
                onChanged: (value) {
                  setState(() {
                    bateriaMinima = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ Filtragem e ordenação dos testes
  List<TestModel> _filtrarTestes() {
    List<TestModel> testes = testesBox.values.toList();

    // Filtra por status
    if (filtroStatus != "Todos") {
      testes = testes.where((t) => t.command == filtroStatus).toList();
    }

    // Filtra por nível de bateria
    testes = testes.where((t) => t.batteryLevel >= bateriaMinima).toList();

    // Filtra por data
    if (filtroData != null) {
      testes = testes.where((t) {
        return DateFormat('dd/MM/yyyy').format(t.timestamp) ==
            DateFormat('dd/MM/yyyy').format(filtroData!);
      }).toList();
    }

    // Ordena os mais recentes primeiro
    testes.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return testes;
  }

  // ✅ Gráfico de Barras de Testes por Dia
  Widget _buildGraficoBarras(Map<String, int> testesPorDia) {
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: testesPorDia.entries.map((e) {
            return BarChartGroupData(
              x: int.parse(e.key.split("/")[0]),
              barRods: [BarChartRodData(toY: e.value.toDouble(), color: Colors.blue, width: 16)],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ✅ Calcula a quantidade de testes por dia
  Map<String, int> _calcularTestesPorDia(List<TestModel> testes) {
    Map<String, int> testesPorDia = {};
    for (var teste in testes) {
      String dataFormatada = DateFormat('dd/MM').format(teste.timestamp);
      testesPorDia[dataFormatada] = (testesPorDia[dataFormatada] ?? 0) + 1;
    }
    return testesPorDia;
  }

  // ✅ Formatação de data
  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(dateTime);
  }

  // ✅ ListTile para exibir os dados
  Widget _historicoListTile(TestModel teste) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: teste.command == "PASS" ? Colors.green : Colors.red,
        child: Icon(teste.command == "PASS" ? Icons.check : Icons.close, color: Colors.white),
      ),
      title: Text("Resultado: ${teste.data}", style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text("Data: ${_formatDateTime(teste.timestamp)}\nBateria: ${teste.batteryLevel}% | Calibração: ${teste.statusCalibracao}"),
    );
  }

  // ✅ Exportação de CSV
  Future<void> _exportarCSV(List<TestModel> testes) async {
    if (testes.isEmpty) return;
    final Directory directory = await getApplicationDocumentsDirectory();
    final File file = File("${directory.path}/historico_testes.csv");
    List<String> linhas = ["Data, Resultado, Status, Bateria, Calibração"];
    for (var teste in testes) {
      linhas.add("${_formatDateTime(teste.timestamp)}, ${teste.data}, ${teste.command}, ${teste.batteryLevel}%, ${teste.statusCalibracao}");
    }
    await file.writeAsString(linhas.join("\n"));
    Share.shareXFiles([XFile(file.path)], text: "Histórico de Testes");
  }
}
