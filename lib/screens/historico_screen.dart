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
  bool mostrandoDetalhes = false;
  TestModel? testeSelecionado;

  void _mostrarDetalhes(TestModel teste) {
    setState(() {
      testeSelecionado = teste;
      mostrandoDetalhes = true;
    });
  }

  void _voltarParaHistorico() {
    setState(() {
      testeSelecionado = null;
      mostrandoDetalhes = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(mostrandoDetalhes ? "Detalhes do Teste" : "Histórico de Testes"),
          leading: mostrandoDetalhes
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _voltarParaHistorico,
                )
              : null,
          bottom: mostrandoDetalhes
              ? null
              : const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.list), text: "Histórico"),
                    Tab(icon: Icon(Icons.star), text: "Favoritos"),
                  ],
                ),
          actions: !mostrandoDetalhes
              ? [
                  IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () => _exportarCSV(),
                    tooltip: "Exportar Testes",
                  ),
                ]
              : null,
        ),
        body: mostrandoDetalhes ? _buildDetalhesView() : _buildHistoricoView(),
      ),
    );
  }

  /// 🔹 Tela principal do histórico
  Widget _buildHistoricoView() {
    return TabBarView(
      children: [
        _buildTestesTab(),
        _buildFavoritosTab(),
      ],
    );
  }

  Widget _buildTestesTab() {
    final historicoState = ref.watch(historicoProvider);
    List<TestModel> testesFiltrados = historicoState.testesFiltrados;
    List<TestModel> favoritos = historicoState.testesFavoritos;
    Map<String, int> testesPorDia = _calcularTestesPorDia(testesFiltrados);

    return Column(
      children: [
        _buildFiltros(),
        _buildGraficoBarras(testesPorDia),
        Expanded(
          child: testesFiltrados.isEmpty
              ? const Center(child: Text("Nenhum teste armazenado.", style: TextStyle(fontSize: 16)))
              : ListView.separated(
                  itemCount: testesFiltrados.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final TestModel teste = testesFiltrados[index];

                    // ✅ Atualiza o status visual de favorito com base na lista
                    final isFavorito = favoritos.any((f) => f.key == teste.key);
                    final testeComFavorito = teste.copyWith().applyFavorito(isFavorito);

                    return TestCard(
                      teste: testeComFavorito,
                      onTap: _mostrarDetalhes,
                      onFavoriteToggle: () {
                        ref.read(historicoProvider.notifier).alternarFavorito(teste);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 🔹 Aba dos Favoritos
  Widget _buildFavoritosTab() {
    final historicoState = ref.watch(historicoProvider);
    List<TestModel> favoritos = historicoState.testesFavoritos;

    return favoritos.isEmpty
        ? const Center(child: Text("Nenhum teste favorito.", style: TextStyle(fontSize: 16)))
        : ListView.builder(
            itemCount: favoritos.length,
            itemBuilder: (context, index) {
              final teste = favoritos[index];

              // ✅ Garante que a estrela apareça corretamente
              final testeComFavorito = teste.copyWith().applyFavorito(true);

              return TestCard(
                teste: testeComFavorito,
                onTap: _mostrarDetalhes,
                onFavoriteToggle: () {
                  ref.read(historicoProvider.notifier).alternarFavorito(teste);
                },
              );
            },
          );
  }

  /// 🔹 Tela de detalhes do teste
  Widget _buildDetalhesView() {
    if (testeSelecionado == null) return const Center(child: Text("Erro ao carregar detalhes"));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Exibir a foto se existir
          if (testeSelecionado!.photoPath != null && File(testeSelecionado!.photoPath!).existsSync())
            Image.file(
              File(testeSelecionado!.photoPath!),
              height: 250,
              width: double.infinity,
              fit: BoxFit.cover,
            )
          else
            const Text("Nenhuma foto disponível", style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),

          const SizedBox(height: 10),

          // 🔹 Exibir todas as informações
          _infoTile("Data", _formatDateTime(testeSelecionado!.timestamp)),
          _infoTile("Funcionário", testeSelecionado!.funcionarioNome ?? "Visitante"),
          _infoTile("Resultado", testeSelecionado!.command),
          _infoTile("Dispositivo", testeSelecionado!.deviceName ?? "Desconhecido"),
          if (ref.watch(configuracoesProvider).exibirStatusCalibracao)
            _infoTile("Status de Calibração", testeSelecionado!.statusCalibracao),
        ],
      ),
    );
  }

  Widget _infoTile(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(valor, style: const TextStyle(fontSize: 16, color: Colors.blueAccent)),
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
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Text(value.toInt().toString()),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < listaTestesPorDia.length) {
                          return Transform.rotate(
                            angle: -0.5,
                            child: Text(listaTestesPorDia[value.toInt()].key),
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
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ).toList(),
              ),
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
    List<String> linhas = ["Data, Resultado, Status${exibirCalibracao ? ', Calibração' : ''}, Dispositivo"];

    for (var teste in testes) {
      linhas.add(
        "${_formatDateTime(teste.timestamp)}, ${teste.command}, ${teste.statusCalibracao}, ${teste.deviceName ?? 'Desconhecido'}"
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
