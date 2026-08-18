// Security phase 3 — app data scoping tests.
//
// Covers the three required scenarios plus the legacy-doc tolerances:
//
//  (a) the org-scoped careRecipients stream returns ONLY same-org docs
//      (and an EMPTY stream when there is no group context — never an
//      unscoped query)
//  (b) careRecipients CREATE writes orgId from the user's VERIFIED active
//      group (and is refused with OrgAccessDeniedException when membership
//      cannot be verified — never an unverified write)
//  (c) a legacy symptomEntries doc WITHOUT orgId (like the 1 live doc in the
//      backup) does not crash the recipient-scoped read path
//  (d) a legacy careRecipients doc without orgId parses (orgId falls back to
//      ''), so unclaimed docs are invisible-but-crash-free pre-Phase 4
//
// All tests run against the in-memory Firestore fake in
// firebase_test_setup.dart — no network, no emulator, no real backend.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/backend/auth/auth_service.dart';
import 'package:new_project/backend/org/org_service.dart';
import 'package:new_project/backend/schema/care_recipients_record.dart';
import 'package:new_project/backend/schema/symptom_entries_record.dart';

import 'firebase_test_setup.dart';

Future<User> signIn(String uid, {String? email}) async {
  fakeAuthPlatform.emitSignedIn(uid: uid, email: email);
  return FirebaseAuth.instance.currentUser!;
}

/// Provisions the real sign-in path: profile (phase 1) then org membership
/// (phase 2) then the in-memory context cache (auth_service._onSignedIn).
Future<String> provision(String uid, {String? email}) async {
  final user = await signIn(uid, email: email);
  await ensureUserProfile(user);
  final orgId = await ensureOrgMembership(user);
  FFAppState().activeGroupId = orgId;
  return orgId;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initFirebaseForTest();
  });

  setUp(() {
    fakeFirestore.clear();
    FFAppState.reset();
  });

  Map<String, dynamic>? docData(String path) => fakeFirestore.dataAt(path);

  group('careRecipients query scoping (one shared helper)', () {
    test('returns only docs of the active org; legacy docs are invisible',
        () async {
      await provision('u1', email: 'founder@example.com');
      FFAppState().activeGroupId = 'org_u1';

      // Seed: one doc in u1's org, one in another org, one legacy (no orgId).
      await CareRecipientsRecord.collection
          .doc('mine')
          .set(createCareRecipientsRecordData(name: 'Mine', orgId: 'org_u1'));
      await CareRecipientsRecord.collection.doc('theirs').set(
          createCareRecipientsRecordData(name: 'Theirs', orgId: 'org_other'));
      await CareRecipientsRecord.collection
          .doc('legacy')
          .set(createCareRecipientsRecordData(name: 'Legacy'));

      final list = await careRecipientsForActiveGroup().first;

      expect(list.map((r) => r.reference.path), ['careRecipients/mine']);
      expect(list.single.name, 'Mine');
      expect(list.single.orgId, 'org_u1');
    });

    test('empty stream (never an unscoped query) without a group context',
        () async {
      // FFAppState.reset() -> activeGroupId null (signed out / stale).
      await CareRecipientsRecord.collection
          .doc('mine')
          .set(createCareRecipientsRecordData(name: 'Mine', orgId: 'org_u1'));

      final list = await careRecipientsForActiveGroup().first;

      expect(list, isEmpty);
    });

    test('legacy careRecipients doc without orgId parses without crashing',
        () async {
      // Mirrors the 2 live backup docs (no orgId until the owner claims them).
      await CareRecipientsRecord.collection
          .doc('legacy1')
          .set(createCareRecipientsRecordData(name: 'MW'));

      final snapshot = await CareRecipientsRecord.collection
          .doc('legacy1')
          .get();
      final record = CareRecipientsRecord.fromSnapshot(snapshot);

      expect(record.name, 'MW');
      expect(record.orgId, ''); // null-safe fallback, no crash
      expect(record.hasOrgId(), isFalse);
    });
  });

  group('careRecipients create (verified orgId)', () {
    test('create writes orgId = the user\'s verified active group', () async {
      await provision('u1', email: 'founder@example.com');

      await createCareRecipientForActiveGroup(
        uid: 'u1',
        data: createCareRecipientsRecordData(
          name: 'Ada',
          primaryCondition: 'Diabetes',
        ),
      );

      // Exactly one careRecipients doc, carrying the verified orgId.
      final created = fakeFirestore.docs.entries
          .where((e) => RegExp(r'^careRecipients/[^/]+$').hasMatch(e.key))
          .toList();
      expect(created.length, 1);
      expect(created.single.value['orgId'], 'org_u1');
      expect(created.single.value['Name'], 'Ada');
      expect(created.single.value['PrimaryCondition'], 'Diabetes');
    });

    test('refused when the profile claims an org but membership is gone '
        '(D1: never write unverified)', () async {
      // u9's profile points at org_u1 but no member doc exists (revoked /
      // stale context).
      fakeFirestore.docs['users/u9'] = {
        'uid': 'u9',
        'activeGroupId': 'org_u1',
      };

      await expectLater(
        createCareRecipientForActiveGroup(
          uid: 'u9',
          data: createCareRecipientsRecordData(name: 'Ghost'),
        ),
        throwsA(isA<OrgAccessDeniedException>()),
      );
      expect(
        fakeFirestore.docs.keys.any((p) => p.startsWith('careRecipients/')),
        isFalse,
      );
    });

    test('refused when the user has no group context at all', () async {
      await expectLater(
        createCareRecipientForActiveGroup(
          uid: 'u9',
          data: createCareRecipientsRecordData(name: 'Ghost'),
        ),
        throwsA(isA<OrgAccessDeniedException>()),
      );
      expect(
        fakeFirestore.docs.keys.any((p) => p.startsWith('careRecipients/')),
        isFalse,
      );
    });
  });

  group('symptomEntries legacy tolerance (recipient-scoped read path)', () {
    test('legacy doc without orgId reads fine through the scoped stream',
        () async {
      await provision('u1', email: 'founder@example.com');
      final recipientRef = FirebaseFirestore.instance.doc('careRecipients/r1');
      FFAppState().selectedCareRecipient = recipientRef;

      // Seed the legacy shape: patientRef only, NO orgId — exactly like the
      // 1 live doc in the backup (design §5.1 Path B).
      await SymptomEntriesRecord.collection.doc('s1').set(
            createSymptomEntriesRecordData(
              symptomName: 'Headache',
              note: 'Legacy note',
              timeLogged: DateTime.utc(2026, 6, 25, 19, 30),
              patientRef: recipientRef,
              isResolved: true,
            ),
          );
      // A second entry for ANOTHER recipient must NOT leak in.
      await SymptomEntriesRecord.collection.doc('s2').set(
            createSymptomEntriesRecordData(
              symptomName: 'Other',
              patientRef:
                  FirebaseFirestore.instance.doc('careRecipients/other'),
              isResolved: false,
            ),
          );

      final list = await symptomEntriesForSelectedRecipient().first;

      expect(list.length, 1);
      expect(list.single.symptomName, 'Headache');
      expect(list.single.patientRef?.path, 'careRecipients/r1');
      // No orgId anywhere in the read path — the record class has no orgId
      // field and the stream never throws for the legacy doc.
      expect(() => SymptomEntriesRecord.fromSnapshot(
              await SymptomEntriesRecord.collection.doc('s1').get()),
          returnsNormally);
    });

    test('empty stream when no recipient is selected (never isEqualTo: null)',
        () async {
      await SymptomEntriesRecord.collection
          .doc('s1')
          .set(createSymptomEntriesRecordData(symptomName: 'Headache'));

      final list = await symptomEntriesForSelectedRecipient().first;

      expect(list, isEmpty);
    });
  });
}
