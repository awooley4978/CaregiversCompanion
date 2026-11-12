// Settings — Household lives in the SHARED CARE group (U2, owner decision
// 2026-11-11).
//
// The Household card used to sit between the SECURITY and SUPPORT groups with
// no heading, while SHARED CARE rendered an empty card. The owner asked for the
// existing card to move under SHARED CARE with its behaviour, styling and
// navigation untouched. This pins both halves of that: it renders inside the
// SHARED CARE group, and tapping it still opens the Household page.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/components/settings_group/settings_group_widget.dart';
import 'package:new_project/pages/group/household_widget.dart';
import 'package:new_project/pages/settings_account/settings_account_widget.dart';

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

  testWidgets('Household renders under SHARED CARE and still opens Household',
      (tester) async {
    fakeAuthPlatform.emitSignedIn(
      uid: 'u1',
      email: 'maria.alvarez@example.com',
      displayName: 'Maria Alvarez',
    );

    final router = GoRouter(
      initialLocation: SettingsAccountWidget.routePath,
      routes: [
        GoRoute(
          path: SettingsAccountWidget.routePath,
          name: SettingsAccountWidget.routeName,
          builder: (_, __) => const SettingsAccountWidget(),
        ),
        GoRoute(
          path: HouseholdWidget.routePath,
          name: HouseholdWidget.routeName,
          builder: (_, __) => const Scaffold(body: Text('HOUSEHOLD PAGE')),
        ),
      ],
    );

    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // The group exists and the Household row is inside it — not a stray card
    // somewhere else on the screen.
    final sharedCare = find.byWidgetPredicate(
      (widget) => widget is SettingsGroupWidget && widget.title == 'SHARED CARE',
    );
    expect(sharedCare, findsOneWidget);
    expect(
      find.descendant(of: sharedCare, matching: find.text('Household')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sharedCare,
        matching: find.text('Members, invites, and roles in your Care Circle'),
      ),
      findsOneWidget,
    );
    expect(find.text('Household'), findsOneWidget);

    // Unchanged navigation: tapping the card pushes the Household page.
    final householdRow = find.text('Household');
    await tester.ensureVisible(householdRow);
    await tester.pumpAndSettle();
    await tester.tap(householdRow);
    await tester.pumpAndSettle();

    expect(find.text('HOUSEHOLD PAGE'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });
}
