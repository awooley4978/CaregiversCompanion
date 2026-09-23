// Section header ACTION wiring (owner live-test round-5, symptom 3: "multiple
// 'Add New' on the page but none are clickable").
//
// Root cause: `SectionHeaderWidget` had no action callback at all. The exported
// component built its trailing ghost ButtonWidget with no `onPressed` and no
// surrounding InkWell, so EVERY section header that passed an action label
// ('Log New', 'View Schedule', ...) rendered a button that looked tappable and
// did nothing. Two of the dashboard's headers passed `action: ''`, which
// `valueOrDefault` treats as absent — so they rendered a dead button labelled
// with the component's 'Log New' default, a label no section ever asked for.
//
// These tests pin the contract the Daily Dashboard now relies on:
//   * an `onAction` callback renders the header's button AND fires it on tap
//     (this is what makes the Medications 'View Schedule' -> Medication Tracker
//     and Meals 'Add Meal' -> Add Meal sheet wiring work);
//   * with no callback the header renders NO button at all — no inert
//     affordance, and in particular no misleading 'Log New' for a blank label
//     (Morning Vitals / the Symptoms header have no create flow yet, so they
//     must not advertise one);
//   * a header whose action is wired the way the Meals header is wired opens
//     the SAME Add Meal sheet the section's own card and 'Add Meal' button open
//     (`openAddMealSheet`), targeted at the recipient the caller resolved.
//
// Rendering the whole CDailyDashboardWidget in a harness is not possible (it
// trips a pre-existing, unrelated carechecklist orderBy TypeError — see
// dashboard_navmenu_actions_test.dart), so the component contract and the
// shared sheet helper are pinned here; the dashboard's own wiring is covered by
// `flutter analyze` in CI.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/components/add_meal_widget.dart';
import 'package:new_project/components/button/button_widget.dart';
import 'package:new_project/components/section_header/section_header_widget.dart';
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
    FFAppState().selectedCareRecipient = null;
    FFAppState().activeGroupId = 'org_test_1';
  });

  DocumentReference recipient(String id) =>
      FirebaseFirestore.instance.doc('careRecipients/$id');

  /// Pumps one section header on its own — the component every dashboard
  /// section renders.
  Future<void> pumpHeader(
    WidgetTester tester, {
    required String title,
    String? action,
    VoidCallback? onAction,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<FFAppState>.value(
        value: FFAppState(),
        child: MaterialApp(
          home: Scaffold(
            body: SectionHeaderWidget(
              title: title,
              action: action,
              onAction: onAction,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('SectionHeaderWidget action button', () {
    testWidgets('with a callback: the button renders and fires on tap',
        (tester) async {
      var taps = 0;
      await pumpHeader(
        tester,
        title: 'Medications',
        action: 'View Schedule',
        onAction: () => taps++,
      );

      // Same config the dashboard's Medications header passes.
      expect(find.text('Medications'), findsOneWidget);
      expect(find.text('View Schedule'), findsOneWidget);
      expect(find.byType(ButtonWidget), findsOneWidget);

      await tester.tap(find.text('View Schedule'));
      await tester.pump();

      expect(taps, 1);
      // The header itself does not navigate/close: the callback owns that.
      expect(find.text('View Schedule'), findsOneWidget);
    });

    testWidgets('without a callback: no button renders, even with a label',
        (tester) async {
      // The pre-fix Morning Vitals header (label, no handler) — the dead button
      // the owner reported.
      await pumpHeader(
        tester,
        title: 'Morning Vitals',
        action: 'Log New',
      );

      expect(find.text('Morning Vitals'), findsOneWidget);
      expect(find.text('Log New'), findsNothing);
      expect(find.byType(ButtonWidget), findsNothing);
    });

    testWidgets('without a callback: a blank label renders no button either',
        (tester) async {
      // The pre-fix Symptoms / Meals headers passed `action: ''`, which
      // valueOrDefault turned into a dead 'Log New'.
      await pumpHeader(tester, title: 'Symptoms', action: '');

      expect(find.text('Symptoms'), findsOneWidget);
      expect(find.text('Log New'), findsNothing);
      expect(find.byType(ButtonWidget), findsNothing);
    });

    testWidgets('no callback: the section layout still renders (title only)',
        (tester) async {
      await pumpHeader(tester, title: 'Meals and Hydration');
      expect(tester.takeException(), isNull);
      expect(find.text('Meals and Hydration'), findsOneWidget);
      expect(find.byType(ButtonWidget), findsNothing);
    });
  });

  group('Daily Dashboard header actions', () {
    testWidgets(
        'the Meals header action opens the same Add Meal sheet the section uses',
        (tester) async {
      // Exactly how the dashboard's 'Meals and Hydration' header is wired:
      // onAction -> the shared openAddMealSheet with the resolved recipient.
      final ref = recipient('r1');
      await tester.pumpWidget(
        ChangeNotifierProvider<FFAppState>.value(
          value: FFAppState(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => SectionHeaderWidget(
                  title: 'Meals and Hydration',
                  action: 'Add Meal',
                  onAction: () => openAddMealSheet(context, ref),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AddMealWidget), findsNothing);

      await tester.tap(find.text('Add Meal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The section's own card/'Add Meal' button sheet, not a new one.
      expect(find.byType(AddMealWidget), findsOneWidget);

      // Close it so the harness ends clean.
      Navigator.of(tester.element(find.byType(AddMealWidget))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AddMealWidget), findsNothing);
    });
  });
}
