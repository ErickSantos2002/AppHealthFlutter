import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🔹 Classe que gerencia o estado das configurações
class ConfiguracoesState {
  final bool exibirStatusCalibracao;
  final bool notificacoesAtivas; // ✅ Novo campo
  final bool fotoAtivada;
  final double tolerancia; // nível permitido de álcool

  ConfiguracoesState({
  required this.exibirStatusCalibracao,
  required this.notificacoesAtivas,
  required this.tolerancia,
  required this.fotoAtivada, // novo
});

  ConfiguracoesState copyWith({
    bool? exibirStatusCalibracao,
    bool? notificacoesAtivas,
    double? tolerancia,
    bool? fotoAtivada
  }) {
    return ConfiguracoesState(
      exibirStatusCalibracao: exibirStatusCalibracao ?? this.exibirStatusCalibracao,
      notificacoesAtivas: notificacoesAtivas ?? this.notificacoesAtivas,
      tolerancia: tolerancia ?? this.tolerancia,
      fotoAtivada: fotoAtivada ?? this.fotoAtivada,
    );
  }
}

/// 🔹 Notifier que gerencia as configurações no SharedPreferences
class ConfiguracoesNotifier extends StateNotifier<ConfiguracoesState> {
  ConfiguracoesNotifier()
      : super(ConfiguracoesState(exibirStatusCalibracao: false, notificacoesAtivas: false, tolerancia: 0.5,fotoAtivada: true)) {
    _carregarConfiguracoes();
  }

  Future<void> _carregarConfiguracoes() async {
    final prefs = await SharedPreferences.getInstance();
    bool exibir = prefs.getBool('exibirStatusCalibracao') ?? false;
    bool notificacoes = prefs.getBool('notificacoesAtivas') ?? false;
    double tolerancia = prefs.getDouble('tolerancia') ?? 0.05;
    if (tolerancia > 1.0) {
      // valor antigo inválido salvo como 500, por exemplo
      tolerancia = 0.05;
      await prefs.setDouble('tolerancia', tolerancia);
    }
    bool fotoAtivada = prefs.getBool('fotoAtivada') ?? true;

    state = state.copyWith(
      exibirStatusCalibracao: exibir,
      notificacoesAtivas: notificacoes,
      tolerancia: tolerancia,
      fotoAtivada: fotoAtivada,
    );
  }

  Future<void> alterarFotoAtivada(bool valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fotoAtivada', valor);
    state = state.copyWith(fotoAtivada: valor);
  }

  Future<void> alterarTolerancia(double valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tolerancia', valor);
    state = state.copyWith(tolerancia: valor);
  }

  Future<void> alterarExibirStatusCalibracao(bool valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('exibirStatusCalibracao', valor);
    state = state.copyWith(exibirStatusCalibracao: valor);
  }

  Future<void> alterarNotificacoes(bool valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificacoesAtivas', valor);
    state = state.copyWith(notificacoesAtivas: valor);
  }
}

/// 🔹 Criando o provider global das configurações
final configuracoesProvider = StateNotifierProvider<ConfiguracoesNotifier, ConfiguracoesState>(
  (ref) => ConfiguracoesNotifier(),
);
