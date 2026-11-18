// Weekly Summary — the screen's real data layer and its two export buttons.
//
// Owner decisions of 2026-11-17 (`/home/team/shared/weekly-summary-proposal-2026-11-17.md`,
// all eleven §13 items approved as recommended):
//  * a real range (default Last 7 days) reusing the Doctor Prep preset sheet;
//  * averages for BP/HR with the reading count, the latest reading for weight
//    and glucose, the other three measurements off the screen;
//  * a daily systolic line with gaps and real axis bounds;
//  * Care Logs from care notes, vitals, water and appointments with real
//    authors, symptoms excluded, four rows;
//  * the real current medication list and count — no adherence, missed doses or
//    "most frequent" (the app stores no dose history);
//  * Notes for Doctor = the period's important/follow-up note, else the most
//    recent one, verbatim with its real author;
//  * the PDF is the same care report Doctor Prep exports, over this page's
//    range; "Export PDF Report" and "Print Summary" go to different
//    destinations, and the share icon shares that same PDF.
//
// Everything runs offline against the in-memory Firestore fake
// (test/firebase_test_setup.dart), seeded and read through the app-facing API.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregivers_companion/app_state.dart';
import 'package:caregivers_companion/backend/backend.dart';
import 'package:caregivers_companion/pages/h_weekly_summary_report/h_weekly_summary_report_widget.dart';
import 'package:caregivers_companion/reports/care_report.dart';
import 'package:caregivers_companion/reports/weekly_summary.dart';
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
    FFAppState().selectedCareRecipient = null;
    FFAppState().activeGroupId = null;
  });

  /// A fixed 'today', so the default Last-7-days window is 11-17 Nov 2026.
  final now = DateTime(2026, 11, 17, 15, 30);
  final week = careReportRangeFor(CareReportPreset.last7Days, now: now);

  DocumentReference recipient(String id) =>
      FirebaseFirestore.instance.doc('careRecipients/$id');

  Future<void> seedRecipient(
    String id, {
    String name = 'Mom',
    String orgId = 'org_test',
  }) async {
    await recipient(id).set({'Name': name, 'orgId': orgId});
  }

  Future<void> seedMember(
    String uid, {
    String displayName = '',
    String orgId = 'org_test',
  }) async {
    await FirebaseFirestore.instance
        .doc('organizations/$orgId/members/$uid')
        .set({
      'status': 'active',
      'displayName': displayName,
    });
  }

  Future<void> seedVital(
    String id, {
    required DocumentReference patient,
    required DateTime? at,
    int systolic = 0,
    int diastolic = 0,
    int heartRate = 0,
    int glucose = 0,
    double weight = 0,
    String loggedByUid = '',
  }) async {
    await VitalLogsRecord.collection.doc(id).set({
      'careRecipientRef': patient,
      'orgId': 'org_test',
      'logDateTime': at,
      'bloodPressureSystolic': systolic,
      'bloodPressureDiastolic': diastolic,
      'heartRate': heartRate,
      'bloodGlucose': glucose,
      'weight': weight,
      'loggedByUid': loggedByUid,
    });
  }

  Future<void> seedWater(
    String id, {
    required DocumentReference patient,
    required DateTime? at,
    double amountFlOz = 8,
    String loggedByUid = '',
  }) async {
    await WaterLogsRecord.collection.doc(id).set({
      'careRecipientRef': patient,
      'orgId': 'org_test',
      'intakeAt': at,
      'amount': amountFlOz,
      'unit': 'fl oz',
      'amountFlOz': amountFlOz,
      'loggedByUid': loggedByUid,
    });
  }

  Future<void> seedNote(
    String id, {
    required DocumentReference patient,
    required String text,
    DateTime? at,
    String createdBy = '',
    bool important = false,
    bool followUpNeeded = false,
  }) async {
    await CareNotesRecord.collection.doc(id).set({
      'careRecipientRef': patient,
      'noteText': text,
      'noteDateTime': at,
      'createdBy': createdBy,
      'important': important,
      'followUpNeeded': followUpNeeded,
    });
  }

  Future<void> seedMedication(
    String id, {
    required DocumentReference patient,
    required String name,
    String dose = '',
    String directions = '',
    String orgId = 'org_test',
  }) async {
    await MedicationsRecord.collection.doc(id).set({
      'orgId': orgId,
      'careRecipientRef': patient,
      'medicationName': name,
      'dose': dose,
      'directions': directions,
    });
  }

  Future<void> seedAppointment(
    String id, {
    required DocumentReference patient,
    required String title,
    DateTime? at,
    String createdByUid = '',
  }) async {
    await AppointmentsRecord.collection.doc(id).set({
      'careRecipientRef': patient,
      'orgId': 'org_test',
      'appointmentTitle': title,
      'appointmentDateTime': at,
      'createdByUid': createdByUid,
    });
  }

  Future<void> seedSymptom(
    String id, {
    required DocumentReference patient,
    required String name,
    required DateTime? at,
  }) async {
    await SymptomEntriesRecord.collection.doc(id).set({
      'patientRef': patient,
      'symptomName': name,
      'note': 'invented-looking symptom note',
      'timeLogged': at,
    });
  }

  group('Vitals Overview', () {
    test('averages carry their reading count; weight and glucose are the '
        'latest reading', () async {
      final mom = recipient('mom');
      await seedRecipient('mom');
      FFAppState().activeGroupId = 'org_test';

      await seedVital('v1',
          patient: mom,
          at: DateTime(2026, 11, 11, 8),
          systolic: 130,
          diastolic: 80,
          heartRate: 70,
          glucose: 110,
          weight: 160.0);
      await seedVital('v2',
          patient: mom,
          at: DateTime(2026, 11, 15, 9),
          systolic: 140,
          diastolic: 90,
          heartRate: 80,
          glucose: 114,
          weight: 164.2);
      // Outside the period: must not move any number on the screen.
      await seedVital('v_out',
          patient: mom,
          at: DateTime(2026, 10, 1, 9),
          systolic: 200,
          diastolic: 110,
          heartRate: 120,
          glucose: 300,
          weight: 200.0);
      // Another recipient's reading: never included.
      await seedVital('v_other',
          patient: recipient('dad'),
          at: DateTime(2026, 11, 12, 9),
          systolic: 90,
          diastolic: 60,
          heartRate: 50,
          glucose: 90,
          weight: 100.0);

      final summary = await loadWeeklySummary(recipientRef: mom, range: week);

      expect(summary.vitals.averageSystolic, 135);
      expect(summary.vitals.averageDiastolic, 85);
      expect(summary.vitals.bloodPressureReadings, 2);
      expect(bloodPressureLabel(summary.vitals), '135/85');
      expect(readingsLabel(summary.vitals.bloodPressureReadings), '2 readings');

      expect(summary.vitals.averageHeartRate, 75);
      expect(heartRateLabel(summary.vitals), '75 bpm');

      // Latest, not an average, with the date it was taken.
      expect(summary.vitals.latestWeight, 164.2);
      expect(summary.vitals.latestWeightAt, DateTime(2026, 11, 15, 9));
      expect(weightLabel(summary.vitals), '164.2 lbs');
      expect(summary.vitals.latestGlucose, 114);
      expect(glucoseLabel(summary.vitals), '114 mg/dL');
    });

    test('a period with no readings reports none — no fabricated numbers',
        () async {
      final mom = recipient('mom');
      await seedRecipient('mom');
      FFAppState().activeGroupId = 'org_test';

      final summary = await loadWeeklySummary(recipientRef: mom, range: week);

      expect(summary.vitals.isEmpty, isTrue);
      expect(bloodPressureLabel(summary.vitals), isNull);
      expect(heartRateLabel(summary.vitals), isNull);
      expect(weightLabel(summary.vitals), isNull);
      expect(glucoseLabel(summary.vitals), isNull);
      expect(summary.dailySystolic, isEmpty);
      expect(summary.systolicSegments, isEmpty);
      expect(summary.logEntries, isEmpty);
      expect(summary.medications, isEmpty);
      expect(summary.doctorNote, isNull);
      expect(summary.isEmpty, isTrue);
    });
  });

  group('the daily systolic line', () {
    test('one point per day, that day\'s mean, gaps on days with no reading',
        () async {
      final mom = recipient('mom');
      await seedRecipient('mom');
      FFAppState().activeGroupId = 'org_test';

      await seedVital('v1',
          patient: mom,
          at: DateTime(2026, 11, 11, 8),
          systolic: 130,
          diastolic: 80);
      await seedVital('v2',
          patient: mom,
          at: DateTime(2026, 11, 11, 20),
          systolic: 140,
          diastolic: 90);
      await seedVital('v3',
          patient: mom,
          at: DateTime(2026, 11, 13, 9),
          systolic: 150,
          diastolic: 95);
      await seedVital('v4',
          patient: mom,
          at: DateTime(2026, 11, 17, 9),
          systolic: 120,
          diastolic: 78);

      final summary = await loadWeeklySummary(recipientRef: mom, range: week);

      expect(summary.dailySystolic.map((p) => p.x), [0, 2, 6]);
      expect(summary.dailySystolic.map((p) => p.systolic), [135.0, 150.0, 120.0]);
      expect(summary.dailySystolic.first.day, DateTime(2026, 11, 11));

      // 12 Nov, 14-16 Nov have no reading: those are GAPS (three separate runs),
      // never zeros.
      expect(summary.systolicSegments.length, 3);
      expect(summary.systolicSegments.every((s) => s.length == 1), isTrue);

      // Real bounds, computed from the real points (not a hardcoded 0-162).
      expect(summary.chartMinY, 110.0);
      expect(summary.chartMaxY, 160.0);
      expect(summary.chartMaxX, 6.0);
      expect(summary.chartDayCount, 7);
      // Weekday initials from the real dates: 11 Nov 2026 is a Wednesday.
      expect(summary.chartXLabels,
          ['W', 'T', 'F', 'S', 'S', 'M', 'T']);
    });

    test('consecutive days stay one continuous line', () async {
      final mom = recipient('mom');
      await seedRecipient('mom');
      FFAppState().activeGroupId = 'org_test';

      await seedVital('v1',
          patient: mom,
          at: DateTime(2026, 11, 11, 8),
          systolic: 130,
          diastolic: 80);
      await seedVital('v2',
          patient: mom,
          at: DateTime(2026, 11, 12, 8),
          systolic: 134,
          diastolic: 82);

      final summary = await loadWeeklySummary(recipientRef: mom, range: week);

      expect(summary.systolicSegments.length, 1);
      expect(summary.systolicSegments.single.map((p) => p.systolic),
          [130.0, 134.0]);
    });
  });

  group('Care Logs', () {
    test('real records with real authors, newest first, four rows, no symptoms',
        () async {
      final mom = recipient('mom');
      await seedRecipient('mom');
      FFAppState().activeGroupId = 'org_test';
      await seedMember('uid_sam', displayName: 'Sam');
      await seedMember('uid_jordan', displayName: 'Jordan');

      await seedNote('n1',
          patient: mom,
          text: 'Morning walk with Mom',
          at: DateTime(2026, 11, 12, 10),
          createdBy: 'Alex');
      await seedVital('v1',
          patient: mom,
          at: DateTime(2026, 11, 13, 8),
          systolic: 132,
          diastolic: 84,
          heartRate: 72,
          loggedByUid: 'uid_sam');
      await seedWater('w1',
          patient: mom,
          at: DateTime(2026, 11, 14, 9),
          amountFlOz: 8,
          loggedByUid: 'uid_sam');
      await seedAppointment('a1',
          patient: mom,
          title: 'Cardiology follow-up',
          at: DateTime(2026, 11, 15, 11),
          createdByUid: 'uid_jordan');
      // A fifth candidate, so the four-row cap is exercised: the newest four
      // survive and this oldest note drops out.
      await seedNote('n2',
          patient: mom,
          text: 'Slept poorly, up three times',
          at: DateTime(2026, 11, 16, 7),
          createdBy: 'Priya');
      // Symptoms store no author, so they are not in this card at all.
      await seedSymptom('s1',
          patient: mom, name: 'Dizziness', at: DateTime(2026, 11, 16, 12));

      final summary = await loadWeeklySummary(recipientRef: mom, range: week);

      expect(summary.logEntries.length, weeklySummaryLogRows);
      expect(summary.logEntries.map((e) => e.source), [
        WeeklySummaryLogSource.careNote,
        WeeklySummaryLogSource.appointment,
        WeeklySummaryLogSource.water,
        WeeklySummaryLogSource.vitals,
      ]);
      expect(summary.logEntries.map((e) => e.text), [
        'Slept poorly, up three times',
        'Appointment: Cardiology follow-up',
        '8 fl oz of water',
        'BP 132/84, HR 72 bpm',
      ]);
      expect(summary.logEntries.map((e) => e.author),
          ['Priya', 'Jordan', 'Sam', 'Sam']);
      expect(summary.logEntries.any((e) => e.text.contains('Morning walk')),
          isFalse);
      expect(summary.logEntries.any((e) => e.text.contains('Dizziness')), isFalse);
    });

    test('a period with nothing logged is empty, not invented rows', () async {
      final mom = recipient('mom');
      await seedRecipient('mom');
      FFAppState().activeGroupId = 'org_test';

      await seedNote('n_out',
          patient: mom,
          text: 'Old note',
          at: DateTime(2026, 9, 1, 10),
          createdBy: 'Alex');

      final summary = await loadWeeklySummary(recipientRef: mom, range: week);
      expect(summary.logEntries, isEmpty);
    });
  });

  group('Medications', () {
    test('the current list and its real count, scoped to the recipient and org',
        () async {
      final mom = recipient('mom');
      await seedRecipient('mom');
      FFAppState().activeGroupId = 'org_test';

      await seedMedication('m1',
          patient: mom, name: 'Metformin', dose: '500mg', directions: 'With breakfast');
      await seedMedication('m2',
          patient: mom, name: 'Lisinopril', dose: '10mg');
      // Another organisation's list: never mixed in.
      await seedMedication('m3',
          patient: mom, name: 'Warfarin', orgId: 'org_other');
      // Another recipient's medication.
      await seedMedication('m4', patient: recipient('dad'), name: 'Atorvastatin');

      final summary = await loadWeeklySummary(recipientRef: mom, range: week);

      expect(summary.medications.map((m) => m.name), ['Lisinopril', 'Metformin']);
      expect(summary.medications.first.dose, '10mg');
      expect(summary.medications.last.schedule, 'With breakfast');
    });
  });

  group('Notes for Doctor', () {
    test('prefers the important / follow-up note, verbatim, with its author',
        () async {
      final mom = recipient('mom');
      await seedRecipient('mom');
      FFAppState().activeGroupId = 'org_test';

      await seedNote('n1',
          patient: mom,
          text: 'Ask about the new knee braces',
          at: DateTime(2026, 11, 11, 9),
          createdBy: 'Alex',
          important: true);
      await seedNote('n2',
          patient: mom,
          text: 'Slept well',
          at: DateTime(2026, 11, 16, 9),
          createdBy: 'Priya');

      final summary = await loadWeeklySummary(recipientRef: mom, range: week);

      expect(summary.doctorNote, isNotNull);
      expect(summary.doctorNote!.text, 'Ask about the new knee braces');
      expect(summary.doctorNote!.author, 'Alex');
      expect(summary.doctorNote!.flagged, isTrue);
      expect(summary.doctorNote!.at, DateTime(2026, 11, 11, 9));
    });

    test('falls back to the most recent note when none is flagged', () async {
      final mom = recipient('mom');
      await seedRecipient('mom');
      FFAppState().activeGroupId = 'org_test';

      await seedNote('n1',
          patient: mom,
          text: 'Older note',
          at: DateTime(2026, 11, 11, 9),
          createdBy: 'Alex');
      await seedNote('n2',
          patient: mom,
          text: 'Newest note',
          at: DateTime(2026, 11, 16, 9),
          createdBy: 'Priya');

      final summary = await loadWeeklySummary(recipientRef: mom, range: week);

      expect(summary.doctorNote!.text, 'Newest note');
      expect(summary.doctorNote!.author, 'Priya');
      expect(summary.doctorNote!.flagged, isFalse);
    });

    test('no note in the period means no note on the card', () async {
      final mom = recipient('mom');
      await seedRecipient('mom');
      FFAppState().activeGroupId = 'org_test';

      final summary = await loadWeeklySummary(recipientRef: mom, range: week);
      expect(summary.doctorNote, isNull);
    });
  });

  // Widget tests: the screen itself.
  Future<void> pumpFrames(WidgetTester tester, {int frames = 30}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    WeeklySummaryPdfAction? sharePdf,
    WeeklySummaryPdfAction? printPdf,
  }) async {
    tester.view.physicalSize = const Size(1080.0, 2400.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<FFAppState>.value(
        value: FFAppState(),
        child: MaterialApp(
          home: HWeeklySummaryReportWidget(
            now: now,
            sharePdf: sharePdf,
            printPdf: printPdf,
          ),
        ),
      ),
    );
    await pumpFrames(tester);
  }

  group('the screen', () {
    testWidgets('shows the real records and none of the invented content',
        (tester) async {
      final mom = recipient('mom');
      await seedRecipient('mom');
      FFAppState().activeGroupId = 'org_test';
      FFAppState().selectedCareRecipient = mom;
      await seedMember('uid_sam', displayName: 'Sam');

      await seedVital('v1',
          patient: mom,
          at: DateTime(2026, 11, 11, 8),
          systolic: 136,
          diastolic: 84,
          heartRate: 76,
          glucose: 118,
          weight: 162.5,
          loggedByUid: 'uid_sam');
      await seedVital('v2',
          patient: mom,
          at: DateTime(2026, 11, 15, 8),
          systolic: 140,
          diastolic: 88,
          heartRate: 78,
          glucose: 121,
          weight: 163.5,
          loggedByUid: 'uid_sam');
      await seedNote('n1',
          patient: mom,
          text: 'Ask about the new knee braces',
          at: DateTime(2026, 11, 16, 9),
          createdBy: 'Alex',
          important: true);
      await seedMedication('m1',
          patient: mom, name: 'Metformin', dose: '500mg');

      await pumpPage(tester);

      // The real range and recipient.
      expect(find.text('Last 7 days'), findsOneWidget);
      expect(find.text('11 Nov 2026 - 17 Nov 2026 · Mom'), findsOneWidget);

      // The real aggregates, with the counts behind the averages.
      expect(find.text('138/86'), findsOneWidget);
      expect(find.text('Avg. BP · 2 readings'), findsOneWidget);
      expect(find.text('77 bpm'), findsOneWidget);
      expect(find.text('Avg. HR · 2 readings'), findsOneWidget);
      expect(find.text('163.5 lbs'), findsOneWidget);
      expect(find.text('121 mg/dL'), findsOneWidget);

      // The real care log rows, medication list and doctor note.
      expect(find.text('BP 136/84, HR 76 bpm, Weight 162.5 lbs, '
          'Glucose 118 mg/dL'), findsOneWidget);
      expect(find.text('Sam'), findsNWidgets(2));
      expect(find.text('1 medication on file'), findsOneWidget);
      expect(find.text('Metformin · 500mg'), findsOneWidget);
      // The same real note appears in Care Logs and in Notes for Doctor.
      expect(find.text('Ask about the new knee braces'), findsNWidgets(2));
      expect(find.text('— Alex · 16 Nov'), findsOneWidget);

      // Nothing the old screen invented survives.
      for (final invented in [
        'Oct 16 – Oct 22, 2023',
        '132/84',
        '72 bpm',
        '164.2 lbs',
        '114 mg/dL',
        '92% Adherence',
        '2 doses missed this week',
        'Most Frequent:',
        'Lisinopril, Metformin',
        'Morning stiffness reported in left knee',
        'Missed evening hydration goal',
      ]) {
        expect(find.text(invented), findsNothing, reason: invented);
      }
    });

    testWidgets('with no care recipient it says so and both buttons are dead',
        (tester) async {
      var shared = 0;
      var printed = 0;
      await pumpPage(
        tester,
        sharePdf: (bytes, name) async => shared++,
        printPdf: (bytes, name) async => printed++,
      );

      expect(
        find.text('Select a care recipient to see their weekly summary.'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Export PDF Report'));
      await tester.tap(find.text('Export PDF Report'));
      await pumpFrames(tester);
      await tester.tap(find.text('Print Summary'));
      await pumpFrames(tester);

      expect(shared, 0);
      expect(printed, 0);
    });

    testWidgets('both buttons build the real PDF and go to different '
        'destinations', (tester) async {
      final mom = recipient('mom');
      await seedRecipient('mom');
      FFAppState().activeGroupId = 'org_test';
      FFAppState().selectedCareRecipient = mom;
      await seedNote('n1',
          patient: mom,
          text: 'Ask about the new knee braces',
          at: DateTime(2026, 11, 16, 9),
          createdBy: 'Alex');

      final shared = <String>[];
      final printed = <String>[];
      final sharedBytes = <List<int>>[];
      await pumpPage(
        tester,
        sharePdf: (bytes, name) async {
          shared.add(name);
          sharedBytes.add(bytes);
        },
        printPdf: (bytes, name) async => printed.add(name),
      );

      await tester.ensureVisible(find.text('Export PDF Report'));
      await tester.tap(find.text('Export PDF Report'));
      await pumpFrames(tester);

      expect(shared.length, 1);
      expect(printed, isEmpty);
      // The same report Doctor Prep exports: a real PDF, named for the
      // recipient.
      expect(String.fromCharCodes(sharedBytes.single.take(4)), '%PDF');
      expect(shared.single, startsWith('care-report-mom-'));
      expect(shared.single, endsWith('.pdf'));

      await tester.ensureVisible(find.text('Print Summary'));
      await tester.tap(find.text('Print Summary'));
      await pumpFrames(tester);

      expect(printed.length, 1);
      expect(shared.length, 1);
      expect(printed.single, startsWith('care-report-mom-'));
    });

    testWidgets('the range row is a real picker that changes the period',
        (tester) async {
      final mom = recipient('mom');
      await seedRecipient('mom');
      FFAppState().activeGroupId = 'org_test';
      FFAppState().selectedCareRecipient = mom;
      // Outside the week, inside the last 30 days.
      await seedNote('n1',
          patient: mom,
          text: 'Note from three weeks ago',
          at: DateTime(2026, 10, 25, 9),
          createdBy: 'Alex');

      await pumpPage(tester);

      expect(find.text('Last 7 days'), findsOneWidget);
      expect(find.text('Note from three weeks ago'), findsNothing);

      await tester.tap(find.text('Last 7 days'));
      await pumpFrames(tester);
      expect(find.text('Choose a date range'), findsOneWidget);

      await tester.tap(find.text('Last 30 days'));
      await pumpFrames(tester);
      await tester.tap(find.text('Generate PDF'));
      await pumpFrames(tester);

      expect(find.text('Last 30 days'), findsOneWidget);
      expect(find.text('19 Oct 2026 - 17 Nov 2026 · Mom'), findsOneWidget);
      expect(find.text('Note from three weeks ago'), findsAtLeastNWidgets(1));
    });
  });
}
