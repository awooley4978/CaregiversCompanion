// Renders [EmergencyInfoData] into the PDF handed to EMS.
//
// Takes assembled data and nothing else (no Firestore, no app state) — the same
// instance the Emergency Info screen displays, so the printout cannot disagree
// with what the caregiver just read on screen.
//
// Content rule: only stored information, and 'Not provided' where the care
// profile holds nothing. Nothing is invented.
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'emergency_info.dart';

/// Text styles for the printout (plain base-14 fonts: no asset loading needed).
final _headingStyle = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold);
final _bodyStyle = pw.TextStyle(fontSize: 10.5);
final _metaStyle = pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700);

/// Builds the EMS PDF. Compression is off so the content stream stays plain
/// text — the printout is short, and it keeps the PDF verifiable in tests.
Future<Uint8List> buildEmergencyInfoPdf(EmergencyInfoData data) async {
  final document = pw.Document(
    title: 'Emergency information - ${data.recipientNameOrNotProvided}',
    subject: 'Emergency information for EMS',
    compress: false,
  );

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 44),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: _metaStyle,
        ),
      ),
      build: (context) => _emergencyInfoWidgets(data),
    ),
  );

  return document.save();
}

List<pw.Widget> _emergencyInfoWidgets(EmergencyInfoData data) => [
      pw.Text(
        'Emergency Information',
        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        data.recipientNameOrNotProvided,
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 2),
      pw.Text('Date of birth: ${data.dateOfBirthOrNotProvided}',
          style: _bodyStyle),
      pw.SizedBox(height: 10),
      pw.Text(
        'Generated ${DateFormat('d MMM yyyy, h:mm a').format(data.generatedAt)} '
        'from the care profile saved in Caregivers Companion.',
        style: _metaStyle,
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        'Values marked "$emergencyInfoNotProvided" are not recorded in the '
        'care profile.',
        style: _metaStyle,
      ),
      pw.SizedBox(height: 14),
      _sectionHeading('Allergies'),
      for (final allergy in data.allergyLines)
        _listLine(allergy == emergencyInfoNotProvided
            ? allergy
            : 'Allergy: $allergy'),
      pw.SizedBox(height: 10),
      _sectionHeading('Medical conditions'),
      for (final condition in data.conditionLines) _listLine(condition),
      pw.SizedBox(height: 10),
      _sectionHeading('Emergency contact'),
      _fieldLine('Name', data.emergencyContactNameOrNotProvided),
      _fieldLine('Phone', data.emergencyContactPhoneOrNotProvided),
      pw.SizedBox(height: 10),
      _sectionHeading('Primary care physician'),
      _fieldLine('Name', data.primaryCarePhysicianNameOrNotProvided),
      _fieldLine('Phone', data.primaryCarePhysicianPhoneOrNotProvided),
      pw.SizedBox(height: 10),
      _sectionHeading('Current medications'),
      for (final medication in data.medicationLines) _listLine(medication),
      pw.SizedBox(height: 10),
      _sectionHeading('Advance directives'),
      _listLine(data.advanceDirectivesOrNotProvided),
    ];

pw.Widget _sectionHeading(String title) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: _headingStyle),
          pw.SizedBox(height: 2),
          pw.Divider(thickness: 0.6, color: PdfColors.grey400),
        ],
      ),
    );

pw.Widget _listLine(String text) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Text(text, style: _bodyStyle),
    );

pw.Widget _fieldLine(String label, String value) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Text('$label: $value', style: _bodyStyle),
    );
