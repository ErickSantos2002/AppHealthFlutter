import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cpf_cnpj_validator/cpf_validator.dart';
import '../models/funcionario_model.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  late Box<FuncionarioModel> funcionariosBox;
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    funcionariosBox = Hive.box<FuncionarioModel>('funcionarios');
  }

  void _adicionarFuncionario({FuncionarioModel? funcionario, int? index}) {
    showDialog(
      context: context,
      builder: (context) {
        String nome = funcionario?.nome ?? "";
        String cargo = funcionario?.cargo ?? "";
        String cpf = funcionario?.cpf ?? "";
        String matricula = funcionario?.matricula ?? "";
        
        final cpfController = TextEditingController(text: cpf);
        final matriculaController = TextEditingController(text: matricula);
        
        return AlertDialog(
          title: Text(funcionario == null ? "Adicionar Funcionário" : "Editar Funcionário"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: "Nome"),
                onChanged: (value) => nome = value,
                controller: TextEditingController(text: nome),
              ),
              TextField(
                decoration: const InputDecoration(labelText: "Cargo (Opcional)"),
                onChanged: (value) => cargo = value,
                controller: TextEditingController(text: cargo),
              ),
              TextField(
                controller: cpfController,
                decoration: const InputDecoration(labelText: "CPF"),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  String formattedCpf = CPFValidator.format(value);
                  cpfController.value = TextEditingValue(
                    text: formattedCpf,
                    selection: TextSelection.collapsed(offset: formattedCpf.length),
                  );
                  cpf = formattedCpf;
                },
              ),
              TextField(
                controller: matriculaController,
                decoration: const InputDecoration(labelText: "Matrícula"),
                keyboardType: TextInputType.text,
                onChanged: (value) => matricula = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () {
                if (nome.isEmpty || (cpf.isEmpty && matricula.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("É obrigatório preencher pelo menos CPF ou Matrícula.")),
                  );
                  return;
                }
                if (cpf.isNotEmpty && !CPFValidator.isValid(cpf)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("CPF inválido!")),
                  );
                  return;
                }
                for (var f in funcionariosBox.values) {
                  if (f.cpf == cpf && cpf.isNotEmpty && f != funcionario) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("CPF já cadastrado!")),
                    );
                    return;
                  }
                  if (f.matricula == matricula && matricula.isNotEmpty && f != funcionario) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Matrícula já cadastrada!")),
                    );
                    return;
                  }
                }
                final novoFuncionario = FuncionarioModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(), // 🔹 Gera um ID único baseado no tempo
                  nome: nome,
                  cargo: cargo,
                  cpf: cpf,
                  matricula: matricula,
                );
                if (funcionario == null) {
                  funcionariosBox.add(novoFuncionario);
                } else {
                  funcionariosBox.putAt(index!, novoFuncionario);
                }
                setState(() {});
                Navigator.pop(context);
              },
              child: Text(funcionario == null ? "Adicionar" : "Salvar"),
            ),
          ],
        );
      },
    );
  }

  void _removerFuncionario(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Exclusão"),
        content: const Text("Tem certeza que deseja excluir este funcionário?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              // 🔹 Buscar pelo ID e remover corretamente
              final funcionarioParaRemover = funcionariosBox.values.firstWhere(
                (f) => f.id == id,
                orElse: () => FuncionarioModel(id: "", nome: ""),
              );

              if (funcionarioParaRemover.id.isNotEmpty) {
                funcionariosBox.delete(funcionarioParaRemover.key);
                setState(() {});
                print("🗑️ Funcionário removido com sucesso: ${funcionarioParaRemover.nome}");
              } else {
                print("⚠️ Erro ao tentar remover funcionário!");
              }

              Navigator.pop(context);
            },
            child: const Text("Excluir", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Funcionários"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _adicionarFuncionario(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
                decoration: InputDecoration(
                  hintText: "Buscar funcionário...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true, // ✅ necessário para que fillColor funcione
                  fillColor: Colors.grey[200], // ✅ cor de fundo desejada
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: funcionariosBox.listenable(),
        builder: (context, Box<FuncionarioModel> box, _) {
          List<FuncionarioModel> funcionarios = box.values.toList(); // ✅ Agora é uma lista válida

          funcionarios.sort((a, b) => a.nome.compareTo(b.nome)); // Ordenando por nome
          return funcionarios.isEmpty
              ? const Center(child: Text("Nenhum funcionário cadastrado."))
              : ListView.builder(
                  itemCount: funcionarios.length,
                  itemBuilder: (context, index) {
                    List<FuncionarioModel> funcionariosList = funcionarios.toList();
                    final funcionario = funcionariosList[index];
                    return ListTile(
                      title: Text(funcionario.nome),
                      subtitle: Text("Cargo: ${funcionario.cargo.isNotEmpty ? funcionario.cargo : 'Não informado'} | CPF: ${funcionario.cpf} | Matrícula: ${funcionario.matricula}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _adicionarFuncionario(funcionario: funcionario, index: index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removerFuncionario(funcionario.id), // 🔹 Agora passamos o ID
                          ),
                        ],
                      ),
                    );
                  },
                );
        },
      ),
    );
  }
}
