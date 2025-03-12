import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ Riverpod
import '../providers/bluetooth_provider.dart'; // ✅ Bluetooth Provider
import 'dart:async';

class InformacoesDispositivoScreen extends ConsumerStatefulWidget {
  const InformacoesDispositivoScreen({super.key});

  @override
  ConsumerState<InformacoesDispositivoScreen> createState() => _InformacoesDispositivoScreenState();
}

class _InformacoesDispositivoScreenState extends ConsumerState<InformacoesDispositivoScreen> {
  String versaoFirmware = "Carregando...";
  String contagemUso = "Carregando...";
  String ultimaCalibracao = "Carregando...";
  StreamSubscription<List<int>>? _bluetoothSubscription;

  @override
  void initState() {
    super.initState();
    _restaurarConexao();
  }
  

  @override
  void dispose() {
    _bluetoothSubscription?.cancel();
    super.dispose();
  }

  /// 🔹 Aguarda a inicialização correta antes de enviar comandos
  Future<void> _restaurarConexao() async {
    final bluetoothNotifier = ref.read(bluetoothProvider.notifier);
    final bluetoothState = ref.read(bluetoothProvider);

    if (bluetoothState.isConnected) {
      print("♻️ Restaurando conexão BLE...");
      await bluetoothNotifier.restoreCharacteristics();
      await Future.delayed(const Duration(seconds: 1));

      if (bluetoothState.writableCharacteristic == null) {
        print("❌ Característica de escrita ainda não disponível após restauração!");
      } else {
        print("✅ Característica de escrita confirmada: ${bluetoothState.writableCharacteristic!.uuid}");
      }

      _iniciarListener();
      _obterInformacoesDispositivo();
    }
  }

  /// 🔹 Escuta notificações BLE corretamente (evita múltiplos listeners)
  void _iniciarListener() {
    final bluetoothState = ref.read(bluetoothProvider);
    _bluetoothSubscription?.cancel();

    _bluetoothSubscription = bluetoothState.notifiableCharacteristic?.value.listen((value) {
      if (value.isNotEmpty && mounted) {
        final processedData = processReceivedData(value);

        print("📩 Dados recebidos: ${processedData["command"]} -> ${processedData["data"]}");

        setState(() {
          if (processedData["command"] == "B01") {
            versaoFirmware = processedData["data"];
            print("✅ Firmware atualizado: $versaoFirmware");
          } else if (processedData["command"] == "B03") {
            contagemUso = "${processedData["data"]} testes";
            print("✅ Contagem de Uso atualizada: $contagemUso");
          } else if (processedData["command"] == "B04") {
            ultimaCalibracao = processedData["data"];
            print("✅ Última Calibração atualizada: $ultimaCalibracao");
          }
        });
      }
    });
  }

  void _atualizarEstado() {
    final bluetoothState = ref.read(bluetoothProvider);

    if (mounted) {
      setState(() {});

      if (bluetoothState.isConnected) {
        print("✅ Dispositivo conectado, buscando informações...");
        _obterInformacoesDispositivo();
      }
    }
  }

  /// 🔹 Aguarda a característica de escrita antes de enviar os comandos
  Future<void> _obterInformacoesDispositivo() async {
    final bluetoothNotifier = ref.read(bluetoothProvider.notifier);
    final bluetoothState = ref.read(bluetoothProvider);

    if (bluetoothState.isConnected && bluetoothState.connectedDevice != null) {
      print("⌛ Aguardando característica de escrita...");
      await Future.delayed(const Duration(seconds: 1));

      if (bluetoothState.writableCharacteristic == null) {
        print("❌ Característica de escrita ainda não disponível! Tentando novamente...");
        await _restaurarConexao();
        return;
      }
      final batteryLevel = bluetoothState.writableCharacteristic != null ? bluetoothState.writableCharacteristic!.properties.read ? 100 : 0 : 0;

      print("📤 Enviando comandos para obter informações...");
      bluetoothNotifier.sendCommand("A01", "INFORMATION", batteryLevel); // Versão do Firmware
      bluetoothNotifier.sendCommand("A03", "0", batteryLevel); // Contagem de Uso
      bluetoothNotifier.sendCommand("A04", "0", batteryLevel); // Última Calibração
    }
  }

  /// 🔹 Função corrigida para processar os dados corretamente
  Map<String, dynamic> processReceivedData(List<int> rawData) {
    if (rawData.length < 20) {
      return {"command": "Erro", "data": "Pacote inválido", "battery": 0};
    }

    String commandCode = String.fromCharCodes(rawData.sublist(1, 4)).trim();
    String receivedData = String.fromCharCodes(rawData.sublist(4, 17)).replaceAll("#", "").trim();
    int battery = rawData[17];

    // ✅ Verifica se o comando recebido é esperado (B01, B03, B04)
    if (commandCode == "B01" || commandCode == "B03" || commandCode == "B04") {
      print("✅ Resposta recebida: $commandCode - $receivedData");
    }

    return {
      "command": commandCode,
      "data": receivedData.isNotEmpty ? receivedData : "Indisponível",
      "battery": battery,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothState = ref.watch(bluetoothProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Informações do Dispositivo")),
      body: bluetoothState.isConnected ? _buildDeviceInfo() : _buildNoDeviceConnected(),
    );
  }

  Widget _buildDeviceInfo() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(Icons.device_hub, "Versão do Firmware", versaoFirmware),
          _buildInfoCard(Icons.bar_chart, "Contagem de Uso", contagemUso),
          _buildInfoCard(Icons.date_range, "Última Calibração", ultimaCalibracao),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              onPressed: _obterInformacoesDispositivo,
              icon: const Icon(Icons.refresh),
              label: const Text("Atualizar Informações"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDeviceConnected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bluetooth_disabled, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            "Nenhum dispositivo conectado.",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Voltar"),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String value) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
