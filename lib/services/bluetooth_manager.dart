import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'handlers/al88_iblow_handler.dart';
import 'handlers/bluetooth_handler.dart';

class BluetoothManager {
  final Ref ref;

  BluetoothManager(this.ref);

  late final BluetoothHandler _handler;

  Future<bool> connectToDevice(BluetoothDevice device) async {
    if (device.name.contains("AL88") || device.name.contains("iBlow")) {
      _handler = Al88IblowHandler(ref);
    } else {
      throw UnsupportedError("Dispositivo não suportado: ${device.name}");
    }

    return await _handler.connectToDevice(device);
  }

  Future<void> discoverCharacteristics(
    BluetoothDevice device,
    Function(BluetoothCharacteristic?, BluetoothCharacteristic?) onCharacteristicsDiscovered,
  ) async {
    await _handler.discoverCharacteristics(device, onCharacteristicsDiscovered);
  }

  Future<void> sendCommand(String comando, String dados) async {
    await _handler.sendCommand(comando, dados);
  }

  Future<void> disconnectDevice() async {
    await _handler.disconnectDevice();
  }

  BluetoothDevice? get connectedDevice => _handler.connectedDevice;

  BluetoothCharacteristic? get writableCharacteristic => _handler.writableCharacteristic;

  BluetoothCharacteristic? get notifiableCharacteristic => _handler.notifiableCharacteristic;

  Map<String, dynamic>? processReceivedData(List<int> rawData) {
    if (_handler is Al88IblowHandler) {
      return (_handler as Al88IblowHandler).processReceivedData(rawData);
    }
    return null;
  }
}