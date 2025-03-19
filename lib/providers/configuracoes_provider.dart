import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🔹 Classe que gerencia o estado das configurações
class ConfiguracoesState {
  final bool exibirStatusCalibracao;

  ConfiguracoesState({required this.exibirStatusCalibracao});

  ConfiguracoesState copyWith({bool? exibirStatusCalibracao}) {
    return ConfiguracoesState(
      exibirStatusCalibracao: exibirStatusCalibracao ?? this.exibirStatusCalibracao,
    );
  }
}

/// 🔹 Notifier que gerencia as configurações no SharedPreferences
class ConfiguracoesNotifier extends StateNotifier<ConfiguracoesState> {
  ConfiguracoesNotifier() : super(ConfiguracoesState(exibirStatusCalibracao: true)) {
    _carregarConfiguracoes();
  }

  /// 🔄 Carrega a configuração do SharedPreferences
  Future<void> _carregarConfiguracoes() async {
    final prefs = await SharedPreferences.getInstance();
    bool exibir = prefs.getBool('exibirStatusCalibracao') ?? true;
    state = state.copyWith(exibirStatusCalibracao: exibir);
  }

  /// 💾 Atualiza e salva a configuração
  Future<void> alterarExibirStatusCalibracao(bool novoValor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('exibirStatusCalibracao', novoValor);
    state = state.copyWith(exibirStatusCalibracao: novoValor);
  }
}

/// 🔹 Criando o provider global das configurações
final configuracoesProvider = StateNotifierProvider<ConfiguracoesNotifier, ConfiguracoesState>(
  (ref) => ConfiguracoesNotifier(),
);
