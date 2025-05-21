// This file is part of the Alcoolemia app.
// It is subject to the license terms in the LICENSE file found in the top-level directory of this distribution.
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:intl/intl.dart';

import '../models/test_model.dart';
import '../models/funcionario_model.dart';
import 'package:hive/hive.dart';

class LaudoPdfHelper {
  static Future<void> exportarTesteComoPDF(
    TestModel teste, {
    required bool exibirStatusCalibracao,
    bool comFoto = true,
  }) async {
    final pdf = pw.Document();
    final funcionariosBox = Hive.box<FuncionarioModel>('funcionarios');

    final funcionario = funcionariosBox.values.firstWhere(
      (f) => f.id == teste.funcionarioId,
      orElse: () => FuncionarioModel(id: "visitante", nome: teste.funcionarioNome),
    );

    // Carregar logo como asset
    final logoBytes = await rootBundle.load('assets/images/logo_laudo.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final image = (teste.photoPath != null && File(teste.photoPath!).existsSync())
        ? pw.MemoryImage(File(teste.photoPath!).readAsBytesSync())
        : null;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: -12, vertical: -24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Topo com logo à direita
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(width: 120), // Espaço à esquerda (pode ser logo da empresa no futuro)
                    pw.Container(
                      width: 120,
                      height: 50,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                // Título centralizado
                pw.Center(
                  child: pw.Text(
                    "Laudo de Teste de Alcoolemia",
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Divider(),
                pw.SizedBox(height: 18),
                // Dados do funcionário/teste
                pw.Text("Nome: ${funcionario.nome}", style: pw.TextStyle(fontSize: 14)),
                if (funcionario.cargo.isNotEmpty)
                  pw.Text("Cargo: ${funcionario.cargo}", style: pw.TextStyle(fontSize: 14)),
                if ((funcionario.cpf ?? "").isNotEmpty)
                  pw.Text("CPF: ${funcionario.cpf}", style: pw.TextStyle(fontSize: 14)),
                if ((funcionario.matricula ?? "").isNotEmpty)
                  pw.Text("Matrícula: ${funcionario.matricula}", style: pw.TextStyle(fontSize: 14)),
                pw.Text("Data e Hora: ${DateFormat('dd/MM/yyyy HH:mm').format(teste.timestamp)}", style: pw.TextStyle(fontSize: 14)),
                pw.Text("Resultado: ${teste.command}", style: pw.TextStyle(fontSize: 14)),
                pw.Text("Dispositivo: ${teste.deviceName ?? 'Desconhecido'}", style: pw.TextStyle(fontSize: 14)),
                if (exibirStatusCalibracao)
                  pw.Text("Status de Calibração: ${teste.statusCalibracao}", style: pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 20),
                if (comFoto && image != null)
                  pw.Center(
                    child: pw.Image(image, height: 300),
                  ),
                pw.Spacer(),
                // Linhas de assinatura
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    pw.Column(
                      children: [
                        pw.Container(
                          width: 160,
                          height: 1,
                          color: PdfColors.grey,
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text("Assinatura 1", style: pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Container(
                          width: 160,
                          height: 1,
                          color: PdfColors.grey,
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text("Assinatura 2", style: pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}