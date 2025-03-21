import 'dart:convert';
import 'dart:async';
import 'package:hive/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/test_model.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../providers/bluetooth_provider.dart';

Map<String, String> unidadeMedida = {
  "0": "g/L",
  "1": "‰",
  "2": "%BAC",
  "3": "mg/L",
  "4": "Decimal point 3-%BAC",
  "5": "mg/100mL",
  "6": "ug/100mL",
  "7": "ug/L",
};

// ✅ Variável para armazenar o último comando recebido
String? ultimoComandoRecebido;

class BluetoothManager {
  final Ref ref;
  BluetoothManager(this.ref);

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writableCharacteristic;
  BluetoothCharacteristic? _notifiableCharacteristic;
  StreamSubscription<List<int>>? _notificationSubscription;

  /// 🔹 Retorna o dispositivo atualmente conectado
  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// 🔹 Retorna a característica de escrita BLE
  BluetoothCharacteristic? get writableCharacteristic => _writableCharacteristic;

  /// 🔹 Retorna a característica de notificação BLE
  BluetoothCharacteristic? get notifiableCharacteristic => _notifiableCharacteristic;

  /// 🔹 Conectar a um dispositivo BLE e atualizar o estado global
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      print("🔗 Tentando conectar ao dispositivo: ${device.name} (${device.remoteId})");
      await device.connect(autoConnect: false);
      _connectedDevice = device;

      print("✅ Conectado! Descobrindo serviços...");
      await discoverCharacteristics(device, (writable, notifiable) {
        ref.read(bluetoothProvider.notifier).setCharacteristics(
          writable: writable,
          notifiable: notifiable,
        );
      });

      return true;
    } catch (e) {
      print("❌ Erro ao conectar: $e");
      return false;
    }
  }

  /// 🔹 Descobrir características BLE e armazená-las no provider
  Future<void> discoverCharacteristics(
      BluetoothDevice device, Function(BluetoothCharacteristic?, BluetoothCharacteristic?) onCharacteristicsDiscovered) async {
    List<BluetoothService> services = await device.discoverServices();

    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.write) {
          _writableCharacteristic = characteristic;
        }

        if (characteristic.properties.notify) {
          _notifiableCharacteristic = characteristic;
          await _activateNotifications(characteristic);
        }
      }
    }

    // ✅ Em vez de chamar diretamente o provider, chamamos a função de callback
    onCharacteristicsDiscovered(_writableCharacteristic, _notifiableCharacteristic);
  }


  /// 🔹 Ativar notificações BLE corretamente
  Future<void> _activateNotifications(BluetoothCharacteristic characteristic) async {
    _notificationSubscription?.cancel();
    _notificationSubscription = characteristic.value.listen((value) {
      if (value.isNotEmpty) {
        processReceivedData(value);
      }
    });

    try {
      await characteristic.setNotifyValue(true);
      print("✅ Notificações BLE ativadas!");
    } catch (e) {
      print("❌ Erro ao ativar notificações: $e");
    }
  }

  /// 🔹 Restaurar características BLE ao reabrir a conexão
  Future<void> restoreCharacteristics() async {
    if (_connectedDevice != null) {
      print("♻️ Restaurando características BLE...");
      await discoverCharacteristics(_connectedDevice!, (writable, notifiable) {
        ref.read(bluetoothProvider.notifier).setCharacteristics(
          writable: writable,
          notifiable: notifiable,
        );
      });
    }
  }

  /// 🔹 Processar dados recebidos e armazenar no Hive
  Map<String, dynamic>? processReceivedData(List<int> rawData) {
    if (rawData.length < 5) return null;

    String commandCode = String.fromCharCodes(rawData.sublist(1, 4)).trim();
    String receivedData = String.fromCharCodes(rawData.sublist(4, rawData.length - 2)).replaceAll("#", "").trim();
    int battery = rawData[rawData.length - 2];

    return {
      "command": commandCode,
      "data": receivedData,
      "battery": battery,
    };
  }

  /// 🔹 Enviar comando BLE ao dispositivo
  Future<void> sendCommand(String command, String data, int battery) async {
    if (_writableCharacteristic == null) {
      print("❌ Característica de escrita não encontrada!");
      return;
    }

    List<int> packet = createPacket(command, data, battery);
    print("📤 Enviando comando: $command com dados: $data");

    try {
      await _writableCharacteristic!.write(packet);
      print("✅ Comando $command enviado com sucesso!");
    } catch (e) {
      print("❌ Erro ao enviar comando: $e");
    }
  }

  /// 🔹 Criar pacote de dados BLE
  List<int> createPacket(String command, String data, int battery) {
    int stx = 0x02;
    int etx = 0x03;
    String commandCode = command.padRight(3);
    String paddedData = data.padRight(13, "#");
    int bcc = calculateBCC(commandCode, paddedData, battery);

    return [
      stx,
      ...utf8.encode(commandCode),
      ...utf8.encode(paddedData),
      battery,
      bcc,
      etx,
    ];
  }

  int calculateBCC(String commandCode, String data, int battery) {
    List<int> bytes = [
      ...utf8.encode(commandCode),
      ...utf8.encode(data),
      battery
    ];
    int sum = bytes.fold(0, (prev, byte) => prev + byte);
    return (~sum + 1) & 0xFF;
  }

  Future<void> disconnectDevice() async {
    if (_connectedDevice != null) {
      print("🔌 Desconectando dispositivo...");
      _notificationSubscription?.cancel();
      await _connectedDevice?.disconnect();
      _connectedDevice = null;
      _writableCharacteristic = null;
      _notifiableCharacteristic = null;

      print("✅ Dispositivo desconectado!");
    }
  }
}
