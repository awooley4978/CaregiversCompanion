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
//    Undo removes exactly that tap; the glass already exactly at the total
//    writes nothing at all;
//  * tapping a glass BELOW today's total (owner decision 2026-11-22) writes ONE
//    negative adjustment document and lowers the total: never an edit or a
//    delete of anything that already existed, never below another caregiver's
//    own intake, and never below zero — see the "tap to lower" group;
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

  /// Seeds one intake by ANOTHER caregiver and returns the raw stored map, so a
  /// test can prove it was never touched.
  Future<Map<String, dynamic>> seedOtherCaregiverIntake({
    required String uid,
    required double amountFlOz,
  }) async {
    final ref = WaterLogsRecord.collection.doc();
    await ref.set(
      createWaterLogsRecordData(
        careRecipientRef: recipientRef(),
        orgId: 'org_test',
        loggedByUid: uid,
        intakeAt: DateTime.now(),
        amount: amountFlOz,
        unit: waterUnitFlOz,
        amountFlOz: amountFlOz,
      ),
    );
    return Map<String, dynamic>.from(fakeFirestore.docs[ref.path]!);
  }

  /// The raw stored map of the record written by [uid] holding [amountFlOz].
  Map<String, dynamic> rawRecordFor(String uid, double amountFlOz) =>
      Map<String, dynamic>.from(
        fakeFirestore.docs.values.singleWhere(
          (doc) =>
              doc['loggedByUid'] == uid && doc['amountFlOz'] == amountFlOz,
        ),
      );

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

    testWidgets('tapping the glass already exactly at the total writes nothing',
        (tester) async {
      await seedRecipient();
      await seedIntake(at: DateTime.now(), amountFlOz: 24);
      await pumpCard(tester);
      expect(filledGlasses(tester), 3);

      // Drop 3 is exactly at 24 fl oz: nothing to add and nothing to correct.
      await tester.tap(find.byKey(const ValueKey('waterGlass2')));
      await tester.pumpAndSettle();

      // No write, no snackbar, nothing removed to "empty" the glass.
      expect(waterDocs().length, 1);
      expect(find.text('24 fl oz'), findsOneWidget);
      expect(find.textContaining('fl oz added'), findsNothing);
      expect(find.textContaining('fl oz removed'), findsNothing);
      expect(find.textContaining('Nothing to reduce'), findsNothing);
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

  // ---------------------------------------------------------------------------
  // Tapping a drop BELOW today's total (owner decision 2026-11-22,
  // water-tap-to-empty-spec.md). A correction is ONE new adjustment document;
  // nothing that already exists is edited or deleted, and one caregiver's tap
  // can never eat into another caregiver's intake.
  // ---------------------------------------------------------------------------
  group('tap outcomes (adjustment entries)', () {
    final now = DateTime(2026, 11, 22, 15, 0);

    WaterLogsRecord entry({
      required double flOz,
      required String uid,
      bool adjustment = false,
      double? targetFlOz,
    }) =>
        WaterLogsRecord.getDocumentFromData(
          createWaterLogsRecordData(
            careRecipientRef: null,
            intakeAt: now,
            amount: flOz.abs(),
            unit: waterUnitFlOz,
            amountFlOz: flOz,
            loggedByUid: uid,
            adjustment: adjustment ? true : null,
            targetFlOz: targetFlOz,
          ),
          recipientRef(),
        );

    WaterTapOutcome tap(
      int glass,
      List<WaterLogsRecord> logs, {
      String uid = 'uid-1',
    }) =>
        waterTapOutcome(
          glassNumber: glass,
          logs: logs,
          now: now,
          uid: uid,
        );

    test('above the total fills, exactly at it does nothing, below corrects', () {
      final logs = [entry(flOz: 24, uid: 'uid-1')];

      final above = tap(4, logs); // 32 > 24
      expect(above.kind, WaterTapKind.fill);
      expect(above.amountFlOz, 8);
      expect(above.newTotalFlOz, 32);

      final at = tap(3, logs); // 24 == 24
      expect(at.kind, WaterTapKind.noOp);
      expect(at.writes, isFalse);
      expect(at.amountFlOz, 0);
      expect(at.message, isNull);

      final below = tap(2, logs); // 16 < 24
      expect(below.kind, WaterTapKind.correction);
      expect(below.amountFlOz, 8);
      expect(below.newTotalFlOz, 16);
      expect(below.targetFlOz, 16);
      expect(below.clamped, isFalse);
      expect(below.message, '8 fl oz removed');
    });

    test('a correction removes the difference when the caller has it to give',
        () {
      // 24 of the caller's own + 24 from another caregiver = 48.
      final logs = [
        entry(flOz: 24, uid: 'uid-1'),
        entry(flOz: 24, uid: 'uid-2'),
      ];
      final outcome = tap(4, logs);
      expect(outcome.kind, WaterTapKind.correction);
      expect(outcome.amountFlOz, 16); // 48 - 32
      expect(outcome.newTotalFlOz, 32);
      expect(outcome.clamped, isFalse);
      expect(outcome.message, '16 fl oz removed');
    });

    test('a correction stops at the caller\'s own intake and says why', () {
      // Only 8 of the caller's own; 40 from another caregiver.
      final logs = [
        entry(flOz: 8, uid: 'uid-1'),
        entry(flOz: 40, uid: 'uid-2'),
      ];
      final outcome = tap(1, logs); // wants 48 - 8 = 40, may give back 8
      expect(outcome.kind, WaterTapKind.correction);
      expect(outcome.amountFlOz, 8);
      expect(outcome.clamped, isTrue);
      // The total lands on the other caregiver's 40, never below it.
      expect(outcome.newTotalFlOz, 40);
      expect(outcome.message, waterReducedToMessage(40));
      expect(
        outcome.message,
        'Reduced to 40 fl oz — the rest was logged by another caregiver.',
      );
    });

    test('with nothing of their own to give back nothing is written', () {
      final logs = [entry(flOz: 48, uid: 'uid-2')];
      final outcome = tap(1, logs);
      expect(outcome.kind, WaterTapKind.noOp);
      expect(outcome.writes, isFalse);
      expect(outcome.amountFlOz, 0);
      expect(outcome.newTotalFlOz, 48);
      expect(outcome.message, waterNothingToReduce);
    });

    test('repeated corrections stay consistent and stop at the caller\'s net',
        () {
      final logs = [
        entry(flOz: 24, uid: 'uid-1'),
        entry(flOz: 24, uid: 'uid-2'),
      ];

      final first = tap(4, logs); // 48 → 32
      expect(first.kind, WaterTapKind.correction);
      expect(first.amountFlOz, 16);
      expect(first.newTotalFlOz, 32);
      logs.add(entry(flOz: -16, uid: 'uid-1', adjustment: true, targetFlOz: 32));

      final second = tap(3, logs); // 32 → 24, exactly the other caregiver's 24
      expect(second.kind, WaterTapKind.correction);
      expect(second.amountFlOz, 8);
      expect(second.newTotalFlOz, 24);
      expect(second.clamped, isFalse);
      logs.add(entry(flOz: -8, uid: 'uid-1', adjustment: true, targetFlOz: 24));

      // All of the caller's own water is given back: the total stays on the
      // other caregiver's 24 and the tap writes nothing.
      final third = tap(1, logs);
      expect(third.kind, WaterTapKind.noOp);
      expect(third.writes, isFalse);
      expect(third.message, waterNothingLeftToReduce);
      expect(waterTotalFlOz(logs, now), 24);

      // Filling still works after a correction.
      expect(tap(4, logs).kind, WaterTapKind.fill);
    });

    test('no tap can push the total below zero or below another caregiver', () {
      final days = <List<WaterLogsRecord>>[
        [],
        [entry(flOz: 8, uid: 'uid-2')],
        [entry(flOz: 8, uid: 'uid-1')],
        [entry(flOz: 8, uid: 'uid-1'), entry(flOz: 48, uid: 'uid-2')],
        [
          entry(flOz: 24, uid: 'uid-1'),
          entry(flOz: 24, uid: 'uid-2'),
          entry(flOz: -16, uid: 'uid-1', adjustment: true, targetFlOz: 32),
        ],
        // Defensive: adjustments already outweigh the intake of the caller.
        [
          entry(flOz: 8, uid: 'uid-2'),
          entry(flOz: -24, uid: 'uid-1', adjustment: true, targetFlOz: 0),
        ],
        // Defensive: a day whose net total is already negative.
        [
          entry(flOz: 8, uid: 'uid-2'),
          entry(flOz: -40, uid: 'uid-1', adjustment: true, targetFlOz: 0),
        ],
      ];

      for (final logs in days) {
        final othersTotal = logs
            .where((log) => log.loggedByUid != 'uid-1')
            .fold<double>(0, (sum, log) => sum + log.amountFlOz);
        for (var glass = 1; glass <= waterGlassCount; glass++) {
          final outcome = tap(glass, logs);
          expect(outcome.newTotalFlOz, greaterThanOrEqualTo(0));
          if (outcome.isCorrection) {
            expect(outcome.amountFlOz, greaterThan(0));
            expect(outcome.newTotalFlOz, greaterThanOrEqualTo(othersTotal));
          }
        }
      }
    });

    test('an adjustment is distinguishable from intake', () {
      final intake = entry(flOz: 24, uid: 'uid-1');
      final adjustment =
          entry(flOz: -16, uid: 'uid-1', adjustment: true, targetFlOz: 32);

      expect(intake.adjustment, isFalse);
      expect(intake.amountFlOz, 24);
      expect(adjustment.adjustment, isTrue);
      // The magnitude stays positive for the rules; the sign carries the effect.
      expect(adjustment.amount, 16);
      expect(adjustment.amountFlOz, -16);
      expect(adjustment.targetFlOz, 32);

      final logs = [intake, entry(flOz: 24, uid: 'uid-2'), adjustment];
      // The card's total is the signed net; a report's intake counts intake only.
      expect(waterTotalFlOz(logs, now), 32);
      expect(waterIntakeOnlyFlOz(logs, now), 48);

      // The wording contract for a history row / report line.
      expect(
        formatWaterAdjustment(adjustment.amountFlOz, adjustment.targetFlOz),
        'Adjusted −16 fl oz (to 32 fl oz)',
      );
    });
  });

  group('tap to lower (adjustment entries)', () {
    testWidgets('tapping a lower drop writes ONE adjustment, lowers the total',
        (tester) async {
      await seedRecipient();
      // The caller logged 24 fl oz of their own; another caregiver logged 24.
      await seedIntake(at: DateTime.now(), amountFlOz: 24);
      final otherRaw =
          await seedOtherCaregiverIntake(uid: 'uid-2', amountFlOz: 24);
      await pumpCard(tester);
      expect(find.text('48 fl oz'), findsOneWidget);
      expect(filledGlasses(tester), 6);

      await tester.tap(find.byKey(const ValueKey('waterGlass3'))); // drop 4
      await tester.pumpAndSettle();

      // ONE new document: the two intakes stay, nothing was removed.
      expect(waterDocs().length, 3);
      final saved = await savedWater();
      expect(saved.where((record) => record.adjustment), hasLength(1));
      expect(saved.where((record) => !record.adjustment), hasLength(2));

      final adjustment = saved.singleWhere((record) => record.adjustment);
      expect(adjustment.amountFlOz, -16);
      expect(adjustment.amount, 16);
      expect(adjustment.targetFlOz, 32);
      expect(adjustment.loggedByUid, 'uid-1');
      expect(adjustment.unit, waterUnitFlOz);
      expect(adjustment.orgId, 'org_test');
      expect(adjustment.careRecipientRef?.path, 'careRecipients/r1');
      expect(adjustment.intakeAt, isNotNull);

      // The total is the honest net figure; drops 1-4 are filled.
      expect(find.text('32 fl oz'), findsOneWidget);
      expect(filledGlasses(tester), 4);
      expect(find.text('16 fl oz removed'), findsOneWidget);

      // The other caregiver's record is byte-identical before and after.
      expect(rawRecordFor('uid-2', 24), equals(otherRaw));
      // And the caller's own earlier intake is untouched.
      expect(rawRecordFor('uid-1', 24)['amountFlOz'], 24);
    });

    testWidgets('with none of their own intake the tap writes nothing, says so',
        (tester) async {
      await seedRecipient();
      final otherRaw =
          await seedOtherCaregiverIntake(uid: 'uid-2', amountFlOz: 48);
      await pumpCard(tester);
      expect(find.text('48 fl oz'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('waterGlass0'))); // drop 1
      await tester.pumpAndSettle();

      // No write, no Undo, and the honest reason — the other caregiver's 48
      // fl oz is intact.
      expect(waterDocs().length, 1);
      expect(find.text(waterNothingToReduce), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
      expect(find.text('48 fl oz'), findsOneWidget);
      expect(filledGlasses(tester), 6);
      expect(rawRecordFor('uid-2', 48), equals(otherRaw));
    });

    testWidgets('Undo deletes exactly the adjustment and restores the total',
        (tester) async {
      await seedRecipient();
      await seedIntake(at: DateTime.now(), amountFlOz: 24);
      final otherRaw =
          await seedOtherCaregiverIntake(uid: 'uid-2', amountFlOz: 24);
      await pumpCard(tester);

      await tester.tap(find.byKey(const ValueKey('waterGlass3')));
      await tester.pumpAndSettle();
      expect(find.text('32 fl oz'), findsOneWidget);
      expect(filledGlasses(tester), 4);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      // Only the adjustment is gone; both intakes are exactly as they were.
      expect(waterDocs().length, 2);
      expect(find.text('48 fl oz'), findsOneWidget);
      expect(filledGlasses(tester), 6);
      expect(rawRecordFor('uid-2', 24), equals(otherRaw));
      expect(rawRecordFor('uid-1', 24)['amountFlOz'], 24);
    });

    testWidgets('a custom amount is unchanged and survives a later correction',
        (tester) async {
      await seedRecipient();
      await seedOtherCaregiverIntake(uid: 'uid-2', amountFlOz: 24);
      await pumpCard(tester);

      // Custom amount: one positive intake record, its own snackbar, no Undo.
      await tester.tap(find.byKey(const ValueKey('waterCustomAmount')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('waterAmountField')), '16');
      await tester.tap(find.byKey(const ValueKey('waterAmountAdd')));
      await tester.pumpAndSettle();

      expect(waterDocs().length, 2);
      final custom =
          (await savedWater()).singleWhere((record) => record.amountFlOz == 16);
      expect(custom.adjustment, isFalse);
      expect(custom.amount, 16);
      expect(custom.targetFlOz, 0);
      expect(find.text('40 fl oz'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
      final customRaw = rawRecordFor('uid-1', 16);

      // A later correction can only give back the caller's own 16, so the total
      // stops on the other caregiver's 24 and the snackbar says why.
      await tester.tap(find.byKey(const ValueKey('waterGlass1'))); // drop 2
      await tester.pumpAndSettle();

      expect(waterDocs().length, 3);
      final adjustment = (await savedWater())
          .singleWhere((record) => record.adjustment);
      expect(adjustment.amountFlOz, -16);
      expect(adjustment.targetFlOz, 16);
      expect(find.text('24 fl oz'), findsOneWidget);
      expect(find.text(waterReducedToMessage(24)), findsOneWidget);
      // The custom entry itself is never edited by the correction.
      expect(rawRecordFor('uid-1', 16), equals(customRaw));
    });
  });
}
