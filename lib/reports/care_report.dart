// Care report — the data layer behind the Doctor Prep page's 'Export' action
// (U5, owner-approved spec 2026-11-03).
//
// Owner direction: build the report from EXISTING care records over a
// user-selected range (presets, no fixed window), include only information that
// was actually recorded, keep original notes verbatim, and let the report
// length scale with the data. Nothing here invents content: a section is built
// only from records that carry their own stored timestamp inside the range, and
// a range with no records produces an honest no-records report.
//
// Which per-recipient collections can be used is fixed by what the app can
// actually READ (see `firebase/firestore.rules`): `symptomEntries`, `careNotes`
// and `medications` are readable; `vitalLogs`, `appointments`, `dashboardNotes`
// and `emerencyinfo` are deny-all in the Phase-4 lockdown, so they cannot be
// reported on at all. `carechecklist` is readable but stores no completion time
// (only a `completed` flag and the task's `created_time`), so it cannot be
// honestly date-ranged and is left out rather than guessed at.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '/app_state.dart';
import '/backend/backend.dart';

/// A date as it appears in the report ('1 Oct 2026').
String careReportDate(DateTime date) => DateFormat('d MMM yyyy').format(date);

/// A timestamp as it appears in the report ('1 Oct 2026, 8:00 PM').
String careReportDateTime(DateTime dateTime) =>
    DateFormat('d MMM yyyy, h:mm a').format(dateTime);

/// The presets offered by the range sheet. 'Last 30 days' is the default.
enum CareReportPreset { last7Days, last30Days, last90Days, allTime, custom }

/// The preset the range sheet opens on (owner spec: Last 30 days).
const CareReportPreset defaultCareReportPreset = CareReportPreset.last30Days;

/// The label shown for a preset in the sheet and in the report header.
String careReportPresetLabel(CareReportPreset preset) {
  switch (preset) {
    case CareReportPreset.last7Days:
      return 'Last 7 days';
    case CareReportPreset.last30Days:
      return 'Last 30 days';
    case CareReportPreset.last90Days:
      return 'Last 90 days';
    case CareReportPreset.allTime:
      return 'All time';
    case CareReportPreset.custom:
      return 'Custom';
  }
}

/// The dates a report covers.
///
/// [start] and [end] are inclusive CALENDAR DAYS (not instants): an entry
/// logged at 23:59 on the end date belongs to the report, which is what a
/// caregiver picking "Last 7 days" expects. A null bound means unbounded, which
/// is how 'All time' is expressed — no invented start date.
class CareReportRange {
  const CareReportRange({required this.label, this.start, this.end});

  final String label;
  final DateTime? start;
  final DateTime? end;

  static DateTime dayOnly(DateTime dateTime) =>
      DateTime(dateTime.year, dateTime.month, dateTime.day);

  /// Whether [timestamp] falls inside the range. A record with no stored
  /// timestamp cannot be placed in a period, so it is never included.
  bool includes(DateTime? timestamp) {
    if (timestamp == null) {
      return false;
    }
    final day = dayOnly(timestamp.toLocal());
    final from = start == null ? null : dayOnly(start!);
    final to = end == null ? null : dayOnly(end!);
    if (from != null && day.isBefore(from)) {
      return false;
    }
    if (to != null && day.isAfter(to)) {
      return false;
    }
    return true;
  }

  /// The resolved bounds printed in the report header ('1 Oct 2026 - 30 Oct
  /// 2026'), or 'All time' when neither bound is set.
  String get boundsLabel {
    if (start == null && end == null) {
      return 'All time';
    }
    if (start == null) {
      return 'Up to ${careReportDate(end!)}';
    }
    if (end == null) {
      return 'From ${careReportDate(start!)}';
    }
    return '${careReportDate(start!)} - ${careReportDate(end!)}';
  }

  @override
  String toString() => '$label ($boundsLabel)';
}

/// Resolves a preset into the concrete range it covers.
///
/// [now] is injectable so tests (and the sheet) are not time-dependent. A custom
/// range with reversed dates is normalised; a custom range with a missing bound
/// is simply open on that side.
CareReportRange careReportRangeFor(
  CareReportPreset preset, {
  DateTime? now,
  DateTime? customStart,
  DateTime? customEnd,
}) {
  final today = CareReportRange.dayOnly(now ?? DateTime.now());
  switch (preset) {
    case CareReportPreset.last7Days:
      return CareReportRange(
        label: careReportPresetLabel(preset),
        start: today.subtract(const Duration(days: 6)),
        end: today,
      );
    case CareReportPreset.last30Days:
      return CareReportRange(
        label: careReportPresetLabel(preset),
        start: today.subtract(const Duration(days: 29)),
        end: today,
      );
    case CareReportPreset.last90Days:
      return CareReportRange(
        label: careReportPresetLabel(preset),
        start: today.subtract(const Duration(days: 89)),
        end: today,
      );
    case CareReportPreset.allTime:
      return CareReportRange(label: careReportPresetLabel(preset));
    case CareReportPreset.custom:
      var from = customStart == null ? null : CareReportRange.dayOnly(customStart);
      var to = customEnd == null ? null : CareReportRange.dayOnly(customEnd);
      if (from != null && to != null && to.isBefore(from)) {
        final swapped = from;
        from = to;
        to = swapped;
      }
      return CareReportRange(
        label: careReportPresetLabel(preset),
        start: from,
        end: to,
      );
  }
}

/// One reported symptom, exactly as it was logged.
class CareReportSymptom {
  const CareReportSymptom({
    required this.name,
    required this.note,
    required this.timeLogged,
    required this.resolved,
  });

  final String name;

  /// The caregiver's original note, verbatim.
  final String note;
  final DateTime? timeLogged;
  final bool resolved;
}

/// One entry of the recipient's stored medication list.
///
/// This is the CURRENT list, not a date-ranged one — a medication record is a
/// standing order, so the report says so explicitly rather than pretending the
/// list only covers the chosen period.
class CareReportMedication {
  const CareReportMedication({
    required this.name,
    required this.dose,
    required this.schedule,
    required this.status,
  });

  final String name;
  final String dose;
  final String schedule;

  /// The stored status/active marker, or '' when the record stores neither.
  final String status;
}

/// One care note, exactly as it was written.
class CareReportNote {
  const CareReportNote({
    required this.text,
    required this.author,
    required this.category,
    required this.timestamp,
  });

  /// The caregiver's original note text, verbatim.
  final String text;
  final String author;
  final String category;
  final DateTime? timestamp;
}

/// Everything a report renders — assembled from records, nothing else.
class CareReportData {
  const CareReportData({
    required this.recipientName,
    required this.careCircleName,
    required this.range,
    required this.generatedAt,
    required this.symptoms,
    required this.medications,
    required this.notes,
  });

  final String recipientName;

  /// The care circle / organisation name, or '' when it could not be read.
  final String careCircleName;
  final CareReportRange range;
  final DateTime generatedAt;
  final List<CareReportSymptom> symptoms;
  final List<CareReportMedication> medications;
  final List<CareReportNote> notes;

  /// Printed instead of sections when nothing was recorded in the period.
  static const noRecordsNotice = 'No care records were recorded in this period.';

  /// Printed under the header so a reader knows why a section is missing.
  static const scopeNotice =
      'This report contains only records saved in the app for the period above. '
      'Sections with no records in that period are omitted.';

  /// The date-ranged sections (symptoms, care notes) hold at least one record.
  bool get hasRangedRecords => symptoms.isNotEmpty || notes.isNotEmpty;

  /// Nothing at all to report — not even a current medication list.
  bool get isEmpty => !hasRangedRecords && medications.isEmpty;

  /// The timestamp of the oldest / newest ranged record, for the header's
  /// 'records from X to Y' line. Null when there are no ranged records.
  DateTime? get firstRecordAt {
    final stamps = _rangedTimestamps;
    if (stamps.isEmpty) {
      return null;
    }
    stamps.sort();
    return stamps.first;
  }

  DateTime? get lastRecordAt {
    final stamps = _rangedTimestamps;
    if (stamps.isEmpty) {
      return null;
    }
    stamps.sort();
    return stamps.last;
  }

  List<DateTime> get _rangedTimestamps => [
        for (final symptom in symptoms)
          if (symptom.timeLogged != null) symptom.timeLogged!,
        for (final note in notes)
          if (note.timestamp != null) note.timestamp!,
      ];
}

/// Builds the report content from already-read records.
///
/// Pure: it does no I/O, so the range rules and section assembly are testable
/// without Firestore. Symptoms and care notes are filtered on their OWN stored
/// timestamp (never a substitute), newest first; medications are the current
/// list, ordered by name.
CareReportData assembleCareReport({
  required String recipientName,
  required String careCircleName,
  required CareReportRange range,
  required DateTime generatedAt,
  required List<SymptomEntriesRecord> symptoms,
  required List<MedicationsRecord> medications,
  required List<CareNotesRecord> notes,
}) {
  final reportSymptoms = symptoms
      .where((record) => range.includes(record.timeLogged))
      .map((record) => CareReportSymptom(
            name: record.symptomName.trim(),
            note: record.note,
            timeLogged: record.timeLogged,
            resolved: record.isResolved,
          ))
      .toList()
    ..sort((a, b) => _newestFirst(a.timeLogged, b.timeLogged));

  final reportNotes = notes
      .where((record) => range.includes(_noteTimestamp(record)))
      .map((record) => CareReportNote(
            text: record.noteText,
            author: record.createdBy.trim(),
            category: record.category.trim(),
            timestamp: _noteTimestamp(record),
          ))
      .toList()
    ..sort((a, b) => _newestFirst(a.timestamp, b.timestamp));

  final reportMedications = medications
      .map((record) => CareReportMedication(
            name: record.medicationName.trim(),
            dose: record.dose.trim(),
            schedule: _medicationSchedule(record),
            status: _medicationStatus(record),
          ))
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return CareReportData(
    recipientName: recipientName,
    careCircleName: careCircleName,
    range: range,
    generatedAt: generatedAt,
    symptoms: reportSymptoms,
    medications: reportMedications,
    notes: reportNotes,
  );
}

/// A care note's own timestamp: when it was written (`noteDateTime`), falling
/// back to the record's `createdAt`. Null when neither is stored.
DateTime? _noteTimestamp(CareNotesRecord record) =>
    record.noteDateTime ?? record.createdAt;

String _medicationSchedule(MedicationsRecord record) {
  final directions = record.directions.trim();
  final timeOfDay = record.timeOfDay.trim();
  if (directions.isNotEmpty) {
    return directions;
  }
  return timeOfDay;
}

String _medicationStatus(MedicationsRecord record) {
  final status = record.status.trim();
  if (status.isNotEmpty) {
    return status;
  }
  if (record.hasActive()) {
    return record.active ? 'Active' : 'Inactive';
  }
  return '';
}

int _newestFirst(DateTime? a, DateTime? b) {
  if (a == null && b == null) {
    return 0;
  }
  if (a == null) {
    return 1;
  }
  if (b == null) {
    return -1;
  }
  return b.compareTo(a);
}

/// A filesystem-safe name for the generated PDF.
String careReportFileName(CareReportData data) {
  final who = data.recipientName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final day = DateFormat('yyyyMMdd').format(data.generatedAt);
  return who.isEmpty ? 'care-report-$day.pdf' : 'care-report-$who-$day.pdf';
}

/// Reads the recipient's care records and assembles the report for [range].
///
/// Only collections the app can actually read are queried, each with the same
/// recipient scoping the rest of the app uses (the field the Phase-4 rules gate
/// on). Reads happen first and any failure is rethrown, so the caller shows a
/// real error instead of printing a silently blank report.
Future<CareReportData> loadCareReportData({
  required DocumentReference recipientRef,
  required CareReportRange range,
  DateTime? generatedAt,
}) async {
  final recipient = await CareRecipientsRecord.getDocumentOnce(recipientRef);
  final activeGroupId = (FFAppState().activeGroupId ?? '').trim();
  final orgId =
      activeGroupId.isNotEmpty ? activeGroupId : recipient.orgId.trim();

  final symptoms = await querySymptomEntriesRecordOnce(
    queryBuilder: (query) => query.where('patientRef', isEqualTo: recipientRef),
  );
  final notes = await queryCareNotesRecordOnce(
    queryBuilder: (query) =>
        query.where('careRecipientRef', isEqualTo: recipientRef),
  );
  // The medications LIST rule gates on the stored orgId, so the query must
  // filter on it (same scoped read the Medication Tracker and Dashboard use).
  final medications = await queryMedicationsRecordOnce(
    queryBuilder: (query) => orgId.isEmpty
        ? query.where('careRecipientRef', isEqualTo: recipientRef)
        : query
            .where('orgId', isEqualTo: orgId)
            .where('careRecipientRef', isEqualTo: recipientRef),
  );

  return assembleCareReport(
    recipientName: recipient.name.trim(),
    careCircleName: await careCircleNameFor(orgId),
    range: range,
    generatedAt: generatedAt ?? DateTime.now(),
    symptoms: symptoms,
    medications: medications,
    notes: notes,
  );
}

/// The care circle / organisation name for [orgId], or '' when it cannot be
/// read (an unset id, a rules denial, an org without a name). Best-effort only:
/// the header omits the line rather than failing the whole export.
Future<String> careCircleNameFor(String orgId) async {
  if (orgId.isEmpty) {
    return '';
  }
  try {
    final record = await OrganizationsRecord.getDocumentOnce(
      FirebaseFirestore.instance.collection('organizations').doc(orgId),
    );
    return record.name.trim();
  } catch (_) {
    return '';
  }
}
