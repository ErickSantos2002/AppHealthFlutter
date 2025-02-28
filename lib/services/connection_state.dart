import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ConnectionStateManager {
  static bool isConnected = false;
  static BluetoothDevice? connectedDevice;
  static Timer? _connectionCheckTimer;

  // ✅ Inicia o monitoramento contínuo da conexão
  static void startMonitoringConnection({int intervalSeconds = 5}) {
    _connectionCheckTimer?.cancel(); // Cancela um timer existente
    _connectionCheckTimer = Timer.periodic(Duration(seconds: intervalSeconds), (timer) async {
      bool stillConnected = await checkDeviceConnection();
      if (!stillConnected) {
        print("⚠️ Dispositivo desconectado!");
        isConnected = false;
        connectedDevice = null;
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
}
