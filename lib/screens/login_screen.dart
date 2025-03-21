import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context); // ✅ Voltar para a tela de perfil após login
          },
          child: const Text("Fazer Login"),
        ),
      ),
    );
  }
}
