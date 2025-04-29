import 'package:flutter/material.dart';
import 'package:Health_App/models/funcionario_model.dart';
import 'package:hive/hive.dart';
import '../providers/configuracoes_provider.dart';
import '../models/test_model.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/export_helper.dart';
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
  int _tabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";

  void _mostrarDetalhes(TestModel teste) {
    setState(() {
      testeSelecionado = teste;
      mostrandoDetalhes = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: 0,
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text(mostrandoDetalhes ? "Detalhes do Teste" : "Histórico de Testes"),
              leading: mostrandoDetalhes
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      mostrandoDetalhes = false;
                      testeSelecionado = null;
                    });
                  },
                )
              : null,
              bottom: mostrandoDetalhes
                  ? null
                  : TabBar(
                      onTap: (index) {
                        setState(() => _tabIndex = index);
                      },
                      tabs: const [
                        Tab(icon: Icon(Icons.list), text: "Histórico"),
                        Tab(icon: Icon(Icons.star), text: "Favoritos"),
                      ],
                    ),
              actions: !mostrandoDetalhes
                  ? [
                      IconButton(
                        icon: const Icon(Icons.download),
                        tooltip: "Exportar Testes",
                        onPressed: () async {
                          try {
                            final historico = ref.read(historicoProvider);
                            final testes = _tabIndex == 0
                                ? historico.testesFiltrados
                                : historico.testesFavoritos;

                            if (testes.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Nenhum teste para exportar.")),
                              );
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Exportando dados...")),
                            );

                            await ExportHelper.exportarTestes(
                              testes: testes,
                              incluirStatusCalibracao: ref.read(configuracoesProvider).exibirStatusCalibracao,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Exportação concluída com sucesso!")),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Erro ao exportar: $e")),
                            );
                          }
                        },
                      ),
                    ]
                  : null,
            ),
            body: mostrandoDetalhes ? _buildDetalhesView() : _buildHistoricoView(),
          );
        },
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
    final funcionariosBox = Hive.box<FuncionarioModel>('funcionarios');

    if (searchQuery.isNotEmpty) {
      testesFiltrados = testesFiltrados.where((teste) {
        final funcionario = funcionariosBox.values.firstWhere(
          (f) => f.id == teste.funcionarioId,
          orElse: () => FuncionarioModel(id: "visitante", nome: teste.funcionarioNome),
        );

        return [
          teste.funcionarioNome,
          funcionario.cpf ?? "",
          funcionario.matricula ?? "",
          funcionario.informacao1 ?? "",
          funcionario.informacao2 ?? "",
          funcionario.cargo,
          teste.deviceName ?? "",
        ].any((campo) => campo.toLowerCase().contains(searchQuery));
      }).toList();
    }
    List<TestModel> favoritos = historicoState.testesFavoritos;
    Map<String, int> testesPorDia = _calcularTestesPorDia(testesFiltrados);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Buscar por nome, CPF, matrícula, info ou dispositivo...",
              hintStyle: TextStyle(
                color: Theme.of(context).hintColor.withOpacity(0.7),
              ),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).cardColor.withOpacity(0.9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            style: Theme.of(context).textTheme.bodyLarge,
            onChanged: (value) {
              setState(() {
                searchQuery = value.toLowerCase().trim();
              });
            },
          ),
        ),
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

                    final tolerancia = ref.watch(configuracoesProvider).tolerancia;
                    return TestCard(
                      teste: testeComFavorito,
                      tolerancia: tolerancia, // ✅ Passa a tolerância para colorir corretamente
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

              final tolerancia = ref.watch(configuracoesProvider).tolerancia;
              return TestCard(
                teste: testeComFavorito,
                tolerancia: tolerancia, // ✅ Passa a tolerância para colorir corretamente
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

    final funcionariosBox = Hive.box<FuncionarioModel>('funcionarios');
    final funcionario = funcionariosBox.values.firstWhere(
      (f) => f.id == testeSelecionado!.funcionarioId,
      orElse: () => FuncionarioModel(id: "visitante", nome: testeSelecionado!.funcionarioNome),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Exibir a foto se existir
          if (testeSelecionado!.photoPath != null &&
              File(testeSelecionado!.photoPath!).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(testeSelecionado!.photoPath!),
                height: 400, // Aumentado
                width: double.infinity,
                fit: BoxFit.contain, // Evita corte da imagem
              ),
            )
          else
            const Text("Nenhuma foto disponível", style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),

          const SizedBox(height: 16),

          _infoTile("Data", _formatDateTime(testeSelecionado!.timestamp)),
          _infoTile("Funcionário", funcionario.nome),
          if (funcionario.cargo.isNotEmpty) _infoTile("Cargo", funcionario.cargo),
          if ((funcionario.cpf ?? "").isNotEmpty) _infoTile("CPF", funcionario.cpf!),
          if ((funcionario.matricula ?? "").isNotEmpty) _infoTile("Matrícula", funcionario.matricula!),
          if ((funcionario.informacao1 ?? "").isNotEmpty) _infoTile("Informação 1", funcionario.informacao1!),
          if ((funcionario.informacao2 ?? "").isNotEmpty) _infoTile("Informação 2", funcionario.informacao2!),
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
                items: ["Todos", "Aprovados", "Rejeitados"].map((status) {
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

  // ✅ Formatação de data
  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(dateTime);
  }
}
