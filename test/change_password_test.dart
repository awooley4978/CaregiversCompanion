// Settings "Change Password" (U2): the SECURITY row used to be dead — it
// declared an `onTap` string the widget never dispatched. It now performs a
// REAL password change with the app's existing Firebase Email/Password
// authentication: re-authenticate with the current password, then set the new
// one. Validation and failures are shown inline, and the sheet only closes on
// success.
//
// The Terms of Service row shares the same dead `onTap` string and must stay
// inert: no URL exists for it, so nothing may be wired — including no shared
// generic handler that would send it somewhere wrong.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/pages/settings_account/settings_account_widget.dart';
import 'firebase_test_setup.dart';

/// Counts navigations, so "the row did nothing" can be asserted.
class _CountingNavigatorObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initFirebaseForTest();
  });

  setUp(() {
    fakeFirestore.clear();
  });

  Future<void> pumpSettings(WidgetTester tester,
      {NavigatorObserver? observer}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const SettingsAccountWidget(),
        navigatorObservers: <NavigatorObserver>[if (observer != null) observer],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapRow(WidgetTester tester, String label) async {
    final row = find.text(label);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  Future<void> fillForm(
    WidgetTester tester, {
    required String current,
    required String next,
    required String confirm,
  }) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), current);
    await tester.enterText(fields.at(1), next);
    await tester.enterText(fields.at(2), confirm);
    await tester.pumpAndSettle();
  }

  testWidgets('Change Password really changes the password', (tester) async {
    fakeAuthPlatform.emitSignedIn(
      uid: 'u1',
      email: 'maria.alvarez@example.com',
      password: 'old-password-1',
    );

    await pumpSettings(tester);
    await tapRow(tester, 'Change Password');

    // The row opens the change-password form.
    expect(find.text('Update Password'), findsOneWidget);

    await fillForm(
      tester,
      current: 'old-password-1',
      next: 'brand-new-pass-9',
      confirm: 'brand-new-pass-9',
    );
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();

    // Firebase was asked to re-authenticate with the current password and then
    // to set the new one — a real change, not a reset email.
    final user = fakeAuthPlatform.signedInUser;
    expect(user.reauthPasswords, ['old-password-1']);
    expect(user.updatedPasswords, ['brand-new-pass-9']);

    // The sheet closed and the page confirmed it.
    expect(find.text('Update Password'), findsNothing);
    expect(find.text('Password updated.'), findsOneWidget);
  });

  testWidgets('mismatched confirmation is refused before any Firebase call',
      (tester) async {
    fakeAuthPlatform.emitSignedIn(
      uid: 'u1',
      email: 'maria.alvarez@example.com',
      password: 'old-password-1',
    );

    await pumpSettings(tester);
    await tapRow(tester, 'Change Password');
    await fillForm(
      tester,
      current: 'old-password-1',
      next: 'brand-new-pass-9',
      confirm: 'brand-new-pass-8',
    );
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();

    expect(find.text('The new passwords do not match.'), findsOneWidget);
    final user = fakeAuthPlatform.signedInUser;
    expect(user.reauthPasswords, isEmpty);
    expect(user.updatedPasswords, isEmpty);
    // Still open, so the caregiver can correct it.
    expect(find.text('Update Password'), findsOneWidget);
    expect(find.text('Password updated.'), findsNothing);
  });

  testWidgets('a too-short new password is refused', (tester) async {
    fakeAuthPlatform.emitSignedIn(
      uid: 'u1',
      email: 'maria.alvarez@example.com',
      password: 'old-password-1',
    );

    await pumpSettings(tester);
    await tapRow(tester, 'Change Password');
    await fillForm(
      tester,
      current: 'old-password-1',
      next: 'short',
      confirm: 'short',
    );
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();

    expect(
      find.text('Your new password must be at least 8 characters.'),
      findsOneWidget,
    );
    expect(fakeAuthPlatform.signedInUser.updatedPasswords, isEmpty);
  });

  testWidgets('a wrong current password shows a clear error and changes nothing',
      (tester) async {
    fakeAuthPlatform.emitSignedIn(
      uid: 'u1',
      email: 'maria.alvarez@example.com',
      password: 'old-password-1',
    );

    await pumpSettings(tester);
    await tapRow(tester, 'Change Password');
    await fillForm(
      tester,
      current: 'not-my-password',
      next: 'brand-new-pass-9',
      confirm: 'brand-new-pass-9',
    );
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();

    expect(find.text('Your current password is incorrect.'), findsOneWidget);
    expect(fakeAuthPlatform.signedInUser.updatedPasswords, isEmpty);
    expect(find.text('Update Password'), findsOneWidget);
    expect(find.text('Password updated.'), findsNothing);
  });

  testWidgets('Terms of Service stays inert: tapping it goes nowhere',
      (tester) async {
    fakeAuthPlatform.emitSignedIn(uid: 'u1', email: 'maria.alvarez@example.com');
    final observer = _CountingNavigatorObserver();

    await pumpSettings(tester, observer: observer);
    final pushesBefore = observer.pushes;

    await tapRow(tester, 'Terms of Service');

    expect(observer.pushes, pushesBefore);
    // No shared generic handler: the tap does not open another row's action.
    expect(find.text('Update Password'), findsNothing);
    expect(find.text('Terms of Service'), findsOneWidget);
  });
}
