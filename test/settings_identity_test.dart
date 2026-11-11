// Settings identity card (U2): the card must show the REAL signed-in
// caregiver, read from their own `users/{uid}` profile record, instead of the
// hardcoded "Abbie Robinson" stranger the FlutterFlow export shipped with.
//
// Layout/styling are unchanged — only the avatar initials, name and email
// values now come from the profile. The not-yet-loaded / unavailable case must
// stay blank (no placeholder text, no invented name).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  Future<void> seedProfile(
    String uid, {
    String? name,
    String? email,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
    });
  }

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SettingsAccountWidget()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('identity card shows the signed-in user, not the hardcoded one',
      (tester) async {
    await seedProfile(
      'u1',
      name: 'Maria Alvarez',
      email: 'maria.alvarez@example.com',
    );
    fakeAuthPlatform.emitSignedIn(
      uid: 'u1',
      email: 'maria.alvarez@example.com',
      displayName: 'Maria Alvarez',
    );
    expect(FirebaseAuth.instance.currentUser?.uid, 'u1');

    await pumpSettings(tester);

    // Real name + email, and the avatar initials derived from the name.
    expect(find.text('Maria Alvarez'), findsOneWidget);
    expect(find.text('maria.alvarez@example.com'), findsOneWidget);
    expect(find.text('MA'), findsOneWidget);

    // The export's placeholder identity is gone.
    expect(find.text('Abbie Robinson'), findsNothing);
    expect(find.text('abbie.r@example.com'), findsNothing);
    expect(find.text('AR'), findsNothing);
  });

  testWidgets('no profile yet: the card shows no name/email and no placeholder',
      (tester) async {
    // Signed in, but the profile record does not exist yet and the auth
    // account carries no details (the not-yet-provisioned case).
    fakeAuthPlatform.emitSignedIn(uid: 'u2');

    await pumpSettings(tester);

    expect(find.text('Abbie Robinson'), findsNothing);
    expect(find.text('abbie.r@example.com'), findsNothing);
    expect(find.text('AR'), findsNothing);
    // The card itself is still there, with its unchanged role chip.
    expect(find.text('Primary Caregiver'), findsOneWidget);
    expect(find.text('Settings & Account'), findsOneWidget);
  });
}
