import 'package:flutter_blue_plus/flutter_blue_plus.dart';

abstract class BluetoothHandler {
  Future<bool> connectToDevice(BluetoothDevice device);

  Future<void> discoverCharacteristics(
    BluetoothDevice device,
    Function(BluetoothCharacteristic?, BluetoothCharacteristic?) onCharacteristicsDiscovered,
  );

  Future<void> sendCommand(String comando, String dados);

  Future<void> disconnectDevice();

  BluetoothDevice? get connectedDevice;
  BluetoothCharacteristic? get writableCharacteristic;
  BluetoothCharacteristic? get notifiableCharacteristic;

  Map<String, dynamic>? processReceivedData(List<int> rawData);
}
