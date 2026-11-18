// Renders a [VitalsExportData] into a printable PDF.
//
// Kept separate from the data layer on purpose (the same split the care report
// uses): this file takes assembled data and nothing else — no Firestore, no app
// state — so the PDF stays testable without a database.
//
// Owner decisions of 2026-11-18 (vitals-export proposal §13, all thirteen
// approved as recommended) applied here:
//  * LANDSCAPE letter: a ten-column table with a notes line under each row does
//    not fit portrait;
//  * one row per reading, day headings above each day's rows, oldest first;
//  * the agreed columns (date, time, BP, heart rate, glucose, oxygen
//    saturation, temperature, weight, pain, real author) with notes on a line
//    under their row — never a notes column, never truncated;
//  * a dash for a measurement that was not recorded, and for a comparison where
//    no target exists. Pain 0 prints "0 / 10";
//  * NO averages, no charts, no interpretation, no metric units: the only
//    judgement is the comparison with a number a human entered, and the header
//    says where those numbers came from and that they are not medical advice;
//  * an honest one-page report when the period holds no readings.
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'care_report.dart';
import 'vitals_export.dart';

/// Text styles (plain base-14 fonts: no asset loading needed).
final _bodyStyle = pw.TextStyle(fontSize: 10);
final _metaStyle = pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700);
final _columnStyle =
    pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);
final _cellStyle = pw.TextStyle(fontSize: 8);
final _comparisonStyle = pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700);

/// Column widths, as flex factors. Shared by the heading row and every reading
/// row so the columns line up across pages.
const List<int> _columnFlex = <int>[26, 20, 26, 18, 22, 16, 20, 20, 18, 26];

/// Builds the export PDF. The page count follows the data: a short period is a
/// single page, a long one continues onto more pages.
Future<Uint8List> buildVitalsExportPdf(VitalsExportData data) async {
  final document = pw.Document(
    title: 'Vitals export - ${data.recipientName}',
    subject: data.range.label,
  );

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter.landscape,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 44),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Text(
                '${data.recipientName} - vitals export (${data.range.label})',
                style: _metaStyle,
              ),
            ),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: _metaStyle,
        ),
      ),
      build: (context) => _exportWidgets(data),
    ),
  );

  return document.save();
}

List<pw.Widget> _exportWidgets(VitalsExportData data) {
  final widgets = <pw.Widget>[
    pw.Text('Vitals Export', style: pw.TextStyle(fontSize: 20)),
    pw.SizedBox(height: 4),
    pw.Text(
      data.recipientName.isEmpty ? 'Care recipient' : data.recipientName,
      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 10),
    pw.Text('Period: ${data.range.label}', style: _bodyStyle),
    pw.Text('Dates covered: ${data.range.boundsLabel}', style: _bodyStyle),
    pw.Text(
      'Report generated: ${careReportDateTime(data.generatedAt)}',
      style: _bodyStyle,
    ),
    pw.Text(
      'Readings in this period: ${data.readingCount}',
      style: _bodyStyle,
    ),
    pw.SizedBox(height: 8),
    pw.Text(vitalsExportLocalTimeNotice, style: _metaStyle),
    if (data.hasTargets) pw.Text(vitalsExportTargetsLine(data), style: _metaStyle),
    if (data.isTruncated)
      pw.Text(vitalsExportTruncatedNotice(data), style: _metaStyle),
    if (data.undatedCount > 0)
      pw.Text(vitalsExportUndatedNotice(data.undatedCount), style: _metaStyle),
    pw.SizedBox(height: 14),
  ];

  if (!data.hasReadings) {
    widgets.add(pw.Text(vitalsExportNoReadingsNotice, style: _bodyStyle));
    return widgets;
  }

  widgets.add(_columnHeadingRow());
  for (final day in data.days) {
    widgets.add(_dayHeading(day));
    for (final reading in day.readings) {
      widgets.add(_readingRow(
        reading,
        day: day.date,
        showComparisons: data.hasTargets,
      ));
      if (reading.hasNotes) {
        widgets.add(_notesRow(reading.notes));
      }
    }
  }
  return widgets;
}

pw.Widget _cell(String text, int index, {pw.TextStyle? style}) => pw.Expanded(
      flex: _columnFlex[index],
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: pw.Text(text, style: style ?? _cellStyle),
      ),
    );

pw.Widget _columnHeadingRow() => pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 0.6, color: PdfColors.grey600),
        ),
      ),
      child: pw.Row(
        children: <pw.Widget>[
          for (var i = 0; i < vitalsExportColumnHeaders.length; i++)
            _cell(vitalsExportColumnHeaders[i], i, style: _columnStyle),
        ],
      ),
    );

pw.Widget _dayHeading(VitalsExportDay day) => pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      color: PdfColors.grey300,
      child: pw.Text(
        day.heading,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    );

pw.Widget _readingRow(
  VitalsExportReading reading, {
  required DateTime day,
  required bool showComparisons,
}) {
  final cells = <pw.Widget>[
    _cell(careReportDate(day), 0),
    _cell(reading.timeText, 1),
  ];
  for (var i = 0; i < vitalsExportMeasurements.length; i++) {
    final measurement = vitalsExportMeasurements[i];
    final comparison = showComparisons ? reading.comparisonFor(measurement) : null;
    cells.add(pw.Expanded(
      flex: _columnFlex[i + 2],
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(reading.valueFor(measurement), style: _cellStyle),
            if (comparison != null)
              pw.Text(comparison, style: _comparisonStyle),
          ],
        ),
      ),
    ));
  }
  cells.add(_cell(reading.author, 9));

  return pw.Container(
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(width: 0.3, color: PdfColors.grey400),
      ),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: cells,
    ),
  );
}

pw.Widget _notesRow(String notes) => pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(6, 2, 6, 4),
      child: pw.Text(
        'Notes: $notes',
        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
      ),
    );
