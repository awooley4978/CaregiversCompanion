// Medication "Taken" control tests (Audit-fix Part1 Unit1).
//
// Pins the two owner-required correctness fixes offline against the in-memory
// Firestore + Auth fakes:
//   (1) DAY ROLLOVER (render): a med renders as Taken/PENDING based on whether
//       its `takenAt` falls on the CURRENT local calendar date — NOT the
//       persisted `taken` boolean alone. A stale `taken:true` from a previous
//       day (or a missing timestamp) renders as Pending and does not count
//       toward today's adherence; only a `takenAt` on today renders Taken.
//   (2) UNTOGGLE (write): untoggling Taken -> Pending writes `taken:false`,
//       `status:'PENDING'` and CLEARS `takenAt` via FieldValue.delete() — it
//       must NOT write a fresh server timestamp, so the stored value is gone
//       and the Flutter record reads `takenAt` as null.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/backend/schema/medications_record.dart';
import 'package:new_project/pages/d_medication_tracker/d_medication_tracker_widget.dart';
import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initFirebaseForTest();
  });
  setUp(() {
    fakeFirestore.clear();
  });

  group('day rollover (effective per-day taken state)', () {
    test('null takenAt -> not taken today (Pending)', () {
      expect(isTakenForDay(null, DateTime(2026, 8, 30, 9, 0)), isFalse);
    });

    test('takenAt on a PREVIOUS local date -> not taken today (Pending)', () {
      final now = DateTime(2026, 8, 30, 9, 0);
      final yesterday = DateTime(2026, 8, 29, 8, 0);
      expect(isTakenForDay(yesterday, now), isFalse);
    });

    test('takenAt on the CURRENT local date -> taken', () {
      final now = DateTime(2026, 8, 30, 9, 0);
      final todayMorning = DateTime(2026, 8, 30, 6, 30);
      expect(isTakenForDay(todayMorning, now), isTrue);
    });

    test('same calendar day at any hour still counts as taken today', () {
      final now = DateTime(2026, 8, 30, 23, 59);
      final early = DateTime(2026, 8, 30, 0, 1);
      expect(isTakenForDay(early, now), isTrue);
    });

    test('last day of month rolls over correctly to the next month', () {
      // taken 2026-08-31 (a day ago) should NOT count on 2026-09-01.
      final now = DateTime(2026, 9, 1, 8, 0);
      final prevMonth = DateTime(2026, 8, 31, 9, 0);
      expect(isTakenForDay(prevMonth, now), isFalse);
      // taken on 2026-09-01 should count on 2026-09-01.
      final sameDay = DateTime(2026, 9, 1, 7, 0);
      expect(isTakenForDay(sameDay, now), isTrue);
    });

    test('a persisted taken:true WITHOUT a timestamp counts as not-taken today',
        () async {
      final ref = FirebaseFirestore.instance
          .collection('medications')
          .doc('stale');
      // Stale data a previous day left behind: taken:true but no takenAt.
      await ref.set({
        'taken': true,
        'status': 'TAKEN',
        'medicationName': 'Lisinopril',
      });
      final snap = await ref.get();
      final record =
          MedicationsRecord.getDocumentFromData(snap.data()!, ref);
      // The boolean says taken, but there is no timestamp -> must NOT count.
      expect(record.taken, isTrue);
      expect(isTakenForDay(record.takenAt, DateTime.now()), isFalse);
    });
  });

  group('untoggle write semantics (clear takenAt, no new timestamp)', () {
    test('untoggle writes taken:false/status:PENDING and clears takenAt',
        () async {
      final ref = FirebaseFirestore.instance
          .collection('medications')
          .doc('m1');
      await ref.set({
        'taken': true,
        'status': 'TAKEN',
        'takenAt': DateTime(2026, 8, 30, 8, 0),
        'medicationName': 'Lisinopril',
      });

      await ref.update(medicationTakenUpdate(taken: false));

      final stored = fakeFirestore.dataAt('medications/m1')!;
      expect(stored['taken'], isFalse);
      expect(stored['status'], 'PENDING');
      // takenAt must be GONE (deleted) on untoggle — never refreshed with a
      // new timestamp.
      expect(stored.containsKey('takenAt'), isFalse);
      expect(stored['takenAt'], isNull);

      // The Flutter record parsed from the stored doc reads takenAt as null.
      final snap = await ref.get();
      final record =
          MedicationsRecord.getDocumentFromData(snap.data()!, ref);
      expect(record.taken, isFalse);
      expect(record.status, 'PENDING');
      expect(record.takenAt, isNull);
      expect(record.hasTakenAt(), isFalse);
    });

    test('marking taken writes taken:true/status:TAKEN and stamps a timestamp',
        () async {
      final ref = FirebaseFirestore.instance
          .collection('medications')
          .doc('m2');
      await ref.set({
        'taken': false,
        'status': 'PENDING',
        'medicationName': 'Metformin',
      });

      await ref.update(medicationTakenUpdate(taken: true));

      final stored = fakeFirestore.dataAt('medications/m2')!;
      expect(stored['taken'], isTrue);
      expect(stored['status'], 'TAKEN');
      // A new timestamp is stamped only when marking Taken.
      expect(stored['takenAt'], isA<DateTime>());
    });
  });
}
