import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/test_model.dart';

class ExportHelper {
  static Future<void> exportarTestes({
    required List<TestModel> testes,
    required bool incluirStatusCalibracao,
  }) async {
    if (testes.isEmpty) {
      print("⚠️ Nenhum teste disponível para exportar.");
      return;
    }

    final Directory tempDir = await getTemporaryDirectory();
    final exportDir = Directory('${tempDir.path}/exportacao');
    if (await exportDir.exists()) {
      await exportDir.delete(recursive: true);
    }
    await exportDir.create(recursive: true);

    // 1. Gera o conteúdo CSV em memória
    final csvBuffer = StringBuffer();
    final header = [
      "Data",
      "Hora",
      "Resultado",
      "Unidade",
      "Dispositivo",
      "Funcionário",
      if (incluirStatusCalibracao) "Calibrado",
      "Foto"
    ];
    csvBuffer.writeln(header.join(','));

    // Fotos a serem incluídas no zip manualmente
    final Map<String, List<int>> fotosBytes = {};

    for (var teste in testes) {
      final data = teste.timestamp;
      final resultado = teste.command.replaceAll(",", ";");
      final unidade = teste.getUnidadeFormatada().replaceAll(",", ";");
      final dispositivo = (teste.deviceName ?? "").replaceAll(",", ";");
      final funcionario = (teste.funcionarioNome).replaceAll(",", ";");
      final calibrado = incluirStatusCalibracao
          ? (teste.statusCalibracao.toLowerCase().contains("normal") ? "Sim" : "Não")
          : "";

      String fotoArquivo = "";
      if (teste.photoPath != null && teste.photoPath!.isNotEmpty) {
        final fotoFile = File(teste.photoPath!);
        if (await fotoFile.exists()) {
          final nomeFoto = 'fotos/${fotoFile.uri.pathSegments.last}';
          final bytes = await fotoFile.readAsBytes();
          fotosBytes[nomeFoto] = bytes;
          fotoArquivo = nomeFoto;
        }
      }

      final linha = [
        "${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}",
        "${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}",
        resultado,
        unidade,
        dispositivo,
        funcionario,
        if (incluirStatusCalibracao) calibrado,
        fotoArquivo
      ].join(',');

      csvBuffer.writeln(linha);
    }

    // 2. Cria o arquivo zip manualmente
    final archive = Archive();

    // Adiciona o CSV
    final csvName = 'testes.csv';
    final csvBytes = Uint8List.fromList(csvBuffer.toString().codeUnits);
    archive.addFile(ArchiveFile(csvName, csvBytes.length, csvBytes));

    // Adiciona as fotos
    fotosBytes.forEach((path, bytes) {
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    });

    // 3. Salva o zip na pasta temporária
    final zipPath = '${tempDir.path}/dados_exportados_${DateTime.now().millisecondsSinceEpoch}.zip';
    final zipFile = File(zipPath);
    await zipFile.writeAsBytes(ZipEncoder().encode(archive));

    print("✅ ZIP manual gerado com ${archive.length} arquivos: $zipPath");

    // 4. Compartilha com o usuário
    await Share.shareXFiles(
      [XFile(zipPath)],
      text: 'Exportação de dados do app',
    );
  }
}
