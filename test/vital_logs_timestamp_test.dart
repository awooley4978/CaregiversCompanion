// Compatibility tests for the legacy String-typed `vitalLogs.createdAt` /
// `updatedAt` fields (U6 / audit item O19).
//
// The model keeps its String field type and no stored data changes: a record
// that already holds a String must read back byte-for-byte as it does today.
// The read path is additionally tolerant of a document that holds a real
// Firestore Timestamp (surfaced as a DateTime by mapFromFirestore) — it must
// not throw, because a throw inside queryCollection's safeGet would silently
// DROP the whole vitalLogs document.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/backend/schema/vital_logs_record.dart';

import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initFirebaseForTest();
  });

  setUp(() {
    fakeFirestore.clear();
  });

  test('legacy String createdAt/updatedAt parse exactly as stored', () async {
    fakeFirestore.writeDoc('vitalLogs/legacy', {
      'heartRate': 72,
      'notes': 'legacy row',
      'createdAt': '2026-08-01T10:15:00.000',
      'updatedAt': '2026-08-02T11:30:00.000',
    });

    final record = await VitalLogsRecord.getDocumentOnce(
      VitalLogsRecord.collection.doc('legacy'),
    );

    expect(record.createdAt, '2026-08-01T10:15:00.000');
    expect(record.updatedAt, '2026-08-02T11:30:00.000');
    expect(record.hasCreatedAt(), isTrue);
    expect(record.hasUpdatedAt(), isTrue);
    expect(record.heartRate, 72);
    expect(record.notes, 'legacy row');
  });

  test('a stored Timestamp does not throw and does not drop the document',
      () async {
    fakeFirestore.writeDoc('vitalLogs/with_timestamp', {
      'heartRate': 88,
      'notes': 'timestamp row',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 8, 1, 10, 15)),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 2, 11, 30)),
    });

    final record = await VitalLogsRecord.getDocumentOnce(
      VitalLogsRecord.collection.doc('with_timestamp'),
    );

    // The rest of the record still loads (before the tolerance change the cast
    // threw and the document was dropped entirely).
    expect(record.heartRate, 88);
    expect(record.notes, 'timestamp row');
    // A non-String value reads as absent — the field stays String-typed.
    expect(record.createdAt, '');
    expect(record.updatedAt, '');
    expect(record.hasCreatedAt(), isFalse);
    expect(record.hasUpdatedAt(), isFalse);
  });
}
