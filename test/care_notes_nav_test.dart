// Care Notes navigation + rendering contract.
//
// Verifies the owner's reported symptom directly: selecting the Care Notes
// destination (its route /fCareNotes) opens the Care Notes screen, NOT the
// "add new care profile" (BCareProfileSetup) screen. Runs through the app's
// real wiring (auth listener -> GlobalKey redirect -> GoRouter) with the
// in-memory Firebase Auth fake, matching auth_state_test conventions and
// using pumpUntilTransition so the test stays deterministic/offline.
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/backend/auth/auth_service.dart';
import 'package:new_project/flutter_flow/nav/nav.dart';
import 'package:new_project/main.dart';
import 'package:new_project/pages/b_care_profile_setup/b_care_profile_setup_widget.dart';
import 'package:new_project/pages/f_care_notes/f_care_notes_widget.dart';
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

  Future<void> pumpUntilTransition(
    WidgetTester tester, {
    required Finder present,
    required Finder absent,
    int maxPumps = 60,
  }) async {
    for (var i = 0; i < maxPumps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (tester.any(present) && !tester.any(absent)) {
        return;
      }
    }
  }

  testWidgets(
      'Care Notes destination opens the notes screen, not care-profile setup',
      (tester) async {
    authSub = attachAuthStateListener(AppStateNotifier.instance);
    fakeAuthPlatform.emitSignedOut();
    await pumpApp(tester);
    expect(find.text('Sign In'), findsWidgets);

    // Sign in through the same auth seam; the router lands on the client
    // directory.
    fakeAuthPlatform.emitSignedIn(
      email: 'caregiver@example.com',
      displayName: 'Test Caregiver',
    );
    await pumpUntilTransition(
      tester,
      present: find.text('Quick Actions'),
      absent: find.text('Sign In'),
    );
    expect(find.text('Quick Actions'), findsOneWidget);

    // Navigate to the Care Notes destination.
    final router =
        GoRouter.of(tester.element(find.text('Quick Actions').first));
    router.go(FCareNotesWidget.routePath);
    await pumpUntilTransition(
      tester,
      present: find.text('Care Notes'),
      absent: find.text('Quick Actions'),
    );

    // The notes screen (with its composer + list) is what shows — not the
    // "add new care profile" screen.
    expect(find.text('Care Notes'), findsOneWidget);
    expect(find.text('Add Note'), findsOneWidget);
    expect(find.byType(BCareProfileSetupWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
