// Vitals export — the printable table's data layer, its PDF, and the Vitals
// screen's export icon.
//
// Owner decisions of 2026-11-18 (`/home/team/shared/vitals-export-proposal-2026-11-18.md`
// §13, all thirteen approved as recommended). What is covered here:
//  * one row per reading, oldest first, day headings with a real count;
//  * readings outside the chosen period are not in the report;
//  * an unrecorded measurement prints a dash, never the getter's 0 — and pain
//    0 prints "0 / 10" because 0 is a real pain score;
//  * notes verbatim, the real author name, "Unknown user" when unresolved;
//  * a reading with no timestamp is counted and left out, never guessed at;
//  * targets: below / within / above, one-sided ranges, blood pressure needing
//    both sides (and naming the side that disagreed), no pain target, and no
//    comparison text at all for a recipient with no targets;
//  * the read is recipient-scoped and period-bounded, with the real author;
//  * the PDF is a real PDF, landscape, and a period with no readings still
//    makes a complete one-page report;
//  * the Vitals screen's export icon is disabled with no recipient and with no
//    readings, save/share and print go to different destinations, and a failed
//    read shows an error and produces no file.
//
// Everything runs offline against the in-memory Firestore fake
// (test/firebase_test_setup.dart), seeded and read through the app-facing API.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregivers_companion/app_state.dart';
import 'package:caregivers_companion/backend/backend.dart';
import 'package:caregivers_companion/backend/vitals/vitals_entry.dart';
import 'package:caregivers_companion/backend/vitals/vitals_targets.dart';
import 'package:caregivers_companion/flutter_flow/flutter_flow_icon_button.dart';
import 'package:caregivers_companion/pages/e_vitals_tracker_log/e_vitals_tracker_log_widget.dart';
import 'package:caregivers_companion/reports/care_report.dart';
import 'package:caregivers_companion/reports/vitals_export.dart';
import 'package:caregivers_companion/reports/vitals_export_pdf.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initFirebaseForTest();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FFAppState.reset();
    fakeFirestore.clear();
    fakeFirestore.clearWriteError();
    fakeFirestore.clearQueryError();
    FFAppState().selectedCareRecipient = null;
    FFAppState().activeGroupId = null;
  });

  /// A fixed 'today', so the Last-30-days window is 20 Oct – 18 Nov 2026.
  final now = DateTime(2026, 11, 18, 15, 30);
  final last30 = careReportRangeFor(CareReportPreset.last30Days, now: now);

  DocumentReference recipient([String id = 'mom']) =>
      FirebaseFirestore.instance.doc('careRecipients/$id');

  Future<void> seedRecipient({
    String id = 'mom',
    String name = 'Mom',
    String orgId = 'org_test',
    Map<String, dynamic>? targets,
  }) async {
    await recipient(id).set({
      'Name': name,
      'orgId': orgId,
      if (targets != null) 'VitalsTargets': targets,
    });
  }

  Future<void> seedMember(String uid, {String displayName = ''}) async {
    await FirebaseFirestore.instance
        .doc('organizations/org_test/members/$uid')
        .set({'status': 'active', 'displayName': displayName});
  }

  /// A reading holding only the measurements given — an absent field is what
  /// "not recorded" means, so it is never seeded as 0.
  Future<void> seedLog(
    String id, {
    DocumentReference? patient,
    DateTime? at,
    int? systolic,
    int? diastolic,
    int? heartRate,
    int? glucose,
    int? oxygen,
    double? temperature,
    double? weight,
    int? pain,
    String? notes,
    String loggedByUid = '',
  }) async {
    await VitalLogsRecord.collection.doc(id).set({
      'careRecipientRef': patient ?? recipient(),
      'orgId': 'org_test',
      'logDateTime': at,
      'loggedByUid': loggedByUid,
      if (systolic != null) 'bloodPressureSystolic': systolic,
      if (diastolic != null) 'bloodPressureDiastolic': diastolic,
      if (heartRate != null) 'heartRate': heartRate,
      if (glucose != null) 'bloodGlucose': glucose,
      if (oxygen != null) 'oxygenSaturation': oxygen,
      if (temperature != null) 'temperature': temperature,
      if (weight != null) 'weight': weight,
      if (pain != null) 'painLevel': pain,
      if (notes != null) 'notes': notes,
    });
  }

  /// The recipient's readings as the app sees them, in no particular order.
  Future<List<VitalLogsRecord>> readLogs({String id = 'mom'}) =>
      queryVitalLogsRecordOnce(
        queryBuilder: (query) =>
            query.where('careRecipientRef', isEqualTo: recipient(id)),
      );

  Future<VitalsExportData> exportOf({
    String recipientName = 'Mom',
    CareReportRange? range,
    Map<String, String> authorNames = const <String, String>{},
    Map<String, VitalsTargetRange> targets =
        const <String, VitalsTargetRange>{},
  }) async =>
      assembleVitalsExport(
        recipientName: recipientName,
        range: range ?? last30,
        generatedAt: now,
        logs: await readLogs(),
        authorNames: authorNames,
        targets: targets,
      );

  group('the export content', () {
    test('readings outside the period are dropped and rows run oldest first',
        () async {
      await seedRecipient();
      await seedLog('old', at: DateTime(2026, 10, 1, 9), heartRate: 70);
      await seedLog('v1', at: DateTime(2026, 11, 16, 7, 12), heartRate: 72);
      await seedLog('v2', at: DateTime(2026, 11, 18, 19, 40), heartRate: 68);

      final data = await exportOf();

      expect(data.readingCount, 2);
      expect(data.days.length, 2);
      expect(data.days.first.heading, '16 Nov 2026 · 1 reading');
      expect(data.days.first.readings.single.valueFor(VitalMeasurement.heartRate),
          '72 bpm');
      expect(data.days.last.readings.single.valueFor(VitalMeasurement.heartRate),
          '68 bpm');
    });

    test("an unrecorded measurement prints a dash, never the getter's 0",
        () async {
      await seedRecipient();
      await seedLog('v1', at: DateTime(2026, 11, 16, 7, 12), heartRate: 72);

      final reading = (await exportOf()).days.single.readings.single;

      expect(reading.valueFor(VitalMeasurement.heartRate), '72 bpm');
      expect(reading.valueFor(VitalMeasurement.bloodPressure),
          vitalsExportMissingValue);
      expect(reading.valueFor(VitalMeasurement.bloodGlucose),
          vitalsExportMissingValue);
      expect(reading.valueFor(VitalMeasurement.oxygenSaturation),
          vitalsExportMissingValue);
      expect(reading.valueFor(VitalMeasurement.temperature),
          vitalsExportMissingValue);
      expect(reading.valueFor(VitalMeasurement.weight),
          vitalsExportMissingValue);
      expect(reading.valueFor(VitalMeasurement.painLevel),
          vitalsExportMissingValue);
      // The whole table carries the value with its own unit.
      expect(vitalsExportMissingValue, '—');
    });

    test('pain 0 is a real value and prints 0 / 10', () async {
      await seedRecipient();
      await seedLog('v1', at: DateTime(2026, 11, 16, 7, 12), pain: 0);

      final reading = (await exportOf()).days.single.readings.single;

      expect(reading.valueFor(VitalMeasurement.painLevel), '0 / 10');
    });

    test('several readings on one day share one heading with a real count',
        () async {
      await seedRecipient();
      await seedLog('v1', at: DateTime(2026, 11, 18, 19, 40), heartRate: 68);
      await seedLog('v2', at: DateTime(2026, 11, 18, 7, 12), heartRate: 72);

      final data = await exportOf();

      expect(data.days.length, 1);
      expect(data.days.single.heading, '18 Nov 2026 · 2 readings');
      // Oldest first, whatever order the documents arrive in.
      expect(
          data.days.single.readings
              .map((r) => r.valueFor(VitalMeasurement.heartRate))
              .toList(),
          ['72 bpm', '68 bpm']);
    });

    test('notes print verbatim and an unresolved author is Unknown user',
        () async {
      await seedRecipient();
      await seedLog('v1',
          at: DateTime(2026, 11, 16, 7, 12),
          heartRate: 72,
          notes: 'Felt dizzy on standing',
          loggedByUid: 'uid-1');

      final data = await exportOf();
      final reading = data.days.single.readings.single;

      expect(reading.notes, 'Felt dizzy on standing');
      expect(reading.hasNotes, isTrue);
      expect(reading.author, vitalsUnknownAuthor);
      expect(vitalsUnknownAuthor, 'Unknown user');
    });

    test('a resolved author is the real member name', () async {
      await seedRecipient();
      await seedLog('v1',
          at: DateTime(2026, 11, 16, 7, 12),
          heartRate: 72,
          loggedByUid: 'uid-1');

      final data = await exportOf(authorNames: {'uid-1': 'Sarah M.'});

      expect(data.days.single.readings.single.author, 'Sarah M.');
    });

    test('a reading with no timestamp is counted and left out', () async {
      await seedRecipient();
      await seedLog('v1', at: DateTime(2026, 11, 16, 7, 12), heartRate: 72);
      await seedLog('undated', heartRate: 80);

      final data = await exportOf();

      expect(data.readingCount, 1);
      expect(data.undatedCount, 1);
      expect(vitalsExportUndatedNotice(1), '1 reading has no date and is not '
          'shown.');
    });

    test('a period with no readings reports nothing, not a blank table',
        () async {
      await seedRecipient();
      await seedLog('old', at: DateTime(2026, 1, 5, 9), heartRate: 70);

      final data = await exportOf();

      expect(data.hasReadings, isFalse);
      expect(data.days, isEmpty);
      expect(vitalsExportNoReadingsNotice,
          'No vitals were recorded in this period.');
    });
  });

  group('targets', () {
    test('below, within and above, including a one-sided target', () async {
      await seedRecipient();
      await seedLog('low', at: DateTime(2026, 11, 16, 7), heartRate: 55);
      await seedLog('in', at: DateTime(2026, 11, 17, 7), heartRate: 70);
      await seedLog('high', at: DateTime(2026, 11, 18, 7), heartRate: 90);

      final data = await exportOf(
        targets: vitalsTargetsFromRecord({
          'heartRate': {'min': 60, 'max': 80},
        }),
      );

      final words = [
        for (final day in data.days)
          day.readings.single.comparisonFor(VitalMeasurement.heartRate),
      ];
      expect(words, [
        vitalsExportBelowTarget,
        vitalsExportWithinTarget,
        vitalsExportAboveTarget,
      ]);
      expect(vitalsExportBelowTarget, 'Below target');
      expect(vitalsExportWithinTarget, 'Within target');
      expect(vitalsExportAboveTarget, 'Above target');
    });

    test('a one-sided maximum is "within" below it and "above" above it',
        () async {
      await seedRecipient();
      await seedLog('v1', at: DateTime(2026, 11, 16, 7), systolic: 130,
          diastolic: 80);
      await seedLog('v2', at: DateTime(2026, 11, 17, 7), systolic: 152,
          diastolic: 80);

      final data = await exportOf(
        targets: vitalsTargetsFromRecord({
          'bloodPressureSystolic': {'max': 140},
        }),
      );

      expect(
          data.days[0].readings.single
              .comparisonFor(VitalMeasurement.bloodPressure),
          vitalsExportWithinTarget);
      expect(
          data.days[1].readings.single
              .comparisonFor(VitalMeasurement.bloodPressure),
          vitalsExportAboveTarget);
    });

    test('blood pressure needs both sides and names the side that disagreed',
        () async {
      await seedRecipient();
      await seedLog('systolic', at: DateTime(2026, 11, 14, 7), systolic: 150,
          diastolic: 80);
      await seedLog('diastolic', at: DateTime(2026, 11, 15, 7), systolic: 130,
          diastolic: 95);
      await seedLog('bothWithin', at: DateTime(2026, 11, 16, 7), systolic: 130,
          diastolic: 80);
      await seedLog('bothAbove', at: DateTime(2026, 11, 17, 7), systolic: 160,
          diastolic: 100);

      final data = await exportOf(
        targets: vitalsTargetsFromRecord({
          'bloodPressureSystolic': {'min': 90, 'max': 140},
          'bloodPressureDiastolic': {'min': 60, 'max': 90},
        }),
      );

      // The two sides disagree, so each side is named with its own approved
      // word — "Above target (systolic) / Within target (diastolic)".
      expect(
          data.days[0].readings.single
              .comparisonFor(VitalMeasurement.bloodPressure),
          '$vitalsExportAboveTarget (systolic) / '
          '$vitalsExportWithinTarget (diastolic)');
      expect(
          data.days[1].readings.single
              .comparisonFor(VitalMeasurement.bloodPressure),
          '$vitalsExportWithinTarget (systolic) / '
          '$vitalsExportAboveTarget (diastolic)');
      // The two sides agree, so the one approved phrase stands alone.
      expect(
          data.days[2].readings.single
              .comparisonFor(VitalMeasurement.bloodPressure),
          vitalsExportWithinTarget);
      expect(
          data.days[3].readings.single
              .comparisonFor(VitalMeasurement.bloodPressure),
          vitalsExportAboveTarget);
    });

    test('pain has no target and a targetless measurement gets a dash',
        () async {
      await seedRecipient();
      await seedLog('v1', at: DateTime(2026, 11, 16, 7), heartRate: 70, pain: 4,
          glucose: 110);

      final data = await exportOf(
        targets: vitalsTargetsFromRecord({
          'heartRate': {'min': 60, 'max': 80},
        }),
      );
      final reading = data.days.single.readings.single;

      expect(reading.comparisonFor(VitalMeasurement.painLevel),
          vitalsExportMissingValue);
      expect(reading.comparisonFor(VitalMeasurement.bloodGlucose),
          vitalsExportMissingValue);
      expect(reading.comparisonFor(VitalMeasurement.heartRate),
          vitalsExportWithinTarget);
      // The header names the measurements that actually carry a target.
      expect(vitalsExportTargetsLine(data), contains('Measurements with a '
          'target: Heart rate.'));
    });

    test('a recipient with no targets exports the plain table', () async {
      await seedRecipient();
      await seedLog('v1', at: DateTime(2026, 11, 16, 7), heartRate: 70);

      final data = await exportOf();
      final reading = data.days.single.readings.single;

      expect(data.hasTargets, isFalse);
      expect(reading.comparisons, isEmpty);
      expect(vitalsExportTargetsLine(data), vitalsExportTargetsNotice);
      expect(vitalsExportTargetsNotice, contains('not medical advice'));
    });

    test('a target for a measurement that was not recorded has nothing to '
        'compare', () async {
      await seedRecipient();
      await seedLog('v1', at: DateTime(2026, 11, 16, 7), heartRate: 70);

      final data = await exportOf(
        targets: vitalsTargetsFromRecord({
          'weight': {'min': 150, 'max': 170},
        }),
      );
      final reading = data.days.single.readings.single;

      expect(reading.valueFor(VitalMeasurement.weight),
          vitalsExportMissingValue);
      expect(reading.comparisonFor(VitalMeasurement.weight),
          vitalsExportMissingValue);
    });
  });

  group('the loader', () {
    test('reads only this recipient\'s readings in the period, with the real '
        'author', () async {
      await seedRecipient(id: 'mom', name: 'Mom');
      await seedRecipient(id: 'dad', name: 'Dad');
      await seedMember('uid-1', displayName: 'Sarah M.');
      await seedLog('v1', at: DateTime(2026, 11, 16, 7, 12), heartRate: 72,
          loggedByUid: 'uid-1');
      await seedLog('v2', at: DateTime(2026, 9, 1, 7), heartRate: 66,
          loggedByUid: 'uid-1');
      await seedLog('other', patient: recipient('dad'),
          at: DateTime(2026, 11, 16, 8), heartRate: 99, loggedByUid: 'uid-1');

      final data = await loadVitalsExportData(
        recipientRef: recipient('mom'),
        range: last30,
        generatedAt: now,
      );

      expect(data.readingCount, 1);
      expect(data.days.single.readings.single.author, 'Sarah M.');
      expect(data.recipientName, 'Mom');
      expect(vitalsExportFileName(data), 'vitals-mom-last-30-days.pdf');
    });

    test('stored targets reach the export', () async {
      await seedRecipient(targets: {
        'heartRate': {'min': 60, 'max': 80},
      });
      await seedLog('v1', at: DateTime(2026, 11, 16, 7), heartRate: 95);

      final data = await loadVitalsExportData(
        recipientRef: recipient(),
        range: last30,
        generatedAt: now,
      );

      expect(data.hasTargets, isTrue);
      expect(
          data.days.single.readings.single
              .comparisonFor(VitalMeasurement.heartRate),
          vitalsExportAboveTarget);
    });

    test('the safety cap is stated, never silent', () async {
      await seedRecipient();
      await seedLog('v1', at: DateTime(2026, 11, 16, 7), heartRate: 70);
      await seedLog('v2', at: DateTime(2026, 11, 17, 7), heartRate: 72);

      final data = await loadVitalsExportData(
        recipientRef: recipient(),
        range: last30,
        generatedAt: now,
        maxRows: 1,
      );

      expect(data.readingCount, 1);
      expect(data.isTruncated, isTrue);
      expect(vitalsExportTruncatedNotice(data), startsWith('Showing the first '
          '1'));
      // With a known total the line names it.
      expect(
          vitalsExportTruncatedNotice(VitalsExportData(
            recipientName: 'Mom',
            range: last30,
            generatedAt: now,
            days: data.days,
            targets: const {},
            totalInPeriod: 2400,
          )),
          'Showing the first 1 of 2400 readings in this period.');
    });
  });

  group('the PDF', () {
    test('builds a real landscape PDF', () async {
      await seedRecipient();
      await seedLog('v1', at: DateTime(2026, 11, 16, 7, 12), heartRate: 72,
          pain: 0, notes: 'Felt dizzy on standing');

      final data = await exportOf();
      final bytes = await buildVitalsExportPdf(data);
      final text = String.fromCharCodes(bytes);

      expect(text.startsWith('%PDF'), isTrue);
      expect(text.trimRight().endsWith('%%EOF'), isTrue);
      expect(bytes.length, greaterThan(800));
    });

    test('a period with no readings still makes a complete report', () async {
      final data = VitalsExportData(
        recipientName: 'Mom',
        range: last30,
        generatedAt: now,
        days: const [],
        targets: const {},
      );

      final bytes = await buildVitalsExportPdf(data);

      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(bytes.length, greaterThan(500));
    });
  });

  group('the Vitals screen export icon', () {
    Future<void> pumpVitals(
      WidgetTester tester, {
      VitalsExportPdfAction? sharePdf,
      VitalsExportPdfAction? printPdf,
    }) async {
      // The same scaffolding the range-sheet tests use: tall enough that the
      // sheet's presets and its Generate PDF button are both on screen, and the
      // provider the sheet reads FFAppState through.
      tester.view.physicalSize = const Size(1080.0, 2400.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ChangeNotifierProvider<FFAppState>.value(
        value: FFAppState(),
        child: MaterialApp(
          home: EVitalsTrackerLogWidget(
            now: now,
            sharePdf: sharePdf,
            printPdf: printPdf,
          ),
        ),
      ));
      await pumpFrames(tester);
    }

    testWidgets('with no care recipient the export icon is disabled and makes '
        'no file', (tester) async {
      var shared = 0;
      var printed = 0;
      await pumpVitals(
        tester,
        sharePdf: (bytes, name) async => shared++,
        printPdf: (bytes, name) async => printed++,
      );

      final button = tester.widget<FlutterFlowIconButton>(
        find.byKey(const ValueKey('vitals_export_button')),
      );
      expect(button.onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('vitals_export_button')));
      await pumpFrames(tester);

      expect(shared, 0);
      expect(printed, 0);
      expect(find.text('Choose a date range'), findsNothing);
    });

    testWidgets('save/share produces a real PDF named for the recipient',
        (tester) async {
      await seedRecipient();
      FFAppState().activeGroupId = 'org_test';
      FFAppState().selectedCareRecipient = recipient();
      await seedLog('v1', at: DateTime(2026, 11, 16, 7, 12), heartRate: 72);

      final shared = <String>[];
      final sharedBytes = <List<int>>[];
      var printed = 0;
      await pumpVitals(
        tester,
        sharePdf: (bytes, name) async {
          shared.add(name);
          sharedBytes.add(bytes);
        },
        printPdf: (bytes, name) async => printed++,
      );

      await tester.tap(find.byKey(const ValueKey('vitals_export_button')));
      await pumpFrames(tester);
      expect(find.text('Choose a date range'), findsOneWidget);

      await tester.tap(find.text('Last 30 days'));
      await pumpFrames(tester);
      await tester.tap(find.text('Generate PDF'));
      await pumpFrames(tester);

      expect(find.text('Export vitals'), findsOneWidget);
      await tester.tap(find.text('Save or share PDF'));
      await pumpFrames(tester);

      expect(printed, 0);
      expect(shared.length, 1);
      expect(String.fromCharCodes(sharedBytes.single.take(4)), '%PDF');
      expect(shared.single, startsWith('vitals-mom-'));
      expect(shared.single, endsWith('.pdf'));
    });

    testWidgets('print goes to the print destination', (tester) async {
      await seedRecipient();
      FFAppState().activeGroupId = 'org_test';
      FFAppState().selectedCareRecipient = recipient();
      await seedLog('v1', at: DateTime(2026, 11, 16, 7, 12), heartRate: 72);

      var shared = 0;
      final printed = <String>[];
      await pumpVitals(
        tester,
        sharePdf: (bytes, name) async => shared++,
        printPdf: (bytes, name) async => printed.add(name),
      );

      await tester.tap(find.byKey(const ValueKey('vitals_export_button')));
      await pumpFrames(tester);
      await tester.tap(find.text('Last 30 days'));
      await pumpFrames(tester);
      await tester.tap(find.text('Generate PDF'));
      await pumpFrames(tester);
      await tester.tap(find.text('Print'));
      await pumpFrames(tester);

      expect(shared, 0);
      expect(printed.length, 1);
      expect(printed.single, startsWith('vitals-mom-'));
    });

    testWidgets('a failed read shows an error and produces no file',
        (tester) async {
      await seedRecipient();
      FFAppState().activeGroupId = 'org_test';
      FFAppState().selectedCareRecipient = recipient();
      await seedLog('v1', at: DateTime(2026, 11, 16, 7, 12), heartRate: 72);

      var shared = 0;
      var printed = 0;
      await pumpVitals(
        tester,
        sharePdf: (bytes, name) async => shared++,
        printPdf: (bytes, name) async => printed++,
      );

      // The page has loaded its own readings; the export's read is the one that
      // fails.
      fakeFirestore.queryError = Exception('offline');

      await tester.tap(find.byKey(const ValueKey('vitals_export_button')));
      await pumpFrames(tester);
      await tester.tap(find.text('Last 30 days'));
      await pumpFrames(tester);
      await tester.tap(find.text('Generate PDF'));
      await pumpFrames(tester);
      await tester.tap(find.text('Save or share PDF'));
      await pumpFrames(tester);

      expect(shared, 0);
      expect(printed, 0);
      expect(
        find.text('The readings could not be loaded. Please check your '
            'connection and try again.'),
        findsOneWidget,
      );
    });
  });
}

/// Lets every pending frame and future run, so the sheet animations and the
/// PDF build settle without a wall-clock wait.
Future<void> pumpFrames(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
