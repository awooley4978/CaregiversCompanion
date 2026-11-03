// Daily Dashboard Symptoms section: log a new entry, resolve an existing one,
// and never fabricate a duplicate (owner-confirmed symptom spec, U1 symptom half).
//
// The exported row's 'Add Entry' button `set()` a COPY of the row on every tap
// (a duplicate entry that also cleared the resolved flag), and no create path
// existed at all. Now:
//   * the row card renders its own record and its only control updates THAT
//     document (`isResolved: true`) — a row tap writes nothing;
//   * a new entry comes from the section header's 'Log New Symptom' sheet, which
//     writes ONE `symptomEntries` doc carrying `symptomName`, `note`,
//     `timeLogged` and `patientRef` = the resolved recipient (the field the
//     create rule gates on);
//   * both writes report a rejection with a snackbar instead of failing silently,
//     and neither ever writes with a null recipient.
// Offline + deterministic against the in-memory Firestore fake (seeded/asserted
// through the app-facing API — see test/firebase_test_setup.dart).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/backend/backend.dart';
import 'package:new_project/backend/org/org_service.dart';
import 'package:new_project/components/dashboard_symptom_add_sheet/dashboard_symptom_add_sheet_widget.dart';
import 'package:new_project/components/dashboard_symptom_card/dashboard_symptom_card_widget.dart';
import 'package:provider/provider.dart';
import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initFirebaseForTest();
  });

  setUp(() {
    FFAppState.reset();
    fakeFirestore.clear();
    fakeFirestore.clearWriteError();
    FFAppState().selectedCareRecipient = null;
  });

  DocumentReference recipient(String id) =>
      FirebaseFirestore.instance.doc('careRecipients/$id');

  /// Seeds one symptom entry through the app-facing `set()` — the same write
  /// path the section's `where(patientRef == ...)` value is encoded on.
  Future<SymptomEntriesRecord> seedSymptom(
    String id,
    DocumentReference patient, {
    String name = 'Dizziness',
    String note = 'After lunch',
    DateTime? timeLogged,
    bool isResolved = false,
  }) async {
    final ref = SymptomEntriesRecord.collection.doc(id);
    await ref.set({
      'symptomName': name,
      'note': note,
      'timeLogged': timeLogged,
      'patientRef': patient,
      'isResolved': isResolved,
    });
    return SymptomEntriesRecord.getDocumentOnce(ref);
  }

  Iterable<MapEntry<String, Map<String, dynamic>>> writtenSymptoms() =>
      fakeFirestore.docs.entries
          .where((e) => e.key.startsWith('symptomEntries/'));

  Future<void> pumpCard(WidgetTester tester, SymptomEntriesRecord record) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<FFAppState>.value(
        value: FFAppState(),
        child: MaterialApp(
          home: Scaffold(
            body: DashboardSymptomCardWidget(record: record),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Pumps the 'Log New Symptom' sheet the way the dashboard opens it (a modal
  /// bottom sheet), so the pop-on-success and the snackbars behave as they do
  /// live.
  Future<void> pumpSheet(
    WidgetTester tester, {
    DocumentReference? careRecipientRef,
    Size viewport = const Size(1200, 2400),
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<FFAppState>.value(
        value: FFAppState(),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showModalBottomSheet(
                    isScrollControlled: true,
                    context: context,
                    builder: (_) => DashboardSymptomAddSheetWidget(
                      careRecipientRef: careRecipientRef,
                    ),
                  ),
                  child: const Text('open symptom sheet'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open symptom sheet'));
    await tester.pumpAndSettle();
  }

  Future<void> tapLogSymptom(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Log Symptom'));
    await tester.pump();
    await tester.tap(find.text('Log Symptom'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // -------------------------------------------------------------------------
  // The row card: resolve in place, never duplicate.
  // -------------------------------------------------------------------------
  group('symptom row', () {
    testWidgets('renders its own record, not hardcoded demo copy',
        (tester) async {
      final record = await seedSymptom('s1', recipient('mine'),
          name: 'Headache', note: 'Mild, left side');
      await pumpCard(tester, record);

      expect(find.text('Headache'), findsOneWidget);
      expect(find.text('Mild, left side'), findsOneWidget);
      expect(find.text('Mark Resolved'), findsOneWidget);
      // The exported row's duplicate-creating control is gone.
      expect(find.text('Add Entry'), findsNothing);
    });

    testWidgets('tapping the row itself creates nothing and resolves nothing',
        (tester) async {
      final record = await seedSymptom('s1', recipient('mine'));
      await pumpCard(tester, record);

      await tester.tap(find.text('Dizziness'));
      await tester.pumpAndSettle();

      // One row tap used to `set()` a copy of the row (duplicate entry). The
      // section now only has the one seeded record, still unresolved.
      expect(writtenSymptoms(), hasLength(1));
      final saved =
          await SymptomEntriesRecord.getDocumentOnce(record.reference);
      expect(saved.isResolved, isFalse);
    });

    testWidgets('Mark Resolved updates that record in place', (tester) async {
      final patient = recipient('mine');
      final record = await seedSymptom('s1', patient);
      await pumpCard(tester, record);

      await tester.tap(find.text('Mark Resolved'));
      await tester.pumpAndSettle();

      // The SAME document is updated — no second entry is created.
      final all = await symptomEntriesForRecipient(recipientRef: patient).first;
      expect(all, hasLength(1));
      expect(all.single.reference.path, record.reference.path);
      expect(all.single.isResolved, isTrue);
      expect(find.text('Symptom marked as resolved.'), findsOneWidget);
    });

    testWidgets('an already-resolved row offers no resolve control',
        (tester) async {
      final record =
          await seedSymptom('s1', recipient('mine'), isResolved: true);
      await pumpCard(tester, record);

      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text('Mark Resolved'), findsNothing);
    });

    testWidgets('a denied resolve shows a snackbar and leaves it unresolved',
        (tester) async {
      final record = await seedSymptom('s1', recipient('mine'));
      await pumpCard(tester, record);

      fakeFirestore.writeError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      );
      await tester.tap(find.text('Mark Resolved'));
      await tester.pumpAndSettle();

      expect(find.text('Could not update this symptom. Please try again.'),
          findsOneWidget);
      final saved =
          await SymptomEntriesRecord.getDocumentOnce(record.reference);
      expect(saved.isResolved, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // The 'Log New Symptom' sheet: one create, scoped to the recipient.
  // -------------------------------------------------------------------------
  group('log new symptom sheet', () {
    testWidgets('creates one entry carrying the resolved recipient as patientRef',
        (tester) async {
      final mine = recipient('mine');
      await pumpSheet(tester, careRecipientRef: mine);

      await tester.enterText(find.byType(TextField).at(0), 'Swollen ankle');
      await tester.enterText(find.byType(TextField).at(1), 'Since the walk');
      await tapLogSymptom(tester);

      final written = writtenSymptoms().toList();
      expect(written, hasLength(1));
      final data = written.single.value;
      expect(data['symptomName'], 'Swollen ankle');
      expect(data['note'], 'Since the walk');
      // The field the create rule gates on.
      expect((data['patientRef'] as dynamic).path, mine.path);
      expect(data['isResolved'], isFalse);
      expect(data['timeLogged'], isNotNull);

      // Confirmed save, and the sheet closes so the caregiver lands back on the
      // dashboard.
      expect(find.text('Symptom logged.'), findsOneWidget);
      expect(find.text('Log Symptom'), findsNothing);
    });

    testWidgets('the new entry reads back through the section\'s own query',
        (tester) async {
      final mine = recipient('mine');
      await pumpSheet(tester, careRecipientRef: mine);

      await tester.enterText(find.byType(TextField).at(0), 'Nausea');
      await tapLogSymptom(tester);

      final loaded =
          await symptomEntriesForRecipient(recipientRef: mine).first;
      expect(loaded, hasLength(1));
      expect(loaded.single.symptomName, 'Nausea');
      expect(loaded.single.patientRef?.path, mine.path);
    });

    testWidgets('Save with NO recipient prompts and writes nothing',
        (tester) async {
      await pumpSheet(tester);

      await tester.enterText(find.byType(TextField).at(0), 'Rash');
      await tapLogSymptom(tester);

      expect(writtenSymptoms(), isEmpty);
      expect(find.text('Select a care recipient to log this symptom.'),
          findsOneWidget);
    });

    testWidgets('Save with no symptom name prompts and writes nothing',
        (tester) async {
      await pumpSheet(tester, careRecipientRef: recipient('mine'));

      await tapLogSymptom(tester);

      expect(writtenSymptoms(), isEmpty);
      expect(find.text('Enter a symptom name.'), findsOneWidget);
    });

    testWidgets('a denied create shows a snackbar and creates nothing',
        (tester) async {
      await pumpSheet(tester, careRecipientRef: recipient('mine'));

      fakeFirestore.writeError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      );
      await tester.enterText(find.byType(TextField).at(0), 'Fever');
      await tapLogSymptom(tester);

      expect(writtenSymptoms(), isEmpty);
      expect(find.text('Could not log the symptom. Please try again.'),
          findsOneWidget);
      // The sheet stays open so the caregiver can retry.
      expect(find.text('Log Symptom'), findsOneWidget);
    });
  });
}
