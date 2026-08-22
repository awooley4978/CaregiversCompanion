// Auth-state contract widget tests (security phase 5 hardening, §5.3 item 6).
//
// Covers the full auth-state contract through the app's REAL wiring — the
// auth listener main() installs (attachAuthStateListener -> AppStateNotifier
// -> GoRouter global redirect) driven by the in-memory Firebase Auth fake:
//
//  1. signed out -> the login screen is shown and NO data screen is reachable
//     (direct deep-links to data routes also bounce to /login)
//  2. on sign-in -> the app routes away from login (to the client directory)
//  3. on sign-out -> the app lands on the login screen
//
// The transition tests (2 and 3) exercise the redirect reacting to auth-state
// changes AFTER the app is already running, not just the cold-start redirect
// covered by test/widget_test.dart.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/backend/auth/auth_service.dart';
import 'package:new_project/flutter_flow/nav/nav.dart';
import 'package:new_project/main.dart';
import 'package:new_project/pages/group/household_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamSubscription<User?> authSub;

  setUpAll(() async {
    await initFirebaseForTest();
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    AppStateNotifier.instance.resetAuthStateForTest();
    FFAppState.reset();
  });

  tearDown(() async {
    await authSub.cancel();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    final appState = FFAppState();
    await tester.pumpWidget(
      ChangeNotifierProvider<FFAppState>(
        create: (context) => appState,
        child: MyApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Pumps frames until [finder] matches (bounded, so tests stay fast and
  /// deterministic) or [maxPumps] is exhausted. After an auth-state change the
  /// router's refresh-driven redirect and the sign-in provisioning complete
  /// over several frames, so a poll beats a fixed pump count.
  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    int maxPumps = 30,
  }) async {
    for (var i = 0; i < maxPumps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (tester.any(finder)) {
        return;
      }
    }
  }

  testWidgets('signed out: login is shown and no data screen is reachable',
      (tester) async {
    authSub = attachAuthStateListener(AppStateNotifier.instance);
    fakeAuthPlatform.emitSignedOut();

    await pumpApp(tester);

    expect(find.text('Caregivers Companion'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);

    // A direct deep-link to a data route bounces to /login (global redirect).
    // GoRouter.of needs a context that is inside the router subtree (below the
    // MaterialApp.router), so use the login screen's element.
    final router =
        GoRouter.of(tester.element(find.text('Sign In').first));
    router.go(HouseholdWidget.routePath);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Still on login, and the Household (data) screen never rendered.
    expect(find.text('Caregivers Companion'), findsOneWidget);
    expect(find.text('Household'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-in routes the app away from the login screen',
      (tester) async {
    authSub = attachAuthStateListener(AppStateNotifier.instance);
    fakeAuthPlatform.emitSignedOut();

    await pumpApp(tester);
    expect(find.text('Caregivers Companion'), findsOneWidget);

    // Sign in through the same auth seam.
    fakeAuthPlatform.emitSignedIn(
      email: 'caregiver@example.com',
      displayName: 'Test Caregiver',
    );
    await pumpUntil(tester, find.text('Quick Actions'));

    // The global redirect moved the user off /login onto the client directory.
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Sign In'), findsNothing);
    expect(find.text('Caregivers Companion'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-out lands the user back on the login screen',
      (tester) async {
    authSub = attachAuthStateListener(AppStateNotifier.instance);
    fakeAuthPlatform.emitSignedOut();
    await pumpApp(tester);
    expect(find.text('Caregivers Companion'), findsOneWidget);

    // Sign in, then sign out — the router must follow both transitions.
    fakeAuthPlatform.emitSignedIn(
      email: 'caregiver@example.com',
      displayName: 'Test Caregiver',
    );
    await pumpUntil(tester, find.text('Quick Actions'));
    expect(find.text('Quick Actions'), findsOneWidget);

    fakeAuthPlatform.emitSignedOut();
    await pumpUntil(tester, find.text('Caregivers Companion'));

    expect(find.text('Caregivers Companion'), findsOneWidget);
    expect(find.text('Quick Actions'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
