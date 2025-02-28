import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String _userName = "Usuário Anônimo";
  String _userEmail = "";
  String? _userPhone;

  bool get isLoggedIn => _isLoggedIn;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String? get userPhone => _userPhone;

  AuthProvider() {
    _loadUserData();
  }

  Future<void> login(String name, String email, {String? phone}) async {
    _isLoggedIn = true;
    _userName = name;
    _userEmail = email;
    _userPhone = phone;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userName', name);
    await prefs.setString('userEmail', email);
    if (phone != null) await prefs.setString('userPhone', phone);

    notifyListeners();
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _userName = "Usuário Anônimo";
    _userEmail = "";
    _userPhone = null;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    notifyListeners();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    _userName = prefs.getString('userName') ?? "Usuário Anônimo";
    _userEmail = prefs.getString('userEmail') ?? "";
    _userPhone = prefs.getString('userPhone');

    notifyListeners();
  }
}
