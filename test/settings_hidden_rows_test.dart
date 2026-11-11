// Settings — inactive rows hidden (U2, owner decision 2026-11-11).
//
// Push Notifications, Private Notes, Biometric Login and Help Center had no
// real functionality behind them (non-persisting switches, no destination),
// so they no longer render. The rows that do something real must all survive
// unchanged.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/pages/settings_account/settings_account_widget.dart';
import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initFirebaseForTest();
  });

  setUp(() {
    fakeFirestore.clear();
  });

  testWidgets('inactive rows are gone and the working rows still render',
      (tester) async {
    await FirebaseFirestore.instance.collection('users').doc('u1').set({
      'uid': 'u1',
      'name': 'Maria Alvarez',
      'email': 'maria.alvarez@example.com',
    });
    fakeAuthPlatform.emitSignedIn(
      uid: 'u1',
      email: 'maria.alvarez@example.com',
      displayName: 'Maria Alvarez',
    );

    await tester.pumpWidget(
      const MaterialApp(home: SettingsAccountWidget()),
    );
    await tester.pumpAndSettle();

    // Hidden until they have real functionality.
    expect(find.text('Push Notifications'), findsNothing);
    expect(find.text('Private Notes'), findsNothing);
    expect(find.text('Biometric Login'), findsNothing);
    expect(find.text('Help Center'), findsNothing);

    // The rows that work are untouched.
    expect(find.text('Preferred Pharmacy'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Household'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
  });
}
