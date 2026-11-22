// Water tracking unit (owner decisions 2026-11-13, proposal §4/§7/§9).
//
// What is covered here:
//  * the derivation helpers — device-local day, fl-oz total, the
//    min(9, floor(total / 8)) glass count, formatting, and the input-sanity
//    bounds for a custom amount;
//  * the empty state is a real derived zero ("0 fl oz") with nine outlined
//    glasses;
//  * a seeded day renders the real fl-oz total and the right filled count;
//  * past 72 fl oz all nine glasses stay filled and the total keeps counting
//    (the glasses are not a goal);
//  * tapping glass N writes exactly ONE record holding the difference up to N
//    (tap 4 from empty → 32 fl oz; tap 4 with 8 fl oz logged → 24 fl oz), so
//    Undo removes exactly that tap; a filled glass writes nothing at all;
//  * the custom-amount sheet writes the entered amount, and invalid input
//    writes nothing and names the field and its range;
//  * Undo deletes exactly the record that action created, and a refused delete
//    keeps the entry and says so;
//  * a failed read shows the honest error state and no total;
//  * switching care recipients never shows another recipient's intake.
//
// TIMEZONE: the day filter must compare DEVICE-LOCAL calendar days, and the CI
// machine runs in UTC, where the bug is invisible. Run this file in a US zone
// to exercise it:  TZ=America/Chicago flutter test test/water_tracking_test.dart
// (ci.yml runs exactly that as a second, non-UTC test step).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregivers_companion/app_state.dart';
import 'package:caregivers_companion/backend/backend.dart';
import 'package:caregivers_companion/backend/water/water_intake.dart';
import 'package:caregivers_companion/components/daily_water_card/daily_water_card_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initFirebaseForTest();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FFAppState.reset();
    fakeFirestore.clear();
    fakeFirestore.clearWriteError();
    FFAppState().selectedCareRecipient = null;
    FFAppState().activeGroupId = null;
    fakeAuthPlatform.emitSignedIn(uid: 'uid-1', email: 'cg@example.com');
  });

  DocumentReference recipientRef([String id = 'r1']) =>
      FirebaseFirestore.instance.doc('careRecipients/$id');

  Future<void> seedRecipient({
    String id = 'r1',
    String name = 'Margaret Alvarez',
    String orgId = 'org_test',
  }) async {
    await recipientRef(id).set({'Name': name, 'orgId': orgId});
  }

  /// Seeds one intake through the app-facing write path.
  Future<void> seedIntake({
    String recipientId = 'r1',
    required DateTime at,
    double amountFlOz = 8,
    String uid = 'uid-1',
    String orgId = 'org_test',
  }) async {
    await WaterLogsRecord.collection.doc().set(
      createWaterLogsRecordData(
        careRecipientRef: recipientRef(recipientId),
        orgId: orgId,
        loggedByUid: uid,
        intakeAt: at,
        amount: amountFlOz,
        unit: waterUnitFlOz,
        amountFlOz: amountFlOz,
      ),
    );
  }

  List<MapEntry<String, Map<String, dynamic>>> waterDocs() => fakeFirestore
      .docs
      .entries
      .where((entry) => entry.key.startsWith('waterLogs/'))
      .toList();

  /// Reads the saved entries through the app-facing path (the raw stored map
  /// holds platform refs, which must not be parsed into records).
  Future<List<WaterLogsRecord>> savedWater([String recipientId = 'r1']) =>
      queryWaterLogsRecordOnce(
        queryBuilder: (q) =>
            q.where('careRecipientRef', isEqualTo: recipientRef(recipientId)),
      );

  /// Pumps the card. Pass [noRecipient] to exercise the no-recipient branch
  /// (an explicit `recipient: null` is indistinguishable from "not supplied").
  Future<void> pumpCard(
    WidgetTester tester, {
    DocumentReference? recipient,
    bool noRecipient = false,
    Stream<List<WaterLogsRecord>>? streamOverride,
  }) async {
    tester.view.physicalSize = const Size(1200.0, 2000.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyWaterCardWidget(
            recipientRef: noRecipient ? null : (recipient ?? recipientRef()),
            streamOverride: streamOverride,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// How many of the nine glass icons are drawn filled.
  int filledGlasses(WidgetTester tester) => tester
      .widgetList(find.descendant(
        of: find.byKey(const ValueKey('waterGlasses')),
        matching: find.byIcon(Icons.water_drop),
      ))
      .length;

  /// How many are drawn outlined (always nine — the icon count).
  int outlinedGlasses(WidgetTester tester) => tester
      .widgetList(find.descendant(
        of: find.byKey(const ValueKey('waterGlasses')),
        matching: find.byIcon(Icons.water_drop_outlined),
      ))
      .length;

  group('derivation helpers', () {
    final now = DateTime(2026, 11, 13, 15, 30);
    final yesterday = DateTime(2026, 11, 12, 23, 30);
    final earlyToday = DateTime(2026, 11, 13, 0, 5);

    WaterLogsRecord log(DateTime? at, double flOz) =>
        WaterLogsRecord.getDocumentFromData(
          createWaterLogsRecordData(
            careRecipientRef: null,
            intakeAt: at,
            amount: flOz,
            unit: waterUnitFlOz,
            amountFlOz: flOz,
          ),
          recipientRef(),
        );

    test('only the device-local day counts toward today', () {
      final logs = [
        log(earlyToday, 8),
        log(now, 16),
        log(yesterday, 40),
      ];
      expect(waterTotalFlOz(logs, now), 24);
    });

    // The CI machine runs in UTC, where a raw-field comparison and a local-day
    // comparison agree, so this case is only meaningful outside UTC. Dart's
    // `toLocal()` honours the TZ environment variable: `ci.yml` re-runs THIS
    // file with `TZ=America/Chicago`, and the same command reproduces it
    // locally. On the pre-fix code (raw `year/month/day` on the UTC instant)
    // this test fails: 2026-11-22 (UTC) != 2026-11-21 (local).
    test('an evening UTC instant counts toward the device-local day', () {
      // 01:15 UTC on Nov 22 is 19:15 on Nov 21 in Chicago (UTC-6).
      final loggedAt = DateTime.utc(2026, 11, 22, 1, 15);
      final localLoggedAt = loggedAt.toLocal();
      final localNow = DateTime(
        localLoggedAt.year,
        localLoggedAt.month,
        localLoggedAt.day,
        19,
        30,
      );

      expect(waterLogsForLocalDay([log(loggedAt, 8)], localNow), hasLength(1));
      expect(waterTotalFlOz([log(loggedAt, 8)], localNow), 8);
      // A record logged the next local evening is still a different day.
      final nextEvening = localNow.add(const Duration(days: 1));
      expect(waterTotalFlOz([log(loggedAt, 8)], nextEvening), 0);
    });

    test('a record without intakeAt cannot be placed in a day', () {
      expect(waterTotalFlOz([log(null, 8)], now), 0);
    });

    test('filled glasses are 8 fl oz each, capped at nine', () {
      expect(waterGlassesFilled(0), 0);
      expect(waterGlassesFilled(7.9), 0);
      expect(waterGlassesFilled(8), 1);
      expect(waterGlassesFilled(16), 2);
      expect(waterGlassesFilled(72), 9);
      expect(waterGlassesFilled(88), 9);
    });

    test('a tap adds the difference up to the tapped glass', () {
      // From an empty day, glass N adds N glasses.
      expect(waterAmountToAddForGlass(1, 0), 8);
      expect(waterAmountToAddForGlass(4, 0), 32);
      expect(waterAmountToAddForGlass(9, 0), 72);
      // 72 fl oz is the most one tap can add, well under the 200 fl oz ceiling.
      expect(waterAmountToAddForGlass(9, 0), lessThan(waterMaxEntryFlOz));
    });

    test('a partially filled day only adds the missing glasses', () {
      // 12 fl oz → glass 1 is filled (and glass 2 is not).
      expect(waterAmountToAddForGlass(1, 12), 0);
      expect(waterAmountToAddForGlass(2, 12), 4);
      expect(waterAmountToAddForGlass(3, 12), 12);
      // 8 fl oz already logged: tap 4 adds 24, reaching 32.
      expect(waterAmountToAddForGlass(4, 8), 24);
    });

    test('a glass that is already filled adds nothing', () {
      expect(waterAmountToAddForGlass(1, 8), 0);
      expect(waterAmountToAddForGlass(1, 40), 0);
      expect(waterAmountToAddForGlass(4, 32), 0);
      expect(waterAmountToAddForGlass(4, 33), 0);
    });

    test('with all nine filled every tap adds nothing', () {
      for (var glass = 1; glass <= waterGlassCount; glass++) {
        expect(waterAmountToAddForGlass(glass, 72), 0);
        expect(waterAmountToAddForGlass(glass, 88), 0);
      }
    });

    test('glass numbers outside the nine drawn glasses add nothing', () {
      expect(waterAmountToAddForGlass(0, 0), 0);
      expect(waterAmountToAddForGlass(-1, 0), 0);
      expect(waterAmountToAddForGlass(10, 0), 0);
    });

    test('the total is formatted in fluid ounces without a goal', () {
      expect(formatWaterFlOz(0), '0 fl oz');
      expect(formatWaterFlOz(24), '24 fl oz');
      expect(formatWaterFlOz(12.5), '12.5 fl oz');
    });

    test('a custom amount is sanity-checked, not interpreted', () {
      expect(validateWaterAmount('8').amount, 8);
      expect(validateWaterAmount(' 12.5 ').amount, 12.5);
      expect(validateWaterAmount('').error, 'Amount (fl oz) is required.');
      expect(validateWaterAmount('abc').error,
          'Amount (fl oz) must be a number between 0 and 200.');
      expect(validateWaterAmount('0').error,
          'Amount (fl oz) must be greater than 0 and no more than 200.');
      expect(validateWaterAmount('-8').error,
          'Amount (fl oz) must be greater than 0 and no more than 200.');
      expect(validateWaterAmount('201').error,
          'Amount (fl oz) must be greater than 0 and no more than 200.');
      expect(validateWaterAmount('200').isValid, isTrue);
    });
  });

  group('the card', () {
    testWidgets('a successful read with no intake shows a real zero',
        (tester) async {
      await seedRecipient();
      await pumpCard(tester);

      expect(find.text('Daily Water Intake'), findsOneWidget);
      expect(find.text('Click to add water'), findsOneWidget);
      expect(find.byKey(const ValueKey('waterTotal')), findsOneWidget);
      expect(find.text('0 fl oz'), findsOneWidget);
      expect(outlinedGlasses(tester), 9);
      expect(filledGlasses(tester), 0);
      // No goal language anywhere on the card.
      expect(find.textContaining('of 9'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('goal'), findsNothing);
    });

    testWidgets('a seeded day renders the real total and filled glasses',
        (tester) async {
      await seedRecipient();
      final now = DateTime.now();
      await seedIntake(at: now, amountFlOz: 8);
      await seedIntake(at: now, amountFlOz: 16);
      await pumpCard(tester);

      expect(find.text('24 fl oz'), findsOneWidget);
      expect(filledGlasses(tester), 3);
      expect(outlinedGlasses(tester), 9);
    });

    testWidgets('past 72 fl oz the glasses stay full and the total counts on',
        (tester) async {
      await seedRecipient();
      final now = DateTime.now();
      await seedIntake(at: now, amountFlOz: 8);
      await seedIntake(at: now, amountFlOz: 80);
      await pumpCard(tester);

      expect(find.text('88 fl oz'), findsOneWidget);
      expect(filledGlasses(tester), 9);
    });

    testWidgets('a failed read shows the honest error state, never a zero',
        (tester) async {
      await seedRecipient();
      await pumpCard(
        tester,
        streamOverride: Stream<List<WaterLogsRecord>>.error(
          Exception('permission-denied'),
        ),
      );

      expect(find.byKey(const ValueKey('waterLoadError')), findsOneWidget);
      expect(find.text(waterCouldNotLoad), findsOneWidget);
      expect(find.byKey(const ValueKey('waterTotal')), findsNothing);
      expect(find.text('0 fl oz'), findsNothing);
      expect(filledGlasses(tester), 0);
    });

    testWidgets('with no recipient the card says so and offers no add',
        (tester) async {
      await pumpCard(tester, noRecipient: true);

      expect(find.text(waterSelectRecipient), findsOneWidget);
      expect(find.byKey(const ValueKey('waterCustomAmount')), findsNothing);
      expect(outlinedGlasses(tester), 9);
    });

    testWidgets('switching recipients never shows the previous one\'s intake',
        (tester) async {
      await seedRecipient(id: 'r1');
      await seedRecipient(id: 'r2');
      await seedIntake(recipientId: 'r1', at: DateTime.now(), amountFlOz: 24);

      await pumpCard(tester, recipient: recipientRef('r1'));
      expect(find.text('24 fl oz'), findsOneWidget);

      await pumpCard(tester, recipient: recipientRef('r2'));
      expect(find.text('0 fl oz'), findsOneWidget);
      expect(find.text('24 fl oz'), findsNothing);
      expect(filledGlasses(tester), 0);
    });
  });

  group('quick-add', () {
    testWidgets('tapping a glass writes ONE attributed 8 fl oz record',
        (tester) async {
      await seedRecipient(orgId: 'org_test');
      await pumpCard(tester);

      await tester.tap(find.byKey(const ValueKey('waterGlass0')));
      await tester.pumpAndSettle();

      expect(waterDocs().length, 1);
      final saved = (await savedWater()).single;
      expect(saved.careRecipientRef?.path, 'careRecipients/r1');
      expect(saved.orgId, 'org_test');
      expect(saved.loggedByUid, 'uid-1');
      expect(saved.unit, waterUnitFlOz);
      expect(saved.amount, 8);
      expect(saved.amountFlOz, 8);
      expect(saved.intakeAt, isNotNull);
      expect(saved.intakeAt!.isAfter(
            DateTime.now().add(const Duration(minutes: 1)),
          ),
          isFalse);

      // The card refreshes from Firestore: 8 fl oz, one glass filled.
      expect(find.text('8 fl oz'), findsOneWidget);
      expect(filledGlasses(tester), 1);
    });

    testWidgets('tapping glass 4 fills glasses 1-4 with ONE record',
        (tester) async {
      await seedRecipient(orgId: 'org_test');
      await seedIntake(at: DateTime.now(), amountFlOz: 8);
      await pumpCard(tester);
      expect(filledGlasses(tester), 1);

      await tester.tap(find.byKey(const ValueKey('waterGlass3')));
      await tester.pumpAndSettle();

      // One new document holding the difference up to 32 fl oz, attributed.
      expect(waterDocs().length, 2);
      final added = (await savedWater())
          .where((record) => record.amountFlOz == 24)
          .single;
      expect(added.amount, 24);
      expect(added.unit, waterUnitFlOz);
      expect(added.orgId, 'org_test');
      expect(added.loggedByUid, 'uid-1');
      expect(find.text('24 fl oz added'), findsOneWidget);

      // The card refreshes from Firestore: 32 fl oz, four glasses filled.
      expect(find.text('32 fl oz'), findsOneWidget);
      expect(filledGlasses(tester), 4);

      // Undo removes exactly the record that tap created — the 8 fl oz
      // entry logged earlier stays.
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(waterDocs().length, 1);
      expect((await savedWater()).single.amountFlOz, 8);
      expect(find.text('8 fl oz'), findsOneWidget);
      expect(filledGlasses(tester), 1);
    });

    testWidgets('tapping an already filled glass writes nothing',
        (tester) async {
      await seedRecipient();
      await seedIntake(at: DateTime.now(), amountFlOz: 24);
      await pumpCard(tester);
      expect(filledGlasses(tester), 3);

      await tester.tap(find.byKey(const ValueKey('waterGlass0')));
      await tester.pumpAndSettle();

      // No write, no snackbar, nothing removed to "empty" the glass.
      expect(waterDocs().length, 1);
      expect(find.text('24 fl oz'), findsOneWidget);
      expect(find.textContaining('fl oz added'), findsNothing);
    });

    testWidgets('the ~5 s Undo removes exactly the record that was added',
        (tester) async {
      await seedRecipient();
      await pumpCard(tester);

      await tester.tap(find.byKey(const ValueKey('waterGlass0')));
      await tester.pumpAndSettle();
      expect(waterDocs().length, 1);
      expect(find.text('8 fl oz added'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(waterDocs(), isEmpty);
      expect(find.text('0 fl oz'), findsOneWidget);
    });

    testWidgets('a refused Undo keeps the entry and says so', (tester) async {
      await seedRecipient();
      await pumpCard(tester);

      await tester.tap(find.byKey(const ValueKey('waterGlass0')));
      await tester.pumpAndSettle();
      expect(waterDocs().length, 1);

      fakeFirestore.writeError = Exception('permission-denied');
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      fakeFirestore.clearWriteError();

      // Nothing was removed, and the card says the entry was kept.
      expect(waterDocs().length, 1);
      expect(find.text(waterUndoKept), findsWidgets);
    });

    testWidgets('a rejected write is reported and writes nothing',
        (tester) async {
      await seedRecipient();
      await pumpCard(tester);

      fakeFirestore.writeError = Exception('permission-denied');
      await tester.tap(find.byKey(const ValueKey('waterGlass0')));
      await tester.pumpAndSettle();
      fakeFirestore.clearWriteError();

      expect(waterDocs(), isEmpty);
      expect(find.textContaining('Could not save this water entry'),
          findsOneWidget);
    });
  });

  group('custom amount', () {
    testWidgets('writes the entered amount at now', (tester) async {
      await seedRecipient();
      await pumpCard(tester);

      await tester.tap(find.byKey(const ValueKey('waterCustomAmount')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('waterAmountField')), '12.5');
      await tester.tap(find.byKey(const ValueKey('waterAmountAdd')));
      await tester.pumpAndSettle();

      expect(waterDocs().length, 1);
      final saved = (await savedWater()).single;
      expect(saved.amount, 12.5);
      expect(saved.amountFlOz, 12.5);
      expect(saved.unit, waterUnitFlOz);
      expect(saved.loggedByUid, 'uid-1');
    });

    testWidgets('invalid input writes nothing and names the field and range',
        (tester) async {
      await seedRecipient();
      await pumpCard(tester);

      await tester.tap(find.byKey(const ValueKey('waterCustomAmount')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('waterAmountField')), '0');
      await tester.tap(find.byKey(const ValueKey('waterAmountAdd')));
      await tester.pumpAndSettle();

      expect(waterDocs(), isEmpty);
      expect(find.byKey(const ValueKey('waterAmountError')), findsOneWidget);
      expect(
        find.text(
            'Amount (fl oz) must be greater than 0 and no more than 200.'),
        findsOneWidget,
      );
    });

    testWidgets('Cancel writes nothing', (tester) async {
      await seedRecipient();
      await pumpCard(tester);

      await tester.tap(find.byKey(const ValueKey('waterCustomAmount')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('waterAmountField')), '10');
      await tester.tap(find.byKey(const ValueKey('waterAmountCancel')));
      await tester.pumpAndSettle();

      expect(waterDocs(), isEmpty);
      expect(find.byKey(const ValueKey('waterAmountField')), findsNothing);
    });
  });
}
