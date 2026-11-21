// Client Directory loading / error / retry contract (owner decision
// 2026-11-21).
//
// The owner reported that an empty directory could silently disguise a
// technical failure: while the app was still working out the care circle, or
// after that resolution failed, the page rendered an empty list — which reads
// as "my loved one's information disappeared". The page now distinguishes four
// states: resolving (spinner), failed (error + Retry), ready-and-empty (the
// genuine empty line, only after a real resolution) and ready-with-recipients.
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregivers_companion/app_state.dart';
import 'package:caregivers_companion/backend/schema/care_recipients_record.dart';
import 'package:caregivers_companion/pages/a_client_directory/a_client_directory_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const orgId = 'org_test_directory';
  const emptyStateText = 'No care recipients in your care circle yet.';

  setUpAll(() async {
    await initFirebaseForTest();
  });

  setUp(() {
    FFAppState.reset();
    fakeFirestore.clear();
    fakeFirestore.clearQueryError();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> seedRecipient(
    String id,
    String name,
    String initials, {
    String org = orgId,
  }) async {
    await CareRecipientsRecord.collection.doc(id).set(
          createCareRecipientsRecordData(
            name: name,
            initials: initials,
            orgId: org,
          ),
        );
  }

  /// Pumps the directory inside the provider the app itself installs.
  ///
  /// [settle] is false for the resolving state: a progress indicator animates
  /// forever, so `pumpAndSettle` would time out by design.
  Future<void> pumpDirectory(WidgetTester tester, {bool settle = true}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<FFAppState>.value(
        value: FFAppState(),
        child: const MaterialApp(
          home: AClientDirectoryWidget(),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('while the care circle resolves: a spinner, never an empty list',
      (tester) async {
    FFAppState().setCareCircleLoading();

    await pumpDirectory(tester, settle: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('Loading your care circle'), findsOneWidget);
    expect(find.text(emptyStateText), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('a failed resolution: an error with Retry, never an empty list',
      (tester) async {
    FFAppState().setCareCircleFailed('Missing or insufficient permissions.');

    await pumpDirectory(tester);

    expect(find.text('We could not load your care circle.'), findsOneWidget);
    expect(find.text('Missing or insufficient permissions.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text(emptyStateText), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Retry re-runs provisioning and the circle appears',
      (tester) async {
    // Provisioning settles on the user's deterministic family org
    // (`org_<uid>`), so a recipient seeded there is the circle it resolves to.
    const uid = 'retry-user';
    final org = 'org_$uid';
    await seedRecipient('mom', 'Margaret Ellis', 'ME', org: org);
    fakeAuthPlatform.emitSignedIn(uid: uid, email: 'retry@example.com');

    FFAppState().setCareCircleFailed('We could not reach your care circle.');

    await pumpDirectory(tester);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Margaret Ellis'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    // Provisioning ran for the signed-in user: the group context is now
    // known, the status is ready and the real circle is listed.
    expect(FFAppState().activeGroupId, org);
    expect(FFAppState().careCircleStatus, CareCircleStatus.ready);
    expect(find.text('Margaret Ellis'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(find.text(emptyStateText), findsNothing);
  });

  testWidgets('a resolved but genuinely empty circle keeps the empty state',
      (tester) async {
    FFAppState().activeGroupId = orgId;
    FFAppState().setCareCircleReady();

    await pumpDirectory(tester);

    expect(find.text(emptyStateText), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  // The circle resolved (status ready, group known) but the recipients query
  // itself failed — a rules denial or a network drop. The StreamBuilder's error
  // must render the failure state, never a silent empty list.
  testWidgets(
      'a failing recipients query: an error with Retry, not an empty list',
      (tester) async {
    FFAppState().activeGroupId = orgId;
    FFAppState().setCareCircleReady();
    fakeFirestore.queryError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing or insufficient permissions.',
    );

    await pumpDirectory(tester);

    expect(find.text('We could not load your care circle.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text(emptyStateText), findsNothing);
  });
}
