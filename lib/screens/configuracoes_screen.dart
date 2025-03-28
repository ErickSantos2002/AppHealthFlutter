import 'package:flutter/material.dart';
import 'package:flutter_hsapp/providers/historico_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
  String versaoApp = "1.0.0"; 

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

  void _abrirWhatsApp() async {
    final uri = Uri.parse("https://wa.me/message/M4IXBOMSG6V6K1");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Não foi possível abrir o WhatsApp")),
      );
    }
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

  Future<void> _exportarDados() async {
    Share.share("Exportação de dados em breve disponível!", subject: "Exportação de Dados");
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

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

          _buildSectionTitle("Configurações de Dados"),
          _buildButtonTile(
            title: "Limpar Histórico",
            subtitle: "Remover todos os testes armazenados",
            icon: Icons.delete,
            onTap: _confirmarLimparHistorico,
            isDestructive: true,
          ),

          _buildSectionTitle("Sobre o Aplicativo"),
          _buildInfoTile("Versão do App", versaoApp, Icons.info),
          _buildButtonTile(
            title: "Ajuda e Suporte",
            subtitle: "Entre em contato para suporte",
            icon: Icons.help,
            onTap: _abrirWhatsApp,
          ),
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

  Widget _buildDropdownTile() {
    return ListTile(
      leading: const Icon(Icons.language, color: Colors.blueAccent),
      title: const Text("Idioma", style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text("Alterar idioma do aplicativo"),
      trailing: DropdownButton<String>(
        value: idiomaSelecionado,
        items: ["Português", "Inglês", "Espanhol"].map((String idioma) {
          return DropdownMenuItem(value: idioma, child: Text(idioma));
        }).toList(),
        onChanged: (String? novoIdioma) {
          setState(() {
            idiomaSelecionado = novoIdioma!;
          });
        },
      ),
    );
  }
}
