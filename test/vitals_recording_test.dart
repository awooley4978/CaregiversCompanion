// Vitals recording unit (owner decisions 2026-11-13, proposal §9).
//
// What is covered here:
//  * the validation/formatting helper (bounds, pain 0, "at least one
//    measurement", notes length, the last-reading and history view models);
//  * saving writes exactly ONE `vitalLogs` document for the recipient on
//    screen, carrying `orgId` and `loggedByUid` as the merged rules require,
//    with a non-future timestamp and only the measurements that were entered;
//  * an invalid form writes nothing and says which field and range is wrong;
//  * the "Last: …" lines show the recipient's real newest values and
//    "No readings yet" when there are none — never a placeholder number;
//  * the history icon shows the recipient's saved readings, newest first, with
//    dates, times and real author names;
//  * edit/delete are offered only to the author or an org owner/admin, and the
//    edit keeps `careRecipientRef`/`orgId`/`loggedByUid` unchanged;
//  * switching care recipients never leaves another recipient's data on
//    screen.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/backend/backend.dart';
import 'package:new_project/backend/vitals/vitals_entry.dart';
import 'package:new_project/pages/e_vitals_tracker_log/e_vitals_tracker_log_widget.dart';
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

  DocumentReference recipientRef([String id = 'r1']) =>
      FirebaseFirestore.instance.doc('careRecipients/$id');

  Future<void> seedRecipient({
    String id = 'r1',
    String name = 'Margaret Alvarez',
    String orgId = 'org_test',
  }) async {
    await recipientRef(id).set({'Name': name, 'orgId': orgId});
  }

  Future<void> seedMember({
    String orgId = 'org_test',
    required String uid,
    required String role,
    String displayName = '',
  }) async {
    await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .doc(uid)
        .set({
      'uid': uid,
      'orgId': orgId,
      'role': role,
      'status': 'active',
      'displayName': displayName,
    });
  }

  /// Seeds one saved reading through the app-facing write path.
  Future<void> seedLog({
    String recipientId = 'r1',
    required DateTime at,
    String uid = 'uid-1',
    String orgId = 'org_test',
    int? heartRate,
    int? systolic,
    int? diastolic,
    double? temperature,
    int? painLevel,
    String? notes,
  }) async {
    await VitalLogsRecord.collection.doc().set(
          createVitalLogsRecordData(
            careRecipientRef: recipientRef(recipientId),
            logDateTime: at,
            bloodPressureSystolic: systolic,
            bloodPressureDiastolic: diastolic,
            heartRate: heartRate,
            temperature: temperature,
            painLevel: painLevel,
            notes: notes,
            orgId: orgId,
            loggedByUid: uid,
          ),
        );
  }

  List<MapEntry<String, Map<String, dynamic>>> vitalDocs() =>
      fakeFirestore.docs.entries
          .where((entry) => entry.key.startsWith('vitalLogs/'))
          .toList();

  Future<void> pumpVitals(WidgetTester tester,
      {DocumentReference? recipient}) async {
    tester.view.physicalSize = const Size(1080.0, 2400.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    FFAppState().selectedCareRecipient = recipient ?? recipientRef();
    await tester.pumpWidget(const MaterialApp(home: EVitalsTrackerLogWidget()));
    await tester.pumpAndSettle();
  }

  /// The page's own inputs, in build order.
  Future<void> enterField(WidgetTester tester, int index, String text) =>
      tester.enterText(find.byType(TextFormField).at(index), text);

  // Field order on the screen: systolic, diastolic, heart rate, glucose,
  // oxygen saturation, temperature, weight, pain, observations.
  const heartRateField = 2;
  const temperatureField = 5;
  const painField = 7;

  group('validation', () {
    test('a single measurement is enough, and pain 0 is valid', () {
      final result = validateVitalsInput(heartRate: '72', painLevel: '0');

      expect(result.isValid, isTrue);
      expect(result.draft!.heartRate, 72);
      expect(result.draft!.painLevel, 0);
      expect(result.draft!.hasMeasurement, isTrue);
    });

    test('an empty form is refused', () {
      final result = validateVitalsInput();

      expect(result.isValid, isFalse);
      expect(result.error, contains('at least one measurement'));
    });

    test('out-of-range values name the field and the accepted range', () {
      expect(validateVitalsInput(heartRate: '999').error,
          'Heart rate (bpm) must be a whole number between 20 and 300.');
      expect(validateVitalsInput(oxygenSaturation: '101').error,
          'Oxygen saturation (%) must be a whole number between 50 and 100.');
      expect(validateVitalsInput(painLevel: '11').error,
          'Pain level (0–10) must be a whole number between 0 and 10.');
      expect(validateVitalsInput(temperature: '79.9').error,
          'Temperature (°F) must be a number between 80 and 115.');
      expect(validateVitalsInput(weight: '20.5').isValid, isTrue);
      expect(validateVitalsInput(weight: '19').error,
          'Weight (lb) must be a number between 20 and 1000.');
    });

    test('non-numeric input is refused', () {
      expect(validateVitalsInput(heartRate: 'fast').error,
          'Heart rate (bpm) must be a whole number between 20 and 300.');
      expect(validateVitalsInput(temperature: 'warm').error,
          'Temperature (°F) must be a number between 80 and 115.');
    });

    test('half a blood pressure reading is refused', () {
      expect(validateVitalsInput(systolic: '120').error,
          contains('Enter both blood pressure numbers'));
      expect(validateVitalsInput(systolic: '120', diastolic: '80').isValid,
          isTrue);
    });

    test('notes longer than 1000 characters are refused', () {
      expect(validateVitalsInput(heartRate: '72', notes: 'x' * 1001).error,
          'Additional observations must be 1000 characters or fewer.');
      expect(validateVitalsInput(heartRate: '72', notes: 'x' * 1000).isValid,
          isTrue);
    });

    test('the last-reading line shows the newest value, else "No readings yet"',
        () {
      final newest = VitalLogsRecord.getDocumentFromData(
        {'heartRate': 72, 'logDateTime': DateTime(2026, 11, 13, 8, 30)},
        recipientRef(),
      );
      final older = VitalLogsRecord.getDocumentFromData(
        {'heartRate': 64, 'logDateTime': DateTime(2026, 11, 12, 7, 0)},
        recipientRef(),
      );

      expect(
        lastReadingText([newest, older], VitalMeasurement.heartRate),
        'Last: 72 bpm · Nov 13, 2026 at 8:30 AM',
      );
      expect(
        lastReadingText([newest, older], VitalMeasurement.weight),
        vitalsNoReadings,
      );
    });
  });

  group('saving', () {
    testWidgets('writes one document for the recipient with orgId + author',
        (tester) async {
      fakeAuthPlatform.emitSignedIn(uid: 'uid-1', displayName: 'Dana');
      await seedRecipient();
      await seedMember(uid: 'uid-1', role: 'caregiver', displayName: 'Dana');
      await pumpVitals(tester);

      expect(find.text('Logging for Margaret Alvarez'), findsOneWidget);

      await enterField(tester, heartRateField, '72');
      await enterField(tester, painField, '0');
      await tester.tap(find.text('Save Daily Logs'));
      await tester.pumpAndSettle();

      final docs = vitalDocs();
      expect(docs, hasLength(1));
      final data = docs.single.value;
      expect(data['orgId'], 'org_test');
      expect(data['loggedByUid'], 'uid-1');
      expect(data['heartRate'], 72);
      expect(data['painLevel'], 0);
      // Only what was entered is written.
      expect(data.containsKey('temperature'), isFalse);
      expect(data.containsKey('notes'), isFalse);

      final loggedAt = data['logDateTime'];
      expect(loggedAt, isA<Timestamp>());
      expect((loggedAt as Timestamp).toDate().isAfter(DateTime.now()), isFalse);

      // It reads back through the model for the recipient on screen.
      final records = await queryVitalLogsRecordOnce(
        queryBuilder: (query) =>
            query.where('careRecipientRef', isEqualTo: recipientRef()),
      );
      expect(records, hasLength(1));
      expect(records.single.careRecipientRef?.path, 'careRecipients/r1');
      expect(records.single.orgId, 'org_test');
      expect(records.single.loggedByUid, 'uid-1');

      expect(find.textContaining('Vitals saved for Margaret Alvarez'),
          findsOneWidget);
      // The saved reading is now the "last" one.
      expect(find.textContaining('Last: 72 bpm'), findsOneWidget);
    });

    testWidgets('an invalid form writes nothing and says why', (tester) async {
      fakeAuthPlatform.emitSignedIn(uid: 'uid-1');
      await seedRecipient();
      await seedMember(uid: 'uid-1', role: 'caregiver');
      await pumpVitals(tester);

      await enterField(tester, heartRateField, '999');
      await tester.tap(find.text('Save Daily Logs'));
      await tester.pumpAndSettle();

      expect(vitalDocs(), isEmpty);
      expect(
        find.text('Heart rate (bpm) must be a whole number between 20 and '
            '300.'),
        findsOneWidget,
      );
    });
  });

  group('reading the recipient', () {
    testWidgets('last readings come from the recipient and nothing is invented',
        (tester) async {
      fakeAuthPlatform.emitSignedIn(uid: 'uid-1');
      await seedRecipient();
      await seedMember(uid: 'uid-1', role: 'caregiver');
      await seedLog(
          at: DateTime(2026, 11, 13, 8, 30),
          heartRate: 72,
          temperature: 98.6);
      await pumpVitals(tester);

      expect(find.textContaining('Last: 72 bpm'), findsOneWidget);
      expect(find.textContaining('Last: 98.6 °F'), findsOneWidget);
      // Six measurements have no reading at all.
      expect(find.text(vitalsNoReadings), findsNWidgets(5));

      // No invented person, diagnosis, classification or leftover control.
      expect(find.text('Logging for Arthur'), findsNothing);
      expect(find.text('Profile: Stroke Recovery, HTN'), findsNothing);
      expect(find.text('Normal'), findsNothing);
      expect(find.text('Elevated'), findsNothing);
      expect(find.text('Symptom Check-in'), findsNothing);
      expect(find.text('Add Care Note'), findsNothing);
      expect(find.text('Dizziness'), findsNothing);
    });

    testWidgets('no care recipient means an honest empty state and no form',
        (tester) async {
      fakeAuthPlatform.emitSignedIn(uid: 'uid-1');
      tester.view.physicalSize = const Size(1080.0, 2400.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
          const MaterialApp(home: EVitalsTrackerLogWidget()));
      await tester.pumpAndSettle();

      expect(find.text('No care recipient selected'), findsOneWidget);
      expect(find.text('Save Daily Logs'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('switching recipient never shows the previous one\'s data',
        (tester) async {
      fakeAuthPlatform.emitSignedIn(uid: 'uid-1');
      await seedRecipient(id: 'r1', name: 'Margaret Alvarez');
      await seedRecipient(id: 'r2', name: 'Robert Chen');
      await seedMember(uid: 'uid-1', role: 'caregiver');
      await seedLog(recipientId: 'r1', at: DateTime(2026, 11, 13), heartRate: 72);
      await seedLog(recipientId: 'r2', at: DateTime(2026, 11, 13), heartRate: 88);
      await pumpVitals(tester);

      expect(find.text('Logging for Margaret Alvarez'), findsOneWidget);
      expect(find.textContaining('Last: 72 bpm'), findsOneWidget);

      FFAppState().selectedCareRecipient = recipientRef('r2');
      await tester.pumpAndSettle();

      expect(find.text('Logging for Robert Chen'), findsOneWidget);
      expect(find.textContaining('Last: 88 bpm'), findsOneWidget);
      expect(find.textContaining('72 bpm'), findsNothing);
    });
  });

  group('history', () {
    testWidgets('shows the recipient\'s readings newest first with real authors',
        (tester) async {
      fakeAuthPlatform.emitSignedIn(uid: 'uid-1');
      await seedRecipient();
      await seedMember(uid: 'uid-1', role: 'caregiver', displayName: 'Dana Reed');
      await seedMember(uid: 'uid-2', role: 'caregiver', displayName: 'Sam Patel');
      await seedLog(
        at: DateTime(2026, 11, 12, 7, 15),
        uid: 'uid-2',
        heartRate: 64,
        notes: 'slept well',
      );
      await seedLog(at: DateTime(2026, 11, 13, 8, 30), heartRate: 72);
      await pumpVitals(tester);

      await tester.tap(find.byKey(const ValueKey('vitals_history_button')));
      await tester.pumpAndSettle();

      expect(find.text('Saved readings'), findsOneWidget);
      expect(find.text('Nov 13, 2026 at 8:30 AM'), findsOneWidget);
      expect(find.text('Nov 12, 2026 at 7:15 AM'), findsOneWidget);
      expect(find.text('Heart rate: 72 bpm'), findsOneWidget);
      expect(find.text('Heart rate: 64 bpm'), findsOneWidget);
      expect(find.text('slept well'), findsOneWidget);
      expect(find.text('Recorded by Dana Reed'), findsOneWidget);
      expect(find.text('Recorded by Sam Patel'), findsOneWidget);

      // Newest first.
      expect(
        tester.getTopLeft(find.text('Nov 13, 2026 at 8:30 AM')).dy,
        lessThan(tester.getTopLeft(find.text('Nov 12, 2026 at 7:15 AM')).dy),
      );
    });

    testWidgets('a caregiver sees no edit/delete on someone else\'s reading',
        (tester) async {
      fakeAuthPlatform.emitSignedIn(uid: 'uid-2');
      await seedRecipient();
      await seedMember(uid: 'uid-2', role: 'caregiver', displayName: 'Sam Patel');
      await seedLog(at: DateTime(2026, 11, 13, 8, 30), uid: 'uid-1', heartRate: 72);
      await pumpVitals(tester);

      await tester.tap(find.byKey(const ValueKey('vitals_history_button')));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Edit reading'), findsNothing);
      expect(find.byTooltip('Delete reading'), findsNothing);
    });

    testWidgets('the author can edit and delete their own reading',
        (tester) async {
      fakeAuthPlatform.emitSignedIn(uid: 'uid-1');
      await seedRecipient();
      await seedMember(uid: 'uid-1', role: 'caregiver', displayName: 'Dana Reed');
      await seedLog(at: DateTime(2026, 11, 13, 8, 30), heartRate: 72);
      await pumpVitals(tester);

      // Edit: the immutable fields stay put, the measurement changes.
      await tester.tap(find.byKey(const ValueKey('vitals_history_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit reading'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Heart rate (bpm)'), '81');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final edited = vitalDocs().single.value;
      expect(edited['heartRate'], 81);
      expect(edited['orgId'], 'org_test');
      expect(edited['loggedByUid'], 'uid-1');
      expect(edited['logDateTime'], isA<Timestamp>());

      // Delete.
      await tester.tap(find.byKey(const ValueKey('vitals_history_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete reading'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(vitalDocs(), isEmpty);
    });

    testWidgets('an org owner can delete a reading they did not write',
        (tester) async {
      fakeAuthPlatform.emitSignedIn(uid: 'uid-owner');
      await seedRecipient();
      await seedMember(uid: 'uid-owner', role: 'owner', displayName: 'Pat');
      await seedLog(at: DateTime(2026, 11, 13, 8, 30), uid: 'uid-1', heartRate: 72);
      await pumpVitals(tester);

      await tester.tap(find.byKey(const ValueKey('vitals_history_button')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Delete reading'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete reading'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(vitalDocs(), isEmpty);
    });
  });
}
