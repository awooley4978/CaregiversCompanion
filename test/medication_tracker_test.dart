// Medication tracker save->query->group linkage tests (Audit-fix Part1 Unit3
// CLOSEOUT).
//
// Pins the two owner-reported Add Medication bugs so they cannot regress:
//   (1) A medication saved by the Add form (the EXACT create payload the form
//       writes in add_medication_widget.dart _save()) is found by the tracker's
//       LIVE query — the same `where careRecipientRef == selected` filter the
//       tracker stream uses. This is the save→tracker contract: a saved med
//       MUST appear in the tracker, never silently dropped.
//   (2) Morning/Afternoon grouping (`isMedicationMorning`) places the saved med
//       in the correct section, including the V1 signature (scheduledTime unset,
//       timeOfDay is the schedule value) the Add form produces.
// Offline + deterministic against the in-memory Firestore fake.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/backend/backend.dart';
import 'package:new_project/backend/schema/medications_record.dart';
import 'package:new_project/flutter_flow/flutter_flow_util.dart';
import 'package:new_project/pages/d_medication_tracker/d_medication_tracker_widget.dart';
import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initFirebaseForTest();
  });
  setUp(() {
    fakeFirestore.clear();
    // The caller's active group context. The tracker's live query filters on it
    // (see below) and the Add form writes it onto the doc.
    FFAppState().activeGroupId = 'org_test_1';
  });

  // Mirrors add_medication_widget.dart _save(): writes a medications doc
  // scoped to the SELECTED recipient with the exact fields the tracker reads,
  // including the caller's active-group orgId.
  Future<void> saveMedication({
    required String name,
    String? dose,
    String? directions,
    String timeOfDay = 'Morning',
  }) async {
    final recipient =
        FirebaseFirestore.instance.doc('carerecipients/r1');
    await MedicationsRecord.collection.doc().set({
      ...createMedicationsRecordData(
        careRecipientRef: recipient,
        medicationName: name,
        dose: dose,
        directions: directions,
        timeOfDay: timeOfDay,
        scheduledTime: null,
        status: 'PENDING',
        active: true,
        refillNeeded: false,
        taken: false,
      ),
      ...mapToFirestore({
        'createdAt': FieldValue.serverTimestamp(),
      }),
      // The org the Phase-4 medications LIST rule gates on
      // (canListRecipientsInOrg(resource.data.orgId)).
      'orgId': FFAppState().activeGroupId,
    });
  }

  test('a saved medication is returned by the tracker query (save->tracker)',
      () async {
    await saveMedication(
      name: 'Lisinopril',
      dose: '10mg - 1 tablet',
      directions: 'Take with food',
      timeOfDay: 'Morning',
    );

    // The tracker's live stream filter, used verbatim:
    //   queryMedicationsRecord(
    //     where('orgId') == activeGroupId
    //       && where('careRecipientRef') == selected)
    // BOTH filters are required: the orgId filter is what makes the field
    // available to the Phase-4 LIST rule during query evaluation.
    final r1 = FirebaseFirestore.instance.doc('carerecipients/r1');
    final result = await queryMedicationsRecordOnce(
      queryBuilder: (q) => q
          .where('orgId', isEqualTo: FFAppState().activeGroupId)
          .where('careRecipientRef', isEqualTo: r1),
    );

    expect(result, hasLength(1));
    expect(result.first.medicationName, 'Lisinopril');
    expect(result.first.dose, '10mg - 1 tablet');
    expect(result.first.directions, 'Take with food');
    expect(result.first.timeOfDay, 'Morning');
    expect(result.first.status, 'PENDING');
    expect(result.first.taken, isFalse);
    expect(result.first.scheduledTime, isNull);
    // Scoped to the selected recipient — the field the tracker gates on.
    expect(result.first.careRecipientRef?.path, 'carerecipients/r1');
  });

  test('the tracker query does NOT return a med scoped to another recipient',
      () async {
    await saveMedication(name: 'Lisinopril');
    final other = FirebaseFirestore.instance.doc('carerecipients/other');
    final result = await queryMedicationsRecordOnce(
      queryBuilder: (q) => q
          .where('orgId', isEqualTo: FFAppState().activeGroupId)
          .where('careRecipientRef', isEqualTo: other),
    );
    expect(result, isEmpty);
  });

  test('the tracker query does NOT return another org\'s med', () async {
    await saveMedication(name: 'Lisinopril');
    final r1 = FirebaseFirestore.instance.doc('carerecipients/r1');
    // Same recipient, different org context: the orgId filter keeps the
    // caller's visible set to their own org (and satisfies the LIST rule, which
    // gates on the doc's orgId being a real membership).
    final result = await queryMedicationsRecordOnce(
      queryBuilder: (q) => q
          .where('orgId', isEqualTo: 'org_someone_else')
          .where('careRecipientRef', isEqualTo: r1),
    );
    expect(result, isEmpty);
  });

  group('isMedicationMorning grouping (Morning/Afternoon sections)', () {
    Future<MedicationsRecord> recordFrom(Map<String, dynamic> data) async {
      final doc = data;
      final ref = FirebaseFirestore.instance.collection('medications').doc();
      await ref.set(doc);
      return MedicationsRecord.getDocumentFromData(doc, ref);
    }

    test('V1 Morning med (scheduledTime unset) groups to Morning', () async {
      final med = await recordFrom({
        'timeOfDay': 'Morning',
        'medicationName': 'A',
      });
      expect(isMedicationMorning(med), isTrue);
    });

    test('V1 Afternoon med (scheduledTime unset) groups to Afternoon', () async {
      final med = await recordFrom({
        'timeOfDay': 'Afternoon',
        'medicationName': 'B',
      });
      expect(isMedicationMorning(med), isFalse);
    });

    test('legacy med with pre-noon clock time groups to Morning', () async {
      final med = await recordFrom({
        'timeOfDay': '',
        'scheduledTime': DateTime(2026, 8, 31, 8, 0),
        'medicationName': 'C',
      });
      expect(isMedicationMorning(med), isTrue);
    });

    test('legacy med with post-noon clock time groups to Afternoon', () async {
      final med = await recordFrom({
        'timeOfDay': '',
        'scheduledTime': DateTime(2026, 8, 31, 14, 0),
        'medicationName': 'D',
      });
      expect(isMedicationMorning(med), isFalse);
    });
  });
}
