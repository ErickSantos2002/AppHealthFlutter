import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🔹 Estado do tema (Light/Dark)
class ThemeState {
  final ThemeMode themeMode;

  ThemeState(this.themeMode);
}

/// 🔹 Notifier responsável por gerenciar o tema
class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(ThemeState(ThemeMode.light)) {
    _loadTheme();
  }

  /// Alterna o tema e salva no SharedPreferences
  Future<void> toggleTheme() async {
    final isDarkMode = state.themeMode == ThemeMode.light;
    state = ThemeState(isDarkMode ? ThemeMode.dark : ThemeMode.light);
    _saveTheme(isDarkMode);
  }

  /// 🔄 Carrega o tema salvo
  Future<void> _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isDarkMode = prefs.getBool('isDarkMode') ?? false;
    state = ThemeState(isDarkMode ? ThemeMode.dark : ThemeMode.light);
  }

  /// 💾 Salva a preferência do usuário
  Future<void> _saveTheme(bool isDarkMode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }
}

/// 🔹 Criando o provider global para o tema
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>(
  (ref) => ThemeNotifier(),
);
