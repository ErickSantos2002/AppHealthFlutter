import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/test_model.dart';

class ExportHelper {
  static Future<void> exportarTestes({
    required List<TestModel> testes,
    required bool incluirStatusCalibracao,
  }) async {
    final Directory tempDir = await getTemporaryDirectory();
    final exportDir = Directory('${tempDir.path}/exportacao');
    final fotosDir = Directory('${exportDir.path}/fotos');

    if (await exportDir.exists()) await exportDir.delete(recursive: true);
    await fotosDir.create(recursive: true);

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

    for (var teste in testes) {
      final data = teste.timestamp;
      final resultado = teste.command;
      final unidade = teste.getUnidadeFormatada();
      final dispositivo = teste.deviceName ?? "";
      final funcionario = teste.funcionarioNome;
      final fotoPath = teste.photoPath ?? "";
      final calibrado = incluirStatusCalibracao
      ? (teste.statusCalibracao.toLowerCase().contains("normal") ? "Sim" : "Não")
      : "";

      String fotoArquivo = "";
      if (fotoPath.isNotEmpty) {
        final fotoFile = File(fotoPath);
        if (await fotoFile.exists()) {
          final nomeFoto = fotoFile.uri.pathSegments.last;
          await fotoFile.copy('${fotosDir.path}/$nomeFoto');
          fotoArquivo = 'fotos/$nomeFoto';
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

    final csvPath = '${exportDir.path}/testes.csv';
    await File(csvPath).writeAsString(csvBuffer.toString());

    final zipEncoder = ZipFileEncoder();
    final zipPath = '${tempDir.path}/dados_exportados.zip';
    zipEncoder.create(zipPath);
    zipEncoder.addDirectory(exportDir);
    zipEncoder.close();

    await Share.shareXFiles([XFile(zipPath)], text: 'Exportação de dados do app');
  }
}
