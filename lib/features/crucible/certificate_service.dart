import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'crucible_feature.dart';

/// Generates a "Proven Idea" certificate for ideas that cleared the full
/// pressure test without being held on any challenge, and received a
/// formal Arbiter judgment. This is a completion certificate from
/// Crucible's own process — NOT a blockchain record, legal filing, or
/// intellectual-property registration, and it says so on its face.
class CertificateService {
  static Future<void> generateAndShare(
    CrucibleController controller, {
    required String ownerName,
  }) async {
    final version = controller.currentVersion;
    if (version == null || controller.report == null) return;

    final shortId = controller.id.length > 6
        ? controller.id.substring(controller.id.length - 6)
        : controller.id;
    final certificateId =
        'CRU-$shortId-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';

    // A genuine SHA-256 hash of the idea content + certificate ID + owner —
    // not a fake or placeholder, actually computed.
    final hashInput = utf8.encode('${version.content}|$certificateId|$ownerName');
    final contentHash = sha256.convert(hashInput).toString();

    final issuedAt = _formatTimestamp(DateTime.now());
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => pw.Stack(
          children: [
            pw.Container(color: PdfColor.fromInt(0xFF667EEA)),
            pw.Positioned(
              left: 15,
              top: 15,
              right: 15,
              bottom: 15,
              child: pw.Container(
                color: PdfColors.white,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(18),
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColor.fromInt(0xFF667EEA), width: 2),
                    ),
                    padding: const pw.EdgeInsets.all(24),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('CERTIFICATE OF PROVEN INVENTION',
                            style: pw.TextStyle(
                                fontSize: 26,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromInt(0xFF667EEA))),
                        pw.SizedBox(height: 6),
                        pw.Text('Pressure-tested by Zetra · Judged by Arbiter',
                            style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                        pw.SizedBox(height: 10),
                        pw.Text('Certificate ID: $certificateId', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('Issued: $issuedAt', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                        pw.SizedBox(height: 18),
                        pw.Text('This certifies that:', style: const pw.TextStyle(fontSize: 11)),
                        pw.SizedBox(height: 4),
                        pw.Text(ownerName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 8),
                        pw.Text('Is recognized as the originator of:', style: const pw.TextStyle(fontSize: 11)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          controller.title,
                          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 20),
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              child: pw.Container(
                                padding: const pw.EdgeInsets.all(10),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.grey100,
                                  border: pw.Border.all(color: PdfColor.fromInt(0xFF667EEA)),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('IDEA SUMMARY',
                                        style: pw.TextStyle(
                                            fontSize: 9,
                                            fontWeight: pw.FontWeight.bold,
                                            color: PdfColor.fromInt(0xFF667EEA))),
                                    pw.SizedBox(height: 4),
                                    pw.Text(controller.oneLiner, style: const pw.TextStyle(fontSize: 9)),
                                    pw.SizedBox(height: 6),
                                    pw.Text('Stages cleared: ${controller.stageIndex}/${controller.totalStages}',
                                        style: const pw.TextStyle(fontSize: 8)),
                                  ],
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 12),
                            pw.Expanded(
                              child: pw.Container(
                                padding: const pw.EdgeInsets.all(10),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.grey100,
                                  border: pw.Border.all(color: PdfColor.fromInt(0xFF667EEA)),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('VERIFICATION DATA',
                                        style: pw.TextStyle(
                                            fontSize: 9,
                                            fontWeight: pw.FontWeight.bold,
                                            color: PdfColor.fromInt(0xFF667EEA))),
                                    pw.SizedBox(height: 4),
                                    pw.Text('SHA-256 Content Hash:', style: const pw.TextStyle(fontSize: 7.5)),
                                    pw.Text(contentHash, style: const pw.TextStyle(fontSize: 6.5)),
                                    pw.SizedBox(height: 4),
                                    pw.Text('Readiness: ${controller.report!.readinessSummary}',
                                        style: const pw.TextStyle(fontSize: 7.5), maxLines: 3),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 18),
                        pw.Text(
                          'This certificate reflects that this idea completed the Crucible pressure-testing process\n'
                          'without being held on any challenge, and received a formal Arbiter judgment.\n'
                          'It is not a legal filing, patent, blockchain record, or intellectual-property registration.',
                          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: '$certificateId.pdf');
  }

  static String _formatTimestamp(DateTime now) {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    return '${days[now.weekday % 7]}, ${now.day} ${months[now.month - 1]} ${now.year} at $h:$m:$s';
  }
}
