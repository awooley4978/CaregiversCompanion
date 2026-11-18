// Vitals Export Unit 1 — optional per-recipient target ranges
// (owner-approved 2026-11-18, vitals-export proposal §13 item 2b/3/4).
//
// Pinned here:
//   (1) reading a target pair: blank means no target, one side may be blank,
//       min must not exceed max, a non-number or a decimal on a whole-number
//       measurement is refused, and nothing is ever defaulted or pre-filled;
//   (2) the stored `VitalsTargets` map is read defensively (junk, unknown keys
//       and wrong types are ignored, never thrown on) and a record with no
//       targets reads as an empty map;
//   (3) the create helper carries the field, and omits it when not supplied;
//   (4) Care Profile Setup edit mode loads the targets, saves them through the
//       merged update (every field the form does not own survives, no second
//       recipient is created), clearing every box really removes them, and an
//       invalid target blocks the save so nothing is written.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/backend/backend.dart';
import 'package:new_project/backend/vitals/vitals_targets.dart';
import 'package:new_project/pages/b_care_profile_setup/b_care_profile_setup_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_test_setup.dart';

Finder targetBox(String key, String side) => find.byKey(
      ValueKey('vitals_target_${key}_$side'),
    );

Finder targetInput(String key, String side) => find.descendant(
      of: targetBox(key, side),
      matching: find.byType(TextField),
    );

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
  });

  group('reading a target pair', () {
    test('both boxes blank means no target at all', () {
      final result = readVitalsTargetPair(
        measurement: kVitalsTargetHeartRate,
        minText: '',
        maxText: '   ',
      );

      expect(result.range, isNull);
      expect(result.error, isNull);
    });

    test('one side alone is a real one-sided target', () {
      final floor = readVitalsTargetPair(
        measurement: kVitalsTargetBloodPressureSystolic,
        minText: '90',
        maxText: '',
      );
      expect(floor.error, isNull);
      expect(floor.range!.min, 90);
      expect(floor.range!.max, isNull);
      expect(floor.range!.toStore(), {'min': 90});

      final ceiling = readVitalsTargetPair(
        measurement: kVitalsTargetBloodPressureSystolic,
        minText: '',
        maxText: '140',
      );
      expect(ceiling.error, isNull);
      expect(ceiling.range!.toStore(), {'max': 140});
    });

    test('both sides are stored independently', () {
      final result = readVitalsTargetPair(
        measurement: kVitalsTargetBloodPressureDiastolic,
        minText: '60',
        maxText: '90',
      );

      expect(result.range!.toStore(), {'min': 60, 'max': 90});
    });

    test('a minimum above the maximum is refused', () {
      final result = readVitalsTargetPair(
        measurement: kVitalsTargetHeartRate,
        minText: '100',
        maxText: '60',
      );

      expect(result.range, isNull);
      expect(result.error, contains('cannot be greater than'));
      expect(result.errorSide, VitalsTargetSide.max);
    });

    test('equal bounds are allowed', () {
      final result = readVitalsTargetPair(
        measurement: kVitalsTargetOxygenSaturation,
        minText: '95',
        maxText: '95',
      );

      expect(result.error, isNull);
      expect(result.range!.toStore(), {'min': 95, 'max': 95});
    });

    test('a non-number is refused, never guessed', () {
      final result = readVitalsTargetPair(
        measurement: kVitalsTargetWeight,
        minText: 'about 160',
        maxText: '',
      );

      expect(result.range, isNull);
      expect(result.error, contains('must be a number'));
      expect(result.errorSide, VitalsTargetSide.min);
    });

    test('a decimal is refused on a whole-number measurement but kept on '
        'temperature and weight', () {
      expect(
        readVitalsTargetPair(
          measurement: kVitalsTargetHeartRate,
          minText: '60.5',
          maxText: '',
        ).error,
        contains('whole number'),
      );
      expect(
        readVitalsTargetPair(
          measurement: kVitalsTargetTemperature,
          minText: '97.8',
          maxText: '99.5',
        ).range!.toStore(),
        {'min': 97.8, 'max': 99.5},
      );
    });

    test('a negative target is refused', () {
      expect(
        readVitalsTargetPair(
          measurement: kVitalsTargetWeight,
          minText: '-5',
          maxText: '',
        ).error,
        contains('cannot be negative'),
      );
    });

    test('pain carries no target at all', () {
      expect(
        kVitalsTargetMeasurements
            .where((m) => m.key == 'painLevel' || m.label == 'Pain'),
        isEmpty,
      );
    });

    test('a stored number formats without a spurious decimal', () {
      expect(formatVitalsTargetNumber(60), '60');
      expect(formatVitalsTargetNumber(60.0), '60');
      expect(formatVitalsTargetNumber(98.6), '98.6');
    });
  });

  group('reading the stored map', () {
    test('a missing map, junk keys and wrong types are ignored', () {
      expect(vitalsTargetsFromRecord(null), isEmpty);
      expect(vitalsTargetsFromRecord(const {}), isEmpty);
      final junk = vitalsTargetsFromRecord(const {
        'notAMeasurement': {'min': 1, 'max': 2},
        'heartRate': 'sixty',
        'weight': {'min': 'heavy', 'max': 200},
      });
      expect(junk.keys, ['weight']);
      expect(junk['weight']!.min, isNull);
      expect(junk['weight']!.max, 200);
    });

    test('a stored range is read back side by side', () {
      final ranges = vitalsTargetsFromRecord(const {
        'bloodPressureSystolic': {'min': 90, 'max': 140},
        'heartRate': {'max': 100},
      });

      expect(ranges['bloodPressureSystolic']!.min, 90);
      expect(ranges['bloodPressureSystolic']!.max, 140);
      expect(ranges['heartRate']!.min, isNull);
      expect(ranges['heartRate']!.max, 100);
    });
  });

  group('record and create helper', () {
    test('the create helper carries the targets, and omits them when not '
        'supplied', () {
      expect(
        createCareRecipientsRecordData(name: 'Ada')['VitalsTargets'],
        isNull,
      );
      expect(
        createCareRecipientsRecordData(
          name: 'Ada',
          vitalsTargets: {
            'heartRate': {'min': 60, 'max': 100},
          },
        )['VitalsTargets'],
        {
          'heartRate': {'min': 60, 'max': 100},
        },
      );
    });

    test('a recipient with no targets reads as an empty map', () async {
      await FirebaseFirestore.instance
          .doc('careRecipients/r1')
          .set({'Name': 'Ada', 'orgId': 'org_test'});
      final record = await CareRecipientsRecord.getDocumentOnce(
          FirebaseFirestore.instance.doc('careRecipients/r1'));

      expect(record.hasVitalsTargets(), isFalse);
      expect(record.vitalsTargets, isEmpty);
    });

    test('stored targets are read off the record', () async {
      await FirebaseFirestore.instance.doc('careRecipients/r1').set({
        'Name': 'Ada',
        'orgId': 'org_test',
        'VitalsTargets': {
          'temperature': {'max': 99.5},
        },
      });
      final record = await CareRecipientsRecord.getDocumentOnce(
          FirebaseFirestore.instance.doc('careRecipients/r1'));

      expect(record.hasVitalsTargets(), isTrue);
      expect(vitalsTargetsFromRecord(record.vitalsTargets)['temperature']!.max,
          99.5);
    });
  });

  group('Care Profile Setup target ranges', () {
    Future<void> signInAndProvision() async {
      fakeAuthPlatform.emitSignedIn(uid: 'u1', email: 'a@example.com');
      fakeFirestore.docs['users/u1'] = {
        'uid': 'u1',
        'activeGroupId': 'org_test',
      };
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc('org_test')
          .collection('members')
          .doc('u1')
          .set({'uid': 'u1', 'status': 'active', 'role': 'owner'});
    }

    Future<DocumentReference> seedRecipient() async {
      final ref = FirebaseFirestore.instance.doc('careRecipients/r1');
      await ref.set({
        'Name': 'Margaret Alvarez',
        'DateOfBirth': '14 Mar 1948',
        'orgId': 'org_test',
        'migrationStatus': 'claimed',
        'CreatedAt': DateTime(2026, 1, 2),
        'Initials': 'MA',
        'MobilityNotes': 'Walker indoors',
        'VitalsTargets': {
          'bloodPressureSystolic': {'min': 90, 'max': 140},
          'temperature': {'max': 99.5},
        },
      });
      return ref;
    }

    Future<void> pumpEditor(WidgetTester tester, DocumentReference? ref) async {
      tester.view.physicalSize = const Size(1080.0, 4000.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: BCareProfileSetupWidget(careRecipients: ref),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> typeTarget(
        WidgetTester tester, String key, String side, String text) async {
      final finder = targetInput(key, side);
      await tester.ensureVisible(finder);
      await tester.enterText(finder, text);
      await tester.pumpAndSettle();
    }

    Future<void> tapSave(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Save Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Profile'));
      await tester.pumpAndSettle();
    }

    testWidgets('loads the stored targets and saves them without touching '
        'anything the form does not own', (tester) async {
      await signInAndProvision();
      final ref = await seedRecipient();
      await pumpEditor(tester, ref);

      // Prefilled from the stored profile — nothing invented, nothing blanked.
      expect(find.text('Vitals Target Ranges'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(targetInput('bloodPressureSystolic', 'min'))
            .controller!
            .text,
        '90',
      );
      expect(
        tester
            .widget<TextField>(targetInput('bloodPressureSystolic', 'max'))
            .controller!
            .text,
        '140',
      );
      expect(
        tester
            .widget<TextField>(targetInput('temperature', 'max'))
            .controller!
            .text,
        '99.5',
      );
      // A measurement with no target stays blank.
      expect(
        tester
            .widget<TextField>(targetInput('heartRate', 'min'))
            .controller!
            .text,
        '',
      );

      await typeTarget(tester, 'heartRate', 'min', '60');
      await typeTarget(tester, 'heartRate', 'max', '100');
      await tapSave(tester);

      final saved = fakeFirestore.dataAt('careRecipients/r1')!;
      final targets = saved['VitalsTargets'] as Map;
      expect(targets['bloodPressureSystolic'], {'min': 90, 'max': 140});
      expect(targets['temperature'], {'max': 99.5});
      expect(targets['heartRate'], {'min': 60, 'max': 100});
      // Nothing was invented for the measurements left blank.
      expect(targets.containsKey('bloodGlucose'), isFalse);
      expect(targets.containsKey('weight'), isFalse);
      // Unrelated stored fields survive the merged update.
      expect(saved['orgId'], 'org_test');
      expect(saved['migrationStatus'], 'claimed');
      expect(saved['Initials'], 'MA');
      expect(saved['MobilityNotes'], 'Walker indoors');
      expect(
        fakeFirestore.docs.keys
            .where((p) => RegExp(r'^careRecipients/[^/]+$').hasMatch(p))
            .length,
        1,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('clearing every box removes the stored targets',
        (tester) async {
      await signInAndProvision();
      final ref = await seedRecipient();
      await pumpEditor(tester, ref);

      await typeTarget(tester, 'bloodPressureSystolic', 'min', '');
      await typeTarget(tester, 'bloodPressureSystolic', 'max', '');
      await typeTarget(tester, 'temperature', 'max', '');
      await tapSave(tester);

      final saved = fakeFirestore.dataAt('careRecipients/r1')!;
      expect(saved['VitalsTargets'], isEmpty);
      expect(saved['Name'], 'Margaret Alvarez');
    });

    testWidgets('an invalid target blocks the save and writes nothing',
        (tester) async {
      await signInAndProvision();
      final ref = await seedRecipient();
      await pumpEditor(tester, ref);

      await typeTarget(tester, 'bloodPressureSystolic', 'min', '150');
      await typeTarget(tester, 'bloodPressureSystolic', 'max', '140');
      await tapSave(tester);

      final saved = fakeFirestore.dataAt('careRecipients/r1')!;
      expect(saved['VitalsTargets'], {
        'bloodPressureSystolic': {'min': 90, 'max': 140},
        'temperature': {'max': 99.5},
      });
      expect(find.textContaining('cannot be greater than'), findsWidgets);
    });

    testWidgets('a non-numeric target blocks the save and writes nothing',
        (tester) async {
      await signInAndProvision();
      final ref = await seedRecipient();
      await pumpEditor(tester, ref);

      await typeTarget(tester, 'weight', 'max', 'heavy');
      await tapSave(tester);

      final saved = fakeFirestore.dataAt('careRecipients/r1')!;
      expect((saved['VitalsTargets'] as Map).containsKey('weight'), isFalse);
      expect(find.textContaining('must be a number'), findsWidgets);
    });

    testWidgets('a new profile saves the targets a caregiver typed',
        (tester) async {
      await signInAndProvision();
      await pumpEditor(tester, null);

      await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Margaret Smith'), 'New Person');
      await tester.pumpAndSettle();
      await typeTarget(tester, 'oxygenSaturation', 'min', '95');
      await tapSave(tester);

      final created = fakeFirestore.docs.entries
          .where((e) => RegExp(r'^careRecipients/[^/]+$').hasMatch(e.key))
          .toList();
      expect(created.length, 1);
      expect(created.single.value['VitalsTargets'], {
        'oxygenSaturation': {'min': 95},
      });
    });
  });
}
