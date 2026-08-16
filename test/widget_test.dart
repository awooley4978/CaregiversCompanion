// CI widget-test harness.
//
// Replaces the FlutterFlow template 'Counter increments smoke test' with a
// minimal smoke test that verifies the app pumps without the known
// [core/no-app] Firebase failure: Firebase is initialized with the test-only
// fakes in test/firebase_test_setup.dart (no network, no real backend), and
// the landing route (AClientDirectoryWidget) resolves its Firestore query to
// an empty result set. The test asserts only that the app pumps without
// unhandled exceptions — no business behavior is asserted.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/main.dart';
import 'package:provider/provider.dart';

import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initFirebaseForTest();
  });

  testWidgets('App pumps without Firebase exceptions', (tester) async {
    // Mirror the real main() bootstrap (minus initFirebase, which the
    // test fakes replace).
    final appState = FFAppState();
    await tester.pumpWidget(
      ChangeNotifierProvider<FFAppState>(
        create: (context) => appState,
        child: MyApp(),
      ),
    );

    // Let the initial route settle and the (fake) Firestore stream emit.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The app pumped without exceptions (e.g. the former core/no-app error).
    expect(tester.takeException(), isNull);
  });
}
