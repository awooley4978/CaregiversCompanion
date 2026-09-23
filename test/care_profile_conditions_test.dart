// Add Care Profile condition chips (owner-approved 2026-09-23).
//
// The chips used to be static decoration — the component had no tap handler —
// and the page's Save never wrote the recipient's Conditions field, so nothing
// the caregiver picked was persisted. These tests pin the fix:
//   (1) tapping a chip toggles its selection, and that selection is readable
//       from the chip's own widget model — which is how the Add Care Profile
//       page reads it back at Save time (the same pattern the Tracking Modules
//       use via `switchModel.switchValue`);
//   (2) the saved careRecipients doc carries the selected condition names in
//       the 'Conditions' list field (schema read path:
//       CareRecipientsRecord.conditions).
//
// Offline + deterministic against the in-memory Firebase fakes: the doc is
// seeded/read through the app-facing API (see
// skills/caregivers-companion-test-fake) — never by parsing a raw dataAt map
// into a record.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/backend/schema/care_recipients_record.dart';
import 'package:new_project/components/condition_chip/condition_chip_model.dart';
import 'package:new_project/components/condition_chip/condition_chip_widget.dart';
import 'package:new_project/flutter_flow/flutter_flow_model.dart';
import 'package:new_project/pages/b_care_profile_setup/b_care_profile_setup_widget.dart';
import 'firebase_test_setup.dart';

/// A page chip model carrying nothing but its current selection.
ConditionChipModel chip(bool selected) =>
    ConditionChipModel()..selectedValue = selected;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initFirebaseForTest();
  });
  setUp(() {
    fakeFirestore.clear();
  });

  // Renders one chip the way the page does: the page owns the model and passes
  // it down with wrapWithModel, so the widget reads/writes that same instance.
  Future<ConditionChipModel> pumpChip(
    WidgetTester tester, {
    required bool selected,
  }) async {
    final chipModel = ConditionChipModel();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: wrapWithModel(
              model: chipModel,
              updateCallback: () {},
              child: ConditionChipWidget(
                label: 'Dementia',
                selected: selected,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return chipModel;
  }

  testWidgets('an unselected chip selects on tap and deselects on the next tap',
      (tester) async {
    final chipModel = await pumpChip(tester, selected: false);

    // Seeded from the page's `selected` parameter: shows the add affordance.
    expect(chipModel.selectedValue, isFalse);
    expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

    await tester.tap(find.text('Dementia'));
    await tester.pump();

    // Selected: the chip looks selected (check icon) AND the page will save it.
    expect(chipModel.selectedValue, isTrue);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline_rounded), findsNothing);

    await tester.tap(find.text('Dementia'));
    await tester.pump();

    expect(chipModel.selectedValue, isFalse);
    expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
  });

  testWidgets('a chip that starts selected deselects on tap', (tester) async {
    final chipModel = await pumpChip(tester, selected: true);

    expect(chipModel.selectedValue, isTrue);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.tap(find.text('Dementia'));
    await tester.pump();

    expect(chipModel.selectedValue, isFalse);
  });

  group('save payload', () {
    test('saves the selected chips in page order, plus the typed Other text',
        () {
      final chips = [
        chip(true), // Diabetes
        chip(false), // Hypertension
        chip(false), // Heart Failure
        chip(false), // Dementia
        chip(true), // Limited Mobility
        chip(true), // Fall Risk
        chip(false), // Wound Care
      ];

      expect(
        careProfileConditionsToSave(chips, otherCondition: "  Parkinson's "),
        ['Diabetes', 'Limited Mobility', 'Fall Risk', "Parkinson's"],
      );
    });

    test('no chips selected and no Other text saves an empty list', () {
      final chips = List.generate(7, (_) => chip(false));

      expect(careProfileConditionsToSave(chips), isEmpty);
      expect(careProfileConditionsToSave(chips, otherCondition: '   '),
          isEmpty);
    });

    test('the typed Other condition is never saved twice', () {
      final chips = List.generate(7, (_) => chip(false));

      expect(
        careProfileConditionsToSave(chips, otherCondition: 'Dementia'),
        ['Dementia'],
      );
    });
  });

  test('a saved care profile reads its conditions back', () async {
    // The payload the page's Save builds (createCareRecipientsRecordData).
    await CareRecipientsRecord.collection.doc('r1').set(
      createCareRecipientsRecordData(
        name: 'Ada',
        conditions: careProfileConditionsToSave(
          [
            chip(true), // Diabetes
            chip(false),
            chip(false),
            chip(false),
            chip(true), // Limited Mobility
            chip(false),
            chip(false),
          ],
          otherCondition: "Parkinson's",
        ),
      ),
    );

    // The exact Firestore field the schema maps to.
    expect(fakeFirestore.dataAt('careRecipients/r1')!['Conditions'],
        ['Diabetes', 'Limited Mobility', "Parkinson's"]);

    // App-facing read: the record parser decodes the document.
    final saved = await CareRecipientsRecord.getDocumentOnce(
      FirebaseFirestore.instance.doc('careRecipients/r1'),
    );
    expect(saved.name, 'Ada');
    expect(saved.conditions, ['Diabetes', 'Limited Mobility', "Parkinson's"]);
  });
}
