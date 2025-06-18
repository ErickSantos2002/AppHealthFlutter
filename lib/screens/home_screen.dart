import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'package:flutter/material.dart';
import 'package:Health_App/providers/configuracoes_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/funcionario_provider.dart';
import '../../../providers/bluetooth_provider.dart';
import '../../../providers/bluetooth_permission_helper.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/funcionario_model.dart';

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
  bool _isCapturingPhotoInternal = false;
  bool isCameraLoading = false; // <- novo

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

  void toggleCamera() async {
    setState(() {
      isFrontCamera = !isFrontCamera;
      isCameraLoading = true;
    });
    await _setupCamera(force: true);
  }

  Future<void> _setupCamera({bool force = false}) async {
    if (cameras != null && cameras!.isNotEmpty) {
      if (cameraController != null) {
        await cameraController!.dispose();
        cameraController = null;
      }
      cameraController = CameraController(
        isFrontCamera ? cameras!.first : cameras!.last,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      try {
        await cameraController!.initialize();
        if (mounted)
          setState(() {
            isCameraLoading = false;
          });
      } catch (e) {
        print('Erro ao inicializar câmera: $e');
        if (mounted)
          setState(() {
            isCameraLoading = false;
          });
      }
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
      scanProvider.clearDevices(); // Limpa a lista imediatamente ao parar
      setState(() {}); // Força atualização do UI
    } else {
      scanProvider.clearDevices(); // Limpa antes de iniciar novo scan
      await scanProvider.startScan();
      setState(() {}); // Força atualização do UI
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
        soproProgress = 0;
        isCapturingPhoto = true; // <- Abre a câmera para ajuste
      });
    }
  }

  Future<void> _tirarFoto() async {
    if (_isCapturingPhotoInternal) {
      print(
        '[UI] _tirarFoto: Já está capturando, ignorando chamada duplicada.',
      );
      return;
    }
    if (!mounted) return;
    if (cameraController == null || !cameraController!.value.isInitialized) {
      print('❌ CameraController não inicializado!');
      ref.read(bluetoothProvider.notifier).salvarTesteComFoto("");
      setState(() {
        isCapturingPhoto = false;
      });
      return;
    }
    if (cameraController!.value.isTakingPicture) {
      print('[UI] _tirarFoto: Camera já está tirando foto, ignorando chamada.');
      return;
    }
    _isCapturingPhotoInternal = true;
    try {
      print('[UI] _tirarFoto: Camera pronta, capturando...');
      final XFile foto = await cameraController!.takePicture();
      final Directory directory = await getApplicationDocumentsDirectory();
      final String caminhoFoto =
          "${directory.path}/foto_teste_${DateTime.now().millisecondsSinceEpoch}.jpg";
      await File(foto.path).copy(caminhoFoto);
      print("📸 Foto capturada e salva em: $caminhoFoto");
      if (!mounted) return;
      ref.read(bluetoothProvider.notifier).salvarTesteComFoto(caminhoFoto);
    } catch (e) {
      print("❌ Erro ao tirar foto: $e");
      if (mounted) ref.read(bluetoothProvider.notifier).salvarTesteComFoto("");
    } finally {
      if (mounted) {
        setState(() {
          isCapturingPhoto = false;
        });
      }
      _isCapturingPhotoInternal = false;
      // Libera a câmera após tirar a foto
      await cameraController?.dispose();
      cameraController = null;
      if (mounted) await _initCamera();
    }
  }

  // Chama _tirarFoto automaticamente quando a camera estiver pronta e isCapturingPhoto for true
  // void _onCameraReady() {
  //   if (isCapturingPhoto && !_isCapturingPhotoInternal && cameraController != null && cameraController!.value.isInitialized && !cameraController!.value.isTakingPicture) {
  //     print('[UI] _onCameraReady: Chamando _tirarFoto automaticamente!');
  //     _tirarFoto();
  //   }
  // }

  Widget _buildCameraView([int? soproProgressProvider]) {
    final progress = soproProgressProvider ?? soproProgress;
    final isCameraReady =
        cameraController != null &&
        cameraController!.value.isInitialized &&
        !isCameraLoading;
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isCameraLoading)
                const Center(child: CircularProgressIndicator()),
              if (!isCameraLoading && isCameraReady)
                CameraPreview(cameraController!)
              else
                const Center(child: CircularProgressIndicator()),

              // Botão para fechar a câmera manualmente
              Positioned(
                top: 40,
                left: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  tooltip: 'Fechar Câmera',
                  onPressed: () async {
                    setState(() {
                      isCapturingPhoto = false;
                    });
                    await cameraController?.dispose();
                    cameraController = null;
                    await _initCamera();
                  },
                ),
              ),

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
        _infoCard(
          "🔹 Resposta",
          statusTeste,
        ), // Mostra o status do teste como resposta
        _infoCard("📊 Dados", data), // Mostra os dados recebidos do aparelho
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
              orElse: () {
                return FuncionarioModel(id: "visitante", nome: "Visitante");
              },
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
    final podeIniciarTeste = true;

    print(
      '[UI] build: precisaCapturarFoto={bluetoothState.precisaCapturarFoto}, testePendente={bluetoothNotifier.testePendente != null}, isCapturingPhoto=$isCapturingPhoto',
    );

    // Se a câmera está aberta para ajuste e chegou o sinal para capturar foto, tira a foto
    if (isCapturingPhoto &&
        bluetoothState.precisaCapturarFoto &&
        bluetoothNotifier.testePendente != null) {
      print('[UI] Chamando _tirarFoto() por precisaCapturarFoto...');
      Future.microtask(() async {
        await _tirarFoto();
        ref.read(bluetoothProvider.notifier).resetarPrecisaCapturarFoto();
        setState(() {
          isCapturingPhoto = false;
        }); // Fecha a câmera após foto
      });
    }

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
                    ? _buildCameraView(bluetoothNotifier.soproProgress)
                    : _buildConnectedUI(
                      bluetoothNotifier.lastCommand,
                      bluetoothNotifier.lastData,
                      bluetoothNotifier.lastBatteryLevel,
                      podeIniciarTeste,
                      bluetoothNotifier.statusTeste,
                    )
                : _buildScanUI(scanDevices),
      ),
    );
  }
}
