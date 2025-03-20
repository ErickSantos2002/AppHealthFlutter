import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/bluetooth_manager.dart';
import '../models/test_model.dart';
import '../providers/historico_provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 🔹 Estado global para gerenciar a conexão Bluetooth
class BluetoothState {
  final bool isConnected;
  final BluetoothDevice? connectedDevice;
  final BluetoothCharacteristic? writableCharacteristic;
  final BluetoothCharacteristic? notifiableCharacteristic;
  final String? selectedFuncionarioId;
  final String? lastCapturedPhotoPath; // 📸 Caminho da última foto tirada

  BluetoothState({
    required this.isConnected,
    this.connectedDevice,
    this.writableCharacteristic,
    this.notifiableCharacteristic,
    this.selectedFuncionarioId,
    this.lastCapturedPhotoPath,
  });

  /// 🔄 Atualiza o estado sem modificar a referência do provider
  BluetoothState copyWith({
    bool? isConnected,
    BluetoothDevice? connectedDevice,
    BluetoothCharacteristic? writableCharacteristic,
    BluetoothCharacteristic? notifiableCharacteristic,
    String? selectedFuncionarioId,
    String? lastCapturedPhotoPath,
  }) {
    return BluetoothState(
      isConnected: isConnected ?? this.isConnected,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      writableCharacteristic: writableCharacteristic ?? this.writableCharacteristic,
      notifiableCharacteristic: notifiableCharacteristic ?? this.notifiableCharacteristic,
      selectedFuncionarioId: selectedFuncionarioId ?? this.selectedFuncionarioId,
      lastCapturedPhotoPath: lastCapturedPhotoPath ?? this.lastCapturedPhotoPath,
    );
  }
}

/// 🔹 Notifier que gerencia o estado do Bluetooth e faz interface com o BluetoothManager
class BluetoothNotifier extends StateNotifier<BluetoothState> {
  final BluetoothManager _bluetoothManager;
  final Ref ref;

  BluetoothNotifier(this.ref)
      : _bluetoothManager = BluetoothManager(ref),
        super(BluetoothState(isConnected: false));

  /// 🔹 Método para selecionar um funcionário antes de iniciar o teste
  void selecionarFuncionario(String funcionarioId) {
    state = state.copyWith(selectedFuncionarioId: funcionarioId);
  }

  String get funcionarioSelecionado => state.selectedFuncionarioId ?? "Visitante";

  /// 🔹 Conecta a um dispositivo e atualiza o estado
  Future<bool> connectToDevice(BluetoothDevice device) async {
    bool success = await _bluetoothManager.connectToDevice(device);
    if (success) {
      state = state.copyWith(isConnected: true, connectedDevice: device);
    }
    return success;
  }

  /// 🔹 Atualiza as características BLE quando forem descobertas
  void setCharacteristics({
    BluetoothCharacteristic? writable,
    BluetoothCharacteristic? notifiable,
  }) {
    if (notifiable != null && notifiable != state.notifiableCharacteristic) {
      print("🔄 [bluetoothProvider] Atualizando característica de notificação global: ${notifiable.uuid}");
      state = state.copyWith(notifiableCharacteristic: notifiable);
    }

    if (writable != null && writable != state.writableCharacteristic) {
      print("✍️ [bluetoothProvider] Atualizando característica de escrita global: ${writable.uuid}");
      state = state.copyWith(writableCharacteristic: writable);
    }
  }

  Future<void> ensureNotificationsActive() async {
    if (state.notifiableCharacteristic != null) {
      await state.notifiableCharacteristic!.setNotifyValue(true);
      print("🔔 Notificações BLE reativadas!");
    } else {
      print("⚠️ Nenhuma característica de notificação encontrada no BluetoothProvider!");
    }
  }

  /// 🔹 Obtém informações do dispositivo após conexão
  Future<void> fetchDeviceInfo() async {
    if (!state.isConnected || state.writableCharacteristic == null) {
      print("❌ Dispositivo não conectado ou característica de escrita indisponível!");
      return;
    }

    print("📤 Enviando comandos para obter informações do dispositivo...");
    sendCommand("A01", "INFORMATION", 0);
    sendCommand("A03", "0", 0);
    sendCommand("A04", "0", 0);
  }

  /// 🔹 Envia um comando para o dispositivo
  Future<void> sendCommand(String command, String data, int battery) async {
    if (state.writableCharacteristic == null) {
      print("❌ Característica de escrita não disponível!");
      return;
    }
    await _bluetoothManager.sendCommand(command, data, battery);
  }

  /// 🔹 Restaura as características BLE
  Future<void> restoreCharacteristics() async {
    if (state.connectedDevice != null) {
      print("♻️ Restaurando características BLE...");
      await _bluetoothManager.discoverCharacteristics(state.connectedDevice!);
    }
  }

  /// 🔹 Desconecta o dispositivo e reseta o estado
  Future<void> disconnect() async {
    await _bluetoothManager.disconnectDevice();
    state = BluetoothState(isConnected: false);
  }

  /// 📌 Captura a resposta do dispositivo e salva os dados do teste
  void processReceivedData(List<int> rawData) {
    if (rawData.length < 20) {
      print("⚠️ Pacote inválido recebido.");
      return;
    }

    String commandCode = String.fromCharCodes(rawData.sublist(1, 4)).trim();
    String receivedData = String.fromCharCodes(rawData.sublist(4, 17)).replaceAll("#", "").trim();
    int battery = rawData[17];

    String translatedCommand = _translateCommand(commandCode);

    // 📌 Se for T11 (resultado do teste), salvar no histórico
    if (commandCode == "T11") {
      _salvarTeste(receivedData, battery);
    }
  }

  /// 🔹 Tradução dos comandos
  String _translateCommand(String command) {
    Map<String, String> commandTranslations = {
      "T01": "Contagem de uso após calibração",
      "T02": "Bloqueio de calibração",
      "T03": "Aquecendo o sensor",
      "T04": "Desligando",
      "T05": "Erro de bateria",
      "T06": "Aguardando sopro",
      "T07": "Assoprando",
      "T08": "Sopro insuficiente",
      "T09": "Erro do sensor",
      "T10": "Analisando",
      "T11": "Resultado do teste",
      "T12": "Modo de espera",
      "T16": "Solicitação da data atual",
      "T20": "Desligado",
      "B20": "Comando recebido",
    };
    return commandTranslations[command] ?? "Comando desconhecido";
  }

  /// 📌 Salvar o teste no banco de dados
  void _salvarTeste(String resultado, int bateria) {
    final partes = resultado.split(",");
    if (partes.length < 3) return;

    String unidade = _converterUnidade(partes[1]);
    String valor = partes[2];
    String statusCalibracao = partes[3] == "1" ? "Modo Calibração" : "Modo Normal";
    String resultadoFinal = "$valor $unidade";

    String funcionarioId = state.selectedFuncionarioId ?? "Visitante";

    final novoTeste = TestModel(
      timestamp: DateTime.now(),
      command: resultadoFinal,
      statusCalibracao: statusCalibracao,
      batteryLevel: bateria,
      funcionarioId: funcionarioId,
      funcionarioNome: funcionarioId == "Visitante" ? "Visitante" : funcionarioId,
      photoPath: state.lastCapturedPhotoPath,
    );

    ref.read(historicoProvider.notifier).adicionarTeste(novoTeste);
  }

  /// 🔹 Converte o código da unidade para string legível
  String _converterUnidade(String unidade) {
    List<String> unidades = ["g/L", "‰", "%BAC", "mg/L", "Dec %BAC", "mg/100mL", "µg/100mL", "µg/L"];
    int index = int.tryParse(unidade) ?? 0;
    return (index >= 0 && index < unidades.length) ? unidades[index] : "Unidade desconhecida";
  }
  /// 🔹 Criamos um provider global para o Bluetooth
  final bluetoothProvider = StateNotifierProvider<BluetoothNotifier, BluetoothState>(
    (ref) => BluetoothNotifier(ref),
  );
}
