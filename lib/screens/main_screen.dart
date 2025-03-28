import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'perfil_screen.dart';
import 'historico_screen.dart';
import 'informacoes_dispositivo_screen.dart';
import 'configuracoes_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const PerfilScreen(),
    const HistoricoScreen(),
    const InformacoesDispositivoScreen(),
    const ConfiguracoesScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack( // ✅ Substituímos o corpo por IndexedStack para preservar o estado das telas
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(context).unselectedWidgetColor,
      backgroundColor: Theme.of(context).colorScheme.surface,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Principal"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Perfil"),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: "Histórico"),
        BottomNavigationBarItem(icon: Icon(Icons.bluetooth), label: "Dispositivo"),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Configurações"),
      ],
    ),
    );
  }
}
