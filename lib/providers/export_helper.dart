import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/test_model.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncfusion;

class ExportHelper {
  static Future<void> exportarTestesTipo({
    required List<TestModel> testes,
    required bool incluirStatusCalibracao,
    required String tipo, // 'zip', 'pdf', 'xls'
  }) async {
    switch (tipo) {
      case 'zip':
        await _exportarZip(testes: testes, incluirStatusCalibracao: incluirStatusCalibracao);
        break;
      case 'pdf':
        await _exportarPdf(testes: testes, incluirStatusCalibracao: incluirStatusCalibracao);
        break;
      case 'xls':
        await _exportarXls(testes: testes, incluirStatusCalibracao: incluirStatusCalibracao);
        break;
      default:
        throw Exception("Tipo de exportação não suportado.");
    }
  }

  // ========================= ZIP (testes + fotos) =========================
  static Future<void> _exportarZip({
    required List<TestModel> testes,
    required bool incluirStatusCalibracao,
  }) async {
    if (testes.isEmpty) return;

    final Directory tempDir = await getTemporaryDirectory();
    final exportDir = Directory('${tempDir.path}/exportacao');
    if (await exportDir.exists()) {
      await exportDir.delete(recursive: true);
    }
    await exportDir.create(recursive: true);

    // 1. Prepara cabeçalho e coleta fotos
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

    final Map<String, List<int>> fotosBytes = {};

    // 2. Gera XLSX em memória
    final workbook = syncfusion.Workbook();
    final sheet = workbook.worksheets[0];
    for (var col = 0; col < header.length; col++) {
      sheet.getRangeByIndex(1, col + 1).setText(header[col]);
    }

    for (var i = 0; i < testes.length; i++) {
      final teste = testes[i];
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

      final row = [
        "${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}",
        "${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}",
        resultado,
        unidade,
        dispositivo,
        funcionario,
        if (incluirStatusCalibracao) calibrado,
        fotoArquivo
      ];
      for (var col = 0; col < row.length; col++) {
        sheet.getRangeByIndex(i + 2, col + 1).setText(row[col]);
      }
    }

    final xlsBytes = workbook.saveAsStream();
    workbook.dispose();

    // 3. Cria o arquivo zip manualmente
    final archive = Archive();

    // Adiciona o XLSX
    final xlsName = 'testes.xlsx';
    archive.addFile(ArchiveFile(xlsName, xlsBytes.length, xlsBytes));

    // Adiciona as fotos
    fotosBytes.forEach((path, bytes) {
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    });

    final zipPath = '${tempDir.path}/dados_exportados_${DateTime.now().millisecondsSinceEpoch}.zip';
    final zipFile = File(zipPath);
    await zipFile.writeAsBytes(ZipEncoder().encode(archive));

    await Share.shareXFiles(
      [XFile(zipPath)],
      text: 'Exportação de dados do app',
    );
  }

  // ========================= PDF =========================
  static Future<void> _exportarPdf({
    required List<TestModel> testes,
    required bool incluirStatusCalibracao,
  }) async {
    if (testes.isEmpty) return;
    final Directory tempDir = await getTemporaryDirectory();
    final pdf = pw.Document();

    final header = [
      "Data",
      "Hora",
      "Resultado",
      "Unidade",
      "Dispositivo",
      "Funcionário",
      if (incluirStatusCalibracao) "Calibrado"
    ];

    final rows = [
      header,
      ...testes.map((teste) {
        final data = teste.timestamp;
        final resultado = teste.command.replaceAll(",", ";");
        final unidade = teste.getUnidadeFormatada().replaceAll(",", ";");
        final dispositivo = (teste.deviceName ?? "").replaceAll(",", ";");
        final funcionario = (teste.funcionarioNome).replaceAll(",", ";");
        final calibrado = incluirStatusCalibracao
            ? (teste.statusCalibracao.toLowerCase().contains("normal") ? "Sim" : "Não")
            : "";
        return [
          "${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}",
          "${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}",
          resultado,
          unidade,
          dispositivo,
          funcionario,
          if (incluirStatusCalibracao) calibrado,
        ];
      }),
    ];

    final now = DateTime.now();
    final dataFormatada = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Relatório de Testes de Alcoolemia",
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                "Data da exportação: $dataFormatada",
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                data: rows,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 10),
              ),
            ],
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    final pdfPath = '${tempDir.path}/testes_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final pdfFile = File(pdfPath);
    await pdfFile.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(pdfPath)],
      text: 'Exportação de testes (PDF)',
    );
  }

  // ========================= XLS (Excel com Syncfusion) =========================
  static Future<void> _exportarXls({
    required List<TestModel> testes,
    required bool incluirStatusCalibracao,
  }) async {
    if (testes.isEmpty) return;
    final tempDir = await getTemporaryDirectory();

    // Cria um novo workbook Excel
    final workbook = syncfusion.Workbook();
    final sheet = workbook.worksheets[0];
    
    final header = [
      "Data",
      "Hora",
      "Resultado",
      "Unidade",
      "Dispositivo",
      "Funcionário",
      if (incluirStatusCalibracao) "Calibrado"
    ];
    // Adiciona header
    for (var col = 0; col < header.length; col++) {
      sheet.getRangeByIndex(1, col + 1).setText(header[col]);
    }

    // Adiciona linhas dos testes
    for (var i = 0; i < testes.length; i++) {
      final teste = testes[i];
      final data = teste.timestamp;
      final resultado = teste.command.replaceAll(",", ";");
      final unidade = teste.getUnidadeFormatada().replaceAll(",", ";");
      final dispositivo = (teste.deviceName ?? "").replaceAll(",", ";");
      final funcionario = (teste.funcionarioNome).replaceAll(",", ";");
      final calibrado = incluirStatusCalibracao
          ? (teste.statusCalibracao.toLowerCase().contains("normal") ? "Sim" : "Não")
          : "";

      final row = [
        "${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}",
        "${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}",
        resultado,
        unidade,
        dispositivo,
        funcionario,
        if (incluirStatusCalibracao) calibrado,
      ];
      for (var col = 0; col < row.length; col++) {
        sheet.getRangeByIndex(i + 2, col + 1).setText(row[col]);
      }
    }

    final bytes = workbook.saveAsStream();
    workbook.dispose();

    final xlsPath = '${tempDir.path}/testes_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final xlsFile = File(xlsPath);
    await xlsFile.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(xlsPath)],
      text: 'Exportação de testes (Excel)',
    );
  }
}
