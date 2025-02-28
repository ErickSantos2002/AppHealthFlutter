import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class BluetoothService {
  final List<BluetoothDevice> _scannedDevices = [];
  BluetoothDevice? _connectedDevice;

  List<BluetoothDevice> get scannedDevices => _scannedDevices;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  Future<bool> isLocationEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<bool> requestPermissions() async {
    if (await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted &&
        await Permission.location.isGranted) {
      return true;
    }

    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<void> startScan({Function? updateUI}) async {
    if (!await requestPermissions()) {
      print("❌ Permissões BLE negadas");
      return;
    }

    if (!await isLocationEnabled()) {
      print("❌ Localização desativada! Ative a localização e tente novamente.");
      return;
    }

    if (!(await FlutterBluePlus.isScanningNow)) {
      await FlutterBluePlus.turnOn();
      print("🔵 Bluetooth ativado automaticamente!");
    }

    _scannedDevices.clear();
    print("🔍 Iniciando escaneamento BLE...");

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    FlutterBluePlus.scanResults.listen((results) {
      for (var result in results) {
        if (!_scannedDevices.any((d) => d.id == result.device.id)) {
          _scannedDevices.add(result.device);
          print("✅ Dispositivo encontrado: ${result.device.name} - ${result.device.id}");
          if (updateUI != null) updateUI(); // Atualiza a interface quando um novo dispositivo é encontrado
        }
      }
    });

    await Future.delayed(const Duration(seconds: 10));
    stopScan();
    print("🛑 Escaneamento finalizado.");
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    print("🛑 Escaneamento interrompido.");
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      print("🔗 Tentando conectar ao dispositivo: ${device.name} (${device.id})");
      await device.connect();
      _connectedDevice = device;
      FlutterBluePlus.stopScan();
      print("✅ Dispositivo conectado!");
    } catch (e) {
      print("❌ Erro ao conectar: $e");
    }
  }

  Future<void> disconnectDevice() async {
    if (_connectedDevice != null) {
      await _connectedDevice?.disconnect();
      print("🔌 Dispositivo desconectado!");
      _connectedDevice = null;
    }
  }
}
