import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'package:flutter/material.dart';
import 'package:Health_App/providers/configuracoes_provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/funcionario_provider.dart';
import '../../../models/funcionario_model.dart';
import '../../../services/bluetooth_scan_service.dart';
import '../../../providers/bluetooth_provider.dart';
import '../../../providers/bluetooth_permission_helper.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

Map<String, String> commandTranslations = {
  "T01": "Contagem de uso após calibração",
  "T02": "Bloqueio de calibração",
  "T03": "Aquecendo",
  "T04": "Desligando",
  "T05": "Erro de bateria",
  "T06": "Soprar",
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
  bool permissoesOk = false;
  bool isCapturingPhoto = false;
  CameraController? cameraController;
  List<CameraDescription>? cameras;
  bool isFlashOn = false;
  bool isFrontCamera = true;
  int soproProgress = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _usarLocalizacao();
    });
    _verificarPermissaoBluetooth();
    _initCamera();
  }

  @override
  void dispose() {
    cameraController?.dispose();
    super.dispose();
  }

  Future<void> _usarLocalizacao() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("❌ Serviço de localização desativado.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      print("⚠️ Permissão negada permanentemente. Abra os Ajustes.");
      await openAppSettings();
      return;
    }

    try {
      // ✅ Isso força o iOS a registrar o uso da localização e mostrar o pop-up
      Position pos = await Geolocator.getCurrentPosition();
      print("📍 Localização obtida: ${pos.latitude}, ${pos.longitude}");
    } catch (e) {
      print("Erro ao obter localização: $e");
    }
  }

  Future<void> _initCamera() async {
    cameras = await availableCameras();
    _setupCamera();
  }

  void _verificarPermissaoBluetooth() async {
    final granted = await BluetoothPermissionHelper.verificarPermissao(context);
    setState(() {
      permissoesOk = granted;
    });
  }

  void _setupCamera() {
    if (cameras != null && cameras!.isNotEmpty) {
      // Dispose do controller anterior antes de criar o novo
      cameraController?.dispose();

      cameraController = CameraController(
        isFrontCamera ? cameras!.first : cameras!.last,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      cameraController!.initialize().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> toggleScan() async {
    final granted = await BluetoothPermissionHelper.verificarPermissao(context);
    if (!granted) {
      print("❌ Permissões insuficientes para iniciar scan.");
      return;
    }
    final scanProvider = ref.read(bluetoothScanProvider.notifier);
    final isScanning = ref.read(bluetoothScanProvider).isNotEmpty;
    if (isScanning) {
      await scanProvider.stopScan();
    } else {
      await scanProvider.startScan();
    }
  }

  Future<void> connectToDevice(ble.BluetoothDevice device) async {
    final bluetoothManager = ref.read(bluetoothProvider.notifier);
    bool success = await bluetoothManager.connectToDevice(device);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Conectado a \\${device.name}"),
          backgroundColor: Colors.blue,
        ),
      );
      ref.read(bluetoothProvider.notifier).fetchDeviceInfo();
    }
  }

  Future<void> _iniciarTeste() async {
    final bluetoothNotifier = ref.read(bluetoothProvider.notifier);
    final bluetoothState = ref.read(bluetoothProvider);
    final deviceName = bluetoothState.connectedDevice?.name.toLowerCase() ?? "";
    await bluetoothNotifier.iniciarNovoTeste();

    // Envia o comando correto conforme o tipo de aparelho
    if (deviceName.contains("iblow") || deviceName.contains("al88")) {
      await bluetoothNotifier.sendCommand("A20", "TEST,START");
    } else if (deviceName.contains("hlx") || deviceName.contains("deimos")) {
      await bluetoothNotifier.sendCommand(
        "9002",
        "START",
      ); // Ajuste conforme protocolo Titan/Deimos
    } else {
      // Default: tenta comando padrão
      await bluetoothNotifier.sendCommand("A20", "TEST,START");
    }

    final config = ref.read(configuracoesProvider);
    if (!config.fotoAtivada) {
      bluetoothNotifier.capturarFoto("");
      setState(() {
        soproProgress = 0;
      });
    } else {
      setState(() {
        isCapturingPhoto = true;
        soproProgress = 0;
      });
    }
  }

  Future<void> _tirarFoto() async {
    if (cameraController != null && cameraController!.value.isInitialized) {
      final XFile foto = await cameraController!.takePicture();
      final Directory directory = await getApplicationDocumentsDirectory();
      final String caminhoFoto =
          "${directory.path}/foto_teste_${DateTime.now().millisecondsSinceEpoch}.jpg";
      await File(foto.path).copy(caminhoFoto);
      ref.read(bluetoothProvider.notifier).capturarFoto(caminhoFoto);
      setState(() {
        isCapturingPhoto = false;
      });
    }
  }

  void toggleCamera() {
    setState(() {
      isFrontCamera = !isFrontCamera;
      _setupCamera();
    });
  }

  void toggleFlash() {
    setState(() {
      isFlashOn = !isFlashOn;
      cameraController?.setFlashMode(
        isFlashOn ? FlashMode.torch : FlashMode.off,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothState = ref.watch(bluetoothProvider);
    final bluetoothNotifier = ref.watch(bluetoothProvider.notifier);
    final scanDevices = ref.watch(bluetoothScanProvider);
    final isConnected = bluetoothState.isConnected;
    final podeIniciarTeste =
        true; // O provider pode expor esse estado se necessário
    final command = bluetoothNotifier.lastCommand;
    final data = bluetoothNotifier.lastData;
    final batteryLevel = bluetoothNotifier.lastBatteryLevel;
    final soproProgressProvider = bluetoothNotifier.soproProgress;
    final statusTeste = bluetoothNotifier.statusTeste;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Health App"),
        actions: [
          IconButton(
            icon: Icon(
              Icons.bluetooth,
              color: permissoesOk ? Colors.green : Colors.red,
            ),
            tooltip: "Status do Bluetooth",
            onPressed: () {
              _verificarPermissaoBluetooth();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child:
            isConnected
                ? isCapturingPhoto
                    ? _buildCameraView(soproProgressProvider)
                    : _buildConnectedUI(
                      command,
                      data,
                      batteryLevel,
                      podeIniciarTeste,
                      statusTeste,
                    )
                : _buildScanUI(scanDevices),
      ),
    );
  }

  Widget _buildCameraView([int? soproProgressProvider]) {
    final progress = soproProgressProvider ?? soproProgress;
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (cameraController != null &&
                  cameraController!.value.isInitialized)
                CameraPreview(cameraController!),

              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: Icon(
                    isFlashOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.blue,
                  ),
                  onPressed: toggleFlash,
                ),
              ),

              Positioned(
                bottom: 40,
                left: 20,
                child: IconButton(
                  icon: const Icon(Icons.switch_camera, color: Colors.blue),
                  onPressed: toggleCamera,
                ),
              ),
            ],
          ),
        ),

        // 🔹 Barra de progresso do sopro
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              Text(
                "Força do Sopro: $progress%",
                style: const TextStyle(fontSize: 16),
              ),
              LinearProgressIndicator(
                value: progress / 100,
                backgroundColor: Colors.grey[300],
                color: progress == 100 ? Colors.green : Colors.blue,
                minHeight: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScanUI(List<ble.BluetoothDevice> devices) {
    return Column(
      children: [
        Image.asset('assets/images/Logo.png', width: 180),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: toggleScan,
          icon: Icon(devices.isNotEmpty ? Icons.stop : Icons.search, size: 20),
          label: Text(
            devices.isNotEmpty ? "Parar Scan" : "Buscar Dispositivos",
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child:
              devices.isEmpty
                  ? Center(
                    child: Text(
                      "Nenhum dispositivo encontrado",
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                  : ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return Card(
                        color: Theme.of(context).cardColor,
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          title: Text(
                            device.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            device.id.toString(),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          trailing: const Icon(
                            Icons.bluetooth,
                            color: Colors.blue,
                          ),
                          onTap: () => connectToDevice(device),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildConnectedUI(
    String command,
    String data,
    int batteryLevel,
    bool podeIniciarTeste,
    String statusTeste,
  ) {
    final funcionarios = ref.watch(funcionarioProvider);
    final selectedFuncionarioId =
        ref.watch(bluetoothProvider).selectedFuncionarioId;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "📡 Conectado ao Dispositivo",
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        _buildFuncionarioSelector(funcionarios, selectedFuncionarioId),
        const SizedBox(height: 20),
        _infoCard("🔹 Resposta", command),
        _infoCard("📊 Dados", data),
        _infoCard("🔋 Bateria", "$batteryLevel%"),
        _infoCard("🟦 Status do Teste", statusTeste),
        const SizedBox(height: 30),
        ElevatedButton.icon(
          onPressed: podeIniciarTeste ? _iniciarTeste : null,
          icon: const Icon(Icons.play_arrow),
          label: const Text("Iniciar Teste"),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () async {
            final deviceName =
                ref
                    .read(bluetoothProvider)
                    .connectedDevice
                    ?.name
                    .toLowerCase() ??
                "";
            if (deviceName.contains("iblow")) {
              final device = ref.read(bluetoothProvider).connectedDevice;
              if (device != null) {
                await ref.read(bluetoothProvider.notifier).disconnect();
                await Future.delayed(const Duration(seconds: 1));
                await ref
                    .read(bluetoothProvider.notifier)
                    .connectToDevice(device);
              }
            } else {
              ref
                  .read(bluetoothProvider.notifier)
                  .sendCommand("A22", "SOFT,RESET");
            }
          },
          icon: const Icon(Icons.restart_alt),
          label: const Text("Reiniciar Dispositivo"),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () {
            ref.read(bluetoothProvider.notifier).disconnect();
            setState(() {
              isCapturingPhoto = false;
              soproProgress = 0;
            });
          },
          icon: const Icon(Icons.close),
          label: const Text("Desconectar"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
        ),
      ],
    );
  }

  Widget _infoCard(String title, String value) {
    return Card(
      elevation: 2,
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFuncionarioSelector(
    List funcionarios,
    String? selectedFuncionarioId,
  ) {
    final nomeFuncionario =
        funcionarios
            .firstWhere(
              (funcionario) => funcionario.id == selectedFuncionarioId,
              orElse:
                  () => FuncionarioModel(id: "visitante", nome: "Visitante"),
            )
            .nome;

    return ListTile(
      title: const Text("Funcionário Selecionado"),
      subtitle: Text(
        selectedFuncionarioId == null ? "Visitante" : nomeFuncionario,
      ),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: () {
        ref
            .read(funcionarioProvider.notifier)
            .carregarFuncionarios(); // 🔹 Força atualização
        _mostrarSelecaoFuncionario(
          ref.watch(funcionarioProvider),
        ); // 🔹 Chama a lista atualizada
      },
    );
  }

  void _mostrarSelecaoFuncionario(List funcionarios) {
    showModalBottomSheet(
      context: context,
      isScrollControlled:
          true, // 🔹 Isso permite ajustar a altura do modal dinamicamente
      builder: (context) {
        TextEditingController filtroController = TextEditingController();
        List funcionariosFiltrados = funcionarios;

        return Padding(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.of(
                  context,
                ).viewInsets.bottom, // 🔹 Ajusta para o teclado
          ),
          child: SingleChildScrollView(
            // 🔹 Evita que o teclado esconda os itens
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: filtroController,
                      decoration: const InputDecoration(
                        labelText: "Buscar Funcionário",
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (query) {
                        setState(() {
                          funcionariosFiltrados =
                              funcionarios
                                  .where(
                                    (f) => f.nome.toLowerCase().contains(
                                      query.toLowerCase(),
                                    ),
                                  )
                                  .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 300,
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          ListTile(
                            title: const Text("Visitante"),
                            onTap: () {
                              ref
                                  .read(bluetoothProvider.notifier)
                                  .selecionarFuncionario("visitante");
                              Navigator.pop(context);
                            },
                          ),
                          ...funcionariosFiltrados.map((funcionario) {
                            return ListTile(
                              title: Text(funcionario.nome),
                              onTap: () {
                                ref
                                    .read(bluetoothProvider.notifier)
                                    .selecionarFuncionario(funcionario.id);
                                Navigator.pop(context);
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
