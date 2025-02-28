import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart'; // ✅ Gerenciador de autenticação

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Perfil")),
      body: authProvider.isLoggedIn ? _buildLoggedInUI(context, authProvider) : _buildLoggedOutUI(context, authProvider),
    );
  }

  // ✅ Tela para usuários NÃO logados
  Widget _buildLoggedOutUI(BuildContext context, AuthProvider authProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_outline, size: 100, color: Colors.grey),
          const SizedBox(height: 20),
          const Text("Você não está logado.", style: TextStyle(fontSize: 18)),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              // ✅ Simula um login e atualiza a tela
              authProvider.login("Usuário Exemplo", "email@example.com", phone: "12345-6789");
            },
            child: const Text("Fazer Login"),
          ),
          const SizedBox(height: 10),
          const Text("Você pode continuar sem login, mas terá menos funcionalidades."),
        ],
      ),
    );
  }

  // ✅ Tela para usuários LOGADOS
  Widget _buildLoggedInUI(BuildContext context, AuthProvider authProvider) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // 🔹 Imagem de Perfil
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blueAccent,
                child: const Icon(Icons.person, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(authProvider.userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(authProvider.userEmail, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 🔹 Dados do Usuário
        _buildInfoTile("Nome", authProvider.userName, Icons.person),
        _buildInfoTile("E-mail", authProvider.userEmail, Icons.email),
        _buildInfoTile("Telefone", authProvider.userPhone ?? "Não informado", Icons.phone),

        const SizedBox(height: 20),

        // 🔹 Opções
        _buildButtonTile(
          title: "Editar Perfil",
          subtitle: "Alterar nome e telefone",
          icon: Icons.edit,
          onTap: () {
            // Adicionar funcionalidade de edição no futuro
          },
        ),
        _buildButtonTile(
          title: "Alterar Senha",
          subtitle: "Modificar senha de acesso",
          icon: Icons.lock,
          onTap: () {
            // Adicionar funcionalidade no futuro
          },
        ),
        _buildButtonTile(
          title: "Sair da Conta",
          subtitle: "Desconectar-se do aplicativo",
          icon: Icons.logout,
          onTap: () {
            authProvider.logout();
          },
          isDestructive: true,
        ),
      ],
    );
  }

  // ✅ Widget para exibir informações do usuário
  Widget _buildInfoTile(String title, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(value),
    );
  }

  // ✅ Widget para botões de ação
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
}
