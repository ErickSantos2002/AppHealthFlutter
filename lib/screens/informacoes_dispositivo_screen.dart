import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/configuracoes_provider.dart';
import '../providers/bluetooth_provider.dart';
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
  bool _conexaoRestaurada = false;
  bool avisoCalibracaoExibido = false;
  bool avisoUsoExibido = false;

  @override
  Widget build(BuildContext context) {
    final bluetoothState = ref.watch(bluetoothProvider);
    if (!bluetoothState.isConnected) {
      avisoCalibracaoExibido = false;
      avisoUsoExibido = false;
    }

    if (bluetoothState.isConnected && !_conexaoRestaurada) {
      print("🔄 [InformacoesDispositivoScreen] Bluetooth conectado! Chamando _restaurarConexao()...");
      _conexaoRestaurada = true;
      Future.microtask(() => _restaurarConexao());
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Informações do Dispositivo")),
      body: bluetoothState.isConnected ? _buildDeviceInfo() : _buildNoDeviceConnected(),
    );
  }

  @override
  void dispose() {
    _bluetoothSubscription?.cancel();
    super.dispose();
  }

  Future<void> _restaurarConexao() async {
    final bluetoothNotifier = ref.read(bluetoothProvider.notifier);
    final bluetoothState = ref.read(bluetoothProvider);

    print("♻️ [InformacoesDispositivoScreen] Restaurando conexão BLE...");

    if (!bluetoothState.isConnected) {
      print("❌ [InformacoesDispositivoScreen] Dispositivo não está conectado!");
      return;
    }

    print("🔎 [InformacoesDispositivoScreen] Descobrindo características BLE...");
    await bluetoothNotifier.restoreCharacteristics();
    await Future.delayed(const Duration(seconds: 1));

    if (bluetoothState.notifiableCharacteristic == null) {
      print("❌ [InformacoesDispositivoScreen] Característica de notificação ainda não disponível!");
      return;
    }

    print("🔍 [InformacoesDispositivoScreen] Característica de notificação confirmada: ${bluetoothState.notifiableCharacteristic!.uuid}");

    await bluetoothState.notifiableCharacteristic!.setNotifyValue(true);
    print("✅ [InformacoesDispositivoScreen] Notificações BLE ativadas!");

    print("🔄 [InformacoesDispositivoScreen] Chamando _iniciarListener()...");
    _iniciarListener();
    _obterInformacoesDispositivo();
  }

  void _iniciarListener() {
    void _verificarAvisos() {
      try {
        final notificacoesAtivas = ref.read(configuracoesProvider).notificacoesAtivas;
        if (!notificacoesAtivas) return; // 🔇 Notificações desativadas

        DateTime hoje = DateTime.now();
        DateTime? dataCalibracao;

        if (ultimaCalibracao.isNotEmpty && ultimaCalibracao.contains(".")) {
          List<String> partes = ultimaCalibracao.split(".");
          if (partes.length == 3) {
            int ano = int.tryParse(partes[0]) ?? 0;
            int mes = int.tryParse(partes[1]) ?? 0;
            int dia = int.tryParse(partes[2]) ?? 0;
            dataCalibracao = DateTime(ano, mes, dia);
          }
        }

        bool calibracaoAtrasada = dataCalibracao != null && hoje.difference(dataCalibracao).inDays > 365;

        int usoAtual = int.tryParse(contagemUso.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        bool usoExcedido = usoAtual > 1000;

        if ((calibracaoAtrasada && !avisoCalibracaoExibido) || (usoExcedido && !avisoUsoExibido)) {
          String mensagem = "";

          if (calibracaoAtrasada && !avisoCalibracaoExibido) {
            mensagem += "⚠️ A calibração do aparelho está atrasada! Realize uma nova calibração.\n\n";
            avisoCalibracaoExibido = true;
          }
          if (usoExcedido && !avisoUsoExibido) {
            mensagem += "⚠️ O limite de 1000 testes foi atingido! Recomenda-se uma calibração.\n";
            avisoUsoExibido = true;
          }

          Future.delayed(Duration.zero, () {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text("⚠️ Atenção"),
                  content: Text(mensagem.trim()),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("OK"),
                    ),
                  ],
                );
              },
            );
          });
        }
      } catch (e) {
        print("Erro ao verificar avisos: $e");
      }
    }
    final bluetoothState = ref.read(bluetoothProvider);

    print("🔄 [InformacoesDispositivoScreen] Tentando iniciar listener BLE...");

    if (bluetoothState.notifiableCharacteristic == null) {
      print("❌ [InformacoesDispositivoScreen] Característica de notificação não encontrada!");
      return;
    }

    print("✅ [InformacoesDispositivoScreen] Característica BLE disponível: ${bluetoothState.notifiableCharacteristic!.uuid}");

    _bluetoothSubscription?.cancel();
    _bluetoothSubscription = bluetoothState.notifiableCharacteristic!.value.listen((value) {
      print("📡 [InformacoesDispositivoScreen] Listener ativo! Recebendo notificações BLE...");

      if (value.isNotEmpty && mounted) {
        final processedData = processReceivedData(value);
        print("📩 [InformacoesDispositivoScreen] Dados recebidos: ${processedData["command"]} -> ${processedData["data"]}");

        setState(() {
          if (processedData["command"] == "B01") versaoFirmware = processedData["data"];
          if (processedData["command"] == "B03") contagemUso = "${processedData["data"]} testes";
          if (processedData["command"] == "B04") ultimaCalibracao = processedData["data"];

          _verificarAvisos(); // 🔹 Chama a função para verificar os avisos
        });
      }
    });

    print("🎯 [InformacoesDispositivoScreen] Listener BLE iniciado com sucesso!");
  }

  /// 🔹 Aguarda a característica de escrita antes de enviar os comandos
  Future<void> _obterInformacoesDispositivo() async {
    final bluetoothNotifier = ref.read(bluetoothProvider.notifier);
    final bluetoothState = ref.read(bluetoothProvider);

    if (bluetoothState.isConnected && bluetoothState.writableCharacteristic != null) {
      print("📤 Enviando comandos para obter informações...");
      bluetoothNotifier.sendCommand("A01", "INFORMATION");
      await Future.delayed(const Duration(milliseconds: 500));
      bluetoothNotifier.sendCommand("A03", "0");
      await Future.delayed(const Duration(milliseconds: 500));
      bluetoothNotifier.sendCommand("A04", "0");
    } else {
      print("❌ Dispositivo não está conectado ou característica de escrita indisponível!");
    }
  }

  /// 🔹 Processa os dados recebidos do Bluetooth
  Map<String, dynamic> processReceivedData(List<int> rawData) {
    print("📩 Pacote recebido (bruto): ${rawData.map((e) => e.toRadixString(16)).join(" ")}");

    if (rawData.length < 5) {
      print("⚠️ Pacote muito curto para ser válido! Tamanho: ${rawData.length}");
      return {"command": "Erro", "data": "Pacote inválido", "battery": 0};
    }

    String commandCode = String.fromCharCodes(rawData.sublist(1, 4)).trim();
    String receivedData = String.fromCharCodes(rawData.sublist(4, 17)).replaceAll("#", "").trim();

    // Substituir vírgulas por pontos para números
    if (receivedData.contains(",")) {
      receivedData = receivedData.replaceAll(",", ".");
    }

    print("✅ Dados processados corretamente: Comando: $commandCode | Dados: $receivedData");

    return {
      "command": commandCode,
      "data": receivedData.isNotEmpty ? receivedData : "Indisponível",
      "battery": rawData.length > 5 ? rawData[4] : 0,
    };
  }

  String _formatarData(String data) {
    if (RegExp(r'^\d{4}\.\d{2}\.\d{2}$').hasMatch(data)) {
      List<String> dateParts = data.split(".");
      return "${dateParts[2]}/${dateParts[1]}/${dateParts[0]}"; // Converte para DD/MM/YYYY
    }
    return data; // Retorna o valor original se não for uma data válida
  }

  String _formatarQuantidadeTestes(String valor) {
    // Se começar com "0.", removemos essa parte
    if (valor.startsWith("0.")) {
      valor = valor.substring(2); // Remove os dois primeiros caracteres "0."
    }

    // Remove zeros à esquerda, garantindo que um número como "000141" vire "141"
    valor = valor.replaceFirst(RegExp(r'^0+'), '');

    // Retorna o valor formatado
    return valor.isNotEmpty ? valor : "0"; // Se ficar vazio após a remoção, retorna "0"
  }

  Widget _buildDeviceInfo() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(Icons.device_hub, "Versão do Firmware", versaoFirmware),
          _buildInfoCard(Icons.bar_chart, "Contagem de Uso", _formatarQuantidadeTestes(contagemUso)),
          _buildInfoCard(Icons.date_range, "Última Calibração", _formatarData(ultimaCalibracao)),
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
    // Se for um número, formatar com 2 casas decimais
    String formattedValue = value;
    if (RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) {
      formattedValue = double.parse(value).toStringAsFixed(2);
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Theme.of(context).cardColor,
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          formattedValue,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
