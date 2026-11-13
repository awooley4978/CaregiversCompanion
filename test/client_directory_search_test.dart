// Directory search contract (U3 cleanup 2026-11-13).
//
// The care directory's search box had no effect: its text was written into
// `AClientDirectoryModel.searchName` but nothing ever read it, so typing
// filtered nothing. The box now filters the already-streamed circle
// client-side by name or initials, shows a "no matches" line when nothing
// matches, and treats blank (including the model's junk default `'" "'`) as
// "show every recipient".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/backend/schema/care_recipients_record.dart';
import 'package:new_project/pages/a_client_directory/a_client_directory_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const orgId = 'org_test_directory';

  setUpAll(() async {
    await initFirebaseForTest();
  });

  setUp(() {
    FFAppState.reset();
    fakeFirestore.clear();
    SharedPreferences.setMockInitialValues({});
    FFAppState().activeGroupId = orgId;
  });

  Future<void> seedRecipient(
    String id,
    String name,
    String initials,
  ) async {
    await CareRecipientsRecord.collection
        .doc(id)
        .set(createCareRecipientsRecordData(
          name: name,
          initials: initials,
          orgId: orgId,
        ));
  }

  Future<void> pumpDirectory(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: AClientDirectoryWidget(),
    ));
    await tester.pumpAndSettle();
  }

  /// Types into the search box and lets the debounce fire.
  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextFormField), text);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('typing filters the list by name and by initials',
      (tester) async {
    await seedRecipient('mom', 'Margaret Ellis', 'ME');
    await seedRecipient('dad', 'Harold Ellis', 'HE');
    await seedRecipient('aunt', 'Doris Pike', 'DP');

    await pumpDirectory(tester);

    // Everything is listed before searching.
    expect(find.text('Margaret Ellis'), findsOneWidget);
    expect(find.text('Harold Ellis'), findsOneWidget);
    expect(find.text('Doris Pike'), findsOneWidget);

    // Name match: only Margaret survives.
    await search(tester, 'margaret');
    expect(find.text('Margaret Ellis'), findsOneWidget);
    expect(find.text('Harold Ellis'), findsNothing);
    expect(find.text('Doris Pike'), findsNothing);

    // Initials match: "he" is Harold Ellis's initials, not a name substring.
    await search(tester, 'he');
    expect(find.text('Harold Ellis'), findsOneWidget);
    expect(find.text('Margaret Ellis'), findsNothing);
    expect(find.text('Doris Pike'), findsNothing);
  });

  testWidgets('a search with no matches shows the no-matches line',
      (tester) async {
    await seedRecipient('mom', 'Margaret Ellis', 'ME');

    await pumpDirectory(tester);
    await search(tester, 'zzz');

    expect(find.text('No care recipients match your search.'), findsOneWidget);
    expect(find.text('Margaret Ellis'), findsNothing);
  });

  testWidgets('a blank search shows every recipient', (tester) async {
    await seedRecipient('mom', 'Margaret Ellis', 'ME');
    await seedRecipient('dad', 'Harold Ellis', 'HE');

    await pumpDirectory(tester);

    // The model's default search string is the junk value '" "': it must not
    // filter anything on first load.
    expect(find.text('Margaret Ellis'), findsOneWidget);
    expect(find.text('Harold Ellis'), findsOneWidget);
    expect(find.text('No care recipients match your search.'), findsNothing);

    // Narrow the list, then clear the box: all recipients come back.
    await search(tester, 'margaret');
    expect(find.text('Harold Ellis'), findsNothing);

    await search(tester, '');
    expect(find.text('Margaret Ellis'), findsOneWidget);
    expect(find.text('Harold Ellis'), findsOneWidget);
    expect(find.text('No care recipients match your search.'), findsNothing);
  });
}
