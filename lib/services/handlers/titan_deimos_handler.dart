import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bluetooth_handler.dart';

class TitanDeimosHandler implements BluetoothHandler {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;
  StreamSubscription<List<int>>? _notifySubscription;

  @override
  Future<bool> connectToDevice(BluetoothDevice device) async {
    _device = device;
    try {
      await _device!.connect();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> discoverCharacteristics(
    BluetoothDevice device,
    Function(BluetoothCharacteristic?, BluetoothCharacteristic) callback,
  ) async {
    List<BluetoothService> services = await device.discoverServices();

    final service = services.firstWhere(
      (s) => s.uuid.toString() == '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
    );

    _writeChar = service.characteristics.firstWhere(
      (c) => c.uuid.toString() == '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
    );

    _notifyChar = service.characteristics.firstWhere(
      (c) => c.uuid.toString() == '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
    );

    await _notifyChar!.setNotifyValue(true);
    print(
      '[TitanDeimosHandler] Notificação ativada para o characteristic: \\${_notifyChar!.uuid}',
    );

    _notifySubscription = _notifyChar!.onValueReceived.listen((data) {
      print('[TitanDeimosHandler] Dados recebidos automaticamente: \\${data}');
      processReceivedData(data);
    });

    // Antes do callback dentro de discoverCharacteristics:
    print('[HANDLER] Discover callback: writable=$_writeChar, notifiable=$_notifyChar');
    callback(_writeChar, _notifyChar!);
  }

  @override
  Future<void> disconnectDevice() async {
    await _notifySubscription?.cancel();
    print('[TitanDeimosHandler] Assinatura de notificação cancelada.');
    await _device?.disconnect();
  }

  @override
  Future<void> sendCommand(String command, String? value) async {
    switch (command) {
      case '9002':
        await _sendTitanCommand(0x9002);
        break;
      case '9003':
        await _sendTitanCommand(0x9003);
        break;
      case '9004':
        await _sendTitanCommand(0x9004);
        break;
      default:
        throw UnimplementedError('Comando não suportado no TitanDeimosHandler');
    }
  }

  Future<void> _sendTitanCommand(int commandCode) async {
    // Protocolo Titan/Deimos: 68 A0..A5 68 01 02 [CMD_L] [CMD_H] CS 16
    final packet = <int>[];
    packet.add(0x68); // start
    packet.addAll(List.filled(6, 0x00)); // endereço
    packet.add(0x68); // start de novo
    packet.add(0x01); // controle: 0x01 (app -> device)
    packet.add(0x02); // comprimento: 2 bytes
    packet.add(commandCode & 0xFF); // CMD_L
    packet.add((commandCode >> 8) & 0xFF); // CMD_H
    int checksum = 0x01 + 0x02 + (commandCode & 0xFF) + ((commandCode >> 8) & 0xFF);
    checksum = checksum & 0xFF;
    packet.add(checksum);
    packet.add(0x16); // end
    await _writeChar!.write(packet, withoutResponse: false);
  }

  @override
  Map<String, dynamic>? processReceivedData(List<int> data) {
    // Protocolo Titan:
    // 0x68, [A0-A5], 0x68, C, L, [DATA], CS, 0x16
    if (data.length < 12) {
      print('[TitanDeimosHandler] Pacote muito curto para protocolo Titan.');
      return null;
    }
    if (data[0] != 0x68 || data[7] != 0x68) {
      print('[TitanDeimosHandler] Start bits inválidos: data[0]=0x${data[0].toRadixString(16)}, data[7]=0x${data[7].toRadixString(16)}');
      return null;
    }
    final address = data.sublist(1, 7);
    final control = data[8];
    final length = data[9];
    if (data.length < 10 + length + 2) {
      print('[TitanDeimosHandler] Pacote incompleto: esperado ${10 + length + 2} bytes, recebido ${data.length}.');
      return null;
    }
    final payload = data.sublist(10, 10 + length);
    final receivedChecksum = data[10 + length];
    final endBit = data[11 + length];
    if (endBit != 0x16) {
      print('[TitanDeimosHandler] End bit inválido: 0x${endBit.toRadixString(16)}');
      return null;
    }
    // Checksum: soma de [control, length, payload...]
    int checksum = control + length;
    for (final b in payload) checksum += b;
    checksum = checksum & 0xFF;
    if (checksum != receivedChecksum) {
      print('[TitanDeimosHandler] Checksum inválido! Calculado: 0x${checksum.toRadixString(16)}, recebido: 0x${receivedChecksum.toRadixString(16)}');
      return null;
    }
    print('[TitanDeimosHandler] Pacote Titan válido. Endereço: ${address.map((b) => b.toRadixString(16)).join(":")}, Controle: 0x${control.toRadixString(16)}, Length: $length, Payload: $payload');
    switch (control) {
      case 0x02:
        return _handleFirmwareVersion(payload);
      case 0x03:
        return _handleUsageCounter(payload);
      case 0x04:
        return _handleTestResult(payload);
      default:
        print('[TitanDeimosHandler] Controle desconhecido: 0x${control.toRadixString(16)}');
        return null;
    }
  }

  Map<String, dynamic> _handleFirmwareVersion(List<int> payload) {
    // TODO: parsing real do firmware
    return {'firmware': payload};
  }

  Map<String, dynamic> _handleUsageCounter(List<int> payload) {
    // TODO: parsing real do contador de uso
    return {'usageCounter': payload};
  }

  Map<String, dynamic> _handleTestResult(List<int> payload) {
    // TODO: parsing real do resultado do teste
    return {'testResult': payload};
  }

  // Getters obrigatórios conforme a interface:

  @override
  BluetoothDevice? get connectedDevice => _device;

  @override
  BluetoothCharacteristic? get writableCharacteristic => _writeChar;

  @override
  BluetoothCharacteristic? get notifiableCharacteristic => _notifyChar;
}
