// Page-connectivity QA fixes for the Daily Dashboard's nav-menu path
// (hamburger menu -> 'Daily Care' with no care recipient selected).
//
// Both guards live as top-level functions in c_daily_dashboard_widget.dart so
// their contract can be pinned without rendering the whole dashboard in a
// harness: rendering it bare trips a pre-existing, unrelated carechecklist
// orderBy TypeError.
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/pages/c_daily_dashboard/c_daily_dashboard_widget.dart';
import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initFirebaseForTest();
  });
  setUp(() {
    FFAppState.reset();
    fakeFirestore.clear();
  });

  group('dashboard Morning Vitals stream with no recipient selected', () {
    test('streams nothing instead of force-unwrapping a null selection', () {
      // The nav-menu 'Daily Care' path (and any fresh session) has no
      // selected care recipient.
      expect(FFAppState().selectedCareRecipient, isNull);

      // Before the fix the Morning Vitals section built its stream with
      // `CareRecipientsRecord.getDocument(FFAppState().selectedCareRecipient!)`,
      // which threw 'Null check operator used on a null value' while the page
      // built (red screen). The defensive deref streams nothing, and the
      // section's builder renders its empty state for that case.
      expect(selectedRecipientVitalsStream(), isNull);
    });
  });

  group('dashboard Care Checklist stream with no parent reference', () {
    test('emits an empty list instead of the denied collectionGroup query',
        () async {
      // parent == null is the nav-menu path: CarechecklistRecord.collection(null)
      // falls back to a collectionGroup('carechecklist') query, which the
      // Firestore rules deny (no `{path=**}/carechecklist` rule), and the
      // section then spun forever behind the missing error branch. The guard
      // streams an empty list — the section's existing empty state.
      final records = await carechecklistForParent(null).first;
      expect(records, isEmpty);
    });
  });
}
