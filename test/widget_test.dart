// CI widget-test harness.
//
// Replaces the FlutterFlow template 'Counter increments smoke test' with
// Firebase-initialized tests (see test/firebase_test_setup.dart — the
// firebase_core mock plus in-memory Firestore and Firebase Auth fakes, no
// network, no real backend). Security phase 1 adds the auth-gate coverage:
//
//  1. signed-out user  -> the global router redirect lands on /login
//  2. signed-in user   -> the redirect keeps the user on the client directory
//  3. smoke test       -> the app pumps without unhandled exceptions
//
// Auth state is driven through fakeAuthPlatform.emitSignedOut() /
// emitSignedIn(), which feed the SAME auth-state listener main() installs
// (attachAuthStateListener), so the tests exercise the production wiring.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/backend/auth/auth_service.dart';
import 'package:new_project/flutter_flow/nav/nav.dart';
import 'package:new_project/main.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamSubscription<User?> authSub;

  setUpAll(() async {
    await initFirebaseForTest();
    // Per-user persisted state (selected recipient, phase 2) is loaded from
    // SharedPreferences on sign-in; the in-memory mock keeps it hermetic.
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    // Cold start for every test: the auth restore has not resolved yet.
    AppStateNotifier.instance.resetAuthStateForTest();
    FFAppState.reset();
  });

  tearDown(() {
    authSub.cancel();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    final appState = FFAppState();
    await tester.pumpWidget(
      ChangeNotifierProvider<FFAppState>(
        create: (context) => appState,
        child: MyApp(),
      ),
    );
    // Let the initial route settle, the (fake) Firestore stream emit, and the
    // auth redirect (if any) resolve.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('signed-out user is redirected to the login screen',
      (tester) async {
    // Mirror the production bootstrap: the auth listener is installed before
    // the app runs, and the persisted-session restore resolves to signed-out.
    authSub = attachAuthStateListener(AppStateNotifier.instance);
    fakeAuthPlatform.emitSignedOut();

    await pumpApp(tester);

    // The global redirect moved the user off '/' onto the login screen.
    expect(find.text('Caregivers Companion'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Continue with Google'), findsOneWidget);
    // The client directory is not reachable while signed out.
    expect(find.text('Quick Actions'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed-in user stays on the client directory', (tester) async {
    authSub = attachAuthStateListener(AppStateNotifier.instance);
    fakeAuthPlatform.emitSignedIn(
      email: 'caregiver@example.com',
      displayName: 'Test Caregiver',
    );

    await pumpApp(tester);

    // No redirect off the initial route; the directory renders.
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Sign In'), findsNothing);
    expect(find.text('Caregivers Companion'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('App pumps without Firebase exceptions', (tester) async {
    // No auth listener / no emitted state: the restore window never resolves,
    // the redirect stays put, and the landing route renders like before.
    await pumpApp(tester);

    // The app pumped without exceptions (e.g. the former core/no-app error).
    expect(tester.takeException(), isNull);
  });
}
