// The Medications page's med card and the Daily Dashboard's dose card, after the
// owner's 2026-11-21 report: the Medications tracker rendered a solid gray
// block, and the dashboard kept a green 'Taken' button beside "All of today's
// doses are taken." that could only answer "No pending dose to mark as taken.".
//
// Three contracts are pinned here:
//
//   1. MedCardWidget PAINTS. It used to throw before its first frame — the
//      component model's `initState` read `widget!.taken`, but
//      `FlutterFlowModel._init` runs `initState` BEFORE it attaches the widget,
//      so `widget` was still null. The throw was caught by the enclosing
//      StreamBuilder and replaced with the release-mode gray ErrorWidget, which
//      is why the whole tracker page went gray as soon as one medication
//      existed. No existing test ever built a card, so CI stayed green.
//   2. the dose card's 'Taken' button is rendered only when a dose is pending
//      for TODAY (the predicate the card uses is pinned here).
//   3. the dose card is re-evaluated when the LOCAL DATE changes — at the next
//      local midnight, and on app resume — so yesterday's "taken" clears itself
//      with no user action.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregivers_companion/app_state.dart';
import 'package:caregivers_companion/backend/backend.dart';
import 'package:caregivers_companion/components/local_date_refresh/local_date_refresh.dart';
import 'package:caregivers_companion/components/med_card/med_card_widget.dart';
import 'package:caregivers_companion/pages/c_daily_dashboard/c_daily_dashboard_widget.dart';
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
  });

  /// Pumps ONE medication card — the component the tracker renders per record.
  Future<void> pumpMedCard(
    WidgetTester tester, {
    required bool taken,
    void Function(bool taken)? onTakenChanged,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<FFAppState>.value(
        value: FFAppState(),
        child: MaterialApp(
          home: Scaffold(
            body: MedCardWidget(
              icon: const Icon(Icons.medication_rounded),
              name: 'Amlodipine',
              dosage: '10mg - 1 tablet',
              time: '08:00 AM',
              taken: taken,
              onTakenChanged: onTakenChanged,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Seeds one `medications` document through the app-facing write path and
  /// parses it back into the record the dose card is given.
  Future<MedicationsRecord> seedMedication(
    String id, {
    String name = 'Donepezil',
    String dose = '10mg',
    DateTime? takenAt,
  }) async {
    final ref = FirebaseFirestore.instance.collection('medications').doc(id);
    await ref.set({
      'medicationName': name,
      'dose': dose,
      'taken': takenAt != null,
      if (takenAt != null) 'takenAt': takenAt,
    });
    final snap = await ref.get();
    return MedicationsRecord.getDocumentFromData(snap.data()!, ref);
  }

  // -------------------------------------------------------------------------
  // 1. The card paints instead of throwing (the gray Medications page).
  // -------------------------------------------------------------------------
  group('MedCardWidget renders (gray Medications page)', () {
    testWidgets('a taken card paints its record instead of throwing',
        (tester) async {
      await pumpMedCard(tester, taken: true);

      // Pre-fix this threw 'Null check operator used on a null value' while the
      // model initialized, and Flutter swapped the subtree for a gray box.
      expect(tester.takeException(), isNull);
      expect(find.byType(MedCardWidget), findsOneWidget);
      expect(find.text('Amlodipine'), findsOneWidget);
      expect(find.text('10mg - 1 tablet'), findsOneWidget);
    });

    testWidgets('a pending card renders PENDING and toggles to TAKEN on tap',
        (tester) async {
      bool? reported;
      await pumpMedCard(
        tester,
        taken: false,
        onTakenChanged: (value) => reported = value,
      );

      expect(tester.takeException(), isNull);
      // The live state is seeded from the widget param (the model starts false
      // and `initState` cannot read the widget).
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('TAKEN'), findsNothing);

      await tester.tap(find.byIcon(Icons.check_circle_rounded));
      await tester.pump();

      expect(find.text('TAKEN'), findsOneWidget);
      expect(reported, isTrue);
    });

    testWidgets('a taken card seeded through the widget starts TAKEN',
        (tester) async {
      await pumpMedCard(
        tester,
        taken: true,
        onTakenChanged: (value) {},
      );

      // `_model.taken = widget.taken` in initState is what makes this true; a
      // model left at its `false` default would show PENDING here.
      expect(find.text('TAKEN'), findsOneWidget);
      expect(find.text('PENDING'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // 2. The green 'Taken' button only exists when there is a dose to act on.
  // -------------------------------------------------------------------------
  group('dose card Taken button visibility', () {
    final now = DateTime(2026, 11, 21, 10, 0);

    test('hidden while the medications are still loading', () {
      expect(
        doseCardShowsTakenButton(
          hasData: false,
          hasError: false,
          meds: const <MedicationsRecord>[],
          now: now,
        ),
        isFalse,
      );
    });

    test('hidden when the medications read failed', () async {
      final med = await seedMedication('m1');
      expect(
        doseCardShowsTakenButton(
          hasData: true,
          hasError: true,
          meds: [med],
          now: now,
        ),
        isFalse,
      );
    });

    test('hidden when the recipient has no medications at all', () {
      expect(
        doseCardShowsTakenButton(
          hasData: true,
          hasError: false,
          meds: const <MedicationsRecord>[],
          now: now,
        ),
        isFalse,
      );
      expect(
        medicationCardHeadline(const <MedicationsRecord>[], now),
        'No medications added yet.',
      );
    });

    test('shown while a dose is still pending today', () async {
      final med = await seedMedication('m1');
      expect(
        doseCardShowsTakenButton(
          hasData: true,
          hasError: false,
          meds: [med],
          now: now,
        ),
        isTrue,
      );
      expect(medicationCardHeadline([med], now), 'Donepezil 10mg');
    });

    test('hidden once every dose is taken today', () async {
      final med = await seedMedication(
        'm1',
        takenAt: DateTime(2026, 11, 21, 8, 0),
      );
      // The owner's screenshot: the all-taken headline with the button still
      // sitting beside it.
      expect(medicationCardHeadline([med], now), 'All of today\'s doses are taken.');
      expect(
        doseCardShowsTakenButton(
          hasData: true,
          hasError: false,
          meds: [med],
          now: now,
        ),
        isFalse,
      );
    });

    test('shown again once the taken timestamp is on a previous day', () async {
      // Taken yesterday: today's dose is pending again, so the button returns.
      final med = await seedMedication(
        'm1',
        takenAt: DateTime(2026, 11, 20, 23, 30),
      );
      expect(
        doseCardShowsTakenButton(
          hasData: true,
          hasError: false,
          meds: [med],
          now: now,
        ),
        isTrue,
      );
    });
  });

  // -------------------------------------------------------------------------
  // 3. The card is re-evaluated when the local date changes.
  // -------------------------------------------------------------------------
  group('local midnight distance', () {
    test('counts to the next LOCAL midnight, not a fixed 24 hours', () {
      expect(
        durationUntilNextLocalMidnight(DateTime(2026, 11, 20, 23, 51)),
        const Duration(minutes: 9),
      );
      expect(
        durationUntilNextLocalMidnight(DateTime(2026, 11, 21, 0, 0)),
        const Duration(hours: 24),
      );
      expect(
        durationUntilNextLocalMidnight(DateTime(2026, 11, 21, 12, 30)),
        const Duration(hours: 11, minutes: 30),
      );
      // Month end rolls into the next month, not a bogus date.
      expect(
        durationUntilNextLocalMidnight(DateTime(2026, 11, 30, 23, 0)),
        const Duration(hours: 1),
      );
    });
  });

  group('LocalDateRefresh', () {
    testWidgets('re-evaluates at the next local midnight', (tester) async {
      var clock = DateTime(2026, 11, 20, 23, 59, 30);
      final seen = <DateTime>[];
      await tester.pumpWidget(
        MaterialApp(
          home: LocalDateRefresh(
            clock: () => clock,
            builder: (context, now) {
              seen.add(now);
              return Text('${now.year}-${now.month}-${now.day}');
            },
          ),
        ),
      );

      expect(find.text('2026-11-20'), findsOneWidget);
      expect(seen.first, DateTime(2026, 11, 20, 23, 59, 30));

      // 30s to midnight, +1s cushion: the rebuild lands inside the new day.
      clock = DateTime(2026, 11, 21, 0, 0, 1);
      await tester.pump(const Duration(seconds: 31));

      expect(find.text('2026-11-21'), findsOneWidget);
      expect(seen.last, DateTime(2026, 11, 21, 0, 0, 1));

      // Dispose so the re-armed midnight timer is cancelled.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('re-evaluates when the app resumes on a later day',
        (tester) async {
      var clock = DateTime(2026, 11, 20, 22, 0);
      await tester.pumpWidget(
        MaterialApp(
          home: LocalDateRefresh(
            clock: () => clock,
            builder: (context, now) =>
                Text('${now.year}-${now.month}-${now.day}'),
          ),
        ),
      );
      expect(find.text('2026-11-20'), findsOneWidget);

      // Backgrounded over midnight: a timer does not run reliably there, so the
      // resume itself has to re-read the clock.
      // The legal background path, then back to the foreground.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clock = DateTime(2026, 11, 21, 7, 15);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(find.text('2026-11-21'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a non-resumed lifecycle event does not force a rebuild',
        (tester) async {
      var builds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: LocalDateRefresh(
            clock: () => DateTime(2026, 11, 20, 12, 0),
            builder: (context, now) {
              builds++;
              return const Text('card');
            },
          ),
        ),
      );
      final afterFirstFrame = builds;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(builds, afterFirstFrame);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
