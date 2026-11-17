// Appointments unit, part 3 (owner-approved 2026-11-16, proposal §5–§7): the ONE
// create-or-edit appointment form and Doctor Visit Prep reading real data.
//
// Pinned here:
//  (1) a NEW appointment is ONE `appointments` document carrying the care
//      recipient's own `orgId` and the caller's `createdByUid` — the two values
//      the merged rules verify — with server-stamped timestamps;
//  (2) editing loads the appointment it was opened with and saves back to that
//      SAME document: a second appointment is never created;
//  (3) an edit sends only the fields the form owns, so Doctor Prep's
//      `questionsToAsk` and the immutable `orgId` / `createdByUid` survive;
//  (4) "Add Question" appends exactly ONE line to the stored `questionsToAsk`
//      text (one question per line, commas never split);
//  (5) Doctor Visit Prep shows the recipient's REAL next appointment and REAL
//      symptom observations instead of the invented cards the export shipped.
//
// The form's clock is injected (`now`), so this file never depends on the wall
// clock. The two Doctor Prep tests use a real "tomorrow" because that page reads
// the device clock when it picks the next upcoming appointment.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/backend/appointments/appointment_form.dart';
import 'package:new_project/backend/backend.dart';
import 'package:new_project/pages/appointment_form/appointment_form_widget.dart';
import 'package:new_project/pages/g_doctor_visit_prep/g_doctor_visit_prep_widget.dart';
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
    fakeAuthPlatform.emitSignedIn(uid: 'uid-1', email: 'cg@example.com');
  });

  // A FIXED local instant — Friday, 20 November 2026, 4:00 PM — handed to the
  // form as `now` and used as the Calendar's selected day, so the form's
  // defaults are deterministic.
  final now = DateTime(2026, 11, 20, 16, 0);
  final selectedDay = DateTime(2026, 11, 20);

  DocumentReference recipientRef([String id = 'r1']) =>
      FirebaseFirestore.instance.doc('careRecipients/$id');

  Future<void> seedRecipient({String id = 'r1'}) async {
    await recipientRef(id).set({'Name': 'Margaret Alvarez', 'orgId': 'org_test'});
  }

  Future<DocumentReference> seedAppointment({
    String recipientId = 'r1',
    required String title,
    required DateTime start,
    String questions = '',
  }) async {
    final ref = AppointmentsRecord.collection.doc();
    await ref.set(
      createAppointmentsRecordData(
        careRecipientRef: recipientRef(recipientId),
        appointmentTitle: title,
        appointmentDateTime: start,
        questionsToAsk: questions.isEmpty ? null : questions,
        orgId: 'org_test',
        createdByUid: 'uid-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return ref;
  }

  /// The recipient's stored appointments, read through the app-facing API.
  Future<List<AppointmentsRecord>> storedAppointments([String id = 'r1']) =>
      queryAppointmentsRecordOnce(
        queryBuilder: (q) =>
            q.where('careRecipientRef', isEqualTo: recipientRef(id)),
      );

  /// How many `appointments` documents exist — the "never a second copy" check.
  int appointmentDocCount() => fakeFirestore.docs.keys
      .where((path) => RegExp(r'^appointments/[^/]+$').hasMatch(path))
      .length;

  Future<void> seedSymptom({
    String recipientId = 'r1',
    required String name,
    String note = '',
    DateTime? timeLogged,
    bool isResolved = false,
  }) async {
    await SymptomEntriesRecord.collection.doc().set(
      createSymptomEntriesRecordData(
        symptomName: name,
        note: note,
        timeLogged: timeLogged,
        patientRef: recipientRef(recipientId),
        isResolved: isResolved,
      ),
    );
  }

  /// Pumps the appointment form on top of a GoRouter route, because the form
  /// closes itself with go_router's `context.pop()` after a successful save.
  Future<void> pumpForm(
    WidgetTester tester, {
    DocumentReference? appointments,
    DocumentReference? careRecipient,
    DateTime? initialDate,
  }) async {
    tester.view.physicalSize = const Size(1080.0, 2600.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/calendar',
      routes: [
        GoRoute(
          path: '/calendar',
          builder: (context, state) => const Scaffold(body: Text('Calendar')),
        ),
        GoRoute(
          path: AppointmentFormWidget.routePath,
          builder: (context, state) => AppointmentFormWidget(
            appointments: appointments,
            careRecipient: careRecipient,
            initialDate: initialDate,
            now: now,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    router.push(AppointmentFormWidget.routePath);
    await tester.pumpAndSettle();
  }

  Future<void> pumpDoctorPrep(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080.0, 4000.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: const GDoctorVisitPrepWidget()));
    await tester.pumpAndSettle();
  }

  /// Tomorrow at [hour]:[minute], local — always a future appointment.
  DateTime tomorrowAt(int hour, int minute) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute);
  }

  group('appointment write payloads', () {
    test('a create payload carries the recipient org, the caller uid and '
        'server-stamped timestamps', () {
      final data = createAppointmentDataFor(
        careRecipientRef: recipientRef(),
        orgId: 'org_test',
        createdByUid: 'uid-1',
        values: AppointmentFormValues(
          title: '  Cardiology Follow-up  ',
          type: 'medical',
          day: selectedDay,
          startHour: 9,
          startMinute: 30,
        ),
      );

      expect(data['appointmentTitle'], 'Cardiology Follow-up');
      expect(data['orgId'], 'org_test');
      expect(data['createdByUid'], 'uid-1');
      expect(data['appointmentDateTime'], isNotNull);
      // The rules require the server's time, not the device's.
      expect(data['createdAt'], isA<FieldValue>());
      expect(data['updatedAt'], isA<FieldValue>());
    });

    test('an update payload sends only the fields the form owns', () {
      final data = updateAppointmentDataFor(AppointmentFormValues(
        title: 'Cardiology Follow-up',
        day: selectedDay,
        startHour: 9,
        startMinute: 30,
      ));

      // Never touched by this form: the recipient, the security fields and the
      // questions Doctor Prep owns.
      expect(data.keys, isNot(contains('careRecipientRef')));
      expect(data.keys, isNot(contains('orgId')));
      expect(data.keys, isNot(contains('createdByUid')));
      expect(data.keys, isNot(contains('questionsToAsk')));
      expect(data.keys, isNot(contains('createdAt')));
      expect(data['updatedAt'], isA<FieldValue>());
      // Cleared optional text is removed, not stored as an empty string.
      expect(data['notes'], isA<FieldValue>());
    });

    test('a question is appended as exactly one new line, never comma-split',
        () {
      const existing = 'Ask about the 10, 20 or 40 mg doses?\n'
          'Ask about the fluid limit this week?';

      final appended = appendAppointmentQuestion(existing, ' When is the scan? ');
      expect(appointmentQuestionLines(appended), [
        'Ask about the 10, 20 or 40 mg doses?',
        'Ask about the fluid limit this week?',
        'When is the scan?',
      ]);
      expect(appended.split('\n').length, 3);
      // A blank question changes nothing.
      expect(appendAppointmentQuestion(existing, '   '), existing);
    });
  });

  group('appointment form', () {
    testWidgets('create mode writes ONE document with the recipient orgId and '
        'the caller uid', (tester) async {
      await seedRecipient();
      await pumpForm(
        tester,
        careRecipient: recipientRef(),
        initialDate: selectedDay,
      );

      await tester.enterText(
          find.byType(TextField).first, 'Cardiology Follow-up');
      await tester.pumpAndSettle();

      // A start time is required; the picker's default is 9:00 AM.
      await tester.tap(find.text('Choose a start time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('9:00 AM'), findsOneWidget);

      await tester.ensureVisible(find.text('Create Appointment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Appointment'));
      await tester.pumpAndSettle();

      expect(appointmentDocCount(), 1);
      final records = await storedAppointments();
      expect(records.length, 1);
      expect(records.single.appointmentTitle, 'Cardiology Follow-up');
      // The values the merged rules verify on create.
      expect(records.single.orgId, 'org_test');
      expect(records.single.createdByUid, 'uid-1');
      expect(records.single.careRecipientRef?.path, 'careRecipients/r1');
      expect(records.single.appointmentDateTime, DateTime(2026, 11, 20, 9, 0));
      // A new appointment has no questions until one is added.
      expect(records.single.questionsToAsk, '');
      expect(tester.takeException(), isNull);
    });

    testWidgets('edit mode updates the same document and never creates a second',
        (tester) async {
      await seedRecipient();
      final ref = await seedAppointment(
        title: 'Cardiology Follow-up',
        start: DateTime(2026, 11, 20, 9, 30),
        questions: 'Ask about the 10, 20 or 40 mg doses?\n'
            'Ask about the fluid limit this week?',
      );
      final path = ref.path;

      await pumpForm(tester, appointments: ref);

      // Edit mode: the stored appointment is loaded into the form.
      expect(find.text('Appointment Details'), findsOneWidget);
      expect(find.text('Cardiology Follow-up'), findsOneWidget);
      expect(find.text('9:30 AM'), findsOneWidget);

      await tester.enterText(
          find.byType(TextField).first, 'Cardiology Follow-up (moved)');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // The SAME document, and still only one of them.
      expect(appointmentDocCount(), 1);
      expect(fakeFirestore.docs.containsKey(path), isTrue);

      final saved = fakeFirestore.docs[path]!;
      expect(saved['appointmentTitle'], 'Cardiology Follow-up (moved)');
      // Untouched by an edit: Doctor Prep's questions and the immutable
      // security fields.
      expect(saved['questionsToAsk'],
          'Ask about the 10, 20 or 40 mg doses?\n'
          'Ask about the fluid limit this week?');
      expect(saved['orgId'], 'org_test');
      expect(saved['createdByUid'], 'uid-1');

      final records = await storedAppointments();
      expect(records.single.careRecipientRef?.path, 'careRecipients/r1');
      expect(records.single.appointmentDateTime, DateTime(2026, 11, 20, 9, 30));
      expect(tester.takeException(), isNull);
    });
  });

  group('Doctor Visit Prep', () {
    testWidgets('shows the real next appointment and the real observations',
        (tester) async {
      await seedRecipient();
      FFAppState().selectedCareRecipient = recipientRef();
      await seedAppointment(
        title: 'Hospice nurse visit',
        start: tomorrowAt(10, 0),
      );
      await seedSymptom(
        name: 'Swelling in ankles',
        note: 'Both ankles, worse in the evening.',
        timeLogged: DateTime.now().subtract(const Duration(hours: 3)),
      );

      await pumpDoctorPrep(tester);

      // The real appointment and the real symptom entry.
      expect(find.text('Hospice nurse visit'), findsOneWidget);
      expect(find.text('Swelling in ankles'), findsOneWidget);
      expect(find.text('Both ankles, worse in the evening.'), findsOneWidget);
      expect(find.text('No upcoming appointment scheduled'), findsNothing);
      expect(
          find.text('No symptoms logged for this care recipient yet.'),
          findsNothing);

      // Nothing invented: the export's hardcoded appointment, questions and
      // observations are gone.
      expect(find.text('Cardiology Follow-up'), findsNothing);
      expect(find.text('Tomorrow at 10:30 AM'), findsNothing);
      expect(find.text('High Blood Pressure'), findsNothing);
      expect(find.text('Shortness of Breath'), findsNothing);
      expect(find.text('Increased Fatigue'), findsNothing);
      expect(find.text('Should we adjust the morning dosage of Lisinopril?'),
          findsNothing);
      expect(
          find.text(
              'Is the recent swelling in ankles typical for heart failure?'),
          findsNothing);
      expect(
          find.text('What are the recommended fluid limits for this week?'),
          findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Add Question appends exactly one line to questionsToAsk',
        (tester) async {
      await seedRecipient();
      FFAppState().selectedCareRecipient = recipientRef();
      final ref = await seedAppointment(
        title: 'Hospice nurse visit',
        start: tomorrowAt(10, 0),
        questions: 'Ask about the 10, 20 or 40 mg doses?',
      );

      await pumpDoctorPrep(tester);
      expect(find.text('Ask about the 10, 20 or 40 mg doses?'), findsOneWidget);

      await tester.ensureVisible(find.text('Add Question'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Question'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField).last, 'Ask about the fluid limit this week');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      final stored = fakeFirestore.docs[ref.path]!['questionsToAsk'] as String;
      expect(stored,
          'Ask about the 10, 20 or 40 mg doses?\n'
          'Ask about the fluid limit this week');
      expect(appointmentQuestionLines(stored).length, 2);
      // Both real questions are on the page.
      expect(find.text('Ask about the 10, 20 or 40 mg doses?'), findsOneWidget);
      expect(find.text('Ask about the fluid limit this week'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
