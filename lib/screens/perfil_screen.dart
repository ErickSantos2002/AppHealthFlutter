import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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

  Future<void> _exportarFuncionarios() async {
    final box = Hive.box<FuncionarioModel>('funcionarios');
    final funcionarios = box.values.toList();

    if (funcionarios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nenhum funcionário para exportar.")),
      );
      return;
    }

    final List<List<dynamic>> rows = [
      ["nome", "cargo", "cpf", "matricula", "informacao1", "informacao2"],
      ...funcionarios.map((f) => [
        f.nome,
        f.cargo,
        f.cpf ?? '',
        f.matricula ?? '',
        f.informacao1 ?? '',
        f.informacao2 ?? '',
      ])
    ];

    final csv = const ListToCsvConverter().convert(rows);

    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/funcionarios_exportados.csv';
    final file = File(filePath);
    await file.writeAsString(csv);

    await Share.shareXFiles([XFile(filePath)], text: 'Funcionários exportados');
  }

  Future<void> _importarFuncionariosCSV() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.bytes == null) return;

    try {
      final Uint8List fileBytes = result.files.single.bytes!;
      final csvData = const Utf8Decoder().convert(fileBytes);
      final rows = const CsvToListConverter().convert(csvData, eol: '\n');

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        final nome = row[0]?.toString() ?? "";
        final cargo = row[1]?.toString() ?? "";
        final cpf = row[2]?.toString() ?? "";
        final matricula = row[3]?.toString() ?? "";
        final info1 = row[4]?.toString() ?? "";
        final info2 = row[5]?.toString() ?? "";

        if (nome.isEmpty) continue;

        final funcionario = FuncionarioModel.novoFuncionario(
          nome: nome,
          cargo: cargo,
          cpf: cpf,
          matricula: matricula,
          informacao1: info1,
          informacao2: info2,
        );

        Hive.box<FuncionarioModel>('funcionarios').put(funcionario.id, funcionario);
      }

      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Funcionários importados com sucesso!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao importar: $e")),
      );
    }
  }

  void _adicionarFuncionario({FuncionarioModel? funcionario, int? index}) {
    showDialog(
      context: context,
      builder: (context) {
        bool mostrarInfo1 = funcionario?.informacao1 != null && funcionario!.informacao1!.isNotEmpty;
        bool mostrarInfo2 = funcionario?.informacao2 != null && funcionario!.informacao2!.isNotEmpty;
        String nome = funcionario?.nome ?? "";
        String cargo = funcionario?.cargo ?? "";
        String cpf = funcionario?.cpf ?? "";
        String matricula = funcionario?.matricula ?? "";

        final cpfController = TextEditingController(text: cpf);
        final matriculaController = TextEditingController(text: matricula);
        final info1Controller = TextEditingController(text: funcionario?.informacao1 ?? "");
        final info2Controller = TextEditingController(text: funcionario?.informacao2 ?? "");
        final nomeController = TextEditingController(text: nome);
        final cargoController = TextEditingController(text: cargo);

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(funcionario == null ? "Adicionar Funcionário" : "Editar Funcionário"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(labelText: "Nome"),
                      onChanged: (value) => nome = value,
                    ),
                    TextField(
                      controller: cargoController,
                      decoration: const InputDecoration(labelText: "Cargo (Opcional)"),
                      onChanged: (value) => cargo = value,
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

                    // Campos adicionais dinâmicos
                    if (mostrarInfo1)
                      TextField(
                        controller: info1Controller,
                        decoration: const InputDecoration(labelText: "Informação Adicional 1"),
                      ),
                    if (mostrarInfo2)
                      TextField(
                        controller: info2Controller,
                        decoration: const InputDecoration(labelText: "Informação Adicional 2"),
                      ),
                    if (!mostrarInfo1 || !mostrarInfo2)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text("Adicionar Informação"),
                          onPressed: () {
                            setState(() {
                              if (!mostrarInfo1) {
                                mostrarInfo1 = true;
                              } else if (!mostrarInfo2) {
                                mostrarInfo2 = true;
                              }
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
                TextButton(
                  onPressed: () {
                    nome = nomeController.text;
                    cargo = cargoController.text;
                    cpf = cpfController.text;
                    matricula = matriculaController.text;

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
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      nome: nome,
                      cargo: cargo,
                      cpf: cpf,
                      matricula: matricula,
                      informacao1: mostrarInfo1 ? info1Controller.text.trim() : null,
                      informacao2: mostrarInfo2 ? info2Controller.text.trim() : null,
                    );


                    if (funcionario == null) {
                      funcionariosBox.add(novoFuncionario);
                    } else {
                      funcionariosBox.putAt(index!, novoFuncionario);
                    }

                    setState(() {}); // Atualiza a tela principal
                    Navigator.pop(context);
                  },
                  child: Text(funcionario == null ? "Adicionar" : "Salvar"),
                ),
              ],
            );
          },
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
            icon: const Icon(Icons.file_upload),
            tooltip: "Importar CSV",
            onPressed: _importarFuncionariosCSV,
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: "Exportar CSV",
            onPressed: _exportarFuncionarios,
          ),
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
