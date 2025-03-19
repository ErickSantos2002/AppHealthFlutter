import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/configuracoes_provider.dart';
import '../models/test_model.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/historico_provider.dart';
import '../widgets/test_card.dart'; // ✅ Importando o novo widget TestCard

class HistoricoScreen extends ConsumerStatefulWidget {
  const HistoricoScreen({super.key});

  @override
  ConsumerState<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends ConsumerState<HistoricoScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Duas abas: Testes e Gráficos
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Histórico de Testes"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list), text: "Histórico"),
              Tab(icon: Icon(Icons.star), text: "Favoritos"), // ✅ Alterado para Favoritos
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _exportarCSV(),
              tooltip: "Exportar Testes",
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildTestesTab(),
            _buildFavoritosTab(), // ✅ Agora exibe os favoritos
          ],
        ),
      ),
    );
  }

  // ✅ Aba dos Testes com lista e filtros
  Widget _buildTestesTab() {
    final historicoState = ref.watch(historicoProvider);
    List<TestModel> testesFiltrados = historicoState.testesFiltrados;
    Map<String, int> testesPorDia = _calcularTestesPorDia(testesFiltrados);

    return Column(
      children: [
        _buildFiltros(), // Filtros no topo
        _buildGraficoBarras(testesPorDia), // Gráfico de barras
        Expanded(
          child: testesFiltrados.isEmpty
              ? const Center(child: Text("Nenhum teste armazenado.", style: TextStyle(fontSize: 16)))
              : ListView.separated(
                  itemCount: testesFiltrados.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final TestModel teste = testesFiltrados[index];
                    return TestCard(teste: teste); // ✅ Agora usamos TestCard
                  },
                ),
        ),
      ],
    );
  }

  // ✅ Aba dos Gráficos (Agora guia de favoritos)
  Widget _buildFavoritosTab() {
    final historicoState = ref.watch(historicoProvider);
    List<TestModel> favoritos = historicoState.testesFavoritos;

    return favoritos.isEmpty
        ? const Center(child: Text("Nenhum teste favorito.", style: TextStyle(fontSize: 16)))
        : ListView.builder(
            itemCount: favoritos.length,
            itemBuilder: (context, index) {
              return TestCard(teste: favoritos[index]);
            },
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
                value: ref.watch(historicoProvider).filtroStatus,
                items: ["Todos", "PASS", "Normal"].map((status) {
                  return DropdownMenuItem(value: status, child: Text(status));
                }).toList(),
                onChanged: (value) {
                  ref.read(historicoProvider.notifier).atualizarFiltroStatus(value!);
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
                    ref.read(historicoProvider.notifier).atualizarFiltroData(pickedDate);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ Gráfico de Barras de Testes por Dia
  Widget _buildGraficoBarras(Map<String, int> testesPorDia) {
    List<MapEntry<String, int>> listaTestesPorDia = testesPorDia.entries.toList();

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          const Text(
            "Testes Realizados por Dia",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false, // 🔹 Remove linhas verticais desnecessárias
                  horizontalInterval: 5, // 🔹 Define intervalos melhores no eixo Y
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.5),
                    strokeWidth: 0.8,
                  ),
                ),
                borderData: FlBorderData(
                  border: const Border(
                    bottom: BorderSide(width: 1),
                    left: BorderSide(width: 1),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30, // 🔹 Mantém espaço para os valores do lado esquerdo
                      interval: 5, // 🔹 Intervalo correto para o eixo Y
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false), // ❌ 🔹 Removendo valores do lado direito
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < listaTestesPorDia.length) {
                          return Transform.rotate(
                            angle: -0.5, // 🔹 Rotaciona um pouco os rótulos para melhor encaixe
                            child: Text(
                              listaTestesPorDia[value.toInt()].key, // 🔹 Exibe a data corretamente
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                barGroups: listaTestesPorDia.asMap().entries.map(
                  (entry) => BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.value.toDouble(),
                        color: Colors.blue,
                        width: 14, // 🔹 Reduz um pouco a largura das barras
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ).toList(),
              ),
            ),
          ),

          // 🔹 Adicionando linha separadora entre o gráfico e os testes
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(
              thickness: 1.5,
              color: Colors.grey,
            ),
          ),
        ],
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

  // ✅ Exportação de CSV
  Future<void> _exportarCSV() async {
    final historicoState = ref.read(historicoProvider);

    // 🔹 Pergunta ao usuário se ele deseja exportar todos os testes ou apenas os favoritos
    bool? exportarFavoritos = await _mostrarDialogoExportacao(context);

    // ✅ Se o usuário tocou fora e não escolheu, simplesmente sai da função
    if (exportarFavoritos == null) return;

    List<TestModel> testes = exportarFavoritos
        ? historicoState.testesFavoritos
        : historicoState.testesFiltrados;

    if (testes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nenhum teste para exportar!")),
      );
      return;
    }

    // 🔹 Diretório para salvar o arquivo
    final Directory directory = await getApplicationDocumentsDirectory();
    final File file = File("${directory.path}/historico_testes.csv");

    // 🔹 Cabeçalho do CSV
    bool exibirCalibracao = ref.read(configuracoesProvider).exibirStatusCalibracao;
    List<String> linhas = ["Data, Resultado, Status${exibirCalibracao ? ', Calibração' : ''}"];

    for (var teste in testes) {
      linhas.add(
        "${_formatDateTime(teste.timestamp)}, ${teste.data}, ${teste.command}${exibirCalibracao ? ', ${teste.statusCalibracao}' : ''}",
      );
    }

    await file.writeAsString(linhas.join("\n"));

    // 🔹 Compartilhar o arquivo CSV
    Share.shareXFiles([XFile(file.path)], text: "Histórico de Testes Exportado");
  }

  /// 🔹 Mostra um diálogo perguntando se o usuário quer exportar favoritos ou todos os testes
  Future<bool?> _mostrarDialogoExportacao(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: true, // ✅ Permite fechar ao tocar fora
      builder: (context) {
        return AlertDialog(
          title: const Text("Exportar Testes"),
          content: const Text("Deseja exportar apenas os testes favoritos?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Exportar todos
              child: const Text("Todos"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true), // Exportar favoritos
              child: const Text("Apenas Favoritos"),
            ),
          ],
        );
      },
    );
  }

  // ✅ Formatação de data
  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(dateTime);
  }
}
