// Back-stack regression tests for the three transitions repaired in PR #37.
//
// Before the fix these three used `go`/`goNamed`, which REPLACES the whole
// stack: the destination had no back entry, so back fell through to the app
// root instead of the screen the caregiver came from. They now push, so one
// Back returns to the ORIGINATING page:
//
//   * Client Directory -> Reports                (back returns to the Directory)
//   * Client Directory -> Add New Care Recipient (back returns to the Directory)
//   * Settings         -> Household              (back returns to Settings)
//
// Unlike nav_menu_navigation_test.dart (which stubs every page behind the nav
// menu sheet), these render the REAL originating page, tap its own control, and
// assert both what is on screen after Back and that a second Back reaches the
// host page — i.e. the stack is origin -> destination, not destination alone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/pages/a_client_directory/a_client_directory_widget.dart';
import 'package:new_project/pages/b_care_profile_setup/b_care_profile_setup_widget.dart';
import 'package:new_project/pages/group/household_widget.dart';
import 'package:new_project/pages/h_weekly_summary_report/h_weekly_summary_report_widget.dart';
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

  /// Host page first, then the two REAL originating pages, then labelled stubs
  /// for the three destinations. The stubs are how the tests know which screen
  /// is on top; the real pages are what makes "back returns to the origin" a
  /// genuine assertion rather than a restatement of the router config.
  GoRouter buildRouter() => GoRouter(
    initialLocation: '/host',
    routes: [
      GoRoute(path: '/host', builder: (_, __) => const _HostPage()),
      GoRoute(
        path: AClientDirectoryWidget.routePath,
        name: AClientDirectoryWidget.routeName,
        builder: (_, __) => const AClientDirectoryWidget(),
      ),
      GoRoute(
        path: SettingsAccountWidget.routePath,
        name: SettingsAccountWidget.routeName,
        builder: (_, __) => const SettingsAccountWidget(),
      ),
      GoRoute(
        path: BCareProfileSetupWidget.routePath,
        name: BCareProfileSetupWidget.routeName,
        builder: (_, __) => const _StubPage('CARE PROFILE SETUP PAGE'),
      ),
      GoRoute(
        path: HWeeklySummaryReportWidget.routePath,
        name: HWeeklySummaryReportWidget.routeName,
        builder: (_, __) => const _StubPage('REPORTS PAGE'),
      ),
      GoRoute(
        path: HouseholdWidget.routePath,
        name: HouseholdWidget.routeName,
        builder: (_, __) => const _StubPage('HOUSEHOLD PAGE'),
      ),
    ],
  );

  /// Pumps the host page (tall viewport so the page controls are on screen) and
  /// returns the router driving it.
  Future<GoRouter> pumpHost(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  /// Pushes one of the real originating pages from the host and waits for it.
  Future<void> openOrigin(
    WidgetTester tester,
    String buttonLabel,
    Type originType,
  ) async {
    await tester.tap(find.text(buttonLabel));
    await tester.pumpAndSettle();
    expect(find.byType(originType), findsOneWidget);
  }

  /// Taps [label] on the current page (scrolling it into view first) and
  /// asserts the destination is now on top with a back entry behind it.
  Future<void> tapControl(WidgetTester tester, String label) async {
    final control = find.text(label);
    await tester.ensureVisible(control);
    await tester.pumpAndSettle();
    await tester.tap(control);
    await tester.pumpAndSettle();
  }

  /// Back must land on [originType] — NOT the app root — and a second Back must
  /// reach the host page.
  Future<void> expectBackReturnsTo(
    WidgetTester tester,
    GoRouter router,
    Type originType,
    String destinationLabel,
  ) async {
    expect(
      find.text(destinationLabel),
      findsOneWidget,
      reason: 'the control must open $destinationLabel',
    );

    expect(router.canPop(), isTrue, reason: 'the transition must keep a stack');

    router.pop();
    await tester.pumpAndSettle();

    expect(
      find.byType(originType),
      findsOneWidget,
      reason: 'back must return to the originating page, not the app root',
    );
    expect(
      find.text('HOST PAGE'),
      findsNothing,
      reason: 'back must not skip past the originating page to the root',
    );
    expect(find.text(destinationLabel), findsNothing);

    // And the originating page is genuinely stacked: one more Back reaches the
    // host, so the stack is host -> origin -> destination.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('HOST PAGE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  testWidgets('Directory -> Reports: back returns to the Directory', (
    tester,
  ) async {
    final router = await pumpHost(tester);
    await openOrigin(tester, 'Open Directory', AClientDirectoryWidget);

    await tapControl(tester, 'Reports');

    await expectBackReturnsTo(
      tester,
      router,
      AClientDirectoryWidget,
      'REPORTS PAGE',
    );
  });

  testWidgets(
    'Directory -> Add New Care Recipient: back returns to the Directory',
    (tester) async {
      final router = await pumpHost(tester);
      await openOrigin(tester, 'Open Directory', AClientDirectoryWidget);

      await tapControl(tester, 'Add New Care Recipient');

      await expectBackReturnsTo(
        tester,
        router,
        AClientDirectoryWidget,
        'CARE PROFILE SETUP PAGE',
      );
    },
  );

  testWidgets('Settings -> Household: back returns to Settings', (
    tester,
  ) async {
    final router = await pumpHost(tester);
    await openOrigin(tester, 'Open Settings', SettingsAccountWidget);

    await tapControl(tester, 'Household');

    await expectBackReturnsTo(
      tester,
      router,
      SettingsAccountWidget,
      'HOUSEHOLD PAGE',
    );
  });
}

class _HostPage extends StatelessWidget {
  const _HostPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('HOST PAGE'),
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    context.pushNamed(AClientDirectoryWidget.routeName),
                child: const Text('Open Directory'),
              ),
            ),
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    context.pushNamed(SettingsAccountWidget.routeName),
                child: const Text('Open Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StubPage extends StatelessWidget {
  const _StubPage(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}
