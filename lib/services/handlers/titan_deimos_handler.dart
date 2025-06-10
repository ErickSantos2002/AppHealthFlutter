import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bluetooth_handler.dart';

class TitanDeimosHandler implements BluetoothHandler {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _writableCharacteristic;
  BluetoothCharacteristic? _notifiableCharacteristic;
  final List<int> deviceAddress = [
    0x99,
    0x99,
    0x99,
    0x99,
    0x99,
    0x99,
  ]; // broadcast temporário

  // Buffer para montar os frames completos
  final List<int> _receiveBuffer = [];

  @override
  Future<bool> connectToDevice(BluetoothDevice device) async {
    _device = device;
    try {
      await device.connect(autoConnect: false);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> disconnectDevice() async {
    if (_device != null) {
      await _device!.disconnect();
    }
  }

  @override
  Future<void> discoverCharacteristics(
    BluetoothDevice device,
    Function(BluetoothCharacteristic?, BluetoothCharacteristic?)
    onCharacteristicsDiscovered,
  ) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid.toString().toLowerCase() ==
          "6e400001-b5a3-f393-e0a9-e50e24dcca9e") {
        for (BluetoothCharacteristic c in service.characteristics) {
          if (c.uuid.toString().toLowerCase() ==
              "6e400002-b5a3-f393-e0a9-e50e24dcca9e") {
            _writableCharacteristic = c;
          } else if (c.uuid.toString().toLowerCase() ==
              "6e400003-b5a3-f393-e0a9-e50e24dcca9e") {
            _notifiableCharacteristic = c;
          }
        }
      }
    }
    if (_notifiableCharacteristic != null) {
      await _notifiableCharacteristic!.setNotifyValue(true);
    }
    onCharacteristicsDiscovered(
      _writableCharacteristic,
      _notifiableCharacteristic,
    );
  }

  @override
  Future<void> sendCommand(String command, String? value) async {
    int? function;
    switch (command) {
      case '9002':
        function = 0x0290;
        break;
      case '9003':
        function = 0x0590;
        break;
      case '9004':
        function = 0x0790;
        break;
      default:
        throw UnimplementedError('Comando não suportado no TitanDeimosHandler');
    }
    await sendTitanCommand(0x01, function);
  }

  Future<void> sendTitanCommand(
    int control,
    int function, [
    List<int> data = const [],
  ]) async {
    if (_writableCharacteristic == null) return;
    List<int> packet = [];

    packet.add(0x68);
    packet.addAll(deviceAddress);
    packet.add(0x68);
    packet.add(control);

    int length = data.length + 2;
    packet.add(length & 0xFF);
    packet.add((length >> 8) & 0xFF);

    packet.add(function & 0xFF);
    packet.add((function >> 8) & 0xFF);

    packet.addAll(data);

    int checksum = packet.fold(0, (sum, b) => (sum + b) & 0xFF);
    packet.add(checksum);
    packet.add(0x16);

    await _writableCharacteristic!.write(
      Uint8List.fromList(packet),
      withoutResponse: true,
    );
  }

  @override
  Map<String, dynamic>? processReceivedData(List<int> data) {
    print(
      '[TitanDeimosHandler] processReceivedData chamado com data: ' +
          data.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' '),
    );
    // Aqui é o "assembler"
    _receiveBuffer.addAll(data);
    print(
      '[TitanDeimosHandler] Buffer após adicionar: ' +
          _receiveBuffer
              .map((e) => e.toRadixString(16).padLeft(2, '0'))
              .join(' '),
    );

    while (_receiveBuffer.contains(0x16)) {
      int startIndex = _receiveBuffer.indexOf(0x68);
      int endIndex = _receiveBuffer.indexOf(0x16, startIndex);
      print(
        '[TitanDeimosHandler] Procurando frame: startIndex=$startIndex, endIndex=$endIndex',
      );

      if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
        print(
          '[TitanDeimosHandler] Frame inválido ou lixo no buffer, descartando até endIndex=$endIndex',
        );
        _receiveBuffer.removeRange(0, endIndex + 1);
        continue;
      }

      List<int> frame = _receiveBuffer.sublist(startIndex, endIndex + 1);
      print(
        '[TitanDeimosHandler] Frame extraído: ' +
            frame.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' '),
      );
      _receiveBuffer.removeRange(0, endIndex + 1);

      // Agora processamos o frame completo
      final result = _processCompleteFrame(frame);
      print(
        '[TitanDeimosHandler] Resultado do processamento do frame: $result',
      );
      if (result != null) {
        return result;
      }
    }
    print('[TitanDeimosHandler] Nenhum frame válido processado.');
    return null;
  }

  Map<String, dynamic>? _processCompleteFrame(List<int> data) {
    try {
      if (data.length < 12 ||
          data[0] != 0x68 ||
          data[7] != 0x68 ||
          data.last != 0x16) {
        print("[TitanDeimosHandler] Frame inválido");
        return null;
      }

      int control = data[8];
      int length = data[9] + (data[10] << 8);
      int functionGroup = data[11];
      int functionCode = data[12];

      // Verifica tamanho mínimo esperado
      if (data.length < 13 + (length - 2)) {
        print("[TitanDeimosHandler] Payload incompleto");
        return null;
      }

      List<int> payload = data.sublist(13, 13 + (length - 2));
      int receivedChecksum = data[data.length - 2];
      int calculatedChecksum = data
          .sublist(0, data.length - 2)
          .fold(0, (sum, b) => (sum + b) & 0xFF);

      if (receivedChecksum != calculatedChecksum) {
        print("[TitanDeimosHandler] Checksum inválido");
        return null;
      }

      // Trata frame de erro
      if (control == 0xC1) {
        int errByte = payload[0];
        print(
          "[TitanDeimosHandler] 📛 Resposta de erro recebida: 0x${errByte.toRadixString(2).padLeft(8, '0')}",
        );

        Map<int, String> errorBits = {
          0: "Illegal data",
          1: "Invalid data ID",
          2: "Data check error",
          3: "Illegal access",
          4: "Device address error",
          7: "Unknown error",
        };

        List<String> errors = [];
        errorBits.forEach((bit, desc) {
          if ((errByte & (1 << bit)) != 0) errors.add(desc);
        });

        return {'errorCode': errByte, 'errorBits': errors};
      }

      // Trata frame de sucesso
      String key =
          "${functionCode.toRadixString(16).padLeft(2, '0')}${functionGroup.toRadixString(16).padLeft(2, '0')}";

      switch (key) {
        case '00ff':
          String version = utf8.decode(payload);
          return {'firmware': version};
        case '0590':
          int totalTests = payload[1] * 256 + payload[0];
          return {'usageCounter': totalTests};
        case '0490':
          int battery = payload[1] * 256 + payload[0];
          return {'battery': battery};
        case '0390':
          int alcoholValue = payload[1] * 256 + payload[0];
          double bac = alcoholValue / 100.0;
          return {'testResult': bac};
        case '0790':
          String date = _parseDate(payload);
          return {'calibrationDate': date};
        case '0890':
          int tempByte = payload[0];
          int sign = (tempByte & 0x80) >> 7;
          int temp = tempByte & 0x7F;
          if (sign == 1) temp = -temp;
          return {'temperature': temp};
        default:
          print("[TitanDeimosHandler] Resposta não tratada: $key");
          return null;
      }
    } catch (e) {
      print("[TitanDeimosHandler] Erro no parsing: $e");
      return null;
    }
  }

  String _parseDate(List<int> payload) {
    if (payload.length < 3) return "Data inválida";
    int year = 2000 + payload[0];
    int month = payload[1];
    int day = payload[2];
    return "$day/$month/$year";
  }

  @override
  BluetoothDevice? get connectedDevice => _device;

  @override
  BluetoothCharacteristic? get writableCharacteristic =>
      _writableCharacteristic;

  @override
  BluetoothCharacteristic? get notifiableCharacteristic =>
      _notifiableCharacteristic;
}
