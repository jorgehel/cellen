import 'package:flutter/material.dart' show Colors;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ---------------------------------------------------------------------------
// Score helpers
// ---------------------------------------------------------------------------

String _scoreLabel(int? score) => switch (score) {
      1 => 'Insuficiente',
      2 => 'Suficiente',
      3 => 'Bom',
      4 => 'Muito Bom',
      5 => 'Excelente',
      _ => '—',
    };

PdfColor _scoreColor(int? score) {
  if (score == null) return PdfColors.grey;
  if (score <= 2) return PdfColors.red700;
  if (score == 3) return PdfColors.orange700;
  return PdfColors.green700;
}

// ---------------------------------------------------------------------------
// Period label
// ---------------------------------------------------------------------------

String _periodLabel(String p) => switch (p) {
      '1T' => '1º Trimestre',
      '2T' => '2º Trimestre',
      '3T' => '3º Trimestre',
      'anual' => 'Anual',
      _ => p,
    };

// ---------------------------------------------------------------------------
// Score bar widget (approximated with colored rectangles)
// ---------------------------------------------------------------------------

pw.Widget _scoreBar(int? score) {
  final filled = score ?? 0;
  final color = _scoreColor(score);
  return pw.Row(
    children: List.generate(5, (i) {
      final active = i < filled;
      return pw.Container(
        width: 16,
        height: 8,
        margin: const pw.EdgeInsets.only(right: 2),
        decoration: pw.BoxDecoration(
          color: active ? color : PdfColors.grey300,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
        ),
      );
    }),
  );
}

// ---------------------------------------------------------------------------
// Score row (label + bar + X/5 text)
// ---------------------------------------------------------------------------

pw.Widget _scoreRow(String label, int? score) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 140,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ),
        _scoreBar(score),
        pw.SizedBox(width: 8),
        pw.Text(
          score != null ? '$score/5' : '—',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _scoreColor(score),
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Text(
          _scoreLabel(score),
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Overall rating badge
// ---------------------------------------------------------------------------

pw.Widget _ratingBadge(String? rating) {
  if (rating == null || rating.isEmpty) return pw.SizedBox();
  final color = switch (rating) {
    'Excelente' => PdfColors.green700,
    'Bom' => PdfColors.blue700,
    'Satisfatório' => PdfColors.orange700,
    _ => PdfColors.red700,
  };
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: pw.BoxDecoration(
      color: color,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.Text(
      rating,
      style: pw.TextStyle(
        fontSize: 11,
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Optional text section (observations, areas to improve, objectives)
// ---------------------------------------------------------------------------

pw.Widget _textSection(String title, String? content) {
  if (content == null || content.trim().isEmpty) return pw.SizedBox();
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          content.trim(),
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Main public function
// ---------------------------------------------------------------------------

Future<void> generateAndShareBoletim({
  required Map<String, dynamic> child,
  required List<Map<String, dynamic>> evaluations,
}) async {
  final pdf = pw.Document();

  // Sort evaluations by date descending
  final sorted = List<Map<String, dynamic>>.from(evaluations)
    ..sort((a, b) {
      final da = a['evaluation_date'] as String? ?? '';
      final db = b['evaluation_date'] as String? ?? '';
      return db.compareTo(da);
    });

  // Child info
  final firstName = child['first_name'] as String? ?? '';
  final lastName = child['last_name'] as String? ?? '';
  final fullName = '$firstName $lastName'.trim();
  final birthDateRaw = child['birth_date'] as String?;
  final birthDate = birthDateRaw != null
      ? DateFormat('dd/MM/yyyy').format(DateTime.parse(birthDateRaw))
      : '—';
  final turmaName = child['turma_name'] as String? ?? '—';

  final generatedDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
  final schoolYear = DateTime.now().year.toString();

  // ---- Build PDF pages ----
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 40),
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header bar
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF1565C0), // deep blue
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'BOLETIM DE AVALIAÇÃO',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Ano Lectivo $schoolYear',
                      style: pw.TextStyle(fontSize: 11, color: PdfColors.blue100),
                    ),
                  ],
                ),
                pw.Text(
                  'Cellen',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // Child info section
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _infoRow('Nome', fullName),
                      pw.SizedBox(height: 4),
                      _infoRow('Data de Nascimento', birthDate),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _infoRow('Turma', turmaName),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 16),
        ],
      ),
      footer: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Gerado em $generatedDate  —  Cellen, Sistema de Gestão',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
            pw.Text(
              'Pág. ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ],
        ),
      ),
      build: (ctx) {
        if (sorted.isEmpty) {
          return [
            pw.Center(
              child: pw.Text(
                'Sem avaliações registadas.',
                style: pw.TextStyle(color: PdfColors.grey600),
              ),
            ),
          ];
        }

        return sorted.map((eval) {
          final period = eval['evaluation_period'] as String? ?? '';
          final dateRaw = eval['evaluation_date'] as String? ?? '';
          final dateFormatted = dateRaw.isNotEmpty
              ? DateFormat('dd/MM/yyyy').format(DateTime.parse(dateRaw))
              : '—';
          final overallRating = eval['overall_rating'] as String?;
          final observations = eval['observations'] as String?;
          final areasToImprove = eval['areas_to_improve'] as String?;
          final objectivesNext = eval['objectives_next_period'] as String?;

          final cognitive = (eval['cognitive'] as num?)?.toInt();
          final motor = (eval['motor'] as num?)?.toInt();
          final language = (eval['language'] as num?)?.toInt();
          final socialEmotional = (eval['social_emotional'] as num?)?.toInt();
          final creativity = (eval['creativity'] as num?)?.toInt();
          final autonomy = (eval['autonomy'] as num?)?.toInt();

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue200),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              color: PdfColors.white,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Period heading row
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: const PdfColor.fromInt(0xFFE3F2FD),
                            borderRadius:
                                const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Text(
                            _periodLabel(period),
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFF1565C0),
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          dateFormatted,
                          style: pw.TextStyle(
                              fontSize: 10, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                    _ratingBadge(overallRating),
                  ],
                ),

                pw.SizedBox(height: 10),
                pw.Divider(color: PdfColors.grey200),
                pw.SizedBox(height: 8),

                // Score rows
                _scoreRow('Cognitivo', cognitive),
                _scoreRow('Motor', motor),
                _scoreRow('Linguagem', language),
                _scoreRow('Social/Emocional', socialEmotional),
                _scoreRow('Criatividade', creativity),
                _scoreRow('Autonomia', autonomy),

                // Optional text sections
                _textSection('Observações', observations),
                _textSection('Áreas a Melhorar', areasToImprove),
                _textSection('Objectivos Próximo Período', objectivesNext),
              ],
            ),
          );
        }).toList();
      },
    ),
  );

  final bytes = await pdf.save();
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'boletim_${firstName.toLowerCase().replaceAll(' ', '_')}.pdf',
  );
}

// ---------------------------------------------------------------------------
// Helper: labelled info row for child section
// ---------------------------------------------------------------------------

pw.Widget _infoRow(String label, String value) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        '$label: ',
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey700,
        ),
      ),
      pw.Flexible(
        child: pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey900),
        ),
      ),
    ],
  );
}
