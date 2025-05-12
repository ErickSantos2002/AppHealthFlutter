import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'package:flutter/material.dart';
import 'package:Health_App/providers/configuracoes_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/funcionario_provider.dart';
import '../models/funcionario_model.dart';
import '../services/bluetooth_scan_service.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/bluetooth_permission_helper.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
  bool permissoesOk = false;
  String command = "";
  String data = "";
  int batteryLevel = 0;
  bool isCapturingPhoto = false; // 🔹 Novo estado para controle da câmera
  CameraController? cameraController;
  List<CameraDescription>? cameras;
  bool isFlashOn = false;
  bool isFrontCamera = true;
  int soproProgress = 0; // 🔹 Progresso do sopro (0 a 100)
  bool podeIniciarTeste = true; // 🔹 Só permite iniciar um novo teste após T12
  late StreamSubscription<ble.BluetoothAdapterState> bluetoothStateSubscription;
  late StreamSubscription<bool> scanStateSubscription;
  ble.BluetoothAdapterState bluetoothState = ble.BluetoothAdapterState.unknown;

  @override
  void initState() {
    super.initState();
    _verificarPermissaoBluetooth();
    _initCamera();

    bluetoothStateSubscription = ble.FlutterBluePlus.adapterState.listen((state) {
      setState(() {
        bluetoothState = state;
      });
    });

    scanStateSubscription = ble.FlutterBluePlus.isScanning.listen((scanActive) {
      setState(() {
        isScanning = scanActive;
      });
    });
  }

  @override
  void dispose() {
    bluetoothStateSubscription.cancel();
    scanStateSubscription.cancel(); // ✅ novo
    super.dispose();
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

  /// 🔹 Inicia a escuta de notificações BLE
  void _startNotifications() {
    final bluetoothData = ref.watch(bluetoothProvider);
    bluetoothData.notifiableCharacteristic?.value.listen((value) async {
      if (value.isNotEmpty && mounted) {
        final processedData = processReceivedData(value);
        setState(() {
          command = processedData["command"];
          data = processedData["data"];
          batteryLevel = processedData["battery"];
        });

        // 🔹 Atualiza a barra de progresso com base no valor do sopro (T07)
        if (command == "Assoprando") {
          int progress = int.tryParse(data) ?? 0;
          setState(() {
            soproProgress = progress;
          });
        }

        // 🔹 Se o sopro for insuficiente (T08), fecha a câmera sem tirar a foto
        if (command == "Sopro insuficiente") {
          setState(() {
            isCapturingPhoto = false;
          });
          return;
        }

        // 🔹 Se o comando for "(T20): Desligado" ou "(T04): Desligado", fecha a câmera sem tirar a foto
        if (command == "Desligando" || command == "Desligado") {
          setState(() {
            isCapturingPhoto = false;
          });
          return;
        }

        // 🔹 Se o comando for "T10: Analisando", captura a foto automaticamente
        if (command == "Analisando" && isCapturingPhoto) {
          _tirarFoto();
        }

        // 🔹 Se o comando for "T12: Modo de espera", permite iniciar outro teste
        if (command == "Modo de espera") {
          setState(() {
            podeIniciarTeste = true;
          });
        } else {
          // 🔹 Se a última notificação NÃO for T12, bloqueia o botão de iniciar teste
          setState(() {
            podeIniciarTeste = false;
          });
        }
      }
    });
  }

  Future<void> toggleScan() async {
    // ✅ Verifica todas as permissões usando o helper
    final granted = await BluetoothPermissionHelper.verificarPermissao(context, silencioso: true);
    if (!granted) {
      print("❌ Permissões insuficientes para iniciar scan.");
      return;
    }

    // ✅ Verifica se o Bluetooth está ativado
    final isOn = bluetoothState == ble.BluetoothAdapterState.on;
    if (!isOn) {
      _mostrarDialogoBluetoothDesligado();
      return;
    }

    // ✅ Inicia ou para o scan
    if (isScanning) {
      print("🛑 Parando scan BLE...");
      scanService.stopScan();
    } else {
      print("🔍 Iniciando scan BLE...");
      scanService.startScan();
    }

    setState(() {
      isScanning = !isScanning;
    });
  }

  void _mostrarDialogoBluetoothDesligado() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Bluetooth Desligado"),
        content: const Text(
          "Para buscar dispositivos, é necessário que o Bluetooth esteja ativado.\n\nAtive o Bluetooth nas configurações do sistema e tente novamente.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> connectToDevice(ble.BluetoothDevice device) async {
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

  Future<void> _iniciarTeste() async {
    if (!podeIniciarTeste) return; // 🔹 Impede iniciar teste se não estiver no estado correto

    ref.read(bluetoothProvider.notifier).iniciarNovoTeste(); // 🔹 Reseta a verificação de duplicados

    // 🔹 Envia o comando primeiro
    ref.read(bluetoothProvider.notifier).sendCommand("A20", "TEST,START");

    // 🔹 Ativa a câmera dentro da tela HomeScreen
    final config = ref.read(configuracoesProvider);

    final bluetoothNotifier = ref.read(bluetoothProvider.notifier);

    // 🔹 Se a câmera estiver desativada, limpa qualquer foto anterior
    if (!config.fotoAtivada) {
      bluetoothNotifier.capturarFoto(""); // Limpa o caminho da última foto
    }
    
    if (config.fotoAtivada) {
      setState(() {
        isCapturingPhoto = true;
        soproProgress = 0;
      });
    } else {
      // 🔹 Se não vai tirar foto, limpa o caminho da última foto salva
      bluetoothNotifier.capturarFoto(""); // Isso evita reutilização
      setState(() {
        soproProgress = 0;
      });
    }
  }

  Future<void> _tirarFoto() async {
    if (cameraController != null && cameraController!.value.isInitialized) {
      final XFile foto = await cameraController!.takePicture();

      // 🔹 Salvar a foto localmente
      final Directory directory = await getApplicationDocumentsDirectory();
      final String caminhoFoto = "${directory.path}/foto_teste_${DateTime.now().millisecondsSinceEpoch}.jpg";
      await File(foto.path).copy(caminhoFoto);

      print("📸 Foto automática salva em: $caminhoFoto");

      // 🔹 Atualizar o provider para associar a foto ao próximo teste
      ref.read(bluetoothProvider.notifier).capturarFoto(caminhoFoto);

      // 🔹 Desativa a câmera após capturar a foto
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
      cameraController?.setFlashMode(isFlashOn ? FlashMode.torch : FlashMode.off);
    });
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

    if (commandCode == "T11") {
      final partes = receivedData.split(',');
      if (partes.length >= 3) {
        receivedData = partes[2]; // Isso será o "0.000"
      }
    }

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
        child: bluetoothState.isConnected
            ? isCapturingPhoto
                ? _buildCameraView() // 🔹 Exibir câmera quando está capturando
                : _buildConnectedUI()
            : _buildScanUI(),
      ),
    );
  }

   Widget _buildCameraView() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (cameraController != null && cameraController!.value.isInitialized)
                CameraPreview(cameraController!),

              Positioned(
                top: 20,
                right: 20,
                child: IconButton(
                  icon: Icon(isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
                  onPressed: toggleFlash,
                ),
              ),

              Positioned(
                bottom: 20,
                left: 20,
                child: IconButton(
                  icon: const Icon(Icons.switch_camera, color: Colors.white),
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
              Text("Força do Sopro: $soproProgress%", style: const TextStyle(fontSize: 16)),
              LinearProgressIndicator(
                value: soproProgress / 100,
                backgroundColor: Colors.grey[300],
                color: soproProgress == 100 ? Colors.green : Colors.blue,
                minHeight: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScanUI() {
    return Column(
      children: [
        Image.asset('assets/images/Logo.png', width: 180),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed: toggleScan,
          icon: Icon(isScanning ? Icons.stop : Icons.search, size: 20),
          label: Text(isScanning ? "Parar Scan" : "Buscar Dispositivos"),
        ),

        const SizedBox(height: 20),

        Expanded(
          child: StreamBuilder<List<ble.BluetoothDevice>>(
            stream: scanService.scannedDevicesStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Text(
                    "Nenhum dispositivo encontrado",
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                );
              }
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final device = snapshot.data![index];
                  return Card(
                    color: Theme.of(context).cardColor,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      title: Text(
                        device.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        device.id.toString(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
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
    final funcionarios = ref.watch(funcionarioProvider);
    final selectedFuncionarioId = ref.watch(bluetoothProvider).selectedFuncionarioId;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "📡 Conectado ao Dispositivo",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        _buildFuncionarioSelector(funcionarios, selectedFuncionarioId),

        const SizedBox(height: 20),

        _infoCard("🔹 Resposta", command),
        _infoCard("📊 Dados", data),
        _infoCard("🔋 Bateria", "$batteryLevel%"),

        const SizedBox(height: 30),

        ElevatedButton.icon(
          onPressed: () => _iniciarTeste(),
          icon: const Icon(Icons.play_arrow),
          label: const Text("Iniciar Teste"),
        ),

        const SizedBox(height: 10),

        ElevatedButton.icon(
          onPressed: () async {
            final deviceName = ref.read(bluetoothProvider).connectedDevice?.name.toLowerCase() ?? "";
            if (deviceName.contains("iblow")) {
              print("🔁 iBlow detectado: reiniciando via reconexão...");
              final device = ref.read(bluetoothProvider).connectedDevice;
              if (device != null) {
                await ref.read(bluetoothProvider.notifier).disconnect();
                await Future.delayed(const Duration(seconds: 1));
                await ref.read(bluetoothProvider.notifier).connectToDevice(device);
              }
            } else {
              ref.read(bluetoothProvider.notifier).sendCommand("A22", "SOFT,RESET");
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
              command = "";
              data = "";
              batteryLevel = 0;
            });
          },
          icon: const Icon(Icons.close),
          label: const Text("Desconectar"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
        )
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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

  Widget _buildFuncionarioSelector(List funcionarios, String? selectedFuncionarioId) {
    final nomeFuncionario = funcionarios.firstWhere(
      (funcionario) => funcionario.id == selectedFuncionarioId,
      orElse: () => FuncionarioModel(id: "visitante", nome: "Visitante"),
    ).nome;

    return ListTile(
      title: const Text("Funcionário Selecionado"),
      subtitle: Text(selectedFuncionarioId == null ? "Visitante" : nomeFuncionario),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: () {
        ref.read(funcionarioProvider.notifier).carregarFuncionarios(); // 🔹 Força atualização
        _mostrarSelecaoFuncionario(ref.watch(funcionarioProvider)); // 🔹 Chama a lista atualizada
      },
    );
  }

  void _mostrarSelecaoFuncionario(List funcionarios) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 🔹 Isso permite ajustar a altura do modal dinamicamente
      builder: (context) {
        TextEditingController filtroController = TextEditingController();
        List funcionariosFiltrados = funcionarios;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, // 🔹 Ajusta para o teclado
          ),
          child: SingleChildScrollView( // 🔹 Evita que o teclado esconda os itens
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
                          funcionariosFiltrados = funcionarios.where(
                            (f) => f.nome.toLowerCase().contains(query.toLowerCase()),
                          ).toList();
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
                              ref.read(bluetoothProvider.notifier).selecionarFuncionario("visitante");
                              Navigator.pop(context);
                            },
                          ),
                          ...funcionariosFiltrados.map((funcionario) {
                            return ListTile(
                              title: Text(funcionario.nome),
                              onTap: () {
                                ref.read(bluetoothProvider.notifier).selecionarFuncionario(funcionario.id);
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
