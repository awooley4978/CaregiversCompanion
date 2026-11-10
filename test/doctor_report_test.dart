// U5 — the Doctor Prep 'Export' action: date-range rules, section assembly and
// PDF generation, all from stored care records.
//
// Owner-approved spec (2026-11-03): the report covers a user-selected range
// with presets and no fixed window; only actually-recorded information is
// included; original notes are preserved verbatim; sections with no records are
// omitted; and a period with no records produces an honest no-records report
// (never placeholder text).
//
// Everything here runs offline against the in-memory Firestore fake
// (test/firebase_test_setup.dart), seeded and read through the app-facing API.
// No golden-file PDF comparisons: the PDF is asserted to be a real, non-trivial
// PDF document, and its CONTENT is asserted on the assembled data it renders.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/backend/backend.dart';
import 'package:new_project/components/doctor_report_range_sheet/doctor_report_range_sheet_widget.dart';
import 'package:new_project/pages/g_doctor_visit_prep/g_doctor_visit_prep_widget.dart';
import 'package:new_project/reports/care_report.dart';
import 'package:new_project/reports/care_report_pdf.dart';
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

  /// A fixed 'today' so every resolved date in these tests is deterministic.
  final now = DateTime(2026, 11, 3, 15, 30);

  DocumentReference recipient(String id) =>
      FirebaseFirestore.instance.doc('careRecipients/$id');

  Future<void> seedRecipient(
    String id, {
    String name = 'Mom',
    String orgId = 'org_test',
  }) async {
    await recipient(id).set({
      'name': name,
      'orgId': orgId,
    });
  }

  Future<void> seedSymptom(
    String id, {
    required DocumentReference patient,
    required String name,
    required DateTime? timeLogged,
    String note = '',
    bool isResolved = false,
  }) async {
    await SymptomEntriesRecord.collection.doc(id).set({
      'symptomName': name,
      'note': note,
      'timeLogged': timeLogged,
      'patientRef': patient,
      'isResolved': isResolved,
    });
  }

  Future<void> seedNote(
    String id, {
    required DocumentReference patient,
    required String text,
    DateTime? noteDateTime,
    DateTime? createdAt,
    String createdBy = '',
    String category = '',
  }) async {
    await CareNotesRecord.collection.doc(id).set({
      'careRecipientRef': patient,
      'noteText': text,
      'noteDateTime': noteDateTime,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'category': category,
    });
  }

  Future<void> seedMedication(
    String id, {
    required DocumentReference patient,
    required String name,
    String dose = '',
    String directions = '',
    String status = '',
    bool active = true,
  }) async {
    await MedicationsRecord.collection.doc(id).set({
      'orgId': 'org_test',
      'careRecipientRef': patient,
      'medicationName': name,
      'dose': dose,
      'directions': directions,
      'status': status,
      'active': active,
    });
  }

  group('date range presets', () {
    test('last 7 / 30 / 90 days resolve to inclusive calendar days', () {
      final last7 = careReportRangeFor(CareReportPreset.last7Days, now: now);
      expect(last7.start, DateTime(2026, 10, 28));
      expect(last7.end, DateTime(2026, 11, 3));

      final last30 = careReportRangeFor(CareReportPreset.last30Days, now: now);
      expect(last30.start, DateTime(2026, 10, 5));
      expect(last30.end, DateTime(2026, 11, 3));

      final last90 = careReportRangeFor(CareReportPreset.last90Days, now: now);
      expect(last90.start, DateTime(2026, 8, 6));
      expect(last90.end, DateTime(2026, 11, 3));
    });

    test('the sheet default is Last 30 days', () {
      expect(defaultCareReportPreset, CareReportPreset.last30Days);
      expect(
        careReportRangeFor(defaultCareReportPreset, now: now).label,
        'Last 30 days',
      );
    });

    test('bounds are inclusive of the boundary days, at any time of day', () {
      final range = careReportRangeFor(CareReportPreset.last7Days, now: now);
      expect(range.includes(DateTime(2026, 10, 28, 0, 0)), isTrue);
      expect(range.includes(DateTime(2026, 10, 28, 23, 59, 59)), isTrue);
      expect(range.includes(DateTime(2026, 11, 3, 0, 0)), isTrue);
      expect(range.includes(DateTime(2026, 11, 3, 23, 59, 59)), isTrue);
      // One second / one day outside the window is excluded.
      expect(range.includes(DateTime(2026, 10, 27, 23, 59, 59)), isFalse);
      expect(range.includes(DateTime(2026, 11, 4, 0, 0)), isFalse);
      // A record with no stored timestamp cannot be placed in a period.
      expect(range.includes(null), isFalse);
    });

    test('all time is unbounded, not a hardcoded window', () {
      final allTime = careReportRangeFor(CareReportPreset.allTime, now: now);
      expect(allTime.start, isNull);
      expect(allTime.end, isNull);
      expect(allTime.boundsLabel, 'All time');
      expect(allTime.includes(DateTime(2019, 1, 2, 9)), isTrue);
      expect(allTime.includes(DateTime(2030, 1, 2, 9)), isTrue);
    });

    test('a custom range is normalised and keeps its inclusive end day', () {
      final custom = careReportRangeFor(
        CareReportPreset.custom,
        now: now,
        customStart: DateTime(2026, 10, 20, 13),
        customEnd: DateTime(2026, 10, 1, 8),
      );
      expect(custom.start, DateTime(2026, 10, 1));
      expect(custom.end, DateTime(2026, 10, 20));
      expect(custom.includes(DateTime(2026, 10, 20, 22, 15)), isTrue);
      expect(custom.includes(DateTime(2026, 10, 21)), isFalse);
    });
  });

  group('report content', () {
    test('only records inside the range are reported, notes verbatim',
        () async {
      final mom = recipient('mom');
      await seedRecipient('mom');
      FFAppState().activeGroupId = 'org_test';

      await seedSymptom(
        's_in',
        patient: mom,
        name: 'Dizziness',
        note: 'After lunch - said the room was "spinning".',
        timeLogged: DateTime(2026, 10, 28, 9, 15),
        isResolved: true,
      );
      await seedSymptom(
        's_out',
        patient: mom,
        name: 'Headache',
        note: 'Old entry',
        timeLogged: DateTime(2026, 10, 20, 9, 15),
      );
      await seedSymptom(
        's_other_recipient',
        patient: recipient('dad'),
        name: 'Cough',
        note: 'Not this recipient',
        timeLogged: DateTime(2026, 11, 1, 9, 15),
      );
      await seedNote(
        'n_in',
        patient: mom,
        text: 'Slept poorly, up 3x. No fever.',
        noteDateTime: DateTime(2026, 11, 3, 23, 50),
        createdBy: 'Alex',
        category: 'Sleep',
      );
      await seedNote(
        'n_created_at_only',
        patient: mom,
        text: 'Used createdAt when noteDateTime is empty.',
        createdAt: DateTime(2026, 10, 29, 8),
      );
      await seedNote(
        'n_out',
        patient: mom,
        text: 'Before the window',
        noteDateTime: DateTime(2026, 9, 1, 8),
      );
      await seedMedication('m_1', patient: mom, name: 'Lisinopril', dose: '10mg');

      final report = await loadCareReportData(
        recipientRef: mom,
        range: careReportRangeFor(CareReportPreset.last7Days, now: now),
        generatedAt: now,
      );

      expect(report.recipientName, 'Mom');
      expect(report.range.label, 'Last 7 days');
      expect(report.symptoms.map((s) => s.name), ['Dizziness']);
      expect(report.symptoms.single.resolved, isTrue);
      expect(
        report.symptoms.single.note,
        'After lunch - said the room was "spinning".',
      );
      expect(
        report.notes.map((n) => n.text),
        ['Slept poorly, up 3x. No fever.', 'Used createdAt when noteDateTime is empty.'],
      );
      expect(report.notes.first.author, 'Alex');
      expect(report.notes.first.category, 'Sleep');
      // The current medication list is not date-ranged.
      expect(report.medications.map((m) => m.name), ['Lisinopril']);
    });

    test('a period with no records reports no records, and omits sections',
        () async {
      final mom = recipient('mom');
      await seedRecipient('mom');
      FFAppState().activeGroupId = 'org_test';
      await seedSymptom(
        's_out',
        patient: mom,
        name: 'Headache',
        timeLogged: DateTime(2026, 1, 1),
      );

      final report = await loadCareReportData(
        recipientRef: mom,
        range: careReportRangeFor(CareReportPreset.last7Days, now: now),
        generatedAt: now,
      );

      expect(report.symptoms, isEmpty);
      expect(report.notes, isEmpty);
      expect(report.medications, isEmpty);
      expect(report.hasRangedRecords, isFalse);
      expect(report.isEmpty, isTrue);
    });

    test('the report carries no section for a collection it cannot read',
        () async {
      // vitals / appointments / dashboard notes / emergency info are deny-all in
      // firestore.rules, so the loader never queries them: a report built for a
      // recipient with data in those collections still reports only what the
      // app can actually read.
      final mom = recipient('mom');
      await seedRecipient('mom');
      FFAppState().activeGroupId = 'org_test';
      fakeFirestore.writeDoc('vitalLogs/v_1', {
        'careRecipientRef': mom,
        'logDateTime': DateTime(2026, 11, 2, 8),
        'heartRate': 88,
      });
      fakeFirestore.writeDoc('appointments/a_1', {
        'careRecipientRef': mom,
        'appointmentTitle': 'Cardiology follow-up',
        'appointmentDateTime': DateTime(2026, 11, 2, 10),
      });

      final report = await loadCareReportData(
        recipientRef: mom,
        range: careReportRangeFor(CareReportPreset.last30Days, now: now),
        generatedAt: now,
      );

      expect(report.isEmpty, isTrue);
    });
  });

  group('PDF output', () {
    CareReportData dataFor({
      List<CareReportSymptom> symptoms = const [],
      List<CareReportMedication> medications = const [],
      List<CareReportNote> notes = const [],
    }) =>
        CareReportData(
          recipientName: 'Mom',
          careCircleName: 'The Rivera family',
          range: careReportRangeFor(CareReportPreset.last7Days, now: now),
          generatedAt: now,
          symptoms: symptoms,
          medications: medications,
          notes: notes,
        );

    test('renders a real PDF with the recorded content', () async {
      final bytes = await buildCareReportPdf(dataFor(
        symptoms: [
          CareReportSymptom(
            name: 'Dizziness',
            note: 'After lunch',
            timeLogged: DateTime(2026, 11, 2, 9),
            resolved: false,
          ),
        ],
        medications: [
          const CareReportMedication(
            name: 'Lisinopril',
            dose: '10mg',
            schedule: 'With breakfast',
            status: 'Active',
          ),
        ],
        notes: [
          CareReportNote(
            text: 'Slept poorly.',
            author: 'Alex',
            category: 'Sleep',
            timestamp: DateTime(2026, 11, 3, 8),
          ),
        ],
      ));

      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('an empty period still renders an honest short PDF', () async {
      final bytes = await buildCareReportPdf(dataFor());
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('the file name identifies the recipient and the day', () {
      expect(careReportFileName(dataFor()), 'care-report-mom-20261103.pdf');
    });
  });

  group('range sheet', () {
    testWidgets('defaults to Last 30 days and pops the chosen range',
        (tester) async {
      CareReportRange? picked;
      await tester.pumpWidget(
        ChangeNotifierProvider<FFAppState>.value(
          value: FFAppState(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    picked = await showModalBottomSheet<CareReportRange>(
                      context: context,
                      builder: (_) => DoctorReportRangeSheetWidget(now: now),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a date range'), findsOneWidget);
      for (final preset in CareReportPreset.values) {
        expect(find.text(careReportPresetLabel(preset)), findsOneWidget);
      }
      // The sheet opens on Last 30 days, so its bounds are the default period.
      expect(find.textContaining('5 Oct 2026 - 3 Nov 2026'), findsOneWidget);

      await tester.tap(find.text('Last 7 days'));
      await tester.pumpAndSettle();
      expect(find.textContaining('28 Oct 2026 - 3 Nov 2026'), findsOneWidget);

      await tester.tap(find.text('Generate PDF'));
      await tester.pumpAndSettle();

      expect(picked, isNotNull);
      expect(picked!.label, 'Last 7 days');
      expect(picked!.start, DateTime(2026, 10, 28));
      expect(picked!.end, DateTime(2026, 11, 3));
    });
  });

  group('Doctor Prep page', () {
    testWidgets('the Export action opens the range sheet', (tester) async {
      tester.view.physicalSize = const Size(1080.0, 2400.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FFAppState().selectedCareRecipient = recipient('mom');

      final router = GoRouter(
        initialLocation: GDoctorVisitPrepWidget.routePath,
        routes: [
          GoRoute(
            path: GDoctorVisitPrepWidget.routePath,
            builder: (context, state) => const GDoctorVisitPrepWidget(),
          ),
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<FFAppState>.value(
          value: FFAppState(),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Export'), findsOneWidget);
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a date range'), findsOneWidget);
      expect(find.text('Generate PDF'), findsOneWidget);
      expect(find.text('Last 30 days'), findsOneWidget);
    });
  });
}
