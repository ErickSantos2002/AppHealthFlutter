import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothPermissionHelper {
  static Future<bool> verificarPermissao(BuildContext context, {bool silencioso = false}) async {
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];

    bool allGranted = true;

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

    if (!silencioso && allGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Permissões de Bluetooth já estão concedidas.")),
      );
    }

    return allGranted;
  }

  static void _mostrarDialogoPermissaoNegada(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Permissão Necessária"),
        content: const Text(
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
}
