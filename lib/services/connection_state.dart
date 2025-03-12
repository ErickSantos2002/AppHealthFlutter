import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart'; // ✅ Importa VoidCallback corretamente

class ConnectionStateManager {
  static bool isConnected = false;
  static BluetoothDevice? connectedDevice;
  static Timer? _connectionCheckTimer;
  static final List<VoidCallback> _observers = []; // ✅ Lista de ouvintes

  // ✅ Inicia o monitoramento contínuo da conexão
  static void startMonitoringConnection({int intervalSeconds = 5}) {
    _connectionCheckTimer?.cancel(); // Cancela um timer existente
    _connectionCheckTimer = Timer.periodic(Duration(seconds: intervalSeconds), (timer) async {
      bool stillConnected = await checkDeviceConnection();
      if (!stillConnected) {
        print("⚠️ Dispositivo desconectado!");
        updateConnectionStatus(false);
        _connectionCheckTimer?.cancel();
      }
    });
  }

  // ✅ Verifica se o dispositivo ainda está conectado
  static Future<bool> checkDeviceConnection() async {
    if (connectedDevice == null) return false;
    List<BluetoothDevice> connectedDevices = await FlutterBluePlus.connectedSystemDevices;
    return connectedDevices.any((device) => device.remoteId == connectedDevice!.remoteId);
  }

  // ✅ Atualiza o estado da conexão e **notifica os ouvintes**
  static void updateConnectionStatus(bool status) {
    if (isConnected != status) {
      isConnected = status;
      _notifyListeners(); // Notifica quem estiver escutando
    }
  }

  // ✅ Notifica todas as telas ouvintes sobre mudanças na conexão
  static void _notifyListeners() {
    for (var observer in _observers) {
      observer();
    }
  }

  // ✅ Permite que telas adicionem ouvintes para mudanças no estado
  static void addListener(VoidCallback callback) {
    _observers.add(callback);
  }

  // ✅ Remove ouvintes quando a tela for fechada
  static void removeListener(VoidCallback callback) {
    _observers.remove(callback);
  }
}
