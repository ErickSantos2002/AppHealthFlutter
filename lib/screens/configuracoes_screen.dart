import 'package:flutter/material.dart';
import 'package:Health_App/providers/historico_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/export_helper.dart';
import '../theme_provider.dart'; // ✅ Importando o novo provider
import '../providers/configuracoes_provider.dart'; // ✅ Importando as configurações
import 'package:url_launcher/url_launcher.dart';


class ConfiguracoesScreen extends ConsumerStatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  ConsumerState<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends ConsumerState<ConfiguracoesScreen> {
  bool notificacoesAtivadas = true;
  String idiomaSelecionado = "Português"; 
  String versaoApp = "1.3.1";

  @override
  void initState() {
    super.initState();
    _obterVersaoApp();
  }

  Future<void> _obterVersaoApp() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      versaoApp = packageInfo.version;
    });
  }

  void _enviarEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'suporte@healthsafety.com.br',
      query: 'subject=Suporte App BLE&body=Olá, preciso de ajuda com...',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Não foi possível abrir o app de e-mail")),
      );
    }
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.archive),
            title: const Text("Exportar testes + fotos (ZIP)"),
            onTap: () {
              Navigator.pop(context);
              _exportarDados(tipo: 'zip');
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text("Exportar apenas testes (PDF)"),
            onTap: () {
              Navigator.pop(context);
              _exportarDados(tipo: 'pdf');
            },
          ),
          ListTile(
            leading: const Icon(Icons.table_chart),
            title: const Text("Exportar apenas testes (Excel)"),
            onTap: () {
              Navigator.pop(context);
              _exportarDados(tipo: 'xls');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarLimparHistorico() async {
    bool? confirmar = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Limpar Histórico"),
          content: const Text("Tem certeza que deseja excluir todos os testes? Essa ação não pode ser desfeita."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () async {
                await Hive.deleteBoxFromDisk('testes');
                ref.invalidate(historicoProvider); // ✅ Força recarregar os testes
                Navigator.pop(context, true);
              },
              child: const Text("Limpar", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Histórico apagado com sucesso!")),
      );
    }
  }

  Future<void> _exportarDados({required String tipo}) async {
    try {
      final historico = ref.read(historicoProvider);
      final testes = historico.testesFiltrados + historico.testesFavoritos;
      final incluirStatus = ref.read(configuracoesProvider).exibirStatusCalibracao;

      if (testes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nenhum teste para exportar.")),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Exportando dados...")),
      );

      await ExportHelper.exportarTestesTipo(
        testes: testes.toSet().toList(), // remove duplicados
        incluirStatusCalibracao: incluirStatus,
        tipo: tipo,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Exportação concluída com sucesso!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao exportar: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final configuracoes = ref.watch(configuracoesProvider);
    final tolerancia = configuracoes.tolerancia;

    return Scaffold(
      appBar: AppBar(title: const Text("Configurações")),
      body: ListView(
        children: [
          const SizedBox(height: 10),

          _buildSectionTitle("Configurações Gerais"),
          _buildSwitchTile(
            title: "Notificações",
            subtitle: "Ativar ou desativar alertas de calibração/uso",
            icon: Icons.notifications,
            value: ref.watch(configuracoesProvider).notificacoesAtivas,
            onChanged: (value) {
              ref.read(configuracoesProvider.notifier).alterarNotificacoes(value);
            },
          ),
          _buildSwitchTile(
            title: "Exibir Status de Calibração",
            subtitle: "Mostrar ou ocultar o status da calibração no histórico",
            icon: Icons.assignment_turned_in,
            value: ref.watch(configuracoesProvider).exibirStatusCalibracao,
            onChanged: (value) {
              ref.read(configuracoesProvider.notifier).alterarExibirStatusCalibracao(value);
            },
          ),
          _buildSwitchTile(
            title: "🌙 Modo Escuro",
            subtitle: "Alternar entre tema claro e escuro",
            icon: Icons.dark_mode,
            value: themeMode == ThemeMode.dark, // ✅ Vai marcar corretamente
            onChanged: (_) {
              ref.read(themeProvider.notifier).toggleTheme(); // ✅ Alterna o tema
            },
          ),
          _buildToleranciaSlider(tolerancia),
          _buildSwitchTile(
            title: "Capturar Foto",
            subtitle: "Tirar uma foto automaticamente antes de cada teste",
            icon: Icons.camera_alt,
            value: configuracoes.fotoAtivada,
            onChanged: (value) {
              ref.read(configuracoesProvider.notifier).alterarFotoAtivada(value);
            },
          ),

          _buildSectionTitle("Configurações de Dados"),
          _buildButtonTile(
            title: "Limpar Histórico",
            subtitle: "Remover todos os testes armazenados",
            icon: Icons.delete,
            onTap: _confirmarLimparHistorico,
            isDestructive: true,
          ),
          _buildButtonTile(
            title: "Exportar Testes",
            subtitle: "Salvar e compartilhar os dados dos testes realizados",
            icon: Icons.upload_file,
            onTap: _showExportOptions,
          ),

          _buildSectionTitle("Sobre o Aplicativo"),
          _buildInfoTile("Versão do App", versaoApp, Icons.info),
          _buildInfoTile("Entre em contato para suporte 4007-1507", "Caso tenha alguma dúvida", Icons.help),
          _buildButtonTile(
            title: "Contato do Desenvolvedor",
            subtitle: "Enviar e-mail",
            icon: Icons.email,
            onTap: _enviarEmail,
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      secondary: Icon(icon, color: Colors.blueAccent),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildToleranciaSlider(double valorAtual) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            "Tolerância de Álcool",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Slider(
          value: valorAtual * 1000,
          min: 0,
          max: 90,
          divisions: 90,
          label: (valorAtual).toStringAsFixed(3),
          onChanged: (value) {
            ref.read(configuracoesProvider.notifier).alterarTolerancia(value / 1000);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text("Valor atual: ${valorAtual.toStringAsFixed(3)}"),
        ),
      ],
    );
  }

  Widget _buildButtonTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : Colors.blueAccent),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(value),
    );
  }

}
