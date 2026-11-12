// Settings identity card (U2): the card must show the REAL signed-in
// caregiver, read from their own `users/{uid}` profile record, instead of the
// hardcoded "Abbie Robinson" stranger the FlutterFlow export shipped with.
//
// Layout/styling are unchanged — only the avatar initials, name and email
// values now come from the profile. The not-yet-loaded / unavailable case must
// stay blank (no placeholder text, no invented name).
//
// The role chip on the same card shows the caregiver's role in their ACTIVE
// organization (owner decision 2026-11-12, option A), read from
// `organizations/{activeGroupId}/members/{uid}.role`. It is omitted entirely
// when the role cannot be reliably determined — never guessed, never inferred
// from ownership.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/app_state.dart' show FFAppState;
import 'package:new_project/pages/settings_account/settings_account_widget.dart';
import 'package:new_project/backend/auth/auth_service.dart' show loadUserProfile;
import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initFirebaseForTest();
  });

  setUp(() {
    fakeFirestore.clear();
    // The org context is cached app-wide; each test starts with no org.
    FFAppState().activeGroupId = null;
  });

  Future<void> seedProfile(
    String uid, {
    String? name,
    String? email,
    String? activeGroupId,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (activeGroupId != null) 'activeGroupId': activeGroupId,
    });
  }

  /// The membership doc the Household page (and the app-layer membership
  /// check) reads: `organizations/{orgId}/members/{uid}`.
  Future<void> seedMembership(
    String orgId,
    String uid, {
    String? role,
    String status = 'active',
  }) async {
    await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .doc(uid)
        .set({
      'uid': uid,
      'orgId': orgId,
      if (role != null) 'role': role,
      'status': status,
    });
  }

  Future<void> pumpSettings(WidgetTester tester) async {
    // Force a fresh State (and therefore a fresh role read) each time: pumping
    // the same widget type twice would otherwise reuse the existing State.
    await tester.pumpWidget(const SizedBox());
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
    // The card itself is still there, but with NO role badge: there is no
    // active org and no membership to read, so the old hardcoded
    // "Primary Caregiver" chip (and any other guess) must be gone.
    expect(find.text('Primary Caregiver'), findsNothing);
    expect(find.text('Caregiver'), findsNothing);
    expect(find.text('Owner'), findsNothing);
    expect(find.text('Settings & Account'), findsOneWidget);
  });

  // Role badge (owner decision 2026-11-12, option A): the chip shows the
  // caregiver's REAL role in their active organization, using the Household
  // page's labels — and never "Primary Caregiver".
  testWidgets('the role chip shows the active org role, not "Primary Caregiver"',
      (tester) async {
    await seedProfile('u1', name: 'Maria Alvarez', activeGroupId: 'org_a');
    await seedMembership('org_a', 'u1', role: 'owner');
    fakeAuthPlatform.emitSignedIn(uid: 'u1');

    await pumpSettings(tester);

    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Primary Caregiver'), findsNothing);
  });

  testWidgets('every Household role label is used verbatim', (tester) async {
    fakeAuthPlatform.emitSignedIn(uid: 'u1');
    const expected = {
      'owner': 'Owner',
      'admin': 'Admin',
      'caregiver': 'Caregiver',
      'viewer': 'Viewer',
    };
    for (final entry in expected.entries) {
      fakeFirestore.clear();
      await seedProfile('u1', name: 'Maria Alvarez', activeGroupId: 'org_a');
      await seedMembership('org_a', 'u1', role: entry.key);

      await pumpSettings(tester);

      expect(find.text(entry.value), findsOneWidget,
          reason: 'role ${entry.key} should render as ${entry.value}');
    }
  });

  testWidgets('no badge when the role cannot be determined', (tester) async {
    // (a) membership doc exists but stores no role — MembersRecord.role
    // defaults to 'viewer'; that default must NOT leak into the badge.
    await seedProfile('u1', name: 'Maria Alvarez', activeGroupId: 'org_a');
    await seedMembership('org_a', 'u1');
    fakeAuthPlatform.emitSignedIn(uid: 'u1');

    await pumpSettings(tester);
    expect(find.text('Viewer'), findsNothing);
    expect(find.text('Caregiver'), findsNothing);
    expect(find.text('Owner'), findsNothing);
    expect(find.text('Primary Caregiver'), findsNothing);

    // (b) the member doc is only an invite, not an active membership.
    fakeFirestore.clear();
    await seedProfile('u1', name: 'Maria Alvarez', activeGroupId: 'org_a');
    await seedMembership('org_a', 'u1', role: 'owner', status: 'invited');

    await pumpSettings(tester);
    expect(find.text('Owner'), findsNothing);
    expect(find.text('Primary Caregiver'), findsNothing);

    // (c) an unrecognised role value is not translated into a guess.
    fakeFirestore.clear();
    await seedProfile('u1', name: 'Maria Alvarez', activeGroupId: 'org_a');
    await seedMembership('org_a', 'u1', role: 'superuser');

    await pumpSettings(tester);
    expect(find.text('Caregiver'), findsNothing);
    expect(find.text('Primary Caregiver'), findsNothing);
  });

  // Org switching: the chip must follow the active org, never show the
  // previous org's role.
  testWidgets('the role chip refreshes when the active org changes',
      (tester) async {
    await seedProfile('u1', name: 'Maria Alvarez', activeGroupId: 'org_a');
    await seedMembership('org_a', 'u1', role: 'caregiver');
    await seedMembership('org_b', 'u1', role: 'admin');
    fakeAuthPlatform.emitSignedIn(uid: 'u1');
    FFAppState().activeGroupId = 'org_a';

    await pumpSettings(tester);
    expect(find.text('Caregiver'), findsOneWidget);

    // setActiveGroupId() updates the cached context and notifies.
    FFAppState().activeGroupId = 'org_b';
    await tester.pumpAndSettle();

    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Caregiver'), findsNothing);
  });

  // U2 edit identity (owner decision 2026-11-11): the pencil opens the edit
  // sheet, saves the caregiver's OWN name to their `users/{uid}` profile, and
  // the card then shows the new name and its initials.
  testWidgets('the pencil saves the signed-in user\'s own name', (tester) async {
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

    await pumpSettings(tester);
    expect(find.text('Maria Alvarez'), findsOneWidget);
    expect(find.text('MA'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pumpAndSettle();

    // The standard modal sheet, prefilled with the current name.
    expect(find.text('Edit your name'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Maria Alvarez',
    );

    await tester.enterText(find.byType(TextField), '  Rosa Alvarez  ');
    await tester.tap(find.text('Save name'));
    await tester.pumpAndSettle();

    // Written (trimmed) to the caregiver's own profile record.
    final saved = await loadUserProfile('u1');
    expect(saved?.name, 'Rosa Alvarez');

    // The card updates: new name, new initials, sheet gone.
    expect(find.text('Rosa Alvarez'), findsOneWidget);
    expect(find.text('RA'), findsOneWidget);
    expect(find.text('Maria Alvarez'), findsNothing);
    expect(find.text('Edit your name'), findsNothing);
  });

  testWidgets('a blank name is rejected and nothing is written',
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

    await pumpSettings(tester);

    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Save name'));
    await tester.pumpAndSettle();

    // Still open, with a real inline error, and the profile is untouched.
    expect(find.text('Please enter your name.'), findsOneWidget);
    expect(find.text('Edit your name'), findsOneWidget);
    final saved = await loadUserProfile('u1');
    expect(saved?.name, 'Maria Alvarez');
  });
}
