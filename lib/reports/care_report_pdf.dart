// Renders a [CareReportData] into a PDF.
//
// Kept separate from the data layer on purpose: the same renderer is meant to
// back the Weekly Summary and Emergency Info export actions later, so it takes
// assembled data and nothing else (no Firestore, no app state).
//
// Content rules from the owner-approved spec (2026-11-03): only recorded
// information, notes verbatim, sections with no records omitted, and an honest
// no-records report when the period is empty.
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'care_report.dart';

/// Text styles for the report (plain base-14 fonts: no asset loading needed).
final _headingStyle = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold);
final _bodyStyle = pw.TextStyle(fontSize: 10);
final _metaStyle = pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700);

/// Builds the report PDF. The page count follows the data: a short period is a
/// single page, a long one simply continues onto more pages.
Future<Uint8List> buildCareReportPdf(CareReportData data) async {
  final document = pw.Document(
    title: 'Care report - ${data.recipientName}',
    subject: data.range.label,
  );

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 44),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Text(
                '${data.recipientName} - care report (${data.range.label})',
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
      build: (context) => _reportWidgets(data),
    ),
  );

  return document.save();
}

List<pw.Widget> _reportWidgets(CareReportData data) {
  final widgets = <pw.Widget>[
    pw.Text('Care Report', style: pw.TextStyle(fontSize: 20)),
    pw.SizedBox(height: 4),
    pw.Text(
      data.recipientName.isEmpty ? 'Care recipient' : data.recipientName,
      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
    ),
    if (data.careCircleName.isNotEmpty)
      pw.Text(data.careCircleName, style: _metaStyle),
    pw.SizedBox(height: 10),
    pw.Text('Period: ${data.range.label}', style: _bodyStyle),
    pw.Text('Dates covered: ${data.range.boundsLabel}', style: _bodyStyle),
    pw.Text(
      'Report generated: ${careReportDateTime(data.generatedAt)}',
      style: _bodyStyle,
    ),
    if (data.hasRangedRecords)
      pw.Text(
        'Records from ${careReportDate(data.firstRecordAt!)} '
        'to ${careReportDate(data.lastRecordAt!)}',
        style: _bodyStyle,
      ),
    pw.SizedBox(height: 8),
    pw.Text(CareReportData.scopeNotice, style: _metaStyle),
    pw.SizedBox(height: 14),
  ];

  if (!data.hasRangedRecords) {
    widgets.add(pw.Text(CareReportData.noRecordsNotice, style: _bodyStyle));
    widgets.add(pw.SizedBox(height: 14));
  }

  if (data.symptoms.isNotEmpty) {
    widgets.addAll(_symptomSection(data.symptoms));
  }
  if (data.medications.isNotEmpty) {
    widgets.addAll(_medicationSection(data.medications));
  }
  if (data.notes.isNotEmpty) {
    widgets.addAll(_noteSection(data.notes));
  }

  return widgets;
}

pw.Widget _sectionHeading(String title, String? note) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: _headingStyle),
          if (note != null) pw.Text(note, style: _metaStyle),
          pw.SizedBox(height: 2),
          pw.Divider(thickness: 0.6, color: PdfColors.grey400),
        ],
      ),
    );

List<pw.Widget> _symptomSection(List<CareReportSymptom> symptoms) => [
      _sectionHeading('Reported symptoms', null),
      for (final symptom in symptoms)
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${symptom.name.isEmpty ? 'Symptom' : symptom.name} '
                '(${symptom.resolved ? 'resolved' : 'unresolved'})',
                style: pw.TextStyle(
                    fontSize: 10.5, fontWeight: pw.FontWeight.bold),
              ),
              if (symptom.timeLogged != null)
                pw.Text(
                  'Logged ${careReportDateTime(symptom.timeLogged!)}',
                  style: _metaStyle,
                ),
              if (symptom.note.trim().isNotEmpty)
                pw.Text(symptom.note, style: _bodyStyle),
            ],
          ),
        ),
      pw.SizedBox(height: 8),
    ];

List<pw.Widget> _medicationSection(List<CareReportMedication> medications) => [
      _sectionHeading(
        'Current medications',
        'The stored medication list - not limited to the period above.',
      ),
      for (final medication in medications)
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                [
                  if (medication.name.isNotEmpty) medication.name,
                  if (medication.dose.isNotEmpty) medication.dose,
                  if (medication.status.isNotEmpty) medication.status,
                ].join(' - '),
                style: pw.TextStyle(fontSize: 10.5),
              ),
              if (medication.schedule.isNotEmpty)
                pw.Text(medication.schedule, style: _metaStyle),
            ],
          ),
        ),
      pw.SizedBox(height: 8),
    ];

List<pw.Widget> _noteSection(List<CareReportNote> notes) => [
      _sectionHeading('Care notes', null),
      for (final note in notes)
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                [
                  if (note.timestamp != null) careReportDateTime(note.timestamp!),
                  if (note.category.isNotEmpty) note.category,
                  if (note.author.isNotEmpty) 'by ${note.author}',
                ].join(' - '),
                style: _metaStyle,
              ),
              pw.Text(note.text, style: _bodyStyle),
            ],
          ),
        ),
    ];
