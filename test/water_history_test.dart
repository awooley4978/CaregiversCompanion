// Water history (owner direction 2026-11-22, water-history-spec.md, unit 1 of 2).
//
// What is covered here:
//  * day grouping and ordering are DEVICE-LOCAL, and a late-evening entry stays
//    on its own local day (the `isSameLocalDay` regression class — run this
//    file in a non-UTC zone too, as ci.yml does);
//  * the day's INTAKE (sum of positive amounts) is kept apart from its NET
//    figure, both are shown when they differ, and a correction never makes a
//    total negative;
//  * an adjustment row reads "Adjusted −16 fl oz (to 32 fl oz)" and is not
//    counted as intake;
//  * an author resolves from the member record, and an unresolved one degrades
//    to the app's existing 'Unknown user' — never a uid;
//  * the read is recipient-scoped and bounded (the query itself is exercised,
//    not the network);
//  * the screen's loading, error-with-Retry and empty states each render, and a
//    failed read is never shown as an empty list;
//  * the Daily Water card's History link opens the screen for that recipient.
//
// TIMEZONE: the day filter must compare DEVICE-LOCAL calendar days, and the CI
// machine runs in UTC, where the bug is invisible. Run this file in a US zone
// to exercise it:  TZ=America/Chicago flutter test test/water_history_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:caregivers_companion/app_state.dart';
import 'package:caregivers_companion/backend/backend.dart';
import 'package:caregivers_companion/backend/water/water_history.dart';
import 'package:caregivers_companion/backend/water/water_intake.dart';
import 'package:caregivers_companion/components/daily_water_card/daily_water_card_widget.dart';
import 'package:caregivers_companion/pages/water_history/water_history_widget.dart';
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
    fakeFirestore.clearQueryError();
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

  /// Seeds one stored water entry through the app-facing write path.
  Future<void> seedWater({
    String recipientId = 'r1',
    required DateTime at,
    double amountFlOz = 8,
    String uid = 'uid-1',
    bool adjustment = false,
    double? targetFlOz,
  }) async {
    await WaterLogsRecord.collection.doc().set(
      createWaterLogsRecordData(
        careRecipientRef: recipientRef(recipientId),
        orgId: 'org_test',
        loggedByUid: uid,
        intakeAt: at,
        amount: amountFlOz.abs(),
        unit: waterUnitFlOz,
        amountFlOz: amountFlOz,
        adjustment: adjustment ? true : null,
        targetFlOz: targetFlOz,
      ),
    );
  }

  /// Seeds one member of the recipient's org, so an author can be resolved.
  Future<void> seedMember({
    String uid = 'uid-1',
    String? displayName = 'Dana Alvarez',
    String email = 'dana@example.com',
  }) async {
    fakeFirestore.writeDoc('organizations/org_test/members/$uid', {
      'uid': uid,
      'orgId': 'org_test',
      'role': 'caregiver',
      'status': 'active',
      if (displayName != null) 'displayName': displayName,
      'email': email,
    });
  }

  /// A record built in memory (no Firestore), for the pure helpers.
  WaterLogsRecord record({
    DateTime? at,
    double amountFlOz = 8,
    String uid = 'uid-1',
    bool adjustment = false,
    double? targetFlOz,
  }) =>
      WaterLogsRecord.getDocumentFromData(
        createWaterLogsRecordData(
          careRecipientRef: null,
          loggedByUid: uid,
          intakeAt: at,
          amount: amountFlOz.abs(),
          unit: waterUnitFlOz,
          amountFlOz: amountFlOz,
          adjustment: adjustment ? true : null,
          targetFlOz: targetFlOz,
        ),
        recipientRef(),
      );

  /// Pumps the history page itself. [noRecipient] exercises the branch where no
  /// care recipient is selected at all.
  Future<void> pumpPage(
    WidgetTester tester, {
    DocumentReference? recipient,
    bool noRecipient = false,
    DateTime? now,
  }) async {
    tester.view.physicalSize = const Size(1200.0, 2000.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: WaterHistoryWidget(
          careRecipients: noRecipient ? null : (recipient ?? recipientRef()),
          now: now ?? DateTime(2026, 11, 22, 18, 0),
        ),
      ),
    );
  }

  final now = DateTime(2026, 11, 22, 18, 0);
  DateTime todayAt(int hour, [int minute = 0]) =>
      DateTime(now.year, now.month, now.day, hour, minute);
  DateTime yesterdayAt(int hour, [int minute = 0]) =>
      DateTime(now.year, now.month, now.day - 1, hour, minute);
  DateTime dayBeforeAt(int hour, [int minute = 0]) =>
      DateTime(now.year, now.month, now.day - 2, hour, minute);

  group('day grouping and ordering are device-local', () {
    test('days are grouped by local calendar day, newest first', () {
      final days = groupWaterHistory(
        [
          record(at: todayAt(0, 5), amountFlOz: 8),
          // 11:30 pm yesterday: in UTC this instant can fall on a different
          // calendar day, which is exactly the bug this pins.
          record(at: yesterdayAt(23, 30), amountFlOz: 16),
          record(at: dayBeforeAt(10), amountFlOz: 24),
        ],
        now: now,
      );

      expect(days.map((day) => day.label), ['Today', 'Yesterday', 'Nov 20']);
      expect(days.map((day) => day.rows.length), [1, 1, 1]);
      expect(days[1].rows.single.amountLabel, '16 fl oz');
    });

    test('entries inside a day are newest first', () {
      final days = groupWaterHistory(
        [
          record(at: todayAt(8), amountFlOz: 8),
          record(at: todayAt(20), amountFlOz: 16),
          record(at: todayAt(12), amountFlOz: 24),
        ],
        now: now,
      );

      expect(days.single.rows.map((row) => row.amountLabel),
          ['16 fl oz', '24 fl oz', '8 fl oz']);
      expect(days.single.rows.first.timeLabel, '8:00 PM');
    });

    test('an entry with no logged time cannot be placed in a day', () {
      final days = groupWaterHistory(
        [record(at: null, amountFlOz: 8), record(at: todayAt(9), amountFlOz: 16)],
        now: now,
      );

      expect(days.single.rows.length, 1);
      expect(days.single.netFlOz, 16);
    });

    test('a day outside the window is not listed', () {
      final days = groupWaterHistory(
        [
          record(at: todayAt(9), amountFlOz: 8),
          record(
            at: DateTime(now.year, now.month, now.day - waterHistoryWindowDays),
            amountFlOz: 16,
          ),
        ],
        now: now,
      );

      expect(days.length, 1);
      expect(days.single.netFlOz, 8);
    });
  });

  group('daily totals distinguish intake from net', () {
    test('a day with intake and a correction shows both figures', () {
      final days = groupWaterHistory(
        [
          record(at: todayAt(8), amountFlOz: 32),
          record(at: todayAt(10), amountFlOz: 16),
          record(
            at: todayAt(12),
            amountFlOz: -16,
            adjustment: true,
            targetFlOz: 32,
          ),
        ],
        now: now,
      );

      final day = days.single;
      expect(day.intakeFlOz, 48);
      expect(day.netFlOz, 32);
      expect(day.totalsLabel, 'Intake 48 fl oz · Net 32 fl oz');
    });

    test('a day of intake only shows a single figure', () {
      final days = groupWaterHistory(
        [record(at: todayAt(8), amountFlOz: 16)],
        now: now,
      );

      expect(days.single.totalsLabel, '16 fl oz');
    });

    test('a correction never makes a total negative', () {
      final days = groupWaterHistory(
        [
          record(
            at: todayAt(9),
            amountFlOz: -8,
            adjustment: true,
            targetFlOz: 8,
          ),
        ],
        now: now,
      );

      expect(days.single.intakeFlOz, 0);
      expect(days.single.totalsLabel, '0 fl oz');
      expect(days.single.totalsLabel.contains('-'), isFalse);
      expect(waterHistoryDayTotalsLabel(0, -8), '0 fl oz');
    });
  });

  group('a correction is never shown as intake', () {
    test('an adjustment row uses the wording contract', () {
      final adjustment = record(
        at: todayAt(12),
        amountFlOz: -16,
        adjustment: true,
        targetFlOz: 32,
      );
      final intake = record(at: todayAt(8), amountFlOz: 16);

      expect(isWaterAdjustment(adjustment), isTrue);
      expect(isWaterAdjustment(intake), isFalse);
      expect(
        waterHistoryAmountLabel(adjustment),
        'Adjusted −16 fl oz (to 32 fl oz)',
      );
      expect(waterHistoryAmountLabel(intake), '16 fl oz');
    });

    test('an adjustment is excluded from the day intake figure', () {
      final days = groupWaterHistory(
        [
          record(at: todayAt(8), amountFlOz: 32),
          record(
            at: todayAt(12),
            amountFlOz: -16,
            adjustment: true,
            targetFlOz: 16,
          ),
        ],
        now: now,
      );

      final day = days.single;
      expect(day.intakeFlOz, 32);
      expect(day.netFlOz, 16);
      final adjustmentRow =
          day.rows.singleWhere((row) => row.isAdjustment);
      expect(adjustmentRow.amountLabel, 'Adjusted −16 fl oz (to 16 fl oz)');
    });

    test('a negative amount is a correction even without the flag', () {
      expect(isWaterAdjustment(record(at: todayAt(8), amountFlOz: -8)), isTrue);
    });
  });

  group('authors', () {
    test('a resolved name is shown as stored', () {
      expect(waterHistoryAuthorLabel('Dana Alvarez'), 'Dana Alvarez');
    });

    test('an unresolved author degrades to the app convention', () {
      expect(waterHistoryAuthorLabel(''), 'Unknown user');
      expect(waterHistoryAuthorLabel('   '), 'Unknown user');
    });

    test('a grouped row carries the resolved author', () {
      final days = groupWaterHistory(
        [record(at: todayAt(8), amountFlOz: 8, uid: 'uid-9')],
        now: now,
        authorNames: const {'uid-9': 'Sam Lee'},
      );

      expect(days.single.rows.single.authorLabel, 'Sam Lee');
    });

    testWidgets('the page resolves a member name and falls back honestly',
        (tester) async {
      await seedRecipient();
      await seedMember(uid: 'uid-1', displayName: 'Dana Alvarez');
      await seedWater(at: todayAt(8), amountFlOz: 16, uid: 'uid-1');
      // A second caregiver with no member record in this org.
      await seedWater(at: todayAt(9), amountFlOz: 8, uid: 'uid-unknown');

      await pumpPage(tester, now: now);
      await tester.pumpAndSettle();

      expect(find.text('Dana Alvarez'), findsOneWidget);
      expect(find.text('Unknown user'), findsOneWidget);
      expect(find.text('uid-unknown'), findsNothing);
    });
  });

  group('the read is recipient-scoped and bounded', () {
    test('only the recipient\'s own entries inside the window are read', () async {
      await seedRecipient();
      await seedRecipient(id: 'r2', name: 'Other Person');
      await seedWater(at: todayAt(8), amountFlOz: 8);
      await seedWater(at: yesterdayAt(9), amountFlOz: 16);
      // Outside the window.
      await seedWater(
        at: DateTime(now.year, now.month, now.day - waterHistoryWindowDays),
        amountFlOz: 32,
      );
      // Another recipient's entry, inside the window.
      await seedWater(recipientId: 'r2', at: todayAt(10), amountFlOz: 64);

      final entries = await waterHistoryEntriesForRecipient(
        recipientRef: recipientRef(),
        now: now,
      );

      expect(entries.map((entry) => entry.amountFlOz), [8, 16]);
      expect(
        entries.every(
            (entry) => entry.careRecipientRef?.path == 'careRecipients/r1'),
        isTrue,
      );
    });

    test('the read is capped at the documented limit', () async {
      await seedRecipient();
      for (var day = 0; day < 5; day++) {
        await seedWater(
          at: DateTime(now.year, now.month, now.day - day, 9),
          amountFlOz: 8,
        );
      }

      final all = await waterHistoryEntriesForRecipient(
        recipientRef: recipientRef(),
        now: now,
      );
      expect(all.length, 5);
      expect(waterHistoryReadLimit, greaterThanOrEqualTo(5));

      // The same query with a smaller bound returns only the newest entries,
      // which is what keeps an unbounded read impossible.
      final capped = await waterHistoryEntriesForRecipient(
        recipientRef: recipientRef(),
        now: now,
        limit: 2,
      );
      expect(capped.length, 2);
      expect(capped.first.amountFlOz, 8);
      expect(capped.first.intakeAt!.isAfter(capped.last.intakeAt!), isTrue);
    });

    test('no recipient means no query at all', () async {
      final entries = await waterHistoryEntriesForRecipient(
        recipientRef: null,
        now: now,
      );
      expect(entries, isEmpty);
    });
  });

  group('the screen shows the real entries', () {
    testWidgets('entries, corrections and day totals', (tester) async {
      await seedRecipient();
      await seedMember(uid: 'uid-1', displayName: 'Dana Alvarez');
      await seedWater(at: todayAt(8), amountFlOz: 16);
      await seedWater(at: todayAt(12, 30), amountFlOz: 8);
      await seedWater(
        at: todayAt(14),
        amountFlOz: -16,
        adjustment: true,
        targetFlOz: 32,
      );
      await seedWater(at: yesterdayAt(20), amountFlOz: 8, uid: 'uid-2');

      await pumpPage(tester, now: now);
      await tester.pumpAndSettle();

      expect(find.text('Water History'), findsOneWidget);
      expect(find.text('Margaret Alvarez'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Intake 24 fl oz · Net 8 fl oz'), findsOneWidget);
      expect(find.text('8 fl oz'), findsWidgets);
      expect(find.text('16 fl oz'), findsOneWidget);
      expect(
        find.text('Adjusted −16 fl oz (to 32 fl oz)'),
        findsOneWidget,
      );
      expect(find.text('8:00 AM'), findsOneWidget);
      expect(find.text('12:30 PM'), findsOneWidget);
      expect(find.text('Dana Alvarez'), findsOneWidget);
    });

    testWidgets('the loading state is a real progress indicator',
        (tester) async {
      await seedRecipient();
      await seedWater(at: todayAt(8), amountFlOz: 8);

      await pumpPage(tester, now: now);

      expect(
        find.byKey(const ValueKey('waterHistoryLoading')),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('waterHistoryLoading')), findsNothing);
    });

    testWidgets('the empty state is honest', (tester) async {
      await seedRecipient();

      await pumpPage(tester, now: now);
      await tester.pumpAndSettle();

      expect(find.text(waterHistoryEmpty), findsOneWidget);
      expect(find.byKey(const ValueKey('waterHistoryError')), findsNothing);
    });

    testWidgets('a failed read shows the error and Retry re-runs it',
        (tester) async {
      await seedRecipient();
      await seedWater(at: todayAt(8), amountFlOz: 16);
      fakeFirestore.queryError = Exception('permission-denied');

      await pumpPage(tester, now: now);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('waterHistoryError')), findsOneWidget);
      // A failed read is never disguised as an empty list.
      expect(find.text(waterHistoryEmpty), findsNothing);
      expect(find.text(waterHistoryRetry), findsOneWidget);

      // The read works again: Retry re-runs it and the entries appear.
      fakeFirestore.clearQueryError();
      await tester.tap(find.text(waterHistoryRetry));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('waterHistoryError')), findsNothing);
      expect(find.text('16 fl oz'), findsOneWidget);
    });

    testWidgets('with no care recipient the screen says so', (tester) async {
      await pumpPage(tester, noRecipient: true);
      await tester.pumpAndSettle();

      expect(find.text(waterHistoryNoRecipient), findsOneWidget);
      expect(find.text(waterHistoryEmpty), findsNothing);
    });
  });

  group('the water card opens the history', () {
    testWidgets('the History link opens the page for that recipient',
        (tester) async {
      tester.view.physicalSize = const Size(1200.0, 2000.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await seedRecipient();
      await seedMember(uid: 'uid-1', displayName: 'Dana Alvarez');
      final localNow = DateTime.now();
      await seedWater(
        at: DateTime(localNow.year, localNow.month, localNow.day, 8),
        amountFlOz: 16,
      );

      final router = GoRouter(
        initialLocation: '/host',
        routes: [
          GoRoute(
            path: '/host',
            builder: (_, __) => Scaffold(
              body: DailyWaterCardWidget(recipientRef: recipientRef()),
            ),
          ),
          // Registered the way lib/flutter_flow/nav/nav.dart registers it: the
          // card passes the recipient id as a query parameter.
          GoRoute(
            path: WaterHistoryWidget.routePath,
            name: WaterHistoryWidget.routeName,
            builder: (_, state) {
              final id = state.uri.queryParameters['careRecipientId'];
              return WaterHistoryWidget(
                careRecipients: id == null || id.isEmpty
                    ? null
                    : FirebaseFirestore.instance.doc('careRecipients/$id'),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('waterHistoryLink')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('waterHistoryLink')));
      await tester.pumpAndSettle();

      expect(find.text('Water History'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('8:00 AM'), findsOneWidget);
      expect(find.text('Dana Alvarez'), findsOneWidget);
    });

    testWidgets('the link is only offered when there is a recipient',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DailyWaterCardWidget(recipientRef: null)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('waterHistoryLink')), findsNothing);
    });
  });
}
