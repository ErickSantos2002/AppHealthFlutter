import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🔹 Classe que gerencia o estado das configurações
class ConfiguracoesState {
  final bool exibirStatusCalibracao;
  final bool notificacoesAtivas; // ✅ Novo campo

  ConfiguracoesState({
    required this.exibirStatusCalibracao,
    required this.notificacoesAtivas,
  });

  ConfiguracoesState copyWith({
    bool? exibirStatusCalibracao,
    bool? notificacoesAtivas,
  }) {
    return ConfiguracoesState(
      exibirStatusCalibracao: exibirStatusCalibracao ?? this.exibirStatusCalibracao,
      notificacoesAtivas: notificacoesAtivas ?? this.notificacoesAtivas,
    );
  }
}

/// 🔹 Notifier que gerencia as configurações no SharedPreferences
class ConfiguracoesNotifier extends StateNotifier<ConfiguracoesState> {
  ConfiguracoesNotifier()
      : super(ConfiguracoesState(exibirStatusCalibracao: true, notificacoesAtivas: true)) {
    _carregarConfiguracoes();
  }

  Future<void> _carregarConfiguracoes() async {
    final prefs = await SharedPreferences.getInstance();
    bool exibir = prefs.getBool('exibirStatusCalibracao') ?? true;
    bool notificacoes = prefs.getBool('notificacoesAtivas') ?? true;
    state = state.copyWith(
      exibirStatusCalibracao: exibir,
      notificacoesAtivas: notificacoes,
    );
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
