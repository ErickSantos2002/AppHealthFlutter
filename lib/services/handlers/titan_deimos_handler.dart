import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bluetooth_handler.dart';

class TitanDeimosHandler implements BluetoothHandler {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _writableCharacteristic;
  BluetoothCharacteristic? _notifiableCharacteristic;
  StreamSubscription<List<int>>? _notificationSubscription;
  final List<int> _receiveBuffer = [];

  static const uartServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const txCharUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
  static const rxCharUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
  static const notifyDescriptorUuid = '00002902-0000-1000-8000-00805f9b34fb';

  List<int> _deviceAddress = [
    0x99,
    0x99,
    0x99,
    0x99,
    0x99,
    0x99,
  ]; // Default: broadcast

  bool _handshakeComplete = false;

  final void Function(Map<String, dynamic>)? onData;

  TitanDeimosHandler({this.onData}) {
    setDeviceAddress([0x99, 0x99, 0x99, 0x99, 0x99, 0x99]);
  }

  Future<void> handshakeAfterConnect() async {
    _handshakeComplete = false;
    // 1. Envia FF02 (ler endereço do dispositivo) com endereço broadcast
    await sendCommand('FF02', '');
    await Future.delayed(const Duration(milliseconds: 400));
    // Aguarda handshake completar (receber resposta FF02 ou 5003)
    int tentativas = 0;
    while (!_handshakeComplete && tentativas < 10) {
      await Future.delayed(const Duration(milliseconds: 200));
      tentativas++;
    }
    // Após handshake, envia FF04 (status de conexão) para liberar o dispositivo
    if (_handshakeComplete) {
      print(
        '[TitanDeimosHandler] Handshake completo, enviando FF04 para liberar o dispositivo...',
      );
      await sendCommand('FF04', '01'); // 01 = conectado
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  @override
  Future<bool> connectToDevice(BluetoothDevice device) async {
    print(
      '[TitanDeimosHandler] Tentando conectar ao dispositivo: ${device.name} (${device.remoteId})',
    );
    _device = device;
    try {
      await device.connect(autoConnect: false);
      print('[TitanDeimosHandler] Conectado com sucesso!');
      // Não faz handshake aqui!
      return true;
    } catch (e) {
      print('[TitanDeimosHandler] Erro ao conectar: ${e.toString()}');
      return false;
    }
  }

  @override
  Future<void> disconnectDevice() async {
    print('[TitanDeimosHandler] Desconectando dispositivo...');
    _notificationSubscription?.cancel();
    if (_device != null) {
      await _device!.disconnect();
      print('[TitanDeimosHandler] Dispositivo desconectado!');
    }
    _device = null;
    _writableCharacteristic = null;
    _notifiableCharacteristic = null;
  }

  @override
  Future<void> discoverCharacteristics(
    BluetoothDevice device,
    Function(BluetoothCharacteristic?, BluetoothCharacteristic?)
    onCharacteristicsDiscovered,
  ) async {
    print('[TitanDeimosHandler] Descobrindo serviços/características...');
    List<BluetoothService> services = await device.discoverServices();
    print('[TitanDeimosHandler] Serviços encontrados: ${services.length}');
    for (BluetoothService service in services) {
      print('[TitanDeimosHandler] Serviço: ${service.uuid}');
      if (service.uuid.toString().toLowerCase() == uartServiceUuid) {
        for (BluetoothCharacteristic c in service.characteristics) {
          final uuid = c.uuid.toString().toLowerCase();
          print('[TitanDeimosHandler] Característica encontrada: ${uuid}');
          if (uuid == txCharUuid) {
            _writableCharacteristic = c;
            print(
              '[TitanDeimosHandler] Característica de escrita selecionada: ${c.uuid}',
            );
          } else if (uuid == rxCharUuid) {
            _notifiableCharacteristic = c;
            print(
              '[TitanDeimosHandler] Característica de notificação selecionada: ${c.uuid}',
            );
          }
        }
      }
    }
    if (_notifiableCharacteristic != null) {
      print('[TitanDeimosHandler] Ativando notificações...');
      await _notifiableCharacteristic!.setNotifyValue(true);
      BluetoothDescriptor? descriptor;
      try {
        descriptor = _notifiableCharacteristic!.descriptors.firstWhere(
          (d) => d.uuid.toString().toLowerCase() == notifyDescriptorUuid,
        );
      } catch (_) {
        descriptor = null;
      }
      if (descriptor != null) {
        print(
          '[TitanDeimosHandler] Escrevendo no descritor 0x2902 para ativar notificações...',
        );
        await descriptor.write([0x01, 0x00]);
      } else {
        print('[TitanDeimosHandler] Descritor 0x2902 não encontrado!');
      }
      _notificationSubscription = _notifiableCharacteristic!.value.listen((
        data,
      ) {
        print(
          '[TitanDeimosHandler] Notificação recebida: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
        );
        processReceivedData(data);
      });
    } else {
      print(
        '[TitanDeimosHandler] Característica de notificação não encontrada!',
      );
    }
    onCharacteristicsDiscovered(
      _writableCharacteristic,
      _notifiableCharacteristic,
    );
    // Agora sim, faz handshake após características disponíveis
    await handshakeAfterConnect();
  }

  @override
  Future<void> sendCommand(String command, String? value) async {
    if (!_handshakeComplete && command != 'FF04' && command != 'FF02') {
      print('[TitanDeimosHandler] Comando bloqueado até handshake completo!');
      return;
    }
    if (_writableCharacteristic == null) {
      print('[TitanDeimosHandler] Característica de escrita não encontrada!');
      return;
    }
    List<int> packet = _buildPacket(command, value);
    print(
      '[TitanDeimosHandler] Enviando comando: ${command}, valor: ${value ?? ''}',
    );
    print(
      '[TitanDeimosHandler] Pacote enviado (HEX): ${packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );
    await _writableCharacteristic!.write(
      Uint8List.fromList(packet),
      withoutResponse: true,
    );
  }

  void setDeviceAddress(List<int> address) {
    if (address.length == 6) {
      // Usa o endereço exatamente como recebido (pode ser ASCII)
      _deviceAddress = List<int>.from(address);
    }
  }

  List<int> _buildPacket(String command, String? value) {
    print(
      '[TitanDeimosHandler] Montando pacote para comando: $command, valor: ${value ?? ''}',
    );
    List<int> address;
    if ((command == 'FF02') || !_handshakeComplete) {
      address = [0x99, 0x99, 0x99, 0x99, 0x99, 0x99];
    } else {
      address = _deviceAddress;
    }
    final startByte = 0x68;
    List<int> frame = [];
    frame.add(startByte);
    frame.addAll(address);
    frame.add(startByte);

    if (command == 'FF04') {
      // FF04: comando de escrita, dataLen=3, payload=04 FF 01
      frame.add(0x04); // Controle: escrita
      frame.addAll([0x03, 0x00]); // DataLen: 3 bytes
      frame.add(0x04); // CMD_LSB
      frame.add(0xFF); // CMD_MSB
      frame.add(0x01); // Status=1 (conectado)
    } else {
      // Demais comandos: leitura padrão
      frame.add(0x01); // Controle: leitura
      frame.addAll([0x02, 0x00]); // DataLen: 2 bytes
      int cmdInt = int.parse(command, radix: 16);
      int cmdLsb = cmdInt & 0xFF;
      int cmdMsb = (cmdInt >> 8) & 0xFF;
      frame.add(cmdLsb);
      frame.add(cmdMsb);
    }
    // Checksum: soma de todos os bytes do frame até o último byte de dados
    int checksum = frame.fold(0, (sum, b) => (sum + b) & 0xFF);
    frame.add(checksum);
    frame.add(0x16); // End byte
    return frame;
  }

  @override
  Map<String, dynamic>? processReceivedData(List<int> data) {
    print(
      '[TitanDeimosHandler] processReceivedData chamada com: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );
    _receiveBuffer.addAll(data);
    while (_receiveBuffer.contains(0x16)) {
      int startIndex = _receiveBuffer.indexWhere((e) => e == 0x68);
      if (startIndex == -1 || _receiveBuffer.length < startIndex + 12) break;
      int endIndex = _receiveBuffer.indexWhere(
        (e) => e == 0x16,
        startIndex + 11,
      );
      if (endIndex == -1) break;
      final frame = _receiveBuffer.sublist(startIndex, endIndex + 1);
      print(
        '[TitanDeimosHandler] Frame detectado: ${frame.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );
      _receiveBuffer.removeRange(0, endIndex + 1);
      final result = _processCompleteFrame(frame);
      if (result != null) {
        // Se for resposta FF02, atualiza o endereço do dispositivo
        if (result['deviceAddress'] != null) {
          setDeviceAddress(result['deviceAddress']);
          _handshakeComplete = true;
          print(
            '[TitanDeimosHandler] Handshake completo! Endereço atualizado: ${_deviceAddress.map((b) => b.toRadixString(16)).join(' ')}',
          );
        }
        // Se for resposta FF04, apenas marca handshake como iniciado
        if (result['command'] == 'FF04') {
          // Não faz nada, só aguarda FF02
        }
        print(
          '[TitanDeimosHandler] Frame processado com sucesso: \\${result.toString()}',
        );
        if (onData != null) onData!(result);
        return result;
      } else {
        print('[TitanDeimosHandler] Frame inválido ou checksum incorreto!');
      }
    }
    return null;
  }

  Map<String, dynamic>? _processCompleteFrame(List<int> data) {
    print(
      '[TitanDeimosHandler] _processCompleteFrame chamada com: \\${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );
    if (data.length < 12 ||
        data[0] != 0x68 ||
        data[7] != 0x68 ||
        data.last != 0x16) {
      print('[TitanDeimosHandler] Frame não bate com o padrão esperado!');
      return null;
    }
    int length = data[9] + (data[10] << 8);
    int payloadStart = 11;
    int payloadEnd = payloadStart + length;
    int checksumPos = payloadEnd;
    int endPos = checksumPos + 1;
    if (data.length < endPos + 1) {
      print(
        '[TitanDeimosHandler] Frame menor que o esperado para o payload! data.length=\\${data.length}, esperado=\\${endPos + 1}',
      );
      return null;
    }
    List<int> payload = data.sublist(payloadStart, payloadEnd);
    int receivedChecksum = data[checksumPos];
    int calculatedChecksum = data
        .sublist(0, checksumPos)
        .fold(0, (sum, b) => (sum + b) & 0xFF);
    print(
      '[TitanDeimosHandler] Checksum recebido: \\${receivedChecksum}, calculado: \\${calculatedChecksum}',
    );
    if (receivedChecksum != calculatedChecksum) {
      print('[TitanDeimosHandler] Checksum inválido!');
      return null;
    }
    print(
      '[TitanDeimosHandler] Payload extraído: \\${payload.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    int control = data[8];
    // Se for resposta de dados (0x81), o comando está nos dois primeiros bytes do payload
    if (control == 0x81 && payload.length >= 2) {
      int cmdL = payload[0];
      int cmdH = payload[1];
      String cmdHex =
          (cmdH << 8 | cmdL).toRadixString(16).padLeft(4, '0').toUpperCase();
      List<int> realPayload = payload.length > 2 ? payload.sublist(2) : [];
      print(
        '[TitanDeimosHandler] [0x81] Comando de resposta extraído do payload: $cmdHex',
      );
      // --- HANDSHAKE ---
      if (!_handshakeComplete && cmdHex == 'FF02' && realPayload.length == 6) {
        print(
          '[TitanDeimosHandler] [Handshake] Endereço extraído do payload FF02: \\${realPayload.map((b) => b.toRadixString(16)).join(' ')}',
        );
        return {'deviceAddress': realPayload, 'command': cmdHex};
      }
      // --- RESPOSTAS DE DADOS ---
      if (cmdHex == 'FF00') {
        // Versão do firmware
        return {'firmware': utf8.decode(realPayload), 'command': cmdHex};
      } else if (cmdHex == 'FF02') {
        // Endereço do dispositivo
        if (realPayload.length == 6) {
          return {'deviceAddress': realPayload, 'command': cmdHex};
        }
      } else if (cmdHex == '9004') {
        // Bateria
        if (realPayload.length >= 2) {
          int batL = realPayload[0];
          int batH = realPayload[1];
          int battery = (batH * 256 + batL);
          return {'battery': battery, 'command': cmdHex};
        }
      } else if (cmdHex == '9005') {
        // Contador de uso
        if (realPayload.length >= 2) {
          int recL = realPayload[0];
          int recH = realPayload[1];
          int records = (recH * 256 + recL);
          return {'usageCounter': records, 'command': cmdHex};
        }
      } else if (cmdHex == '9007') {
        // Data de calibração
        if (realPayload.length >= 3) {
          int year = 2000 + realPayload[0];
          String month = realPayload[1].toString().padLeft(2, '0');
          String day = realPayload[2].toString().padLeft(2, '0');
          String date = '$year.$month.$day';
          return {'lastCalibrationDate': date, 'command': cmdHex};
        }
      } else if (cmdHex == 'FF04') {
        return {'command': cmdHex};
      } else if (cmdHex == 'FF01') {
        // Data/hora do dispositivo
        if (realPayload.length >= 6) {
          int year = 2000 + realPayload[0];
          String month = realPayload[1].toString().padLeft(2, '0');
          String day = realPayload[2].toString().padLeft(2, '0');
          String hour = realPayload[3].toString().padLeft(2, '0');
          String min = realPayload[4].toString().padLeft(2, '0');
          String sec = realPayload[5].toString().padLeft(2, '0');
          String dateTime = '$year.$month.$day $hour:$min:$sec';
          return {'deviceDateTime': dateTime, 'command': cmdHex};
        }
      } else if (cmdHex == '9002') {
        // Status do teste de álcool
        if (realPayload.isNotEmpty) {
          int status = realPayload[0];
          return {'testStatus': status, 'command': cmdHex};
        }
      } else if (cmdHex == '9003') {
        // Resultado do teste de álcool
        if (realPayload.length >= 2) {
          int valL = realPayload[0];
          int valH = realPayload[1];
          double result = (valH * 256 + valL) / 100.0;
          return {'testResult': result, 'command': cmdHex};
        }
      }
      // Default: retorna payload bruto
      return {'payload': realPayload, 'command': cmdHex};
    }

    // --- HANDSHAKE LEGADO (5003) ---
    String headerCmdHex =
        data[6].toRadixString(16).padLeft(2, '0').toUpperCase() +
        data[5].toRadixString(16).padLeft(2, '0').toUpperCase();
    if (!_handshakeComplete &&
        headerCmdHex == '5003' &&
        payload.length >= 6 &&
        payload[0] == 0x02 &&
        payload[1] == 0xFF) {
      List<int> addr = data.sublist(1, 7);
      print(
        '[TitanDeimosHandler] [Handshake] Endereço extraído do frame 5003: \\${addr.map((b) => b.toRadixString(16)).join(' ')}',
      );
      return {'deviceAddress': addr, 'command': headerCmdHex};
    }

    // --- ERRO PADRÃO (C1/C4) ---
    if (data[6] == 0xC1 || data[6] == 0xC4) {
      int errByte = payload.isNotEmpty ? payload[0] : 0;
      String errMsg = _parseErrorByte(errByte);
      print(
        '[TitanDeimosHandler] Erro recebido: $errMsg (0x${errByte.toRadixString(2).padLeft(8, '0')})',
      );
      return {
        'error': true,
        'errorCode': errByte,
        'errorMessage': errMsg,
        'command': headerCmdHex,
      };
    }

    // --- OUTROS COMANDOS (header) ---
    return {'payload': payload, 'command': headerCmdHex};
  }

  // Decodifica o byte de erro conforme protocolo
  String _parseErrorByte(int err) {
    if (err == 0) return 'Dados ilegais';
    List<String> msgs = [];
    if ((err & 0x01) != 0) msgs.add('Dados ilegais');
    if ((err & 0x02) != 0) msgs.add('Identificação de dados inválida');
    if ((err & 0x04) != 0) msgs.add('Erro de verificação de dados');
    if ((err & 0x08) != 0) msgs.add('Acesso ilegal');
    if ((err & 0x10) != 0) msgs.add('Erro de endereço do dispositivo');
    if ((err & 0x80) != 0) msgs.add('Erro desconhecido');
    if (msgs.isEmpty) msgs.add('Erro não especificado');
    return msgs.join(' / ');
  }

  @override
  BluetoothDevice? get connectedDevice => _device;
  @override
  BluetoothCharacteristic? get writableCharacteristic =>
      _writableCharacteristic;
  @override
  BluetoothCharacteristic? get notifiableCharacteristic =>
      _notifiableCharacteristic;
  bool get handshakeComplete => _handshakeComplete;
}
