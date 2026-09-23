// Daily Dashboard nav-menu ACTIONS wiring (owner report 2026-09-22).
//
// The Daily Dashboard has two entry points: pushed WITH the careRecipients
// route param (client directory card tap / post-Save-Profile, PR #23) and from
// the nav menu's 'Daily Care' entry, which pushes it with NO param. PR #29 made
// the sections parent-safe on that second path; these tests pin the ACTIONS on
// it — the dashboard resolves ONE working recipient (route param, else the
// app-wide selection) and every read/write below is scoped to it:
//
//   * symptoms   – recipient-scoped stream (was: the stale/absent selection)
//   * checklist  – the recipient's real subcollection (was: always empty)
//   * med Taken  – the Medication Tracker's own update payload (PR #22)
//   * Add Note   – a real `careNotes` write (was: a print stub)
//
// Rendering the WHOLE dashboard in this harness trips a pre-existing, unrelated
// carechecklist orderBy TypeError (see dashboard_page_connectivity_test.dart),
// so the contracts are pinned through the top-level functions the page itself
// calls, plus a direct widget test of the note sheet.
//
// Seeding goes through `fakeFirestore.writeDoc` (raw store) rather than the
// app-facing `set()` for the DateTime-bearing rows, so the rows parse exactly
// as stored — same trick medication_taken_test uses for `takenAt`.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/backend/backend.dart';
import 'package:new_project/backend/org/org_service.dart';
import 'package:new_project/components/dashboard_notes_form/dashboard_notes_form_widget.dart';
import 'package:new_project/pages/c_daily_dashboard/c_daily_dashboard_widget.dart';
import 'package:new_project/pages/d_medication_tracker/d_medication_tracker_widget.dart';
import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initFirebaseForTest();
  });

  setUp(() {
    FFAppState.reset();
    fakeFirestore.clear();
  });

  DocumentReference recipient(String id) =>
      FirebaseFirestore.instance.doc('careRecipients/$id');

  // -------------------------------------------------------------------------
  // 1. Recipient resolution: the route param, else the app-wide selection.
  // -------------------------------------------------------------------------
  group('dashboardRecipientRef', () {
    test('no param and no selection -> no recipient (PR #29 empty state)', () {
      expect(dashboardRecipientRef(null), isNull);
    });

    test('nav-menu path (no param) falls back to the app-wide selection', () {
      final selected = recipient('selected');
      FFAppState().selectedCareRecipient = selected;
      expect(dashboardRecipientRef(null)?.path, selected.path);
    });

    test('a pushed recipient param wins over a stale selection', () {
      final selected = recipient('selected');
      FFAppState().selectedCareRecipient = selected;
      final pushed = CareRecipientsRecord.getDocumentFromData(
        {'name': 'Mom'},
        recipient('pushed'),
      );
      expect(dashboardRecipientRef(pushed)?.path, 'careRecipients/pushed');
    });
  });

  // -------------------------------------------------------------------------
  // 2. Symptoms: loads the RESOLVED recipient's entries whatever the selection
  //    says, and never drops an entry that has no logged time.
  // -------------------------------------------------------------------------
  group('symptoms section', () {
    Future<void> seedSymptom(String id, DocumentReference patient,
        String name, DateTime? timeLogged) async {
      // Seeded through the app-facing set(): that is the write path the query's
      // condition value is encoded on too (a raw store write leaves the
      // reference unconverted, so where(patientRef == ...) never matches), and
      // the logged time is then merged in raw so the store hands it back as the
      // DateTime the record parser reads.
      await SymptomEntriesRecord.collection.doc(id).set({
        'symptomName': name,
        'patientRef': patient,
        'timeLogged': null,
        'note': 'logged by caregiver',
        'isResolved': false,
      });
      fakeFirestore.writeDoc('symptomEntries/$id', {'timeLogged': timeLogged},
          options: SetOptions(merge: true));
    }

    test('reads the resolved recipient\'s entries and nobody else\'s',
        () async {
      final mine = recipient('mine');
      final other = recipient('other');
      await seedSymptom('s1', mine, 'Dizziness', DateTime(2026, 9, 21, 8));
      await seedSymptom('s2', other, 'Headache', DateTime(2026, 9, 21, 9));
      // A stale selection must not leak the other recipient's data in.
      FFAppState().selectedCareRecipient = other;

      final records =
          await symptomEntriesForRecipient(recipientRef: mine).first;
      expect(records.map((r) => r.symptomName), ['Dizziness']);
    });

    test('an entry with no logged time still loads, newest first', () async {
      final mine = recipient('mine');
      await seedSymptom('s1', mine, 'Untimed', null);
      await seedSymptom('s2', mine, 'Older', DateTime(2026, 9, 1, 8));
      await seedSymptom('s3', mine, 'Newer', DateTime(2026, 9, 20, 8));

      final records = [
        ...await symptomEntriesForRecipient(recipientRef: mine).first
      ]..sort(symptomEntriesNewestFirst);
      expect(records.map((r) => r.symptomName), ['Newer', 'Older', 'Untimed']);
    });

    test('no resolved recipient -> empty stream, never a null-ref query',
        () async {
      expect(
        await symptomEntriesForRecipient(recipientRef: null).first,
        isEmpty,
      );
    });
  });

  // -------------------------------------------------------------------------
  // 3. Care Checklist: the resolved recipient's real subcollection (the
  //    nav-menu path used to stream an empty list forever).
  // -------------------------------------------------------------------------
  group('care checklist section', () {
    void seedChecklist(String id, DocumentReference parent, String title,
        DateTime? createdTime) {
      fakeFirestore.writeDoc('careRecipients/${parent.id}/carechecklist/$id', {
        'title': title,
        'subtitle': '15 minutes, with the walker',
        'completed': false,
        'created_time': createdTime,
      });
    }

    test('reads the resolved recipient\'s checklist, newest first', () async {
      final mine = recipient('mine');
      final other = recipient('other');
      seedChecklist('c1', mine, 'Morning Mobility Exercise',
          DateTime(2026, 9, 1, 8));
      seedChecklist('c2', mine, 'Blood Pressure Check', DateTime(2026, 9, 20, 8));
      seedChecklist('c3', other, 'Someone else\'s task', DateTime(2026, 9, 21, 8));

      final records = await carechecklistForParent(mine).first;
      expect(
        records.map((r) => r.title),
        ['Blood Pressure Check', 'Morning Mobility Exercise'],
      );
    });

    test('a row saved without created_time is not dropped (no orderBy)',
        () async {
      final mine = recipient('mine');
      // orderBy('created_time') silently DROPS this document, which is how the
      // section can query successfully and still render nothing.
      seedChecklist('c1', mine, 'Refill the pill organiser', null);

      final records = await carechecklistForParent(mine).first;
      expect(records.map((r) => r.title), ['Refill the pill organiser']);
    });

    test('no resolved recipient -> empty stream (never a collectionGroup read)',
        () async {
      expect(await carechecklistForParent(null).first, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // 4. Med 'Taken': the same scoped lookup + update payload the Medication
  //    Tracker uses, resolved from the dashboard recipient.
  // -------------------------------------------------------------------------
  group('medication Taken action', () {
    Future<void> seedMed(
      String id,
      DocumentReference patient,
      String name,
      DateTime? scheduledTime, {
      DateTime? takenAt,
    }) async {
      // Same reason as seedSymptom: the reference (and the orgId the action's
      // query filters on) goes in through the app-facing set(); the two
      // timestamps are merged in raw.
      await MedicationsRecord.collection.doc(id).set({
        'careRecipientRef': patient,
        'medicationName': name,
        'timeOfDay': 'Morning',
        'scheduledTime': null,
        'status': takenAt == null ? 'PENDING' : 'TAKEN',
        'active': true,
        'refillNeeded': false,
        'taken': takenAt != null,
        'takenAt': null,
        'orgId': FFAppState().activeGroupId,
      });
      fakeFirestore.writeDoc('medications/$id', {
        'scheduledTime': scheduledTime,
        'takenAt': takenAt,
      }, options: SetOptions(merge: true));
    }

    /// The tracker's own list query — the lookup the dashboard's Taken action
    /// reuses (both filters are required by the Phase-4 medications LIST rule).
    Future<List<MedicationsRecord>> scopedMeds(DocumentReference patient) =>
        queryMedicationsRecordOnce(
          queryBuilder: (q) => q
              .where('orgId', isEqualTo: FFAppState().activeGroupId)
              .where('careRecipientRef', isEqualTo: patient),
        );

    test('marks the next PENDING dose taken, scoped to the recipient',
        () async {
      final mine = recipient('mine');
      final other = recipient('other');
      FFAppState().activeGroupId = 'org_test_1';
      final today = DateTime(2026, 9, 22, 10);

      await seedMed('m1', mine, 'Lisinopril', DateTime(2026, 9, 22, 8),
          takenAt: DateTime(2026, 9, 22, 8));
      await seedMed('m2', mine, 'Donepezil', DateTime(2026, 9, 22, 9));
      // Another recipient's earlier dose must never be the one we stamp.
      await seedMed('m3', other, 'Not mine', DateTime(2026, 9, 22, 7));

      final meds = await scopedMeds(mine);
      expect(meds, hasLength(2));

      final dose = nextPendingDose(meds, today);
      expect(dose?.medicationName, 'Donepezil');

      // The exact write the dashboard's Taken button performs.
      await dose!.reference.update(medicationTakenUpdate(taken: true));

      final stored = fakeFirestore.dataAt('medications/m2')!;
      expect(stored['taken'], isTrue);
      expect(stored['status'], 'TAKEN');
      expect(stored['takenAt'], isNotNull);
      final updated =
          MedicationsRecord.getDocumentFromData(stored, dose.reference);
      expect(updated.taken, isTrue);
      expect(isTakenForDay(updated.takenAt, today), isTrue);

      // The dose that was already taken today is left exactly as it was.
      expect(
        MedicationsRecord.getDocumentFromData(
          fakeFirestore.dataAt('medications/m1')!,
          FirebaseFirestore.instance.doc('medications/m1'),
        ).takenAt!.hour,
        8,
      );
    });

    test('leaves the records alone when every dose is taken today', () async {
      final mine = recipient('mine');
      FFAppState().activeGroupId = 'org_test_1';
      await seedMed('m1', mine, 'Lisinopril', DateTime(2026, 9, 22, 8),
          takenAt: DateTime(2026, 9, 22, 8));

      expect(nextPendingDose(await scopedMeds(mine), DateTime(2026, 9, 22, 10)),
          isNull);
    });

    test('a dose taken on a PREVIOUS day reads as pending again', () async {
      final mine = recipient('mine');
      FFAppState().activeGroupId = 'org_test_1';
      await seedMed('m1', mine, 'Lisinopril', DateTime(2026, 9, 21, 8),
          takenAt: DateTime(2026, 9, 21, 8));

      final dose =
          nextPendingDose(await scopedMeds(mine), DateTime(2026, 9, 22, 10));
      expect(dose?.medicationName, 'Lisinopril');
    });
  });

  // -------------------------------------------------------------------------
  // 5. Add Note sheet: Save writes a real org-scoped `careNotes` record.
  // -------------------------------------------------------------------------
  group('dashboard note sheet', () {
    Future<void> pumpSheet(
      WidgetTester tester,
      DocumentReference? careRecipientRef,
    ) async {
      // A tall viewport so the sheet's Save row is on screen.
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            body: DashboardNotesFormWidget(
              authorBg: const Color(0x00000000),
              careRecipientRef: careRecipientRef,
              isPrivate: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Iterable<MapEntry<String, Map<String, dynamic>>> writtenNotes() =>
        fakeFirestore.docs.entries.where((e) => e.key.startsWith('careNotes/'));

    testWidgets('Save creates a careNotes record for the resolved recipient',
        (tester) async {
      fakeAuthPlatform.emitSignedIn(
        uid: 'caregiver-1',
        email: 'caregiver@example.com',
        displayName: 'Test Caregiver',
      );
      final mine = recipient('mine');

      await pumpSheet(tester, mine);
      // The composer starts empty — the old sheet showed a hardcoded demo note.
      expect(find.text('New note'), findsOneWidget);
      expect(find.textContaining('Mom had a small appetite'), findsNothing);

      await tester.enterText(
        find.byType(TextField),
        'Mom ate a full breakfast and took her morning meds.',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final written = writtenNotes().toList();
      expect(written, hasLength(1));
      final data = written.single.value;
      expect(
        data['noteText'],
        'Mom ate a full breakfast and took her morning meds.',
      );
      expect((data['careRecipientRef'] as dynamic).path, mine.path);
      expect(data['createdBy'], 'Test Caregiver');
      expect(data['createdAt'], isNotNull);
      expect(data['noteDateTime'], isNotNull);
    });

    testWidgets('Save with no recipient tells the caregiver instead of writing',
        (tester) async {
      fakeAuthPlatform.emitSignedIn(uid: 'caregiver-1');
      await pumpSheet(tester, null);

      await tester.enterText(find.byType(TextField), 'A note with no patient');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(writtenNotes(), isEmpty);
      expect(
        find.text('Select a care recipient to add a note.'),
        findsOneWidget,
      );
    });

    testWidgets('an empty note is never written', (tester) async {
      fakeAuthPlatform.emitSignedIn(uid: 'caregiver-1');
      await pumpSheet(tester, recipient('mine'));

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(writtenNotes(), isEmpty);
      expect(find.text('Write a note before saving.'), findsOneWidget);
    });
  });
}
