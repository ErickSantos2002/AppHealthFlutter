import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/funcionario_model.dart';

class FuncionarioNotifier extends StateNotifier<List<FuncionarioModel>> {
  FuncionarioNotifier() : super([]) {
    carregarFuncionarios();
  }

  void carregarFuncionarios() async {
    final box = await Hive.openBox<FuncionarioModel>('funcionarios');
    state = box.values.toList();
  }

  void adicionarFuncionario(String nome) async {
    final box = await Hive.openBox<FuncionarioModel>('funcionarios');
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final novoFuncionario = FuncionarioModel(id: id, nome: nome);
    await box.put(id, novoFuncionario);
    state = [...state, novoFuncionario];
  }
}

final funcionarioProvider = StateNotifierProvider<FuncionarioNotifier, List<FuncionarioModel>>(
  (ref) => FuncionarioNotifier(),
);
