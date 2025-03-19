import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/bluetooth_manager.dart';

/// 🔹 Estado global para gerenciar a conexão Bluetooth
class BluetoothState {
  final bool isConnected;
  final BluetoothDevice? connectedDevice;
  final BluetoothCharacteristic? writableCharacteristic;
  final BluetoothCharacteristic? notifiableCharacteristic;

  BluetoothState({
    required this.isConnected,
    this.connectedDevice,
    this.writableCharacteristic,
    this.notifiableCharacteristic,
  });

  /// 🔄 Atualiza o estado sem modificar a referência do provider
  BluetoothState copyWith({
    bool? isConnected,
    BluetoothDevice? connectedDevice,
    BluetoothCharacteristic? writableCharacteristic,
    BluetoothCharacteristic? notifiableCharacteristic,
  }) {
    return BluetoothState(
      isConnected: isConnected ?? this.isConnected,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      writableCharacteristic: writableCharacteristic ?? this.writableCharacteristic,
      notifiableCharacteristic: notifiableCharacteristic ?? this.notifiableCharacteristic,
    );
  }
}

/// 🔹 Notifier que gerencia o estado do Bluetooth e faz interface com o BluetoothManager
class BluetoothNotifier extends StateNotifier<BluetoothState> {
  final BluetoothManager _bluetoothManager;

  BluetoothNotifier(Ref ref)
      : _bluetoothManager = BluetoothManager(ref),
        super(BluetoothState(isConnected: false));

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
    sendCommand("A01", "INFORMATION", 0); // Versão do Firmware
    sendCommand("A03", "0", 0); // Contagem de Uso
    sendCommand("A04", "0", 0); // Última Calibração
  }

  /// 🔹 Envia um comando para o dispositivo
  Future<void> sendCommand(String command, String data, int battery) async {
    if (state.writableCharacteristic == null) {
      print("❌ Característica de escrita não disponível!");
      return;
    }
    await _bluetoothManager.sendCommand(command, data, battery);
  }

  /// 🔹 Restaura as características BLE (Corrigindo o erro)
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
}

/// 🔹 Criamos um provider global para o Bluetooth
final bluetoothProvider = StateNotifierProvider<BluetoothNotifier, BluetoothState>(
  (ref) => BluetoothNotifier(ref),
);
