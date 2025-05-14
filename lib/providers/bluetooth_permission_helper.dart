import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class BluetoothPermissionHelper {
  static Future<bool> verificarPermissao(BuildContext context, {bool silencioso = false}) async {
  bool allGranted = true;

  if (Platform.isAndroid) {
    print("🟢 Verificando permissões no Android...");

    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];

    for (var permission in permissions) {
      var status = await permission.status;
      print("🔍 Status de ${permission.toString()}: $status");

      if (status.isGranted) continue;

      if (status.isDenied) {
        var result = await permission.request();
        print("📥 Resultado do pedido de ${permission.toString()}: $result");

        if (!result.isGranted) {
          allGranted = false;
        }
      } else if (status.isPermanentlyDenied) {
        print("❌ Permissão ${permission.toString()} permanentemente negada.");
        allGranted = false;
        _mostrarDialogoPermissaoNegada(context);
      }
    }
  } else {
    print("🍏 Verificando permissões no iOS...");

    bool locationEnabled = await Geolocator.isLocationServiceEnabled();
    print("📡 Serviço de localização ativo: $locationEnabled");

    if (!locationEnabled) {
      print("⚠️ Localização desativada no sistema.");
      allGranted = false;
      _mostrarDialogoAtivarLocalizacao(context);
    }

    LocationPermission permission = await Geolocator.checkPermission();
    print("🔎 Status atual da permissão de localização: $permission");

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      print("📥 Resultado da solicitação de permissão de localização: $permission");
    }

    if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
      print("❌ Localização negada ou permanentemente negada: $permission");
      allGranted = false;
      _mostrarDialogoPermissaoNegada(
        context,
        mensagemPersonalizada: "A permissão de localização é necessária para detectar dispositivos Bluetooth no iOS.",
      );
    }
  }

  print("✅ Resultado final da verificação de permissões: $allGranted");

  if (!silencioso && allGranted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Permissões de Bluetooth já estão concedidas.")),
    );
  }

  return allGranted;
}

  static void _mostrarDialogoPermissaoNegada(BuildContext context, {String? mensagemPersonalizada}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Permissão Necessária"),
        content: Text(
          mensagemPersonalizada ??
              "Algumas permissões de Bluetooth foram negadas permanentemente. "
              "Para utilizar o app corretamente, vá até as configurações do sistema e habilite as permissões manualmente.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text("Abrir Configurações"),
          ),
        ],
      ),
    );
  }

  static void _mostrarDialogoAtivarLocalizacao(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Localização Desativada"),
        content: const Text(
          "A localização do dispositivo está desativada. "
          "Ative o GPS nas configurações do sistema para que o app possa detectar dispositivos Bluetooth corretamente.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fechar"),
          ),
          TextButton(
            onPressed: () {
              Geolocator.openLocationSettings();
              Navigator.pop(context);
            },
            child: const Text("Abrir Configurações"),
          ),
        ],
      ),
    );
  }
}
