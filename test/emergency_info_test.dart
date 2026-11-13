// Emergency Info (U4): the screen and the EMS PDF read the selected care
// recipient's real profile.
//
// Owner decisions for this unit: every fabricated medical/personal value is
// replaced by the recipient's stored profile data (allergies, conditions,
// emergency contact name/phone, primary care physician name/phone, date of
// birth, medications); anything the profile does not hold reads "Not provided";
// the sms: action is gone; "Export PDF for EMS" builds a real PDF from the same
// loaded data the screen displays; the Pharmacy card is hidden.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/backend/backend.dart';
import 'package:new_project/pages/i_emergency_information/i_emergency_information_widget.dart';
import 'package:new_project/reports/emergency_info.dart';
import 'package:new_project/reports/emergency_info_pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_test_setup.dart';

/// The text a PDF actually prints, pulled back out of its (uncompressed)
/// content stream so a test can assert on the words a reader sees.
String pdfText(List<int> bytes) => RegExp(r'\[\((.*?)\)\]')
    .allMatches(latin1.decode(bytes, allowInvalid: true))
    .map((match) => match.group(1)!)
    .join(' ')
    .replaceAll(r'\', '');

/// The page's own source, for the assertions about the removed sms: action and
/// the single data load that feeds both the screen and the PDF.
String emergencyInfoPageSource() => File(
      'lib/pages/i_emergency_information/i_emergency_information_widget.dart',
    ).readAsStringSync();

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
  });

  DocumentReference recipientRef() =>
      FirebaseFirestore.instance.doc('careRecipients/r1');

  /// A recipient with every field this screen shows.
  Future<void> seedFullRecipient() async {
    await recipientRef().set({
      'Name': 'Margaret Alvarez',
      'DateOfBirth': '14 Mar 1948',
      'Allergies': ['Penicillin', 'Latex'],
      'Conditions': ['Hypertension', 'Type 2 Diabetes'],
      'EmergencyContactName': 'James Jenkins',
      'EmergencyContactPhone': '(555) 010-2233',
      'PrimaryCarePhysicianName': 'Dr. Sarah Reed',
      'PrimaryCarePhysicianPhone': '(555) 010-9988',
      'orgId': 'org_test',
    });
    await MedicationsRecord.collection.doc('m1').set({
      'orgId': 'org_test',
      'careRecipientRef': recipientRef(),
      'medicationName': 'Lisinopril',
      'dose': '10mg',
      'directions': '1 tablet daily',
    });
  }

  /// A recipient whose profile holds only a name.
  Future<void> seedBareRecipient() async {
    await recipientRef().set({
      'Name': 'Margaret Alvarez',
      'orgId': 'org_test',
    });
  }

  Future<void> pumpEmergencyInfo(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080.0, 2400.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    FFAppState().selectedCareRecipient = recipientRef();
    await tester.pumpWidget(const MaterialApp(home: IEmergencyInformationWidget()));
    await tester.pumpAndSettle();
  }

  testWidgets('the screen renders the real care recipient profile',
      (tester) async {
    await seedFullRecipient();
    await pumpEmergencyInfo(tester);

    // Who this is.
    expect(find.text('Margaret Alvarez'), findsOneWidget);
    expect(find.text('DOB: 14 Mar 1948'), findsOneWidget);

    // Real allergies and conditions, not invented badges.
    expect(find.text('Allergy: Penicillin'), findsOneWidget);
    expect(find.text('Allergy: Latex'), findsOneWidget);
    expect(find.text('Hypertension'), findsOneWidget);
    expect(find.text('Type 2 Diabetes'), findsOneWidget);

    // Real contacts.
    expect(find.text('James Jenkins'), findsOneWidget);
    expect(find.text('(555) 010-2233'), findsOneWidget);
    expect(find.text('Dr. Sarah Reed'), findsOneWidget);
    expect(find.text('(555) 010-9988'), findsOneWidget);

    // The real medication list.
    expect(find.text('• Lisinopril 10mg - 1 tablet daily'), findsOneWidget);

    // Nothing fabricated survives.
    expect(find.text('Allergy: Penicillin'), findsOneWidget);
    expect(find.text('Fall Risk'), findsNothing);
    expect(find.text('CVS Health - Downtown'), findsNothing);
    expect(find.text('Pharmacy'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fields the profile does not hold read "Not provided"',
      (tester) async {
    await seedBareRecipient();
    await pumpEmergencyInfo(tester);

    expect(find.text('Margaret Alvarez'), findsOneWidget);
    expect(find.text('DOB: $emergencyInfoNotProvided'), findsOneWidget);
    expect(find.text('Allergies: $emergencyInfoNotProvided'), findsOneWidget);
    expect(find.text('Conditions: $emergencyInfoNotProvided'), findsOneWidget);
    expect(find.text('• $emergencyInfoNotProvided'), findsOneWidget);
    // Emergency contact name/phone and physician name/phone.
    expect(find.text(emergencyInfoNotProvided), findsWidgets);
    // Advance directives have no field on the care profile.
    expect(find.text(emergencyInfoNotProvided), findsWidgets);

    // None of the old hardcoded content is invented to fill the gaps.
    expect(find.text('James Jenkins'), findsNothing);
    expect(find.text('Dr. Sarah Reed'), findsNothing);
    expect(find.text('(555) 123-4567'), findsNothing);
    expect(find.text('Fall Risk'), findsNothing);
    expect(find.textContaining('DNR'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('the sms: action is gone from the page', () {
    final source = emergencyInfoPageSource();
    expect(source.contains('sms'), isFalse,
        reason: 'the dead sms: action must not survive');
    // The Export action now builds the EMS PDF from the loaded data.
    expect(source.contains('buildEmergencyInfoPdf(info)'), isTrue);
    expect(source.contains('onPressed: _exporting ? null : _exportPdf'), isTrue);
  });

  test('the EMS PDF is built from the same data the screen shows', () async {
    await seedFullRecipient();
    final info = await EmergencyInfoData.load(
      recipientRef: recipientRef(),
      generatedAt: DateTime(2026, 11, 13, 9, 30),
    );

    // The screen renders exactly this object (see the widget test above for the
    // rendered values); the PDF is built from the same instance.
    final bytes = await buildEmergencyInfoPdf(info);
    expect(latin1.decode(bytes, allowInvalid: true).startsWith('%PDF'), isTrue);

    final printed = pdfText(bytes);
    expect(printed, contains('Margaret Alvarez'));
    expect(printed, contains('Date of birth: 14 Mar 1948'));
    expect(printed, contains('Allergy: Penicillin'));
    expect(printed, contains('Hypertension'));
    expect(printed, contains('James Jenkins'));
    expect(printed, contains('555) 010-2233'));
    expect(printed, contains('Dr. Sarah Reed'));
    expect(printed, contains('Lisinopril 10mg - 1 tablet daily'));
    // Nothing invented, and no pharmacy (the profile holds none).
    expect(printed, contains('Advance directives $emergencyInfoNotProvided'));
    expect(printed.contains('CVS'), isFalse);
    expect(printed.contains('Fall Risk'), isFalse);
  });

  test('the EMS PDF says "Not provided" for an empty profile', () async {
    await seedBareRecipient();
    final info = await EmergencyInfoData.load(
      recipientRef: recipientRef(),
      generatedAt: DateTime(2026, 11, 13, 9, 30),
    );
    final printed = pdfText(await buildEmergencyInfoPdf(info));

    expect(printed, contains('Margaret Alvarez'));
    expect(printed, contains('Date of birth: $emergencyInfoNotProvided'));
    expect(printed, contains('Allergies $emergencyInfoNotProvided'));
    expect(printed, contains('Current medications $emergencyInfoNotProvided'));
    expect(printed, contains('Name: $emergencyInfoNotProvided'));
    expect(printed, contains('Phone: $emergencyInfoNotProvided'));
    expect(printed.contains('Penicillin'), isFalse);
    expect(printed.contains('James Jenkins'), isFalse);
  });
}
