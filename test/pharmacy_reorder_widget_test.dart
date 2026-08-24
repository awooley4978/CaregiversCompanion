// Medication Reorder flow widget tests.
//
// Guards the two owner-required behaviors of the "Order"/"Reorder" action on
// the refill item (offline/deterministic, using the in-memory Firestore +
// Auth fakes and a fake url_launcher platform):
//   * No preferred pharmacy set -> tapping Order PROMPTS the user to choose a
//     pharmacy (owner req 4) and launches nothing.
//   * A pharmacy IS set -> tapping Order HANDS OFF (launches) that pharmacy's
//     refill page URL (owner req 3/7).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/backend/pharmacy/pharmacy_service.dart';
import 'package:new_project/components/refill_item/refill_item_widget.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'firebase_test_setup.dart';

class FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  final List<String> launchedUrls = [];

  @override
  final LinkDelegate? linkDelegate = null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeUrlLauncherPlatform urlLauncher;

  setUpAll(() async {
    await initFirebaseForTest();
    urlLauncher = FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = urlLauncher;
  });
  setUp(() {
    fakeFirestore.clear();
    urlLauncher.launchedUrls.clear();
  });

  Future<void> signIn(String uid) async {
    fakeAuthPlatform.emitSignedIn(uid: uid, email: '$uid@example.com');
    expect(FirebaseAuth.instance.currentUser, isNotNull);
  }

  Future<void> pumpRefillItem(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RefillItemWidget(name: 'Lisinopril'),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Reorder with NO pharmacy prompts the user to choose one',
      (tester) async {
    await signIn('u1'); // no preferredPharmacy stored
    await pumpRefillItem(tester);

    await tester.tap(find.text('Order'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The pharmacy chooser sheet is shown; nothing was launched.
    expect(find.text('Preferred Pharmacy'), findsOneWidget);
    expect(find.text('CVS'), findsOneWidget);
    expect(find.text('Walgreens'), findsOneWidget);
    expect(urlLauncher.launchedUrls, isEmpty);
  });

  testWidgets('Reorder with a pharmacy set hands off to its refill page',
      (tester) async {
    await signIn('u1');
    await PharmacyService().setPreferredPharmacy('u1', id: kPharmacyWalgreens);
    await pumpRefillItem(tester);

    await tester.tap(find.text('Order'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The correct Walgreens refill URL was opened; no chooser shown.
    expect(urlLauncher.launchedUrls, ['https://www.walgreens.com/refill']);
    expect(find.text('Preferred Pharmacy'), findsNothing);
  });
}
