// The Emergency Info a caregiver can hand to a paramedic.
//
// ONE load feeds both surfaces: the Emergency Info screen renders this object
// and the EMS PDF is rendered from the same instance, so the screen and the
// printout can never disagree.
//
// Every value comes from the selected care recipient's stored profile. Nothing
// is invented: a field the profile does not hold reads [emergencyInfoNotProvided].
// The Pharmacy card is deliberately absent (pharmacy stays a future care-profile
// feature) and the denied `emerencyinfo` collection is never read.
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Shown wherever the care recipient profile holds no value for a field.
const String emergencyInfoNotProvided = 'Not provided';

/// One entry of the recipient's stored medication list, as EMS needs it.
class EmergencyInfoMedication {
  const EmergencyInfoMedication({
    required this.name,
    required this.dose,
    required this.directions,
  });

  final String name;
  final String dose;
  final String directions;

  /// 'Lisinopril 10mg - 1 tablet daily'; empty parts are skipped.
  String get label {
    final head = [name, dose].where((part) => part.isNotEmpty).join(' ');
    return [
      if (head.isNotEmpty) head,
      if (directions.isNotEmpty) directions,
    ].join(' - ');
  }
}

/// Everything the Emergency Info screen and its EMS PDF show.
class EmergencyInfoData {
  const EmergencyInfoData({
    required this.recipientName,
    required this.dateOfBirth,
    required this.allergies,
    required this.conditions,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.primaryCarePhysicianName,
    required this.primaryCarePhysicianPhone,
    required this.medications,
    required this.advanceDirectivesStatus,
    required this.advanceDirectivesNotes,
    required this.generatedAt,
  });

  final String recipientName;

  /// Stored as a string on the care profile, so it is shown exactly as stored.
  final String dateOfBirth;
  final List<String> allergies;
  final List<String> conditions;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String primaryCarePhysicianName;
  final String primaryCarePhysicianPhone;
  final List<EmergencyInfoMedication> medications;

  /// The care profile's Advance Directives status: 'on_file', 'not_on_file' or
  /// 'unknown' (owner-approved 2026-11-14). A profile saved before the field
  /// existed reads 'unknown' — a real answer, not a missing one.
  final String advanceDirectivesStatus;

  /// Optional free-text detail stored with the status.
  final String advanceDirectivesNotes;
  final DateTime generatedAt;

  /// [value], or [emergencyInfoNotProvided] when it is blank.
  static String orNotProvided(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? emergencyInfoNotProvided : trimmed;
  }

  String get recipientNameOrNotProvided => orNotProvided(recipientName);
  String get dateOfBirthOrNotProvided => orNotProvided(dateOfBirth);
  String get emergencyContactNameOrNotProvided =>
      orNotProvided(emergencyContactName);
  String get emergencyContactPhoneOrNotProvided =>
      orNotProvided(emergencyContactPhone);
  String get primaryCarePhysicianNameOrNotProvided =>
      orNotProvided(primaryCarePhysicianName);
  String get primaryCarePhysicianPhoneOrNotProvided =>
      orNotProvided(primaryCarePhysicianPhone);
  /// 'On file' / 'Not on file' / 'Unknown', with the notes appended when the
  /// caregiver recorded any. Never 'Not provided': the status always has an
  /// answer, and Unknown is one of them.
  String get advanceDirectivesDisplay {
    final status = advanceDirectivesStatusLabel(advanceDirectivesStatus);
    final notes = advanceDirectivesNotes.trim();
    return notes.isEmpty ? status : '$status — $notes';
  }

  /// The medication lines to print, or a single 'Not provided' line.
  List<String> get medicationLines {
    final lines = medications
        .map((medication) => medication.label)
        .where((label) => label.isNotEmpty)
        .toList();
    return lines.isEmpty ? const [emergencyInfoNotProvided] : lines;
  }

  /// The allergy labels for the quick-view badges / PDF section.
  List<String> get allergyLines =>
      allergies.isEmpty ? const [emergencyInfoNotProvided] : allergies;

  List<String> get conditionLines =>
      conditions.isEmpty ? const [emergencyInfoNotProvided] : conditions;

  /// Initials for the contact card avatar, derived from the stored name. Blank
  /// when no name is stored, so nothing is invented.
  static String initialsFor(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return '';
    }
    final first = words.first.substring(0, 1);
    final last = words.length > 1 ? words.last.substring(0, 1) : '';
    return '$first$last'.toUpperCase();
  }

  /// Reads the recipient's profile and medication list into [EmergencyInfoData].
  ///
  /// Reads only what the app can already access: the recipient document and the
  /// org-scoped medication list (the same scoped read the Medication Tracker and
  /// the care report use). A failed read is rethrown so the caller can say so
  /// instead of showing an invented empty profile.
  static Future<EmergencyInfoData> load({
    required DocumentReference recipientRef,
    DateTime? generatedAt,
  }) async {
    final recipient = await CareRecipientsRecord.getDocumentOnce(recipientRef);
    final activeGroupId = (FFAppState().activeGroupId ?? '').trim();
    final orgId =
        activeGroupId.isNotEmpty ? activeGroupId : recipient.orgId.trim();

    final medications = await queryMedicationsRecordOnce(
      queryBuilder: (query) => orgId.isEmpty
          ? query.where('careRecipientRef', isEqualTo: recipientRef)
          : query
              .where('orgId', isEqualTo: orgId)
              .where('careRecipientRef', isEqualTo: recipientRef),
    );
    medications.sort((a, b) => a.medicationName
        .toLowerCase()
        .compareTo(b.medicationName.toLowerCase()));

    return EmergencyInfoData(
      recipientName: recipient.name.trim(),
      dateOfBirth: recipient.dateOfBirth.trim(),
      allergies: recipient.allergies
          .map((allergy) => allergy.trim())
          .where((allergy) => allergy.isNotEmpty)
          .toList(),
      conditions: recipient.conditions
          .map((condition) => condition.trim())
          .where((condition) => condition.isNotEmpty)
          .toList(),
      emergencyContactName: recipient.emergencyContactName.trim(),
      emergencyContactPhone: recipient.emergencyContactPhone.trim(),
      primaryCarePhysicianName: recipient.primaryCarePhysicianName.trim(),
      primaryCarePhysicianPhone: recipient.primaryCarePhysicianPhone.trim(),
      advanceDirectivesStatus: recipient.advanceDirectivesStatus,
      advanceDirectivesNotes: recipient.advanceDirectivesNotes.trim(),
      medications: medications
          .map((record) => EmergencyInfoMedication(
                name: record.medicationName.trim(),
                dose: record.dose.trim(),
                directions: record.directions.trim(),
              ))
          .toList(),
      generatedAt: generatedAt ?? DateTime.now(),
    );
  }
}

/// The caregiver-facing label for a stored Advance Directives status.
String advanceDirectivesStatusLabel(String status) {
  switch (status.trim()) {
    case 'on_file':
      return 'On file';
    case 'not_on_file':
      return 'Not on file';
    default:
      return 'Unknown';
  }
}

/// A filesystem-safe name for the generated EMS PDF.
String emergencyInfoFileName(EmergencyInfoData data) {
  final who = data.recipientName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final day = DateFormat('yyyyMMdd').format(data.generatedAt);
  return who.isEmpty ? 'emergency-info-$day.pdf' : 'emergency-info-$who-$day.pdf';
}
