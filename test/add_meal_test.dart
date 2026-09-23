// Add Meal save-feedback widget tests (owner live-test round-5, symptom 1:
// "Add meal still can't be saved").
//
// Guards the Add Meal sheet's save path:
//   * with a care recipient and typed values, Save writes a `mealEntries` doc
//     scoped to that recipient (patientRef — the field the create rule gates on)
//     AND carrying the caller's active-group orgId (the field the new mealEntries
//     LIST rule gates the dashboard's live meal query on), then confirms the save
//     ("Meal saved.") and closes the sheet — before this the handler awaited the
//     write and returned, so a silent success, a silent denial and a no-op all
//     looked identical to the caregiver;
//   * with NO recipient, Save prompts and writes nothing;
//   * with no active group context, Save prompts instead of writing a doc the
//     rules would reject;
//   * the sheet body scrolls, so the Save row is reachable (and not clipped) on a
//     short viewport.
// Offline + deterministic against the in-memory Firestore fake (seeded/asserted
// through the app-facing API — see test/firebase_test_setup.dart).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/components/add_meal_widget.dart';
import 'package:new_project/pages/c_daily_dashboard/c_daily_dashboard_widget.dart';
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
    // No recipient selected by default; the selected-recipient tests set one.
    FFAppState().selectedCareRecipient = null;
    // A default active group context so saved meals carry the orgId the rules'
    // LIST read path gates the dashboard's meal query on.
    FFAppState().activeGroupId = 'org_test_1';
  });

  DocumentReference recipient(String id) =>
      FirebaseFirestore.instance.doc('careRecipients/$id');

  /// Pumps the Add Meal sheet the way the dashboard opens it (a modal bottom
  /// sheet), so the pop-on-success and the snackbars behave as they do live.
  Future<void> pumpSheet(
    WidgetTester tester, {
    DocumentReference? patientRef,
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
                    builder: (_) => AddMealWidget(patientRef: patientRef),
                  ),
                  child: const Text('open meal sheet'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open meal sheet'));
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save Meal'));
    await tester.pump();
    await tester.tap(find.text('Save Meal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Iterable<MapEntry<String, Map<String, dynamic>>> writtenMeals() =>
      fakeFirestore.docs.entries.where((e) => e.key.startsWith('mealEntries/'));

  testWidgets('Save writes an org-scoped meal for the passed recipient, '
      'confirms it and closes the sheet', (tester) async {
    final mine = recipient('mine');
    await pumpSheet(tester, patientRef: mine);

    // The Add Meal form: Meal Type dropdown, Meal Name, Amount Eaten, Notes.
    await tester.enterText(find.byType(TextField).at(0), 'Scrambled Eggs');
    await tester.enterText(find.byType(TextField).at(1), '1/2 cup');
    await tester.enterText(find.byType(TextField).at(2), 'Ate well this morning');
    await tapSave(tester);

    final written = writtenMeals().toList();
    expect(written, hasLength(1));
    final data = written.single.value;
    expect(data['mealName'], 'Scrambled Eggs');
    expect(data['amountEaten'], '1/2 cup');
    expect(data['caregiveNote'], 'Ate well this morning');
    // The recipient is the field the create rule gates on...
    expect((data['patientRef'] as dynamic).path, mine.path);
    // ...and orgId is the field the mealEntries LIST rule gates on, which is why
    // the dashboard's live meal query can read this doc without a get().
    expect(data['orgId'], 'org_test_1');
    expect(data['createdAt'], isA<DateTime>());

    // Save feedback (the whole point of symptom 1): a confirmed save...
    expect(find.text('Meal saved.'), findsOneWidget);
    // ...and the sheet closes, so the caregiver lands back on the dashboard.
    expect(find.text('Save Meal'), findsNothing);
  });

  testWidgets('the saved meal reads back through the app-facing query the '
      'dashboard card uses', (tester) async {
    final mine = recipient('mine');
    FFAppState().selectedCareRecipient = mine;
    await pumpSheet(tester, patientRef: mine);

    await tester.enterText(find.byType(TextField).at(0), 'Turkey Sandwich');
    await tapSave(tester);

    // The dashboard's own read path: orgId + patientRef, newest first.
    final loaded = await mealEntriesForRecipient(recipientRef: mine).first;
    expect(loaded, hasLength(1));
    expect(loaded.single.mealName, 'Turkey Sandwich');
    expect(loaded.single.patientRef?.path, mine.path);
  });

  testWidgets('Save with NO recipient prompts and writes nothing',
      (tester) async {
    await pumpSheet(tester);

    await tester.enterText(find.byType(TextField).at(0), 'Soup');
    await tapSave(tester);

    expect(writtenMeals(), isEmpty);
    expect(find.text('Select a care recipient to save this meal.'),
        findsOneWidget);
  });

  testWidgets('Save with NO active group context prompts and writes nothing',
      (tester) async {
    // The rules require orgId on create (the LIST rule gates on it), so saving
    // with no group context must be a clear prompt — never a doc without orgId
    // and never an opaque permission-denied.
    FFAppState().activeGroupId = null;
    final mine = recipient('mine');
    await pumpSheet(tester, patientRef: mine);

    await tester.enterText(find.byType(TextField).at(0), 'Soup');
    await tapSave(tester);

    expect(writtenMeals(), isEmpty);
    expect(find.text('Your care group is not loaded yet. Please try again.'),
        findsOneWidget);
  });

  testWidgets('the Save row stays reachable on a short viewport (the body '
      'scrolls)', (tester) async {
    // A short phone-shaped viewport: the form is taller than the sheet, so a
    // non-scrollable body would clip the Save row (silently in a release build).
    final mine = recipient('mine');
    await pumpSheet(tester,
        patientRef: mine, viewport: const Size(400, 700));

    expect(find.byType(SingleChildScrollView), findsWidgets);
    await tester.enterText(find.byType(TextField).at(0), 'Oatmeal');
    await tapSave(tester);

    expect(writtenMeals(), hasLength(1));
    expect(
      writtenMeals().single.value['mealName'],
      'Oatmeal',
      reason: 'the Save row must be reachable on a short viewport',
    );
  });
}
