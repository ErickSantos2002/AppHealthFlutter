import 'dart:convert';
import 'dart:async';
import 'package:hive/hive.dart';
import '../models/test_model.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/connection_state.dart';

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
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writableCharacteristic;
  BluetoothCharacteristic? _notifiableCharacteristic;
  StreamSubscription<List<int>>? _notificationSubscription; // ✅ Armazena a assinatura

  BluetoothDevice? get connectedDevice => _connectedDevice;
  BluetoothCharacteristic? get writableCharacteristic => _writableCharacteristic;
  BluetoothCharacteristic? get notifiableCharacteristic => _notifiableCharacteristic;

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      print("🔗 Tentando conectar ao dispositivo: ${device.name} (${device.remoteId})");
      await device.connect(autoConnect: false);
      _connectedDevice = device;
      
      print("✅ Conectado! Descobrindo serviços...");
      await discoverCharacteristics(device);

      ConnectionStateManager.connectedDevice = device;
      ConnectionStateManager.isConnected = true;
      ConnectionStateManager.startMonitoringConnection(); // ✅ Inicia o monitoramento automático

      return true;
    } catch (e) {
      print("❌ Erro ao conectar: $e");
      return false;
    }
  }

  Future<void> discoverCharacteristics(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();

    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.write) {
          _writableCharacteristic = characteristic;
          print("✍️ Característica de escrita detectada!");
        }

        if (characteristic.properties.notify) {
          _notifiableCharacteristic = characteristic;
          print("📩 Característica de notificação detectada!");

          // ✅ Remove listener anterior antes de criar um novo
          _notificationSubscription?.cancel();
          _notificationSubscription = characteristic.value.listen((value) {
            if (value.isNotEmpty) {
              processReceivedData(value);
            }
          });

          await characteristic.setNotifyValue(true);
        }
      }
    }
  }

  // ✅ Método para restaurar características ao voltar para a tela
  Future<void> restoreCharacteristics() async {
    if (_connectedDevice != null) {
      print("♻️ Restaurando características BLE...");
      await discoverCharacteristics(_connectedDevice!);
    }
  }

  void processReceivedData(List<int> rawData) {
    if (rawData.length < 20) return;

    String commandCode = String.fromCharCodes(rawData.sublist(1, 4)).trim();
    String receivedData = String.fromCharCodes(rawData.sublist(4, 17)).replaceAll("#", "").trim();
    int battery = rawData[17];

    // ✅ Verifica se o comando já foi salvo para evitar duplicação
    if (commandCode == ultimoComandoRecebido) {
      print("⚠️ Teste duplicado detectado, ignorando...");
      return;
    }
    ultimoComandoRecebido = commandCode; // ✅ Atualiza o último comando salvo

    // ✅ Tratamento do dado recebido
    List<String> dataParts = receivedData.split(',');
    if (dataParts.length < 4) {
      print("❌ Dados recebidos inválidos: $receivedData");
      return;
    }

    // ✅ Interpretação dos valores
    String statusTeste = dataParts[0] == "1" ? "PASS" : "Normal";
    String unidade = unidadeMedida[dataParts[1]] ?? "Desconhecido";
    String resultado = dataParts[2];

    // ✅ Tratamento do resultado (removendo zeros desnecessários)
    if (resultado.contains(RegExp(r'^\d+$'))) {
      resultado = (int.parse(resultado) / 1000).toStringAsFixed(3);
    }

    String statusCalibracao = dataParts[3] == "0" ? "OK" : "Fora do período de calibração";

    // ✅ Criando um modelo para salvar
    TestModel teste = TestModel(
      command: statusTeste, 
      data: "$resultado $unidade",
      batteryLevel: battery,
      timestamp: DateTime.now(),
      statusCalibracao: statusCalibracao,
    );

    var box = Hive.box<TestModel>('testes');
    box.add(teste);

    print("✅ Teste salvo no histórico: $statusTeste - $resultado $unidade");
  }

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
      _notificationSubscription?.cancel(); // ✅ Cancela o listener ao desconectar
      await _connectedDevice?.disconnect();
      _connectedDevice = null;
      _writableCharacteristic = null;
      _notifiableCharacteristic = null;
      print("✅ Dispositivo desconectado!");
    }
  }
}