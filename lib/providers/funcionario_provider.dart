import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/funcionario_model.dart';

class FuncionarioNotifier extends StateNotifier<List<FuncionarioModel>> {
  FuncionarioNotifier() : super([]) {
    carregarFuncionarios(); // 🔹 Carrega funcionários ao iniciar
  }

  final Box<FuncionarioModel> _funcionarioBox = Hive.box<FuncionarioModel>('funcionarios');

  void carregarFuncionarios() {
    state = _funcionarioBox.values.toList(); // 🔹 Atualiza o estado com os dados do Hive
  }

  void adicionarFuncionario(FuncionarioModel novoFuncionario) {
    _funcionarioBox.put(novoFuncionario.id, novoFuncionario);
    carregarFuncionarios(); // 🔹 Força atualização do estado
  }

  void removerFuncionario(String funcionarioId) {
    _funcionarioBox.delete(funcionarioId);
    carregarFuncionarios(); // 🔹 Força atualização do estado
  }
}

final funcionarioProvider = StateNotifierProvider<FuncionarioNotifier, List<FuncionarioModel>>(
  (ref) => FuncionarioNotifier(),
);
