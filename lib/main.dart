import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/main_screen.dart';
import 'screens/perfil_screen.dart';
import 'screens/login_screen.dart'; // ✅ Importando a tela de login
import 'package:hive_flutter/hive_flutter.dart';
import 'models/test_model.dart';
import 'theme_provider.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  Hive.registerAdapter(TestModelAdapter());
  await Hive.openBox<TestModel>('testes');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => AuthProvider()),
      ],
      child: const MeuAppBLE(),
    ),
  );
}

class MeuAppBLE extends StatelessWidget {
  const MeuAppBLE({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Meu App BLE",
      themeMode: themeProvider.themeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const MainScreen(),
      routes: {
        "/perfil": (context) => const PerfilScreen(),
        "/login": (context) => const LoginScreen(), // ✅ Adicionando a rota de login
      },
    );
  }
}
