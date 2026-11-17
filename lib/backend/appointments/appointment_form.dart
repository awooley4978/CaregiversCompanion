// Appointments unit, part 3: the pure layer behind the ONE appointment form.
//
// The same form creates an appointment ("New Event" on the Calendar) and edits
// one (Doctor Visit Prep's "Details"), which is the create-or-edit pattern the
// owner already approved for Care Profile Setup: no document reference means
// create, one means update that document — never a second copy.
//
// Everything here is pure so the rules below can be pinned without a widget
// tree:
//  * a title and a start time are required, an end time is optional and may not
//    be before the start;
//  * questions to ask are one per LINE inside the existing `questionsToAsk`
//    string — nothing is ever split on a comma (the owner's conditions rule);
//  * creates go through the record helper so `orgId` / `createdByUid` are the
//    values the merged security rules verify, and `createdAt` / `updatedAt` are
//    server-stamped (`createdAt == request.time` / `updatedAt == request.time`);
//  * updates send only the fields this form owns and never touch
//    `careRecipientRef`, `orgId`, `createdByUid` or `questionsToAsk`.
import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/backend.dart';

/// Shown when the caregiver has not typed a title.
const String appointmentTitleRequired = 'Enter a title for this appointment.';

/// Shown when no date has been chosen.
const String appointmentDateRequired = 'Choose the date of this appointment.';

/// Shown when no start time has been chosen.
const String appointmentStartRequired = 'Choose a start time.';

/// Shown when the end time falls before the start time (the rules refuse it).
const String appointmentEndBeforeStart =
    'The end time cannot be before the start time.';

/// Shown when there is no care recipient to file the appointment under.
const String appointmentNoRecipient =
    'Select a care recipient before adding an appointment.';

/// Shown when the recipient is not linked to a household, so the rules' org
/// check could never pass.
const String appointmentNoHousehold =
    'This care recipient is not linked to a household, so an appointment '
    'cannot be saved.';

/// Shown when the caregiver is not signed in.
const String appointmentNotSignedIn =
    'Sign in to save an appointment.';

/// Shown when the write is refused (offline, permissions, missing index).
const String appointmentSaveFailed =
    'Could not save this appointment. Please check your connection and try '
    'again.';

/// The questions stored in a `questionsToAsk` string: one per non-empty line.
///
/// Commas are NEVER separators — "Ask about the 10, 20 or 40 mg doses?" is one
/// question (the same rule the owner set for conditions).
List<String> appointmentQuestionLines(String text) => text
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList();

/// The stored text for [questions], one per line (the inverse of
/// [appointmentQuestionLines]).
String appointmentQuestionsText(Iterable<String> questions) => questions
    .map((question) => question.trim())
    .where((question) => question.isNotEmpty)
    .join('\n');

/// Appends [question] as one more line, leaving every existing question
/// exactly as it was stored. A blank question changes nothing.
String appendAppointmentQuestion(String existing, String question) {
  final text = question.trim();
  if (text.isEmpty) {
    return existing;
  }
  final lines = appointmentQuestionLines(existing)..add(text);
  return appointmentQuestionsText(lines);
}

/// The start instant of an appointment on [day] at [hour]:[minute], or null
/// while either half is still missing.
DateTime? appointmentStartAt(DateTime? day, int? hour, int? minute) {
  if (day == null || hour == null || minute == null) {
    return null;
  }
  return DateTime(day.year, day.month, day.day, hour, minute);
}

/// What the form holds, independent of any widget.
///
/// The end time is always on the appointment's own day: the form offers a date
/// plus two times, and a stored end on another day is not something it can
/// express (the rules only require `endDateTime >= appointmentDateTime`).
class AppointmentFormValues {
  const AppointmentFormValues({
    this.title = '',
    this.type = '',
    this.providerName = '',
    this.location = '',
    this.reason = '',
    this.notes = '',
    this.day,
    this.startHour,
    this.startMinute,
    this.endHour,
    this.endMinute,
    this.followUpNeeded = false,
  });

  final String title;
  final String type;
  final String providerName;
  final String location;
  final String reason;
  final String notes;

  /// The appointment's calendar day (device-local, midnight).
  final DateTime? day;

  /// The start time of day; null until the caregiver picks one.
  final int? startHour;
  final int? startMinute;

  /// The optional end time of day.
  final int? endHour;
  final int? endMinute;

  final bool followUpNeeded;

  DateTime? get startAt => appointmentStartAt(day, startHour, startMinute);

  DateTime? get endAt => appointmentStartAt(day, endHour, endMinute);

  /// The values a stored appointment is edited with — every field the form
  /// owns, read from the record itself.
  factory AppointmentFormValues.fromRecord(AppointmentsRecord record) {
    final start = record.appointmentDateTime?.toLocal();
    final end = record.endDateTime?.toLocal();
    return AppointmentFormValues(
      title: record.appointmentTitle,
      type: record.appointmentType,
      providerName: record.providerName,
      location: record.location,
      reason: record.reason,
      notes: record.notes,
      day: start == null
          ? null
          : DateTime(start.year, start.month, start.day),
      startHour: start?.hour,
      startMinute: start?.minute,
      endHour: end?.hour,
      endMinute: end?.minute,
      followUpNeeded: record.followUpNeeded,
    );
  }
}

/// The first thing that stops [values] being saved, or null when it is
/// complete. Checked in the order the form presents its fields.
String? appointmentFormError(AppointmentFormValues values) {
  if (values.title.trim().isEmpty) {
    return appointmentTitleRequired;
  }
  if (values.day == null) {
    return appointmentDateRequired;
  }
  final start = values.startAt;
  if (start == null) {
    return appointmentStartRequired;
  }
  final end = values.endAt;
  if (end != null && end.isBefore(start)) {
    return appointmentEndBeforeStart;
  }
  return null;
}

String? _optional(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}

/// The payload for a NEW appointment.
///
/// `orgId` and `createdByUid` are the values the merged rules verify
/// (`orgId == recipientOrgId(...)`, `createdByUid == request.auth.uid`), and the
/// two timestamps are server stamps so `createdAt == request.time` holds.
Map<String, dynamic> createAppointmentDataFor({
  required DocumentReference careRecipientRef,
  required String orgId,
  required String createdByUid,
  required AppointmentFormValues values,
}) {
  return createAppointmentsRecordData(
    careRecipientRef: careRecipientRef,
    appointmentTitle: values.title.trim(),
    appointmentType: _optional(values.type),
    appointmentDateTime: values.startAt,
    endDateTime: values.endAt,
    providerName: _optional(values.providerName),
    location: _optional(values.location),
    reason: _optional(values.reason),
    notes: _optional(values.notes),
    followUpNeeded: values.followUpNeeded,
    orgId: orgId,
    createdByUid: createdByUid,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  );
}

/// The payload for editing an EXISTING appointment.
///
/// Only the fields this form owns are sent: `careRecipientRef`, `orgId` and
/// `createdByUid` are immutable under the rules, and `questionsToAsk` belongs
/// to Doctor Visit Prep's "Add Question" — an edit here must never drop a
/// question. `updatedAt` is a server stamp (`updatedAt == request.time`), and
/// cleared optional text is removed rather than stored as an empty string.
Map<String, dynamic> updateAppointmentDataFor(AppointmentFormValues values) {
  dynamic orDelete(String value) {
    final text = value.trim();
    return text.isEmpty ? FieldValue.delete() : text;
  }

  final end = values.endAt;
  return {
    'appointmentTitle': values.title.trim(),
    'appointmentType': orDelete(values.type),
    'appointmentDateTime': values.startAt,
    'endDateTime': end == null ? FieldValue.delete() : end,
    'providerName': orDelete(values.providerName),
    'location': orDelete(values.location),
    'reason': orDelete(values.reason),
    'notes': orDelete(values.notes),
    'followUpNeeded': values.followUpNeeded,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
