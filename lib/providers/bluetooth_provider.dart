import 'package:Health_App/providers/configuracoes_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/funcionario_model.dart';
import '../services/bluetooth_manager.dart';
import '../models/test_model.dart';
import '../providers/historico_provider.dart';
import 'funcionario_provider.dart';
import '../models/device_info.dart';

/// 🔹 Estado global para gerenciar a conexão Bluetooth
class BluetoothState {
  final bool isConnected;
  final BluetoothDevice? connectedDevice;
  final BluetoothCharacteristic? writableCharacteristic;
  final BluetoothCharacteristic? notifiableCharacteristic;
  final String? selectedFuncionarioId;
  final String? lastCapturedPhotoPath; // 📸 Caminho da última foto tirada
  final DeviceInfo? deviceInfo;

  BluetoothState({
    required this.isConnected,
    this.connectedDevice,
    this.writableCharacteristic,
    this.notifiableCharacteristic,
    this.selectedFuncionarioId,
    this.lastCapturedPhotoPath,
    this.deviceInfo,
  });

  /// 🔄 Atualiza o estado sem modificar a referência do provider
  BluetoothState copyWith({
    bool? isConnected,
    BluetoothDevice? connectedDevice,
    BluetoothCharacteristic? writableCharacteristic,
    BluetoothCharacteristic? notifiableCharacteristic,
    String? selectedFuncionarioId,
    String? lastCapturedPhotoPath,
    DeviceInfo? deviceInfo,
  }) {
    return BluetoothState(
      isConnected: isConnected ?? this.isConnected,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      writableCharacteristic:
          writableCharacteristic ?? this.writableCharacteristic,
      notifiableCharacteristic:
          notifiableCharacteristic ?? this.notifiableCharacteristic,
      selectedFuncionarioId:
          selectedFuncionarioId ?? this.selectedFuncionarioId,
      lastCapturedPhotoPath:
          lastCapturedPhotoPath ?? this.lastCapturedPhotoPath,
      deviceInfo: deviceInfo ?? this.deviceInfo,
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
  void selecionarFuncionario(String? funcionarioId) {
    state = state.copyWith(selectedFuncionarioId: funcionarioId);
  }

  String get funcionarioSelecionado =>
      state.selectedFuncionarioId ?? "Visitante";

  /// 🔹 Conecta a um dispositivo e atualiza o estado
  Future<bool> connectToDevice(BluetoothDevice device) async {
    bool success = await _bluetoothManager.connectToDevice(device);
    if (success) {
      state = state.copyWith(isConnected: true, connectedDevice: device);

      // ✅ Agora usamos a função de callback para atualizar características BLE
      _bluetoothManager.discoverCharacteristics(device, (writable, notifiable) {
        setCharacteristics(writable: writable, notifiable: notifiable);
        listenToNotifications();
      });
    }
    return success;
  }

  /// 🔹 Atualiza as características BLE quando forem descobertas
  void setCharacteristics({
    BluetoothCharacteristic? writable,
    BluetoothCharacteristic? notifiable,
  }) {
    if (notifiable != null && notifiable != state.notifiableCharacteristic) {
      print(
        "🔄 [bluetoothProvider] Atualizando característica de notificação global: ${notifiable.uuid}",
      );
      state = state.copyWith(notifiableCharacteristic: notifiable);
    }

    if (writable != null && writable != state.writableCharacteristic) {
      print(
        "✍️ [bluetoothProvider] Atualizando característica de escrita global: ${writable.uuid}",
      );
      state = state.copyWith(writableCharacteristic: writable);
    }
  }

  Future<void> ensureNotificationsActive() async {
    if (state.notifiableCharacteristic != null) {
      await state.notifiableCharacteristic!.setNotifyValue(true);
      print("🔔 Notificações BLE reativadas!");
    } else {
      print(
        "⚠️ Nenhuma característica de notificação encontrada no BluetoothProvider!",
      );
    }
  }

  void listenToNotifications() {
    final characteristic = state.notifiableCharacteristic;
    if (characteristic == null) return;

    characteristic.value.listen((rawData) {
      final parsed = _bluetoothManager.processReceivedData(rawData);
      if (parsed == null) return;

      // Atualiza DeviceInfo centralizado
      updateDeviceInfo(parsed);

      // Mantém processamento de teste para iBlow
      _processarTeste(parsed);
    });
  }

  Future<void> _reiniciarIBlow() async {
    final device = state.connectedDevice;
    if (device != null) {
      await disconnect();
      await Future.delayed(
        const Duration(seconds: 1),
      ); // Pequeno delay antes de reconectar
      await connectToDevice(device);
    }
  }

  String?
  _ultimoResultadoSalvo; // Variável para rastrear o último resultado salvo

  void _processarTeste(Map<String, dynamic> parsed) {
    final command = parsed["command"];
    final data = parsed["data"];
    final battery = parsed["battery"];

    if (command == "T11") {
      final agora = DateTime.now();
      final partes = data.split(",");
      if (partes.length < 3) return;

      String unidade = _converterUnidade(partes[1]);
      String valor = partes[2];
      String statusCalibracao =
          partes.length > 3 && partes[3] == "1"
              ? "Modo Calibração"
              : "Modo Normal";

      final resultadoFinal = "$valor $unidade";

      // 🔹 Se for o mesmo resultado que já foi salvo, ignoramos
      if (_ultimoResultadoSalvo == resultadoFinal) {
        print("⚠️ Teste duplicado ignorado!");
        return;
      }

      _ultimoResultadoSalvo =
          resultadoFinal; // Atualiza o último resultado salvo

      // 🔹 Pegamos a lista de funcionários
      final funcionarios = ref.read(funcionarioProvider);

      // 🔹 Encontramos o funcionário correspondente ao ID selecionado
      final funcionario = funcionarios.firstWhere(
        (f) => f.id == state.selectedFuncionarioId,
        orElse: () => FuncionarioModel(id: "visitante", nome: "Visitante"),
      );

      final isAcima = TestModel(
        timestamp: agora,
        command: resultadoFinal,
        statusCalibracao: statusCalibracao,
        batteryLevel: battery,
        funcionarioId: funcionario.id,
        funcionarioNome: funcionario.nome,
        photoPath: state.lastCapturedPhotoPath,
        deviceName: state.connectedDevice?.name,
      ).isAcimaDaTolerancia(ref.read(configuracoesProvider).tolerancia);

      final novoTeste = TestModel(
        timestamp: agora,
        command: resultadoFinal,
        statusCalibracao: statusCalibracao,
        batteryLevel: battery,
        funcionarioId: funcionario.id,
        funcionarioNome: funcionario.nome,
        photoPath: state.lastCapturedPhotoPath,
        deviceName: state.connectedDevice?.name,
        isFavorito:
            isAcima, // ✅ Isso aqui faz ele já ir como favorito se passar o limite
      );

      state = state.copyWith(lastCapturedPhotoPath: null);

      ref.read(historicoProvider.notifier).adicionarTeste(novoTeste);
      print("✅ Teste salvo com sucesso: $resultadoFinal");
      // Se for iBlow, desconecta e reconecta para resetar interface
      final deviceName = state.connectedDevice?.name.toLowerCase() ?? "";
      if (deviceName.contains("iblow")) {
        print("🔁 iBlow detectado: reiniciando via reconexão...");
        _reiniciarIBlow();
      }
    }
  }

  Future<void> iniciarNovoTeste() async {
    _ultimoResultadoSalvo = null; // 🔹 Reseta o rastreador de testes duplicados
    print("🔄 Novo teste iniciado! Resetando controle de duplicação.");
  }

  /// 🔹 Obtém informações do dispositivo após conexão
  Future<void> fetchDeviceInfo() async {
    if (!state.isConnected || state.writableCharacteristic == null) {
      print(
        "❌ Dispositivo não conectado ou característica de escrita indisponível!",
      );
      return;
    }

    print("📤 Enviando comandos para obter informações do dispositivo...");
    sendCommand("A01", "INFORMATION");
    sendCommand("A03", "0");
    sendCommand("A04", "0");
  }

  /// 🔹 Envia um comando para o dispositivo
  Future<void> sendCommand(String command, String data) async {
    if (state.writableCharacteristic == null) {
      print("❌ Característica de escrita não disponível!");
      return;
    }
    await _bluetoothManager.sendCommand(command, data);
  }

  void capturarFoto(String caminhoFoto) {
    state = state.copyWith(lastCapturedPhotoPath: caminhoFoto);
    print("📸 Foto salva para o próximo teste: $caminhoFoto");
  }

  /// 🔹 Restaura as características BLE
  Future<void> restoreCharacteristics() async {
    if (state.connectedDevice != null) {
      print("♻️ Restaurando características BLE...");
      await _bluetoothManager.discoverCharacteristics(state.connectedDevice!, (
        writable,
        notifiable,
      ) {
        setCharacteristics(writable: writable, notifiable: notifiable);
        listenToNotifications();
      });
    }
  }

  /// 🔹 Desconecta o dispositivo e reseta o estado
  Future<void> disconnect() async {
    await _bluetoothManager.disconnectDevice();
    state = BluetoothState(isConnected: false);
  }

  /// 🔹 Converte o código da unidade para string legível
  String _converterUnidade(String unidade) {
    List<String> unidades = [
      "g/L",
      "‰",
      "%BAC",
      "mg/L",
      "Dec %BAC",
      "mg/100mL",
      "µg/100mL",
      "µg/L",
    ];
    int index = int.tryParse(unidade) ?? 0;
    return (index >= 0 && index < unidades.length)
        ? unidades[index]
        : "Unidade desconhecida";
  }

  /// Atualiza o DeviceInfo com novos dados processados
  void updateDeviceInfo(Map<String, dynamic> parsed) {
    final current = state.deviceInfo ?? DeviceInfo();
    DeviceInfo updated = current;

    if (parsed.containsKey('battery')) {
      updated = updated.copyWith(battery: parsed['battery']);
    }
    if (parsed.containsKey('usageCounter')) {
      updated = updated.copyWith(usageCounter: parsed['usageCounter']);
    }
    if (parsed.containsKey('calibrationDate') ||
        parsed.containsKey('lastCalibrationDate')) {
      updated = updated.copyWith(
        lastCalibrationDate:
            parsed['calibrationDate'] ?? parsed['lastCalibrationDate'],
      );
    }
    if (parsed.containsKey('testResult')) {
      updated = updated.copyWith(
        testResult:
            parsed['testResult'] is double
                ? parsed['testResult']
                : double.tryParse(parsed['testResult'].toString()),
      );
    }
    if (parsed.containsKey('firmware')) {
      updated = updated.copyWith(firmware: parsed['firmware']);
    }
    if (parsed.containsKey('temperature')) {
      updated = updated.copyWith(temperature: parsed['temperature']);
    }

    state = state.copyWith(deviceInfo: updated);
  }

  // Adiciona método público para processar dados recebidos
  Map<String, dynamic>? processReceivedData(List<int> rawData) {
    return _bluetoothManager.processReceivedData(rawData);
  }
}

/// 🔹 Criamos um provider global para o Bluetooth
final bluetoothProvider =
    StateNotifierProvider<BluetoothNotifier, BluetoothState>(
      (ref) => BluetoothNotifier(ref),
    );
