import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/test_model.dart';
import 'package:intl/intl.dart';

/// 🔹 Estado que gerencia os testes e os favoritos
class HistoricoState {
  final List<TestModel> testesFiltrados;
  final List<TestModel> testesFavoritos;
  final String filtroStatus;
  final DateTime? filtroData;

  HistoricoState({
    required this.testesFiltrados,
    required this.testesFavoritos,
    required this.filtroStatus,
    required this.filtroData,
  });

  HistoricoState copyWith({
    List<TestModel>? testesFiltrados,
    List<TestModel>? testesFavoritos,
    String? filtroStatus,
    DateTime? filtroData,
  }) {
    return HistoricoState(
      testesFiltrados: testesFiltrados ?? this.testesFiltrados,
      testesFavoritos: testesFavoritos ?? this.testesFavoritos,
      filtroStatus: filtroStatus ?? this.filtroStatus,
      filtroData: filtroData ?? this.filtroData,
    );
  }
}

/// 🔹 Notifier que gerencia o histórico de testes e favoritos
class HistoricoNotifier extends StateNotifier<HistoricoState> {
  late Box<TestModel> _testesBox;
  late Box<String> _favoritosBox;

  HistoricoNotifier()
      : super(HistoricoState(
          testesFiltrados: [],
          testesFavoritos: [],
          filtroStatus: "Todos",
          filtroData: null,
        )) {
    carregarTestes();
  }

  /// 🔄 Carrega os testes e os favoritos do Hive
  Future<void> carregarTestes() async {
    _testesBox = await Hive.openBox<TestModel>('testes');
    _favoritosBox = await Hive.openBox<String>('favoritos');

    List<TestModel> testes = _testesBox.values.toList();
    List<TestModel> favoritos = testes
        .where((teste) => _favoritosBox.containsKey(teste.timestamp.toString()))
        .toList();

    state = state.copyWith(testesFavoritos: favoritos);
    _aplicarFiltros(testes);
  }

  /// 🔹 Aplica filtros nos testes
  void _aplicarFiltros(List<TestModel> testes) {
    List<TestModel> filtrados = testes;

    // Filtra por status
    if (state.filtroStatus != "Todos") {
      filtrados = filtrados.where((t) => t.command == state.filtroStatus).toList();
    }

    // Filtra por data
    if (state.filtroData != null) {
      filtrados = filtrados.where((t) {
        return DateFormat('dd/MM/yyyy').format(t.timestamp) ==
            DateFormat('dd/MM/yyyy').format(state.filtroData!);
      }).toList();
    }

    // Ordena os mais recentes primeiro
    filtrados.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    state = state.copyWith(testesFiltrados: filtrados);
  }

  /// 🔹 Atualiza o filtro de status
  void atualizarFiltroStatus(String novoStatus) {
    state = state.copyWith(filtroStatus: novoStatus);
    carregarTestes();
  }

  /// 🔹 Atualiza o filtro de data
  void atualizarFiltroData(DateTime? novaData) {
    state = state.copyWith(filtroData: novaData);
    carregarTestes();
  }

  /// 🔹 Reseta todos os filtros
  void limparFiltros() {
    state = HistoricoState(testesFiltrados: [], testesFavoritos: [], filtroStatus: "Todos", filtroData: null);
    carregarTestes();
  }

  /// ⭐ Adiciona ou remove um teste dos favoritos e salva no Hive
  void alternarFavorito(TestModel teste) {
    final favoritos = List<TestModel>.from(state.testesFavoritos);
    String testeKey = teste.timestamp.toString();

    if (favoritos.contains(teste)) {
      favoritos.remove(teste);
      _favoritosBox.delete(testeKey); // ❌ Remove do Hive
    } else {
      favoritos.add(teste);
      _favoritosBox.put(testeKey, "favorito"); // ✅ Salva no Hive
    }

    state = state.copyWith(testesFavoritos: favoritos);
  }
}

/// 🔹 Criando o provider global do histórico
final historicoProvider = StateNotifierProvider<HistoricoNotifier, HistoricoState>(
  (ref) => HistoricoNotifier(),
);
