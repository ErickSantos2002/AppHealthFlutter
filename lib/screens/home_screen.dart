import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bluetooth_scan_service.dart';
import '../providers/bluetooth_provider.dart';

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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final BluetoothScanService scanService = BluetoothScanService();
  bool isScanning = false;
  String command = "";
  String data = "";
  int batteryLevel = 0;

  @override
  void initState() {
    super.initState();
  }

  /// 🔹 Inicia a escuta de notificações BLE
  void _startNotifications() {
    final bluetoothState = ref.read(bluetoothProvider);
    bluetoothState.notifiableCharacteristic?.value.listen((value) {
      if (value.isNotEmpty && mounted) {
        final processedData = processReceivedData(value);
        setState(() {
          command = processedData["command"];
          data = processedData["data"];
          batteryLevel = processedData["battery"];
        });
      }
    });
  }

  void toggleScan() {
    if (isScanning) {
      scanService.stopScan();
    } else {
      scanService.startScan();
    }
    setState(() {
      isScanning = !isScanning;
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    final bluetoothManager = ref.read(bluetoothProvider.notifier);
    bool success = await bluetoothManager.connectToDevice(device);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Conectado a ${device.name}"), backgroundColor: Colors.blue),
      );
      _startNotifications(); // 🔹 Inicia escuta de notificações BLE
        ref.read(bluetoothProvider.notifier).connectToDevice(device).then((success) {
        if (success) {
          print("✅ Dispositivo conectado com sucesso!");
          // 🔹 Agora notificamos a tela de informações para buscar os dados
          ref.read(bluetoothProvider.notifier).fetchDeviceInfo();
        }
      });
    }
  }

  Map<String, dynamic> processReceivedData(List<int> rawData) {
    if (rawData.length < 20) {
      return {"command": "Erro", "data": "Pacote inválido", "battery": 0};
    }

    String commandCode = String.fromCharCodes(rawData.sublist(1, 4)).trim();
    String receivedData = String.fromCharCodes(rawData.sublist(4, 17)).replaceAll("#", "").trim();
    int battery = rawData[17];

    // ✅ Traduzindo o comando, se existir no mapa
    String translatedCommand = commandTranslations[commandCode] ?? "Comando desconhecido";

    return {
      "command": translatedCommand, // Agora retorna a tradução
      "data": receivedData,
      "battery": battery,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothState = ref.watch(bluetoothProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Bluetooth BLE App")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: bluetoothState.isConnected ? _buildConnectedUI() : _buildScanUI(),
      ),
    );
  }

  Widget _buildScanUI() {
    return Column(
      children: [
        Image.asset('assets/images/Logo.png', width: 120),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed: toggleScan,
          icon: Icon(isScanning ? Icons.stop : Icons.search, size: 20),
          label: Text(isScanning ? "Parar Scan" : "Buscar Dispositivos"),
        ),

        const SizedBox(height: 20),

        Expanded(
          child: StreamBuilder<List<BluetoothDevice>>(
            stream: scanService.scannedDevicesStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("Nenhum dispositivo encontrado"));
              }
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final device = snapshot.data![index];
                  return Card(
                    color: Colors.blue[100],
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(device.id.toString()),
                      trailing: const Icon(Icons.bluetooth, color: Colors.blue),
                      onTap: () => connectToDevice(device),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("📡 Conectado ao Dispositivo", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),

        _infoCard("🔹 Resposta", command),
        _infoCard("📊 Dados", data),
        _infoCard("🔋 Bateria", "$batteryLevel%"),

        const SizedBox(height: 30),

        ElevatedButton.icon(
          onPressed: () {
            ref.read(bluetoothProvider.notifier).sendCommand("A20", "TEST,START", batteryLevel);
          },
          icon: const Icon(Icons.play_arrow),
          label: const Text("Iniciar Teste"),
        ),

        const SizedBox(height: 10),

        ElevatedButton.icon(
          onPressed: () {
            ref.read(bluetoothProvider.notifier).sendCommand("A22", "SOFT,RESET", batteryLevel);
          },
          icon: const Icon(Icons.restart_alt),
          label: const Text("Reiniciar Dispositivo"),
        ),

        const SizedBox(height: 10),

        ElevatedButton.icon(
          onPressed: () {
            ref.read(bluetoothProvider.notifier).disconnect();
            setState(() {
              command = "";
              data = "";
              batteryLevel = 0;
            });
          },
          icon: const Icon(Icons.close),
          label: const Text("Desconectar"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        ),
      ],
    );
  }

  Widget _infoCard(String title, String value) {
    return Card(
      elevation: 2,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(color: Colors.blueAccent)),
          ],
        ),
      ),
    );
  }
}
