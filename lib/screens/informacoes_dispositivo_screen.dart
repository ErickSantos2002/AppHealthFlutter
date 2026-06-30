import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/configuracoes_provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../providers/bluetooth_provider.dart';
import 'dart:async';

class InformacoesDispositivoScreen extends ConsumerStatefulWidget {
  const InformacoesDispositivoScreen({super.key});

  @override
  ConsumerState<InformacoesDispositivoScreen> createState() =>
      _InformacoesDispositivoScreenState();
}

class _InformacoesDispositivoScreenState
    extends ConsumerState<InformacoesDispositivoScreen> {
  String versaoFirmware = "Carregando...";
  String contagemUso = "Carregando...";
  String ultimaCalibracao = "Carregando...";
  StreamSubscription<List<int>>? _bluetoothSubscription;
  bool _conexaoRestaurada = false;
  bool avisoCalibracaoExibido = false;
  bool avisoUsoExibido = false;
  bool avisoProximidadeExibido = false;
  BluetoothDevice? _ultimoDispositivoConectado;

  @override
  Widget build(BuildContext context) {
    final bluetoothState = ref.watch(bluetoothProvider);
    if (!bluetoothState.isConnected) {
      avisoCalibracaoExibido = false;
      avisoUsoExibido = false;
    }

    if (bluetoothState.isConnected) {
      final dispositivoAtual = bluetoothState.connectedDevice;

      if (_ultimoDispositivoConectado?.id != dispositivoAtual?.id) {
        print("🔁 Novo dispositivo conectado detectado!");
        _ultimoDispositivoConectado = dispositivoAtual;
        _conexaoRestaurada = false; // Força nova restauração
      }

      if (!_conexaoRestaurada) {
        print("🔄 Chamando _restaurarConexao() para o novo dispositivo...");
        _conexaoRestaurada = true;
        Future.microtask(() => _restaurarConexao());
      }
    } else {
      // 🔄 Se estiver desconectado, limpar os dados exibidos
      _ultimoDispositivoConectado = null;
      _conexaoRestaurada = false;
      versaoFirmware = "Carregando...";
      contagemUso = "Carregando...";
      ultimaCalibracao = "Carregando...";
      avisoCalibracaoExibido = false;
      avisoUsoExibido = false;
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Informações do Dispositivo")),
      body:
          bluetoothState.isConnected
              ? _buildDeviceInfo()
              : _buildNoDeviceConnected(),
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

    print(
      "🔎 [InformacoesDispositivoScreen] Descobrindo características BLE...",
    );
    await bluetoothNotifier.restoreCharacteristics();
    await Future.delayed(const Duration(seconds: 1));

    // Relê o estado APÓS a restauração — o snapshot inicial ficou
    // desatualizado (Riverpod é imutável; restoreCharacteristics criou
    // um novo objeto de estado).
    final estadoAtual = ref.read(bluetoothProvider);

    if (estadoAtual.notifiableCharacteristic == null) {
      print(
        "❌ [InformacoesDispositivoScreen] Característica de notificação ainda não disponível!",
      );
      return;
    }

    print(
      "🔍 [InformacoesDispositivoScreen] Característica de notificação confirmada: ${estadoAtual.notifiableCharacteristic!.uuid}",
    );

    await estadoAtual.notifiableCharacteristic!.setNotifyValue(true);
    print("✅ [InformacoesDispositivoScreen] Notificações BLE ativadas!");

    print("🔄 [InformacoesDispositivoScreen] Chamando _iniciarListener()...");
    _iniciarListener();
    _obterInformacoesDispositivo();
  }

  void _iniciarListener() {
    void verificarAvisos() {
      try {
        final notificacoesAtivas =
            ref.read(configuracoesProvider).notificacoesAtivas;
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

        bool calibracaoAtrasada =
            dataCalibracao != null &&
            hoje.difference(dataCalibracao).inDays > 365;

        int usoAtual =
            int.tryParse(contagemUso.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final deviceName =
            ref.watch(bluetoothProvider).connectedDevice?.name.toLowerCase() ??
            "";
        final isAL88 = deviceName.contains("al88");
        final usoProximoDoLimite = isAL88 && usoAtual >= 900 && usoAtual < 1000;
        bool usoExcedido = usoAtual > 1000;

        if ((calibracaoAtrasada && !avisoCalibracaoExibido) ||
            (usoExcedido && !avisoUsoExibido) ||
            (usoProximoDoLimite && !avisoProximidadeExibido)) {
          String mensagem = "";

          if (calibracaoAtrasada && !avisoCalibracaoExibido) {
            mensagem +=
                "⚠️ A calibração do aparelho está atrasada! Realize uma nova calibração.\n\n";
            avisoCalibracaoExibido = true;
          }
          if (usoProximoDoLimite && !avisoProximidadeExibido) {
            mensagem +=
                "⚠️ Faltam ${1000 - usoAtual} testes para o limite de 1000! Recomendamos calibrar o aparelho.\n";
            avisoProximidadeExibido = true;
          }
          if (isAL88 && usoExcedido && !avisoUsoExibido) {
            mensagem +=
                "⚠️ O limite de 1000 testes foi atingido! Recomenda-se uma calibração.\n";
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
      print(
        "❌ [InformacoesDispositivoScreen] Característica de notificação não encontrada!",
      );
      return;
    }

    print(
      "✅ [InformacoesDispositivoScreen] Característica BLE disponível: ${bluetoothState.notifiableCharacteristic!.uuid}",
    );

    _bluetoothSubscription?.cancel();
    _bluetoothSubscription = bluetoothState.notifiableCharacteristic!.value.listen((
      value,
    ) {
      print(
        "📡 [InformacoesDispositivoScreen] Listener ativo! Recebendo notificações BLE...",
      );

      if (value.isNotEmpty && mounted) {
        setState(() {
          verificarAvisos();
        });
      }
    });

    print(
      "🎯 [InformacoesDispositivoScreen] Listener BLE iniciado com sucesso!",
    );
  }

  /// 🔹 Aguarda a característica de escrita antes de enviar os comandos
  Future<void> _obterInformacoesDispositivo() async {
    final bluetoothNotifier = ref.read(bluetoothProvider.notifier);
    final bluetoothState = ref.read(bluetoothProvider);

    if (bluetoothState.isConnected &&
        bluetoothState.writableCharacteristic != null) {
      final deviceName =
          bluetoothState.connectedDevice?.name.toLowerCase() ?? "";
      print("📤 Enviando comandos para obter informações...");
      if (deviceName.contains("al88") || deviceName.contains("iblow")) {
        bluetoothNotifier.sendCommand("A01", "INFORMATION");
        await Future.delayed(const Duration(milliseconds: 500));
        bluetoothNotifier.sendCommand("A03", "0");
        await Future.delayed(const Duration(milliseconds: 500));
        bluetoothNotifier.sendCommand("A04", "0");
      } else if (deviceName.contains("deimos") ||
          deviceName.contains("hlx") ||
          deviceName.contains("titan")) {
        // Comandos corretos para Titan/Deimos/HLX
        bluetoothNotifier.sendCommand("FF00", ""); // Firmware
        await Future.delayed(const Duration(milliseconds: 500));
        bluetoothNotifier.sendCommand("9005", ""); // Contagem de uso
        await Future.delayed(const Duration(milliseconds: 500));
        bluetoothNotifier.sendCommand("9007", ""); // Última calibração
        await Future.delayed(const Duration(milliseconds: 500));
        bluetoothNotifier.sendCommand("9004", ""); // Bateria
      } else {
        print("❌ Tipo de dispositivo desconhecido para envio de comandos!");
      }
    } else {
      print(
        "❌ Dispositivo não está conectado ou característica de escrita indisponível!",
      );
    }
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
    return valor.isNotEmpty
        ? valor
        : "0"; // Se ficar vazio após a remoção, retorna "0"
  }

  Widget _buildDeviceInfo() {
    final deviceInfo = ref.watch(bluetoothProvider).deviceInfo;
    final deviceName =
        ref.watch(bluetoothProvider).connectedDevice?.name.toLowerCase() ?? "";
    final versao = deviceInfo?.firmware ?? "Carregando...";
    final uso =
        deviceInfo?.usageCounter != null
            ? deviceInfo!.usageCounter.toString()
            : "Carregando...";
    final calibracao = deviceInfo?.lastCalibrationDate ?? "Carregando...";

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(Icons.device_hub, "Versão do Firmware", versao),
          _buildInfoCard(
            Icons.bar_chart,
            "Contagem de Uso",
            _formatarQuantidadeTestes(uso),
          ),
          if (!deviceName.contains("al88"))
            _buildInfoCard(
              Icons.date_range,
              "Última Calibração",
              _formatarData(calibracao),
            ),
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
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          formattedValue,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
