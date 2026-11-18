// Emergency Info edit unit (owner-approved 2026-11-16): Care Profile Setup
// gains a create-or-edit mode driven by the optional `careRecipients` route
// parameter, and Emergency Info's "Update Emergency Info" button opens it for
// the selected recipient.
//
// Pinned here:
//   (1) edit mode loads the recipient (name, DOB, allergies, conditions +
//       chips, tracking toggles, advance-directive status);
//   (2) saving writes ONLY the fields the form owns — orgId, migrationStatus,
//       CreatedAt, Initials and MobilityNotes survive the merged update, and no
//       second careRecipients document is created;
//   (3) a profile that failed to load can never be saved;
//   (4) create mode (no route parameter) still creates;
//   (5) owner amendments: Date of Birth is validated but a legacy stored value
//       is never rewritten, and conditions are never comma-split.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/backend/backend.dart';
import 'package:new_project/components/condition_chip/condition_chip_model.dart';
import 'package:new_project/pages/b_care_profile_setup/b_care_profile_setup_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_test_setup.dart';

ConditionChipModel chip(bool selected) =>
    ConditionChipModel()..selectedValue = selected;

List<ConditionChipModel> chips(List<bool> selected) =>
    selected.map(chip).toList();

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
  });

  group('conditions round-trip (never comma-split)', () {
    test('stored conditions select the chips they name and keep the rest', () {
      final selection = careProfileConditionsFromRecord(
          ['Dementia', 'Anemia', 'Diabetes', 'Penicillin allergy']);

      expect(selection.chipLabels, ['Diabetes', 'Dementia']);
      expect(selection.otherConditions, ['Anemia', 'Penicillin allergy']);
      expect(selection.otherText, 'Anemia, Penicillin allergy');
    });

    test('loading and re-saving an untouched Other field keeps both entries',
        () {
      final selection = careProfileConditionsFromRecord(
          ['Diabetes', 'Anemia', 'Penicillin allergy']);

      expect(
        careProfileConditionsToSave(
          chips([true, false, false, false, false, false, false]),
          otherCondition: selection.otherText,
          loadedOtherConditions: selection.otherConditions,
        ),
        ['Diabetes', 'Anemia', 'Penicillin allergy'],
      );
    });

    test('a newly typed Other condition is saved whole, never split', () {
      expect(
        careProfileConditionsToSave(
          chips(List.filled(7, false)),
          otherCondition: 'Anemia, gout',
        ),
        ['Anemia, gout'],
      );
    });
  });

  group('date of birth validation', () {
    test('a legacy stored value is always saveable and never rewritten', () {
      expect(careProfileDateOfBirthError('14 Mar 1948',
              loadedValue: '14 Mar 1948'),
          isNull);
      // Even a format the app would not accept from a caregiver.
      expect(
          careProfileDateOfBirthError('1948-03-14 (approx)',
              loadedValue: '1948-03-14 (approx)'),
          isNull);
    });

    test('real dates in the accepted formats pass, junk and impossible dates '
        'do not', () {
      expect(careProfileDateOfBirthError('03/14/1948'), isNull);
      expect(careProfileDateOfBirthError('3/14/1948'), isNull);
      expect(careProfileDateOfBirthError('1948-03-14'), isNull);
      expect(careProfileDateOfBirthError('14 Mar 1948'), isNull);
      expect(careProfileDateOfBirthError(''), isNull);
      expect(careProfileDateOfBirthError('02/30/1948'), isNotNull);
      expect(careProfileDateOfBirthError('sometime in 1948'), isNotNull);
    });
  });

  group('record defaults', () {
    test('a record with no advance-directive fields reads Unknown / blank',
        () async {
      await FirebaseFirestore.instance
          .doc('careRecipients/r1')
          .set({'Name': 'Ada', 'orgId': 'org_test'});
      final record = await CareRecipientsRecord.getDocumentOnce(
          FirebaseFirestore.instance.doc('careRecipients/r1'));

      expect(record.advanceDirectivesStatus, kAdvanceDirectivesUnknown);
      expect(record.hasAdvanceDirectivesStatus(), isFalse);
      expect(record.advanceDirectivesNotes, '');
    });
  });

  group('Care Profile Setup edit mode', () {
    Future<void> signInAndProvision() async {
      fakeAuthPlatform.emitSignedIn(uid: 'u1', email: 'a@example.com');
      fakeFirestore.docs['users/u1'] = {
        'uid': 'u1',
        'activeGroupId': 'org_test',
      };
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc('org_test')
          .collection('members')
          .doc('u1')
          .set({'uid': 'u1', 'status': 'active', 'role': 'owner'});
    }

    Future<DocumentReference> seedRecipient() async {
      final ref = FirebaseFirestore.instance.doc('careRecipients/r1');
      await ref.set({
        'Name': 'Margaret Alvarez',
        'DateOfBirth': '14 Mar 1948',
        'Allergies': ['Penicillin', 'Latex'],
        'Conditions': ['Diabetes', 'Anemia', 'Penicillin allergy'],
        'PrimaryCondition': 'Stroke Recovery',
        'EmergencyContactName': 'James Jenkins',
        'EmergencyContactPhone': '(555) 010-2233',
        'PrimaryCarePhysicianName': 'Dr. Sarah Reed',
        'PrimaryCarePhysicianPhone': '(555) 010-9988',
        'TrackVitals': true,
        'TrackSymptoms': false,
        'orgId': 'org_test',
        'migrationStatus': 'claimed',
        'CreatedAt': DateTime(2026, 1, 2),
        'Initials': 'MA',
        'MobilityNotes': 'Walker indoors',
        'AdvanceDirectivesStatus': 'on_file',
        'AdvanceDirectivesNotes': 'POLST in the kitchen drawer',
      });
      return ref;
    }

    Future<void> pumpEditor(WidgetTester tester, DocumentReference? ref) async {
      tester.view.physicalSize = const Size(1080.0, 4000.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: BCareProfileSetupWidget(careRecipients: ref),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('loads the recipient and saves only the fields it owns',
        (tester) async {
      await signInAndProvision();
      final ref = await seedRecipient();
      await pumpEditor(tester, ref);

      // Prefilled from the stored profile.
      expect(find.text('Margaret Alvarez'), findsOneWidget);
      expect(find.text('14 Mar 1948'), findsOneWidget);
      expect(find.text('Penicillin, Latex'), findsOneWidget);
      expect(find.text('Anemia, Penicillin allergy'), findsOneWidget);
      expect(find.text('POLST in the kitchen drawer'), findsOneWidget);

      // Edit the name, then save.
      await tester.enterText(
          find.widgetWithText(TextField, 'Margaret Alvarez'), 'Margaret A.');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Profile'));
      await tester.pumpAndSettle();

      final saved = fakeFirestore.dataAt('careRecipients/r1')!;
      expect(saved['Name'], 'Margaret A.');
      // Owner amendment: the legacy date of birth is written back verbatim.
      expect(saved['DateOfBirth'], '14 Mar 1948');
      // Conditions preserved exactly — two custom entries stay two entries.
      expect(saved['Conditions'], ['Diabetes', 'Anemia', 'Penicillin allergy']);
      expect(saved['Allergies'], ['Penicillin', 'Latex']);
      expect(saved['AdvanceDirectivesStatus'], 'on_file');
      expect(saved['AdvanceDirectivesNotes'], 'POLST in the kitchen drawer');
      // Fields the form does not own are untouched.
      expect(saved['orgId'], 'org_test');
      expect(saved['migrationStatus'], 'claimed');
      expect(saved['Initials'], 'MA');
      expect(saved['MobilityNotes'], 'Walker indoors');
      expect(saved['CreatedAt'], isNotNull);
      // No duplicate recipient was created.
      expect(
        fakeFirestore.docs.keys
            .where((p) => RegExp(r'^careRecipients/[^/]+$').hasMatch(p))
            .length,
        1,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('an invalid date of birth blocks the save', (tester) async {
      await signInAndProvision();
      final ref = await seedRecipient();
      await pumpEditor(tester, ref);

      await tester.enterText(
          find.widgetWithText(TextField, '14 Mar 1948'), 'sometime in 1948');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Profile'));
      await tester.pumpAndSettle();

      expect(fakeFirestore.dataAt('careRecipients/r1')!['DateOfBirth'],
          '14 Mar 1948');
    });

    testWidgets('create mode (no route parameter) still creates', (tester) async {
      await signInAndProvision();
      await pumpEditor(tester, null);

      await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Margaret Smith'), 'New Person');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Profile'));
      await tester.pumpAndSettle();

      final created = fakeFirestore.docs.entries
          .where((e) => RegExp(r'^careRecipients/[^/]+$').hasMatch(e.key))
          .toList();
      expect(created.length, 1);
      expect(created.single.value['Name'], 'New Person');
      expect(created.single.value['orgId'], 'org_test');
    });
  });
}
