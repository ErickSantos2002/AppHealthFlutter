import 'package:Health_App/providers/configuracoes_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/funcionario_model.dart';
import '../services/bluetooth_manager.dart';
import '../models/test_model.dart';
import '../providers/historico_provider.dart';
import 'funcionario_provider.dart';
import '../models/device_info.dart';
import '../services/bluetooth_scan_service.dart';
import 'dart:async';

/// 🔹 Estado global para gerenciar a conexão Bluetooth
class BluetoothState {
  final bool isConnected;
  final BluetoothDevice? connectedDevice;
  final BluetoothCharacteristic? writableCharacteristic;
  final BluetoothCharacteristic? notifiableCharacteristic;
  final String? selectedFuncionarioId;
  final String? lastCapturedPhotoPath; // 📸 Caminho da última foto tirada
  final DeviceInfo? deviceInfo;
  final bool testeSalvo; // Flag para notificar a tela
  final bool precisaCapturarFoto; // Novo flag

  BluetoothState({
    required this.isConnected,
    this.connectedDevice,
    this.writableCharacteristic,
    this.notifiableCharacteristic,
    this.selectedFuncionarioId,
    this.lastCapturedPhotoPath,
    this.deviceInfo,
    this.testeSalvo = false,
    bool? precisaCapturarFoto,
  }) : precisaCapturarFoto = precisaCapturarFoto ?? false;

  /// 🔄 Atualiza o estado sem modificar a referência do provider
  BluetoothState copyWith({
    bool? isConnected,
    BluetoothDevice? connectedDevice,
    BluetoothCharacteristic? writableCharacteristic,
    BluetoothCharacteristic? notifiableCharacteristic,
    String? selectedFuncionarioId,
    String? lastCapturedPhotoPath,
    DeviceInfo? deviceInfo,
    bool? testeSalvo,
    bool? precisaCapturarFoto,
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
      testeSalvo: testeSalvo ?? this.testeSalvo,
      precisaCapturarFoto: precisaCapturarFoto ?? this.precisaCapturarFoto,
    );
  }
}

/// 🔹 Notifier que gerencia o estado do Bluetooth e faz interface com o BluetoothManager
class BluetoothNotifier extends StateNotifier<BluetoothState> {
  final BluetoothManager _bluetoothManager;
  final Ref ref;

  // Getters para facilitar o consumo na tela
  String get lastCommand {
    // Retorna apenas o último comando processado recebido do handler
    return _lastParsedCommand ?? "-";
  }

  String get lastData {
    // Se for comando de teste, retorna o resultado processado
    if (_lastResultadoFinal != null &&
        (_lastParsedCommand == "T11" || _lastParsedCommand == "9003")) {
      return _lastResultadoFinal!;
    }
    // Caso contrário, retorna o dado cru
    return _lastParsedData ?? "-";
  }

  int get lastBatteryLevel {
    return state.deviceInfo?.battery ?? 0;
  }

  double? get testResult => state.deviceInfo?.testResult;

  String get statusTeste {
    // Exemplo: pode ser "Aguardando", "Analisando", etc, conforme lógica do handler
    return _lastStatusTeste ?? "-";
  }

  int get soproProgress => _lastSoproProgress ?? 0;

  // Variáveis internas para armazenar últimos dados recebidos
  String? _lastParsedCommand;
  String? _lastParsedData;
  String? _lastStatusTeste;
  int? _lastSoproProgress;
  String? _lastResultadoFinal; // Novo: armazena o último resultado processado

  BluetoothNotifier(this.ref)
    : _bluetoothManager = BluetoothManager(ref),
      super(BluetoothState(isConnected: false));

  /// 🔹 Método para selecionar um funcionário antes de iniciar o teste
  void selecionarFuncionario(String? funcionarioId) {
    state = state.copyWith(selectedFuncionarioId: funcionarioId);
  }

  String get funcionarioSelecionado =>
      state.selectedFuncionarioId ?? "Visitante";

  // Flag para notificar a tela quando um teste for salvo
  bool get testeSalvo => state.testeSalvo;
  void resetarTesteSalvo() {
    state = state.copyWith(testeSalvo: false);
  }

  /// 🔹 Conecta a um dispositivo e atualiza o estado
  Future<bool> connectToDevice(BluetoothDevice device) async {
    bool success = await _bluetoothManager.connectToDevice(device);
    if (success) {
      state = state.copyWith(isConnected: true, connectedDevice: device);

      // ✅ Agora usamos a função de callback para atualizar características BLE
      await _bluetoothManager.discoverCharacteristics(device, (
        writable,
        notifiable,
      ) {
        setCharacteristics(writable: writable, notifiable: notifiable);
        listenToNotifications();
      });
      await _garantirCaracteristicaEscrita();
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
      // Atualiza variáveis para UI
      _lastParsedCommand = parsed["command"]?.toString();
      _lastParsedData =
          parsed["data"]?.toString() ?? parsed["payload"]?.toString();
      if (parsed["command"] == "T07" && parsed["data"] != null) {
        // Progresso do sopro
        _lastSoproProgress = int.tryParse(parsed["data"].toString());
      }
      if (parsed["command"] == "T10") {
        _lastStatusTeste = "Analisando";
      } else if (parsed["command"] == "T12") {
        _lastStatusTeste = "Aguardando";
      } else if (parsed["command"] == "T11") {
        _lastStatusTeste = "Resultado";
      }
      // Mantém processamento de teste para iBlow
      _processarTeste(parsed);
    });
  }

  Future<void> reiniciarIBlow() async {
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
  TestModel? _testePendente; // Teste aguardando foto

  TestModel? get testePendente => _testePendente;

  void _processarTeste(Map<String, dynamic> parsed) {
    final command = parsed["command"];
    final data = parsed["data"];
    final battery = parsed["battery"];
    final testResult = parsed["testResult"];
    final deviceName =
        state.connectedDevice != null
            ? state.connectedDevice!.name.toLowerCase()
            : "";
    final agora = DateTime.now();
    final funcionarios = ref.read(funcionarioProvider);
    final funcionario = funcionarios.firstWhere(
      (f) => f.id == state.selectedFuncionarioId,
      orElse: () => FuncionarioModel(id: "visitante", nome: "Visitante"),
    );
    String resultadoFinal = "";
    String unidade = "";
    String statusCalibracao = "N/A";
    bool isDuplicado = false;
    bool isFavorito = false;
    final config = ref.read(configuracoesProvider);
    final fotoAtivada = config.fotoAtivada;

    // --- iBlow/AL88 ---
    if ((deviceName.contains("iblow") || deviceName.contains("al88")) &&
        command == "T11") {
      if (data == null) return;
      final partes = data.split(",");
      if (partes.length < 3) return;
      unidade = _converterUnidade(partes[1]);
      resultadoFinal = "${partes[2]} $unidade";
      statusCalibracao =
          partes.length > 3 && partes[3] == "1"
              ? "Modo Calibração"
              : "Modo Normal";
      if (_ultimoResultadoSalvo == resultadoFinal) {
        print("⚠️ Teste duplicado ignorado!");
        isDuplicado = true;
      }
      _ultimoResultadoSalvo = resultadoFinal;
      isFavorito = TestModel(
        timestamp: agora,
        command: resultadoFinal,
        statusCalibracao: statusCalibracao,
        batteryLevel: battery ?? 0,
        funcionarioId: funcionario.id,
        funcionarioNome: funcionario.nome,
        photoPath: state.lastCapturedPhotoPath,
        deviceName: state.connectedDevice?.name,
      ).isAcimaDaTolerancia(ref.read(configuracoesProvider).tolerancia);
      _lastResultadoFinal = resultadoFinal; // Salva resultado processado
    }
    // --- Foto para Titan/Deimos: comando 9002 status 2 ---
    else if (command == "9002" &&
        (deviceName.contains("hlx") || deviceName.contains("deimos"))) {
      if (data != null && (data.toString() == "2" || data == 2)) {
        // Só dispara fluxo de foto, não salva teste nem mexe em histórico
        state = state.copyWith(precisaCapturarFoto: true);
        print("🕓 Status 2 recebido em 9002: disparando captura de foto");
      }
      return;
    }
    // --- HLX/Deimos: comando 9003 ---
    else if ((deviceName.contains("hlx") || deviceName.contains("deimos")) &&
        command == "9003") {
      if (testResult == null || (testResult is! num)) {
        print(
          "[BluetoothProvider] Comando 9003 recebido, mas testResult é null ou não numérico. Ignorando. parsed: $parsed",
        );
        return;
      }
      unidade = "mg/L";
      resultadoFinal = "${testResult.toString()} $unidade";
      if (_ultimoResultadoSalvo == resultadoFinal) {
        print("⚠️ Teste duplicado ignorado!");
        return; // <-- Garante que só salva uma vez
      }
      _ultimoResultadoSalvo = resultadoFinal;
      isFavorito = TestModel(
        timestamp: agora,
        command: resultadoFinal,
        statusCalibracao: statusCalibracao,
        batteryLevel: battery ?? 0,
        funcionarioId: funcionario.id,
        funcionarioNome: funcionario.nome,
        photoPath: state.lastCapturedPhotoPath, // associa a foto capturada
        deviceName: state.connectedDevice?.name,
      ).isAcimaDaTolerancia(ref.read(configuracoesProvider).tolerancia);
      _lastResultadoFinal = resultadoFinal;
      // Salva imediatamente o teste com a foto e limpa o caminho
      final testeComFoto = TestModel(
        timestamp: agora,
        command: resultadoFinal,
        statusCalibracao: statusCalibracao,
        batteryLevel: battery ?? 0,
        funcionarioId: funcionario.id,
        funcionarioNome: funcionario.nome,
        photoPath: state.lastCapturedPhotoPath,
        deviceName: state.connectedDevice?.name ?? '',
        isFavorito: isFavorito,
      );
      ref.read(historicoProvider.notifier).adicionarTeste(testeComFoto);
      print(
        "✅ Teste salvo no histórico com foto (Titan/Deimos): " +
            (state.lastCapturedPhotoPath ?? ''),
      );
      state = state.copyWith(
        testeSalvo: true,
        precisaCapturarFoto: false,
        lastCapturedPhotoPath: null,
      );
      _testePendente = null;
      return;
    }
    // --- Outros aparelhos: tenta lógica genérica ---
    else if (command == "9003") {
      if (testResult == null || (testResult is! num)) {
        print(
          "[BluetoothProvider] Comando 9003 recebido (genérico), mas testResult é null ou não numérico. Ignorando. parsed: $parsed",
        );
        return;
      }
      unidade = "mg/L";
      resultadoFinal = "${testResult.toString()} $unidade";
      if (_ultimoResultadoSalvo == resultadoFinal) {
        print("⚠️ Teste duplicado ignorado!");
        isDuplicado = true;
      }
      _ultimoResultadoSalvo = resultadoFinal;
      isFavorito = TestModel(
        timestamp: agora,
        command: resultadoFinal,
        statusCalibracao: statusCalibracao,
        batteryLevel: battery ?? 0,
        funcionarioId: funcionario.id,
        funcionarioNome: funcionario.nome,
        photoPath: state.lastCapturedPhotoPath,
        deviceName: state.connectedDevice?.name,
      ).isAcimaDaTolerancia(ref.read(configuracoesProvider).tolerancia);
      _lastResultadoFinal = resultadoFinal;
    } else {
      return;
    }

    if (isDuplicado) return;

    final novoTeste = TestModel(
      timestamp: agora,
      command: resultadoFinal,
      statusCalibracao: statusCalibracao,
      batteryLevel: battery ?? 0,
      funcionarioId: funcionario.id,
      funcionarioNome: funcionario.nome,
      photoPath: null, // Foto será associada depois
      deviceName: state.connectedDevice?.name ?? '',
      isFavorito: isFavorito,
    );

    // Salvar imediatamente se fotoAtivada == false
    if (!fotoAtivada) {
      ref.read(historicoProvider.notifier).adicionarTeste(novoTeste);
      print("✅ Teste salvo no histórico (sem foto)");
      state = state.copyWith(testeSalvo: true, precisaCapturarFoto: false);
      _testePendente = null;
      return;
    }

    // Se for Titan/Deimos (9003) OU iBlow/AL88 (T11) e fotoAtivada == true, aguarda foto
    if ((command == "9003") ||
        ((deviceName.contains("iblow") || deviceName.contains("al88")) &&
            command == "T11")) {
      _testePendente = novoTeste;
      state = state.copyWith(testeSalvo: false, precisaCapturarFoto: true);
      print("🕓 Teste pendente aguardando foto: $resultadoFinal");
    }
  }

  /// Salva o teste pendente com o caminho da foto
  void salvarTesteComFoto(String caminhoFoto) {
    if (_testePendente != null) {
      final testeComFoto = _testePendente!.copyWith(photoPath: caminhoFoto);
      ref.read(historicoProvider.notifier).adicionarTeste(testeComFoto);
      print("✅ Teste salvo no histórico com foto: $caminhoFoto");
      _testePendente = null;
      state = state.copyWith(
        testeSalvo: false,
        lastCapturedPhotoPath: null,
        precisaCapturarFoto: false,
      );
    } else {
      // Não há teste pendente ainda (ex: Titan/Deimos: foto antes do 9003)
      print(
        "⚠️ Nenhum teste pendente para associar foto! Salvando caminho para uso futuro.",
      );
      state = state.copyWith(
        lastCapturedPhotoPath: caminhoFoto,
        precisaCapturarFoto: false,
      );
    }
  }

  Future<void> iniciarNovoTeste() async {
    _ultimoResultadoSalvo = null; // 🔹 Reseta o rastreador de testes duplicados
    _testePendente = null; // 🔹 Garante que não há teste pendente
    // Resetar flags de foto para evitar estados residuais
    state = state.copyWith(
      precisaCapturarFoto: false,
      lastCapturedPhotoPath: null,
      testeSalvo: false,
    );
    print(
      "🔄 Novo teste iniciado! Resetando controle de duplicação e flags de foto.",
    );
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
    // Salva o caminho da foto e reseta o flag para evitar múltiplos disparos
    state = state.copyWith(
      lastCapturedPhotoPath: caminhoFoto,
      precisaCapturarFoto: false,
    );
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
      await _garantirCaracteristicaEscrita();
    }
  }

  /// 🔹 Garante a característica de escrita no estado.
  /// 1) Fallback: adota a do handler se o estado estiver sem.
  /// 2) Retry único de descoberta se ainda faltar e o device estiver conectado.
  Future<void> _garantirCaracteristicaEscrita() async {
    if (state.writableCharacteristic == null &&
        _bluetoothManager.writableCharacteristic != null) {
      print(
        "♻️ [bluetoothProvider] Adotando característica de escrita do handler (fallback).",
      );
      setCharacteristics(
        writable: _bluetoothManager.writableCharacteristic,
        notifiable: _bluetoothManager.notifiableCharacteristic,
      );
    }

    if (state.writableCharacteristic == null && state.connectedDevice != null) {
      print(
        "🔁 [bluetoothProvider] Escrita ainda ausente — 1 retry de descoberta...",
      );
      await _bluetoothManager.discoverCharacteristics(state.connectedDevice!, (
        writable,
        notifiable,
      ) {
        setCharacteristics(writable: writable, notifiable: notifiable);
      });
      if (state.writableCharacteristic == null &&
          _bluetoothManager.writableCharacteristic != null) {
        setCharacteristics(
          writable: _bluetoothManager.writableCharacteristic,
          notifiable: _bluetoothManager.notifiableCharacteristic,
        );
      }
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

    // --- AL88/iBlow: parse info commands ---
    final command = parsed['command']?.toString();
    final data = parsed['data']?.toString();
    final deviceName = state.connectedDevice?.name.toLowerCase() ?? "";
    if (deviceName.contains("iblow") || deviceName.contains("al88")) {
      if (command == "B01" && data != null && data.isNotEmpty) {
        // Firmware info: string como "iBlow v1.23" ou similar
        updated = updated.copyWith(firmware: data);
      } else if (command == "B03" && data != null && data.isNotEmpty) {
        // Usage counter: número como string
        final usage = int.tryParse(data.replaceAll(RegExp(r'[^0-9]'), ''));
        if (usage != null) updated = updated.copyWith(usageCounter: usage);
      } else if (command == "B04" && data != null && data.isNotEmpty) {
        // Calibration date: formato YYYY.MM.DD
        updated = updated.copyWith(lastCalibrationDate: data);
      }
    }

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

  /// Método unificado para receber dados dos handlers
  void onDataFromHandler(Map<String, dynamic> data) {
    // Log para debug: mostra todos os comandos e dados recebidos do handler
    print(
      '[BluetoothProvider] onDataFromHandler: comando=${data['command']}, data=${data['data']}, payload=${data['payload']}',
    );
    // Atualiza DeviceInfo se aplicável
    updateDeviceInfo(data);
    // Processa teste se aplicável (ex: comando de resultado)
    _processarTeste(data);
    // Pode adicionar outros tratamentos centralizados aqui
  }

  // Adiciona método público para processar dados recebidos
  Map<String, dynamic>? processReceivedData(List<int> rawData) {
    return _bluetoothManager.processReceivedData(rawData);
  }

  // Garante que o método está público
  void resetarPrecisaCapturarFoto() {
    state = state.copyWith(precisaCapturarFoto: false);
  }
}

/// 🔹 Criamos um provider global para o Bluetooth
final bluetoothProvider =
    StateNotifierProvider<BluetoothNotifier, BluetoothState>(
      (ref) => BluetoothNotifier(ref),
    );

class BluetoothScanNotifier extends StateNotifier<List<BluetoothDevice>> {
  final BluetoothScanService _scanService = BluetoothScanService();
  StreamSubscription<List<BluetoothDevice>>? _subscription;

  BluetoothScanNotifier() : super([]) {
    _subscription = _scanService.scannedDevicesStream.listen((devices) {
      state = devices;
    });
  }

  Future<void> startScan() async {
    await _scanService.startScan();
  }

  Future<void> stopScan() async {
    await _scanService.stopScan();
  }

  void clearDevices() {
    _scanService.clearDevices();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final bluetoothScanProvider =
    StateNotifierProvider<BluetoothScanNotifier, List<BluetoothDevice>>(
      (ref) => BluetoothScanNotifier(),
    );
