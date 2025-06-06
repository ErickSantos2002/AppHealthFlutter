import 'package:Health_App/services/handlers/titan_deimos_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'handlers/al88_iblow_handler.dart';
import 'handlers/bluetooth_handler.dart';

class BluetoothManager {
  final Ref ref;

  BluetoothManager(this.ref);

  BluetoothHandler? _handler;

  Future<bool> connectToDevice(BluetoothDevice device) async {
    final name = device.name.toUpperCase();

    // Evita reinicializar o handler se ele já existe
    if (_handler == null) {
      if (name.contains("AL88") || name.contains("IBLOW")) {
        _handler = Al88IblowHandler(ref);
      } else if (name.contains("DEIMOS") || name.contains("HLX")) {
        _handler = TitanDeimosHandler();
      } else {
        throw UnsupportedError("Dispositivo não suportado: ${device.name}");
      }
    } else {
      debugPrint("BluetoothHandler já inicializado para ${device.name}");
    }

    return await _handler!.connectToDevice(device);
  }

  Future<void> discoverCharacteristics(
    BluetoothDevice device,
    Function(BluetoothCharacteristic?, BluetoothCharacteristic?)
    onCharacteristicsDiscovered,
  ) async {
    await _handler!.discoverCharacteristics(device, (writable, notifiable) {
      print(
        '[BluetoothManager] Características recebidas do handler: writable=[32m$writable[0m, notifiable=[34m$notifiable[0m',
      );
      if (notifiable != null) {
        notifiable.setNotifyValue(true);
      }
      onCharacteristicsDiscovered(writable, notifiable);
    });
  }

  Future<void> sendCommand(String comando, String dados) async {
    await _handler?.sendCommand(comando, dados);
  }

  Future<void> disconnectDevice() async {
    await _handler?.disconnectDevice();
  }

  BluetoothDevice? get connectedDevice => _handler?.connectedDevice;

  BluetoothCharacteristic? get writableCharacteristic =>
      _handler?.writableCharacteristic;

  BluetoothCharacteristic? get notifiableCharacteristic =>
      _handler?.notifiableCharacteristic;

  Map<String, dynamic>? processReceivedData(List<int> rawData) {
    return _handler?.processReceivedData(rawData);
  }
}
