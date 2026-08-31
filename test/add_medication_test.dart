// Add Medication create-flow widget tests (Audit-fix Part1 Unit3).
//
// Guards the newly-wired "Add Medication" create form:
//   * With a care recipient selected + a name entered, Save writes a
//     `medications` doc scoped to the SELECTED recipient's careRecipientRef
//     (the field the Phase-4 rules and the tracker's live stream gate on),
//     pre-set to a PENDING/not-taken state so it can be live-tested with the
//     "Taken" toggle.
//   * With NO recipient selected, Save prompts the user and writes nothing.
//   * With no medication name, Save blocks the write (an unnamed med would
//     render only as "Untitled").
// Offline + deterministic against the in-memory Firestore fake.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/components/add_medication/add_medication_widget.dart';
import 'package:new_project/flutter_flow/flutter_flow_util.dart';
import 'package:provider/provider.dart';
import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initFirebaseForTest();
  });

  setUp(() {
    fakeFirestore.clear();
    // No recipient selected by default; the selected-recipient test sets one.
    FFAppState().selectedCareRecipient = null;
  });

  Future<void> pumpForm(WidgetTester tester) async {
    // The widget reads FFAppState via context.watch (mirroring AddMealWidget);
    // the real app provides it in main(). Provide the singleton here too.
    await tester.pumpWidget(
      ChangeNotifierProvider<FFAppState>.value(
        value: FFAppState(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AddMedicationWidget(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save Medication'));
    await tester.pump();
    await tester.tap(find.text('Save Medication'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Map<String, dynamic>? soleMedicationDoc() {
    final meds = fakeFirestore.docs.entries
        .where((e) => e.key.startsWith('medications/'))
        .toList();
    if (meds.isEmpty) {
      return null;
    }
    expect(meds, hasLength(1), reason: 'expected exactly one medication doc');
    return meds.first.value;
  }

  testWidgets('Save writes a medications doc for the SELECTED recipient',
      (tester) async {
    FFAppState().selectedCareRecipient =
        FirebaseFirestore.instance.doc('carerecipients/r1');
    await pumpForm(tester);

    await tester.enterText(find.byType(TextField).at(0), 'Lisinopril');
    await tester.enterText(find.byType(TextField).at(1), '10mg - 1 tablet');
    await tester.enterText(find.byType(TextField).at(2), 'Take with food');
    await tapSave(tester);

    final data = soleMedicationDoc();
    expect(data, isNotNull);
    expect(data!['medicationName'], 'Lisinopril');
    expect(data['dose'], '10mg - 1 tablet');
    expect(data['directions'], 'Take with food');
    // Default Time of Day is Morning, and it is the ACTUAL V1 schedule value.
    expect(data['timeOfDay'], 'Morning');
    // V1 captures no clock time — scheduledTime must be left unset (absent/null),
    // never synthesized as a representative 08:00/14:00 from the section choice.
    expect(data['scheduledTime'], isNull);
    // A freshly-created med is PENDING / not yet taken (so the "Taken" toggle
    // can be live-tested against it without seed data).
    expect(data['status'], 'PENDING');
    expect(data['taken'], isFalse);
    expect(data['active'], isTrue);
    expect(data['refillNeeded'], isFalse);
    expect(data['createdAt'], isA<DateTime>());
    // The doc is scoped to the selected recipient — this is the field the
    // tracker's stream (and the Phase-4 rules) gate on.
    expect((data['careRecipientRef'] as dynamic).path, 'carerecipients/r1');
  });

  testWidgets('Save with NO recipient selected prompts and writes nothing',
      (tester) async {
    await pumpForm(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Metformin');
    await tapSave(tester);

    expect(soleMedicationDoc(), isNull);
    expect(find.text('Select a care recipient to add this medication.'),
        findsOneWidget);
  });

  testWidgets('Save with NO medication name blocks the write', (tester) async {
    FFAppState().selectedCareRecipient =
        FirebaseFirestore.instance.doc('carerecipients/r1');
    await pumpForm(tester);

    await tapSave(tester);

    expect(soleMedicationDoc(), isNull);
    expect(find.text('Enter a medication name.'), findsOneWidget);
  });

  testWidgets('blank fields render BLANK — the SlotValue sentinel is never '
      'displayed as field text (owner bug 1)', (tester) async {
    FFAppState().selectedCareRecipient =
        FirebaseFirestore.instance.doc('carerecipients/r1');
    await pumpForm(tester);

    // The FlutterFlow template seeded empty fields with the literal
    // `SlotValue($meal_name)` placeholder; it must never show in the form.
    expect(find.textContaining('SlotValue'), findsNothing);
    // All three text fields start empty (only label + hint, no placeholder
    // text in the controller), so the form reads as a normal blank form.
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields, hasLength(3));
    for (final field in fields) {
      expect(field.controller?.text ?? '', isEmpty,
          reason: 'a blank form field must render blank, not a sentinel');
    }
  });

  testWidgets('a saved medication NEVER persists the SlotValue sentinel as a '
      'name (owner bug 1)', (tester) async {
    FFAppState().selectedCareRecipient =
        FirebaseFirestore.instance.doc('carerecipients/r1');
    await pumpForm(tester);

    await tester.enterText(find.byType(TextField).at(0), 'Atorvastatin');
    await tapSave(tester);

    final data = soleMedicationDoc();
    expect(data, isNotNull);
    expect(data!['medicationName'], 'Atorvastatin');
    expect('${data['medicationName']}'.contains('SlotValue'), isFalse);
    expect('${data['medicationName']}'.contains('\$meal_name'), isFalse);
    // Blank dose/directions are stored as null/absent — never the sentinel.
    expect(data.containsKey('dose'), isFalse);
    expect(data['dose'], isNull);
    expect(data.containsKey('directions'), isFalse);
    expect(data['directions'], isNull);
  });
}
