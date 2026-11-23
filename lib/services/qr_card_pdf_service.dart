import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';

import '../models/student.dart';

class QrCardPdfService {
  static Future<Uint8List> generate(List<Student> students) async {
    if (students.isEmpty) {
      throw ArgumentError('Minimal satu siswa diperlukan untuk membuat PDF.');
    }

    final document = pw.Document();
    final cards = <pw.Widget>[];

    for (final student in students) {
      final painter = QrPainter(
        data: student.qrCode,
        version: QrVersions.auto,
        gapless: true,
      );
      final imageData = await painter.toImageData(
        256,
        format: ui.ImageByteFormat.png,
      );
      if (imageData == null) {
        throw StateError('QR untuk ${student.name} tidak dapat dibuat.');
      }

      cards.add(
        pw.Container(
          width: 250,
          height: 150,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey600),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(
                pw.MemoryImage(imageData.buffer.asUint8List()),
                width: 105,
                height: 105,
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      student.name,
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      maxLines: 2,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'NIS: ${student.nis}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      'Kelas: ${student.className}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Kartu QR Siswa',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Wrap(spacing: 12, runSpacing: 12, children: cards),
        ],
      ),
    );

    return document.save();
  }
}
