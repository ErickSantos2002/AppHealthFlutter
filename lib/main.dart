import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ Importando Riverpod
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/main_screen.dart';
import 'screens/perfil_screen.dart';
import 'screens/login_screen.dart';
import 'models/test_model.dart';
import 'models/funcionario_model.dart';
import 'theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  //await Hive.deleteBoxFromDisk('testes');
  //await Hive.deleteBoxFromDisk('funcionarios');
  Hive.registerAdapter(TestModelAdapter());
  await Hive.openBox<TestModel>('testes');
  Hive.registerAdapter(FuncionarioModelAdapter());
  await Hive.openBox<FuncionarioModel>('funcionarios');

  runApp(
    ProviderScope( // ✅ Agora o Riverpod gerencia os providers
      child: const MeuAppBLE(),
    ),
  );
}

class MeuAppBLE extends ConsumerWidget {
  const MeuAppBLE({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider); // 🔹 Obtém o ThemeState
    final themeMode = themeState.themeMode; // 🔹 Acessa o themeMode dentro do ThemeState

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Meu App BLE",
      themeMode: themeMode, // 🔹 Agora passamos o ThemeMode correto
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const MainScreen(),
      routes: {
        "/perfil": (context) => const PerfilScreen(),
        "/login": (context) => const LoginScreen(),
      },
    );
  }
}
