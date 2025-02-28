import 'package:flutter/material.dart';

class InformacoesDispositivoScreen extends StatelessWidget {
  const InformacoesDispositivoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Informações do Dispositivo")),
      body: const Center(child: Text("Tela de Informações do Dispositivo")),
    );
  }
}
