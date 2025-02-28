import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/test_model.dart'; // ✅ Importando o modelo para registrar o adaptador
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();

  // ✅ Registrar o adaptador antes de abrir o banco
  Hive.registerAdapter(TestModelAdapter());

  // ✅ Apagar o banco apenas se precisar (remova essa linha se não quiser apagar sempre)
  // await Hive.deleteBoxFromDisk('testes');

  await Hive.openBox<TestModel>('testes'); // Criamos um banco para armazenar os testes

  runApp(const MeuAppBLE());
}

class MeuAppBLE extends StatelessWidget {
  const MeuAppBLE({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Meu App BLE",
      theme: AppTheme.lightTheme, // Corrigindo para chamar o tema corretamente
      home: const MainScreen(),
    );
  }
}
