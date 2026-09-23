// Care-recipient picker sheet — owner round-5 finding #5 (PRE-EXISTING dead UI,
// not a PR #27 regression).
//
// Every row was `MouseRegion -> AnimatedContainer -> Padding -> Row` with no
// InkWell/GestureDetector/onTap anywhere in the file, so tapping a profile did
// nothing (rows only highlighted on hover), and the exported footer row had lost
// its content (an empty MouseRegion/AnimatedContainer) — the scrim was the only
// way out, which the owner experienced as "clicking does nothing and it gets
// stuck in that menu".
//
// These tests pump the sheet ALONE: it is self-contained (its recipients come
// from careRecipientsForActiveGroup()). Rendering the whole dashboard here would
// trip the pre-existing carechecklist orderBy TypeError
// (dashboard_page_connectivity_test.dart).
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/backend/schema/care_recipients_record.dart';
import 'package:new_project/components/patent_picker_sheet_widget.dart';
import 'package:new_project/pages/c_daily_dashboard/c_daily_dashboard_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_test_setup.dart';

/// A 1x1 transparent PNG (built and CRC-checked offline), used to satisfy the
/// rows' placeholder avatar from the image cache.
const _transparentPixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=';

/// Pre-seed the image cache so the rows' avatar never goes to the network in
/// this harness: flutter_test's mock HttpClient answers every request with a
/// 400, and the resulting NetworkImageLoadException is reported as a test
/// failure. Keyed by the same [NetworkImage] the sheet's `Image.network`
/// builds, so the provider resolves from the cache instead.
Future<void> seedPickerAvatar() async {
  final codec = await ui.instantiateImageCodec(
    base64Decode(_transparentPixelPng),
  );
  final frame = await codec.getNextFrame();
  PaintingBinding.instance.imageCache.putIfAbsent(
    const NetworkImage(recipientPickerAvatarUrl),
    () => OneFrameImageStreamCompleter(
      Future<ImageInfo>.value(ImageInfo(image: frame.image)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const orgId = 'org_test_1';

  setUpAll(() async {
    await initFirebaseForTest();
    await seedPickerAvatar();
  });

  setUp(() {
    FFAppState.reset();
    fakeFirestore.clear();
    // Tapping a row sets FFAppState().selectedCareRecipient, whose setter
    // persists the per-user selection through SharedPreferences.
    SharedPreferences.setMockInitialValues({});
  });

  Future<DocumentReference> seedRecipient(String id, String name) async {
    final ref = CareRecipientsRecord.collection.doc(id);
    await ref.set(createCareRecipientsRecordData(name: name, orgId: orgId));
    return ref;
  }

  // The value the sheet popped with, captured through the push future.
  var popped = false;
  DocumentReference? poppedWith;

  /// Pushes the sheet as its own route (by itself) and records what it pops
  /// with.
  Future<void> showPicker(WidgetTester tester) async {
    popped = false;
    poppedWith = null;
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push<DocumentReference?>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: PatentPickerSheetWidget()),
          ),
        )
        .then((value) {
      popped = true;
      poppedWith = value;
    });
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a row selects that recipient and pops with it',
      (tester) async {
    FFAppState().activeGroupId = orgId;
    await seedRecipient('mom', 'Mom');
    final dad = await seedRecipient('dad', 'Dad');

    await showPicker(tester);

    // Both of the active circle's recipients are listed...
    expect(find.text('Mom'), findsOneWidget);
    expect(find.text('Dad'), findsOneWidget);
    // ...and nothing is selected before the tap.
    expect(FFAppState().selectedCareRecipient, isNull);

    await tester.tap(find.text('Dad'));
    await tester.pumpAndSettle();

    // The sheet is gone, it popped with the chosen reference, and the app-wide
    // selection follows it (the value the dashboard's child sheets and cards
    // read).
    expect(find.byType(PatentPickerSheetWidget), findsNothing);
    expect(popped, isTrue);
    expect(poppedWith?.path, dad.path);
    expect(FFAppState().selectedCareRecipient?.path, dad.path);
  });

  testWidgets('the sheet has a visible way to dismiss it, popping no selection',
      (tester) async {
    FFAppState().activeGroupId = orgId;
    await seedRecipient('mom', 'Mom');
    await seedRecipient('dad', 'Dad');

    await showPicker(tester);

    // The exported footer row was an empty container: no close control at all.
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(PatentPickerSheetWidget), findsNothing);
    expect(popped, isTrue);
    expect(poppedWith, isNull);
    expect(FFAppState().selectedCareRecipient, isNull);
  });

  testWidgets('a dismissed sheet leaves the working recipient alone',
      (tester) async {
    FFAppState().activeGroupId = orgId;
    final mom = await seedRecipient('mom', 'Mom');
    await seedRecipient('dad', 'Dad');
    FFAppState().selectedCareRecipient = mom;

    await showPicker(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(poppedWith, isNull);
    expect(FFAppState().selectedCareRecipient?.path, mom.path);
  });

  // The dashboard chip that opens the sheet used to render hardcoded demo copy
  // ('M' / 'Mom') whatever was loaded, so the caregiver could not see which
  // profile was active.
  group('dashboard chip label', () {
    CareRecipientsRecord recipient(String id, String name) =>
        CareRecipientsRecord.getDocumentFromData(
          {'Name': name},
          FirebaseFirestore.instance.doc('careRecipients/$id'),
        );

    test('describes the working recipient, not a hardcoded name', () {
      final mom = recipient('mom', 'Mom');
      final dad = recipient('dad', 'Dad');

      expect(dashboardChipRecipient([mom, dad], dad.reference)?.name, 'Dad');
      // No selection resolved yet -> the first of the caller's recipients.
      expect(dashboardChipRecipient([mom, dad], null)?.name, 'Mom');
      // A stale selection from another circle never names the chip.
      expect(
        dashboardChipRecipient(
          [mom],
          FirebaseFirestore.instance.doc('careRecipients/gone'),
        )?.name,
        'Mom',
      );
      expect(dashboardChipRecipient(const [], null), isNull);
    });

    test('the avatar letter is the recipient\'s initial', () {
      expect(recipientChipInitial(recipient('mom', 'Mom')), 'M');
      expect(recipientChipInitial(recipient('blank', '   ')), '?');
      expect(recipientChipInitial(null), '?');
    });
  });
}
