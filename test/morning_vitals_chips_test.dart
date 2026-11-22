// Morning Vitals chips on the Daily Dashboard (owner-approved 2026-11-22).
//
// The card used to render four invented readings — '72 bpm', '118/76',
// '94 mg/dL', '142 lbs' — which "look like genuine medical measurements".
// What is pinned here:
//  * each chip shows that measurement's OWN latest recorded value from
//    `vitalLogs` plus the date of that same record (different measurements
//    legitimately come from different logs at different times);
//  * a recipient with no vitals shows "No reading yet" for all four, and the
//    old hardcoded strings appear nowhere in the page;
//  * the read is recipient-scoped (the rules deny unconstrained lists) and a
//    failed read surfaces as "Couldn't load vitals", never as "No reading yet";
//  * the chip renders the value and the date line.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregivers_companion/backend/backend.dart';
import 'package:caregivers_companion/backend/vitals/vitals_entry.dart';
import 'package:caregivers_companion/components/vital_chip/vital_chip_widget.dart';
import 'package:caregivers_companion/pages/c_daily_dashboard/c_daily_dashboard_widget.dart';

import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initFirebaseForTest();
  });

  setUp(() {
    fakeFirestore.clear();
    fakeFirestore.clearWriteError();
    fakeFirestore.clearQueryError();
  });

  DocumentReference recipientRef([String id = 'r1']) =>
      FirebaseFirestore.instance.doc('careRecipients/$id');

  /// Seeds one `vitalLogs` document through the app's own write shape, so the
  /// read path below parses it exactly as the app does.
  Future<void> seedLog({
    required String recipientId,
    required DateTime at,
    int? heartRate,
    int? systolic,
    int? diastolic,
    int? glucose,
    double? weight,
  }) async {
    await VitalLogsRecord.collection.doc().set(
      createVitalLogsRecordData(
        careRecipientRef: recipientRef(recipientId),
        logDateTime: at,
        heartRate: heartRate,
        bloodPressureSystolic: systolic,
        bloodPressureDiastolic: diastolic,
        bloodGlucose: glucose,
        weight: weight,
        orgId: 'org_test',
        loggedByUid: 'uid-1',
      ),
    );
  }

  group('latestVitalChipReading', () {
    test('takes each measurement\'s own newest value and date', () {
      final newest = VitalLogsRecord.getDocumentFromData(
        {
          'heartRate': 72,
          'logDateTime': DateTime(2026, 11, 21, 9, 15),
        },
        recipientRef(),
      );
      final older = VitalLogsRecord.getDocumentFromData(
        {
          'heartRate': 64,
          'weight': 142.5,
          'logDateTime': DateTime(2026, 11, 19, 7, 0),
        },
        recipientRef(),
      );

      final sorted = sortVitalsNewestFirst([older, newest]);

      expect(latestVitalChipReading(sorted, VitalMeasurement.heartRate)?.value,
          '72 bpm');
      expect(
        latestVitalChipReading(sorted, VitalMeasurement.heartRate)?.dateText,
        formatVitalChipDate(DateTime(2026, 11, 21, 9, 15)),
      );
      // The weight comes from the older record - its own newest value, not the
      // newest record overall.
      expect(latestVitalChipReading(sorted, VitalMeasurement.weight)?.value,
          '142.5 lb');
      expect(
        latestVitalChipReading(sorted, VitalMeasurement.weight)?.dateText,
        formatVitalChipDate(DateTime(2026, 11, 19, 7, 0)),
      );
      // Nothing recorded for blood pressure or glucose.
      expect(latestVitalChipReading(sorted, VitalMeasurement.bloodPressure),
          isNull);
      expect(latestVitalChipReading(sorted, VitalMeasurement.bloodGlucose),
          isNull);
    });

    test('the chip date is short, device-local and time-bearing', () {
      final at = DateTime(2026, 11, 21, 9, 15);
      final text = formatVitalChipDate(at);
      expect(text, 'Nov 21, 9:15 AM');
      expect(text, isNot(contains('2026')));
    });
  });

  group('loadMorningVitalReadings', () {
    test('shows the recipient\'s real values and their own dates', () async {
      await seedLog(
        recipientId: 'r1',
        at: DateTime(2026, 11, 21, 9, 15),
        heartRate: 72,
        systolic: 118,
        diastolic: 76,
        glucose: 94,
        weight: 142.0,
      );

      final readings = await loadMorningVitalReadings(recipientRef());

      expect(readings[VitalMeasurement.heartRate]?.value, '72 bpm');
      expect(readings[VitalMeasurement.bloodPressure]?.value, '118/76 mmHg');
      expect(readings[VitalMeasurement.bloodGlucose]?.value, '94 mg/dL');
      expect(readings[VitalMeasurement.weight]?.value, '142 lb');
      for (final measurement in morningVitalMeasurements) {
        expect(readings[measurement]?.dateText,
            formatVitalChipDate(DateTime(2026, 11, 21, 9, 15)));
      }
    });

    test('each measurement keeps its own newest reading and date', () async {
      await seedLog(
        recipientId: 'r1',
        at: DateTime(2026, 11, 19, 7, 0),
        weight: 142.0,
      );
      await seedLog(
        recipientId: 'r1',
        at: DateTime(2026, 11, 21, 9, 15),
        heartRate: 72,
      );
      await seedLog(
        recipientId: 'r1',
        at: DateTime(2026, 11, 20, 6, 30),
        heartRate: 64,
      );

      final readings = await loadMorningVitalReadings(recipientRef());

      expect(readings[VitalMeasurement.heartRate]?.value, '72 bpm');
      expect(readings[VitalMeasurement.heartRate]?.dateText,
          formatVitalChipDate(DateTime(2026, 11, 21, 9, 15)));
      expect(readings[VitalMeasurement.weight]?.value, '142 lb');
      expect(readings[VitalMeasurement.weight]?.dateText,
          formatVitalChipDate(DateTime(2026, 11, 19, 7, 0)));
    });

    test('a recipient with no vitals gets "No reading yet" four times',
        () async {
      final readings = await loadMorningVitalReadings(recipientRef());

      expect(morningVitalMeasurements, hasLength(4));
      for (final measurement in morningVitalMeasurements) {
        expect(readings[measurement]?.value, vitalChipNoReading);
        expect(readings[measurement]?.dateText, isNull);
      }
      expect(vitalChipNoReading, 'No reading yet');
    });

    test('another recipient\'s readings never appear', () async {
      await seedLog(
        recipientId: 'r2',
        at: DateTime(2026, 11, 21, 9, 15),
        heartRate: 88,
        weight: 130.0,
      );

      final readings = await loadMorningVitalReadings(recipientRef('r1'));

      for (final measurement in morningVitalMeasurements) {
        expect(readings[measurement]?.value, vitalChipNoReading);
      }
    });

    test('a failed read throws, so it is never shown as "no readings"',
        () async {
      fakeFirestore.queryError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );

      await expectLater(
        loadMorningVitalReadings(recipientRef()),
        throwsA(isA<FirebaseException>()),
      );
      expect(vitalChipLoadError, "Couldn't load vitals");
    });
  });

  test('the four invented readings are gone from the dashboard page', () {
    final source = File(
      'lib/pages/c_daily_dashboard/c_daily_dashboard_widget.dart',
    ).readAsStringSync();

    for (final invented in ['72 bpm', '118/76', '94 mg/dL', '142 lbs']) {
      expect(source.contains(invented), isFalse,
          reason: 'the dashboard still contains the invented value $invented');
    }
  });

  group('the chip itself', () {
    Future<void> pumpChip(WidgetTester tester,
        {required String value, String? date}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VitalChipWidget(
              label: 'Heart Rate',
              value: value,
              date: date,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the value with its reading date', (tester) async {
      await pumpChip(tester, value: '72 bpm', date: 'Nov 21, 9:15 AM');

      expect(find.text('Heart Rate'), findsOneWidget);
      expect(find.text('72 bpm'), findsOneWidget);
      expect(find.text('Nov 21, 9:15 AM'), findsOneWidget);
    });

    testWidgets('shows the honest empty state with no date line',
        (tester) async {
      await pumpChip(tester, value: vitalChipNoReading);

      expect(find.text(vitalChipNoReading), findsOneWidget);
      expect(find.textContaining('AM'), findsNothing);
      expect(find.textContaining('PM'), findsNothing);
    });
  });
}
