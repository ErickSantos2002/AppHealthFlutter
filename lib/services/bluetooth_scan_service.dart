import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class BluetoothScanService {
  final List<BluetoothDevice> _scannedDevices = [];
  final StreamController<List<BluetoothDevice>> _deviceController = StreamController.broadcast();
  bool _isScanning = false;

  Stream<List<BluetoothDevice>> get scannedDevicesStream => _deviceController.stream;

  Future<bool> isLocationEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<bool> requestPermissions() async {
  if (Platform.isAndroid) {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  } else {
    // iOS não precisa solicitar via permission_handler
    return true;
  }
}
  void _updateDevices() {
    _deviceController.add(List.from(_scannedDevices));
  }

  Future<void> startScan({Function? updateUI}) async {
    if (_isScanning) return; // Evita múltiplos scans simultâneos
    if (!await requestPermissions()) {
      print("❌ Permissões BLE negadas");
      return;
    }
    if (!await isLocationEnabled()) {
      print("❌ Localização desativada! Ative a localização e tente novamente.");
      return;
    }

    print("🔍 Iniciando escaneamento BLE...");
    _scannedDevices.clear();
    _isScanning = true;

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    FlutterBluePlus.scanResults.listen((results) {
      for (var result in results) {
        final device = result.device;
        final nome = device.name.toUpperCase();

        // Aceita dispositivos cujo nome começa com AL88, IBLOW, HLX ou DEIMOS
        final ehValido = nome.startsWith("AL88") ||
                        nome.startsWith("IBLOW") ||
                        nome.startsWith("HLX") ||
                        nome.startsWith("DEIMOS");

        final jaAdicionado = _scannedDevices.any((d) => d.id == device.id);

        if (ehValido && !jaAdicionado && device.name.isNotEmpty) {
          _scannedDevices.add(device);
          _updateDevices();
          print("✅ Dispositivo válido encontrado: ${device.name} - ${device.id}");
        }
      }
    });

    await Future.delayed(const Duration(seconds: 10));
    stopScan();
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    print("🛑 Escaneamento finalizado.");
  }
}
