// U6 PR A — branding strings + dynamic version (owner decisions 2026-11-12).
//
//   * The Settings footer shows the product name "Caregivers Companion" plus
//     the version read at runtime from the app package — never a hardcoded
//     version string — and degrades to the product name alone when the lookup
//     fails (as it does in plain widget tests, where `package_info_plus` has
//     no platform implementation).
//   * No note component invents an author: the composer header is blank until
//     the signed-in user's display name is known, then shows the real name,
//     and a note card with no stored author renders blank — never
//     'Sarah (Primary)'.
// Offline + deterministic: Firebase is replaced by the in-memory fakes in
// test/firebase_test_setup.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/components/dashboard_notes_form/dashboard_notes_form_widget.dart';
import 'package:new_project/components/note_card/note_card_widget.dart';
import 'package:new_project/pages/settings_account/settings_account_widget.dart';
import 'package:provider/provider.dart';
import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initFirebaseForTest();
  });

  setUp(() {
    FFAppState.reset();
    fakeFirestore.clear();
    fakeAuthPlatform.emitSignedOut();
  });

  /// Every string a widget tree renders as `Text` (used to assert that a
  /// fabricated author appears nowhere).
  List<String?> renderedTexts(WidgetTester tester) =>
      tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();

  Future<void> pumpWithAppState(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<FFAppState>.value(
        value: FFAppState(),
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Settings footer', () {
    testWidgets('shows the product name and the version from the package',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsAccountWidget(versionLoader: () async => '1.4.2'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Caregivers Companion v1.4.2'), findsOneWidget);
      // The old wrong product name and its hardcoded version are gone.
      expect(find.textContaining('Caregiver Command'), findsNothing);
      expect(find.textContaining('v1.2.4'), findsNothing);
      // The line under it is untouched.
      expect(find.text('Made with ❤️ for caregivers'), findsOneWidget);
    });

    testWidgets('falls back to the product name alone when the lookup fails',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsAccountWidget(
            versionLoader: () async =>
                throw Exception('package info unavailable'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Caregivers Companion'), findsOneWidget);
      expect(find.textContaining('Caregiver Command'), findsNothing);
      expect(find.text('Made with ❤️ for caregivers'), findsOneWidget);
    });

    testWidgets('renders the product name when no version is returned',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsAccountWidget(versionLoader: () async => null),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Caregivers Companion'), findsOneWidget);
    });

    testWidgets('the real package lookup degrades cleanly (no plugin in tests)',
        (tester) async {
      // No injected loader: `PackageInfo.fromPlatform()` throws
      // MissingPluginException here, and the footer must still render.
      await tester.pumpWidget(
        const MaterialApp(home: SettingsAccountWidget()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Caregivers Companion'), findsOneWidget);
      expect(find.textContaining('Caregiver Command'), findsNothing);
    });
  });

  group('Notes author', () {
    testWidgets('the composer header is blank before the signed-in user is '
        'known, then shows the real display name', (tester) async {
      // No signed-in user yet: no invented author of any kind.
      await pumpWithAppState(tester, const DashboardNotesFormWidget());
      expect(renderedTexts(tester), isNot(contains('Sarah (Primary)')));
      expect(renderedTexts(tester), contains(''));

      // Signed in: the header shows the real display name.
      fakeAuthPlatform.emitSignedIn(
        uid: 'u1',
        email: 'maria.alvarez@example.com',
        displayName: 'Maria Alvarez',
      );
      await pumpWithAppState(tester, const DashboardNotesFormWidget());
      expect(renderedTexts(tester), contains('Maria Alvarez'));
      expect(renderedTexts(tester), isNot(contains('Sarah (Primary)')));
    });

    testWidgets('a note card with no stored author renders blank, never a '
        'placeholder identity', (tester) async {
      await pumpWithAppState(tester, const NoteCardWidget());

      expect(find.text('Sarah (Primary)'), findsNothing);
      expect(renderedTexts(tester), isNot(contains('Sarah (Primary)')));
      expect(renderedTexts(tester), isNot(contains('S')));
      expect(renderedTexts(tester), contains(''));
    });

    testWidgets('a note card renders a stored author exactly as stored',
        (tester) async {
      await pumpWithAppState(
        tester,
        const NoteCardWidget(authorName: 'Joan Whitfield', authorInitials: 'JW'),
      );

      expect(find.text('Joan Whitfield'), findsOneWidget);
      expect(find.text('JW'), findsOneWidget);
    });
  });
}
