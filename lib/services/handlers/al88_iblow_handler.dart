import '../../providers/bluetooth_provider.dart';
import 'bluetooth_handler.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../bluetooth_manager.dart';

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

class Al88IblowHandler implements BluetoothHandler {
  final Ref ref;
  Al88IblowHandler(this.ref);

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writableCharacteristic;
  BluetoothCharacteristic? _notifiableCharacteristic;
  StreamSubscription<List<int>>? _notificationSubscription;

  /// 🔹 Retorna o dispositivo atualmente conectado
  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// 🔹 Retorna a característica de escrita BLE
  BluetoothCharacteristic? get writableCharacteristic =>
      _writableCharacteristic;

  /// 🔹 Retorna a característica de notificação BLE
  BluetoothCharacteristic? get notifiableCharacteristic =>
      _notifiableCharacteristic;

  /// 🔹 Conectar a um dispositivo BLE e atualizar o estado global
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      print(
        "🔗 Tentando conectar ao dispositivo: ${device.name} (${device.remoteId})",
      );
      await device.connect(autoConnect: false);
      _connectedDevice = device;

      print("✅ Conectado! Descobrindo serviços...");
      await discoverCharacteristics(device, (writable, notifiable) {
        ref
            .read(bluetoothProvider.notifier)
            .setCharacteristics(writable: writable, notifiable: notifiable);
      });

      return true;
    } catch (e) {
      print("❌ Erro ao conectar: $e");
      return false;
    }
  }

  /// 🔹 Descobrir características BLE e armazená-las no provider
  Future<void> discoverCharacteristics(
    BluetoothDevice device,
    Function(BluetoothCharacteristic?, BluetoothCharacteristic?)
    onCharacteristicsDiscovered,
  ) async {
    List<BluetoothService> services = await device.discoverServices();

    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        final uuid = characteristic.uuid.toString().toLowerCase();

        // 🟢 Aceita apenas a característica de escrita correta (fff2)
        if (_writableCharacteristic == null &&
            uuid.contains("fff2") &&
            (characteristic.properties.write ||
                characteristic.properties.writeWithoutResponse)) {
          _writableCharacteristic = characteristic;
          print("✅ Característica escrita selecionada: ${characteristic.uuid}");
        }

        // 🔄 Notificações (normalmente fff1)
        if (_notifiableCharacteristic == null &&
            characteristic.properties.notify) {
          _notifiableCharacteristic = characteristic;
          await _activateNotifications(characteristic);
        }
      }
    }

    onCharacteristicsDiscovered(
      _writableCharacteristic,
      _notifiableCharacteristic,
    );
  }

  /// 🔹 Ativar notificações BLE corretamente
  Future<void> _activateNotifications(
    BluetoothCharacteristic characteristic,
  ) async {
    _notificationSubscription?.cancel();
    _notificationSubscription = characteristic.value.listen((value) {
      if (value.isNotEmpty) {
        final parsed = processReceivedData(value);
        if (parsed != null) {
          // Notifica o provider centralizado
          ref.read(bluetoothProvider.notifier).updateDeviceInfo(parsed);
        }
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
        ref
            .read(bluetoothProvider.notifier)
            .setCharacteristics(writable: writable, notifiable: notifiable);
      });
    }
  }

  /// 🔹 Processar dados recebidos e armazenar no Hive
  @override
  Map<String, dynamic>? processReceivedData(List<int> rawData) {
    if (rawData.length < 5) return null;

    String commandCode = String.fromCharCodes(rawData.sublist(1, 4)).trim();
    String receivedData =
        String.fromCharCodes(
          rawData.sublist(4, rawData.length - 2),
        ).replaceAll("#", "").trim();
    final hasBattery = rawData.length == 20;
    int? battery = hasBattery ? rawData[rawData.length - 2] : null;

    return {"command": commandCode, "data": receivedData, "battery": battery};
  }

  @override
  Future<void> sendCommand(String command, String data) async {
    if (_writableCharacteristic == null) {
      print("❌ Característica de escrita não encontrada!");
      return;
    }

    final packet = createPacket(command, data);

    if (packet.length != 20) {
      print(
        "❌ Pacote inválido! Tamanho esperado: 20, recebido: ${packet.length}",
      );
      return;
    }

    // 🧪 Debug: mostrar o pacote antes de enviar
    final hex =
        packet
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ')
            .toUpperCase();
    final ascii =
        packet
            .map((b) => (b >= 32 && b <= 126) ? String.fromCharCode(b) : '.')
            .join();
    print("📦 Pacote (HEX): $hex");
    print("📦 Pacote (ASCII): $ascii");

    print("📤 Enviando comando: $command com dados: $data");

    try {
      await _writableCharacteristic!.write(packet, withoutResponse: true);
      print("✅ Comando $command enviado com sucesso!");
      print(
        "💡 Usando característica: ${_writableCharacteristic?.uuid} (write: ${_writableCharacteristic?.properties.write}, withoutResponse: ${_writableCharacteristic?.properties.writeWithoutResponse})",
      );
    } catch (e) {
      print("❌ Erro ao enviar comando: $e");
    }
  }

  List<int> createPacket(String command, String data) {
    final packet = List<int>.filled(20, 0); // Sempre 20 bytes

    packet[0] = 0x02; // STX
    final cmdBytes = ascii.encode(command.padRight(3).substring(0, 3));
    packet.setRange(1, 4, cmdBytes);

    // Preenchimento personalizado para comandos conhecidos
    if (command == "A01") {
      packet.setRange(4, 15, ascii.encode("INFORMATION")); // 11 bytes
      packet.setRange(15, 18, ascii.encode("###")); // 3 bytes
    } else if (command == "A02") {
      packet.setRange(4, 14, ascii.encode("CAL,UNLOCK")); // 10 bytes
      packet.setRange(14, 18, ascii.encode("####")); // 4 bytes
    } else if ((command == "A03" || command == "A04") && data.length == 1) {
      packet[4] = ascii.encode(data)[0]; // 1 byte
      packet.setRange(5, 18, ascii.encode("#############")); // 13 bytes
    } else if (command == "A20") {
      packet.setRange(4, 14, ascii.encode("TEST,START")); // 10 bytes
      packet.setRange(14, 18, ascii.encode("####")); // 4 bytes
    } else {
      // Fallback genérico para dados simples
      final payload = ascii.encode(data.padRight(13, "#").substring(0, 13));
      packet.setRange(4, 17, payload);
    }

    // Calcular e inserir BCC
    packet[18] = calculateBCC(packet);

    // ETX
    packet[19] = 0x03;

    return packet;
  }

  int calculateBCC(List<int> packet) {
    // Soma dos bytes entre índices 1 e 17 (exclui STX, BCC e ETX)
    int sum = 0;
    for (int i = 1; i < 18; i++) {
      sum += packet[i];
    }

    return (0x10000 - sum) % 256;
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
