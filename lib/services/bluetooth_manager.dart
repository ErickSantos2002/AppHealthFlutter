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
      await discoverCharacteristics(device);

      return true;
    } catch (e) {
      print("❌ Erro ao conectar: $e");
      return false;
    }
  }

  /// 🔹 Descobrir características BLE e armazená-las no provider
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
          await _activateNotifications(characteristic);
        }
      }
    }

    // 🔹 Atualiza as características no estado global
    ref.read(bluetoothProvider.notifier).setCharacteristics(
      writable: _writableCharacteristic,
      notifiable: _notifiableCharacteristic,
    );
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
      await discoverCharacteristics(_connectedDevice!);
    }
  }

  /// 🔹 Processar dados recebidos e armazenar no Hive
  void processReceivedData(List<int> rawData) {
    if (rawData.length < 5) {
      print("⚠️ Pacote muito curto para ser válido! Tamanho: ${rawData.length}");
      return;
    }

    String commandCode = String.fromCharCodes(rawData.sublist(1, 4)).trim();
    String receivedData = String.fromCharCodes(rawData.sublist(4, rawData.length - 2)).replaceAll("#", "").trim();
    int battery = rawData[rawData.length - 2]; // Captura o nível da bateria corretamente

    // ✅ Verifica se o comando já foi salvo para evitar duplicação
    if (commandCode == ultimoComandoRecebido) {
      print("⚠️ Teste duplicado detectado, ignorando...");
      return;
    }
    ultimoComandoRecebido = commandCode; // Atualiza o último comando salvo

    // 🔹 Corrigir separador decimal e remover caracteres indesejados
    receivedData = receivedData.replaceAll(",", ".").replaceAll(RegExp(r'[^0-9a-zA-Z.\s]'), '');

    // 🔹 Separar os dados recebidos corretamente
    List<String> dataParts = receivedData.split(',');

    if (dataParts.length < 4) {
      print("⚠️ Dados recebidos possuem menos de 4 partes, mas ainda serão processados: $receivedData");
    }

    // 🔹 Interpretar status do teste
    String statusTeste = (dataParts.isNotEmpty && dataParts[0] == "1") ? "PASS" : "Normal";

    // 🔹 Identificar unidade de medida
    String unidade = (dataParts.length > 1) ? unidadeMedida[dataParts[1]] ?? "Desconhecido" : "Desconhecido";

    // 🔹 Processar resultado corretamente
    String resultado = (dataParts.length > 2) ? dataParts[2] : "0.000";

    if (resultado.contains(RegExp(r'^\d+$'))) {
      resultado = (int.parse(resultado) / 1000).toStringAsFixed(3);
    }

    // 🔹 Verificar status da calibração
    String statusCalibracao = (dataParts.length > 3 && dataParts[3] == "0") ? "OK" : "Fora do período de calibração";

    // ✅ Criando um modelo para salvar os dados
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
