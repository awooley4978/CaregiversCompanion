// Nav menu navigation contract (owner navigation repairs 2026-11-03).
//
// Two defects, pinned here through the real menu widget:
//
//   * The 'Daily Dashboard' pill had no handler at all (a plain Container +
//     Text), so tapping it did nothing. It now navigates exactly like the
//     working pill entries around it.
//   * Five entries (MENU, People, Daily Care, Reports, Settings) pushed their
//     destination WITHOUT dismissing the sheet first, so the still-open menu
//     sat underneath the destination and system back returned to the menu
//     instead of the page the caregiver came from.
//
// The menu is rendered in a real modal bottom sheet under a minimal GoRouter
// that registers the app's own route names/paths as stub pages, so the tests
// assert the two things that matter: the destination is shown, and the sheet is
// gone (which is what makes back return to the previous screen).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:new_project/components/nav_menu_directory/nav_menu_directory_widget.dart';
import 'package:new_project/pages/a_client_directory/a_client_directory_widget.dart';
import 'package:new_project/pages/b_care_profile_setup/b_care_profile_setup_widget.dart';
import 'package:new_project/pages/c_daily_dashboard/c_daily_dashboard_widget.dart';
import 'package:new_project/pages/h_weekly_summary_report/h_weekly_summary_report_widget.dart';
import 'package:new_project/pages/settings_account/settings_account_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The app's menu destinations, registered by the same name/path the menu's
  /// `pushNamed` calls use, each rendering a labelled stub page.
  GoRouter buildRouter() => GoRouter(
    initialLocation: '/host',
    routes: [
      GoRoute(path: '/host', builder: (_, __) => const _HostPage()),
      GoRoute(
        path: AClientDirectoryWidget.routePath,
        name: AClientDirectoryWidget.routeName,
        builder: (_, __) => const _StubPage('DIRECTORY PAGE'),
      ),
      GoRoute(
        path: BCareProfileSetupWidget.routePath,
        name: BCareProfileSetupWidget.routeName,
        builder: (_, __) => const _StubPage('CARE PROFILE SETUP PAGE'),
      ),
      GoRoute(
        path: CDailyDashboardWidget.routePath,
        name: CDailyDashboardWidget.routeName,
        builder: (_, __) => const _StubPage('DASHBOARD PAGE'),
      ),
      GoRoute(
        path: HWeeklySummaryReportWidget.routePath,
        name: HWeeklySummaryReportWidget.routeName,
        builder: (_, __) => const _StubPage('REPORTS PAGE'),
      ),
      GoRoute(
        path: SettingsAccountWidget.routePath,
        name: SettingsAccountWidget.routeName,
        builder: (_, __) => const _StubPage('SETTINGS PAGE'),
      ),
    ],
  );

  /// Pumps the host page (tall viewport so the whole menu is on screen) and
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

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();
    // 'Vitals' is a menu-only label: it is how these tests tell whether the
    // sheet is still on screen.
    expect(find.text('Vitals'), findsOneWidget);
  }

  testWidgets(
    "the 'Daily Dashboard' pill opens the dashboard and dismisses the menu",
    (tester) async {
      final router = await pumpHost(tester);
      await openMenu(tester);

      await tester.tap(find.text('Daily Dashboard'));
      await tester.pumpAndSettle();

      expect(find.text('DASHBOARD PAGE'), findsOneWidget);
      // The sheet is dismissed, so the dashboard is not sitting on top of it.
      expect(find.text('Vitals'), findsNothing);
      // Back therefore returns to the page the caregiver came from.
      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('HOST PAGE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the five label entries dismiss the sheet before navigating', (
    tester,
  ) async {
    const destinations = {
      'MENU': 'DIRECTORY PAGE',
      'People': 'DIRECTORY PAGE',
      'Daily Care': 'DASHBOARD PAGE',
      'Reports': 'REPORTS PAGE',
      'Settings': 'SETTINGS PAGE',
    };

    for (final entry in destinations.entries) {
      final router = await pumpHost(tester);
      await openMenu(tester);

      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();

      expect(
        find.text(entry.value),
        findsOneWidget,
        reason: '${entry.key} must open its destination',
      );
      expect(
        find.text('Vitals'),
        findsNothing,
        reason: '${entry.key} must dismiss the menu sheet before navigating',
      );

      // Back returns to the previous screen, not to the menu.
      expect(
        router.canPop(),
        isTrue,
        reason: '${entry.key} keeps a back stack',
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(
        find.text('HOST PAGE'),
        findsOneWidget,
        reason: 'back from ${entry.key} must return to the previous screen',
      );
      expect(
        find.text('Vitals'),
        findsNothing,
        reason: 'back from ${entry.key} must not land on the menu',
      );
      expect(tester.takeException(), isNull);
    }
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
                onPressed: () => showModalBottomSheet(
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  enableDrag: false,
                  context: context,
                  builder: (_) => const NavMenuDirectoryWidget(),
                ),
                child: const Text('Open menu'),
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
