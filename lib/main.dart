import 'package:flutter/material.dart';
import 'package:Health_App/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ Importando Riverpod
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';
import 'screens/main_screen.dart';
import 'screens/perfil_screen.dart';
import 'models/test_model.dart';
import 'models/funcionario_model.dart';
import 'theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Hive.initFlutter();
  //await Hive.deleteBoxFromDisk('testes');
  //await Hive.deleteBoxFromDisk('funcionarios');
  Hive.registerAdapter(TestModelAdapter());
  await Hive.openBox<TestModel>('testes');
  Hive.registerAdapter(FuncionarioModelAdapter());
  await Hive.openBox<FuncionarioModel>('funcionarios');

  runApp(
    ProviderScope(
      // ✅ Agora o Riverpod gerencia os providers
      child: const MeuAppBLE(),
    ),
  );
}

class MeuAppBLE extends ConsumerWidget {
  const MeuAppBLE({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider); // Agora é diretamente ThemeMode

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Meu App BLE",
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const MainScreen(),
      routes: {"/perfil": (context) => const PerfilScreen()},
    );
  }
}
