import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class BluetoothPermissionHelper {
  static Future<bool> verificarPermissao(BuildContext context, {bool silencioso = false}) async {
    bool allGranted = true;

    if (Platform.isAndroid) {
      final permissions = [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ];

      for (var permission in permissions) {
        var status = await permission.status;

        if (status.isGranted) continue;

        if (status.isDenied) {
          var result = await permission.request();
          if (!result.isGranted) {
            allGranted = false;
          }
        } else if (status.isPermanentlyDenied) {
          allGranted = false;
          _mostrarDialogoPermissaoNegada(context);
        }
      }
    } else {
      // iOS: precisa da permissão de localização E do serviço de localização ativado
      var locationStatus = await Permission.locationWhenInUse.status;

      if (locationStatus.isDenied) {
        var result = await Permission.locationWhenInUse.request();
        locationStatus = result;
      }

      if (!locationStatus.isGranted) {
        allGranted = false;
        _mostrarDialogoPermissaoNegada(context, mensagemPersonalizada: "A permissão de localização é necessária para detectar dispositivos Bluetooth no iOS.");
      } else {
        // ✅ Verifica se os serviços de localização estão ativados
        bool locationEnabled = await Geolocator.isLocationServiceEnabled();
        if (!locationEnabled) {
          allGranted = false;
          _mostrarDialogoAtivarLocalizacao(context);
        }
      }

      // iOS 13+: ainda é necessário declarar bluetooth nos plist, mas não há permissão explícita via código.
    }

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