// Vitals export — the data layer behind the Vitals screen's export icon.
//
// Owner decisions of 2026-11-18 (`/home/team/shared/vitals-export-proposal-2026-11-18.md`
// §13, all thirteen approved as recommended) implemented here:
//  * one row per READING, never one row per day; a day heading above that day's
//    rows, oldest first;
//  * every cell comes from that reading's own stored fields. A measurement that
//    was not recorded prints a dash, never the getter's 0 — and pain 0 is a real
//    value that prints "0 / 10";
//  * `notes` verbatim, on a line under its own row;
//  * the author is the real member display name, falling back to the app's
//    existing "Unknown user" (`vitalsUnknownAuthor`), never a blank cell;
//  * the comparison is against the target ranges a HUMAN entered for this
//    recipient (Unit 1, `VitalsTargets` on `careRecipients`). The only words are
//    "Below target" / "Within target" / "Above target", with a dash where no
//    target exists. Nothing here interprets a reading, defaults a number or
//    derives one from DateOfBirth;
//  * no averages, no charts, no metric units, no other collection, no org-wide
//    read — this is a reader, in every branch. Nothing is written.
//
// The query is recipient-scoped and range-bounded, which is exactly what the
// merged `vitalLogs` rules gate a list on, and what the composite index
// (`careRecipientRef` ASC, `logDateTime` DESC) already covers.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '/backend/backend.dart';
import '/backend/org/org_service.dart';
import '/backend/vitals/vitals_entry.dart';
import '/backend/vitals/vitals_targets.dart';
import 'care_report.dart';

/// Printed wherever a measurement was not recorded. Never a 0, never blank.
const String vitalsExportMissingValue = '—';

/// Printed when the chosen period holds no readings at all.
const String vitalsExportNoReadingsNotice =
    'No vitals were recorded in this period.';

/// The one line that states where the target numbers came from.
const String vitalsExportTargetsNotice =
    'Targets were entered for this care recipient by the care team and are not '
    'medical advice.';

/// A stored timestamp is printed as local time, and the report says so once.
const String vitalsExportLocalTimeNotice = 'Times are shown in local time.';

/// The only three comparison words that may appear (owner decision, item 3).
const String vitalsExportBelowTarget = 'Below target';
const String vitalsExportWithinTarget = 'Within target';
const String vitalsExportAboveTarget = 'Above target';

/// The high safety cap on one export. Reaching it prints an explicit
/// "showing N of M" line — a report never truncates silently.
const int kVitalsExportMaxRows = 2000;

/// The table's column headings, in display order. Each measurement column's
/// values carry their own unit, so the heading stays short.
const List<String> vitalsExportColumnHeaders = <String>[
  'Date',
  'Time',
  'BP',
  'HR',
  'Glucose',
  'O2',
  'Temp',
  'Weight',
  'Pain',
  'Logged by',
];

/// The measurements that get a column, in display order.
const List<VitalMeasurement> vitalsExportMeasurements =
    <VitalMeasurement>[
  VitalMeasurement.bloodPressure,
  VitalMeasurement.heartRate,
  VitalMeasurement.bloodGlucose,
  VitalMeasurement.oxygenSaturation,
  VitalMeasurement.temperature,
  VitalMeasurement.weight,
  VitalMeasurement.painLevel,
];

String _decimalText(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);

/// One measurement of one reading as it is printed: the recorded value with its
/// unit, or [vitalsExportMissingValue] when it was not recorded.
///
/// The branch is on `has<Field>()`, never on the value, so an unrecorded
/// measurement can never print as the getter's 0. Blood pressure prints
/// whichever of the pair exists with a dash for the other.
String vitalsExportValueText(VitalLogsRecord log, VitalMeasurement measurement) {
  switch (measurement) {
    case VitalMeasurement.bloodPressure:
      final hasSystolic = log.hasBloodPressureSystolic();
      final hasDiastolic = log.hasBloodPressureDiastolic();
      if (!hasSystolic && !hasDiastolic) {
        return vitalsExportMissingValue;
      }
      final systolic =
          hasSystolic ? '${log.bloodPressureSystolic}' : vitalsExportMissingValue;
      final diastolic =
          hasDiastolic ? '${log.bloodPressureDiastolic}' : vitalsExportMissingValue;
      return '$systolic/$diastolic ${measurement.unit}';
    case VitalMeasurement.heartRate:
      return log.hasHeartRate()
          ? '${log.heartRate} ${measurement.unit}'
          : vitalsExportMissingValue;
    case VitalMeasurement.bloodGlucose:
      return log.hasBloodGlucose()
          ? '${log.bloodGlucose} ${measurement.unit}'
          : vitalsExportMissingValue;
    case VitalMeasurement.oxygenSaturation:
      return log.hasOxygenSaturation()
          ? '${log.oxygenSaturation} ${measurement.unit}'
          : vitalsExportMissingValue;
    case VitalMeasurement.temperature:
      return log.hasTemperature()
          ? '${_decimalText(log.temperature)} ${measurement.unit}'
          : vitalsExportMissingValue;
    case VitalMeasurement.weight:
      return log.hasWeight()
          ? '${_decimalText(log.weight)} ${measurement.unit}'
          : vitalsExportMissingValue;
    case VitalMeasurement.painLevel:
      // 0 is a real pain score: the check is on null, never on truthiness.
      return log.hasPainLevel()
          ? '${log.painLevel} / 10'
          : vitalsExportMissingValue;
  }
}

/// Which side of a one-sided or two-sided target a value fell on.
String _comparisonWord(num value, VitalsTargetRange range) {
  if (range.min != null && value < range.min!) {
    return vitalsExportBelowTarget;
  }
  if (range.max != null && value > range.max!) {
    return vitalsExportAboveTarget;
  }
  return vitalsExportWithinTarget;
}

/// The comparison printed under one measurement's value, or null when there is
/// nothing to compare (no recorded value, or no target for that measurement).
///
/// Blood pressure is "within" only when every side that has a target is within;
/// when the two sides disagree the cell names which side fell where, using only
/// the three approved words.
String? vitalsExportComparisonText(
  VitalLogsRecord log,
  VitalMeasurement measurement,
  Map<String, VitalsTargetRange> targets,
) {
  if (measurement == VitalMeasurement.bloodPressure) {
    final systolicTarget = targets[kVitalsTargetBloodPressureSystolic.key];
    final diastolicTarget = targets[kVitalsTargetBloodPressureDiastolic.key];
    if (systolicTarget == null && diastolicTarget == null) {
      return null;
    }
    final systolic =
        log.hasBloodPressureSystolic() ? log.bloodPressureSystolic : null;
    final diastolic =
        log.hasBloodPressureDiastolic() ? log.bloodPressureDiastolic : null;
    final systolicWord = systolic == null || systolicTarget == null
        ? null
        : _comparisonWord(systolic, systolicTarget);
    final diastolicWord = diastolic == null || diastolicTarget == null
        ? null
        : _comparisonWord(diastolic, diastolicTarget);
    if (systolicWord == null && diastolicWord == null) {
      return null;
    }
    if (systolicWord != null && diastolicWord != null) {
      if (systolicWord == diastolicWord) {
        return systolicWord;
      }
      return '$systolicWord (systolic) / $diastolicWord (diastolic)';
    }
    return systolicWord ?? diastolicWord;
  }

  final target = targets[measurement.name];
  if (target == null) {
    return null;
  }
  num? value;
  switch (measurement) {
    case VitalMeasurement.heartRate:
      value = log.hasHeartRate() ? log.heartRate : null;
      break;
    case VitalMeasurement.bloodGlucose:
      value = log.hasBloodGlucose() ? log.bloodGlucose : null;
      break;
    case VitalMeasurement.oxygenSaturation:
      value = log.hasOxygenSaturation() ? log.oxygenSaturation : null;
      break;
    case VitalMeasurement.temperature:
      value = log.hasTemperature() ? log.temperature : null;
      break;
    case VitalMeasurement.weight:
      value = log.hasWeight() ? log.weight : null;
      break;
    case VitalMeasurement.painLevel:
    case VitalMeasurement.bloodPressure:
      value = null;
      break;
  }
  return value == null ? null : _comparisonWord(value, target);
}

/// The heading above a day's rows: '18 Nov 2026 · 2 readings'. The count is a
/// real count of that day's readings.
String vitalsExportDayHeading(DateTime day, int count) =>
    '${careReportDate(day)} · $count ${count == 1 ? 'reading' : 'readings'}';

/// The time of a reading, device-local: '7:12 AM'.
String vitalsExportTimeText(DateTime at) =>
    DateFormat('h:mm a').format(at.toLocal());

/// One reading's row.
class VitalsExportReading {
  const VitalsExportReading({
    required this.loggedAt,
    required this.timeText,
    required this.values,
    required this.comparisons,
    required this.author,
    required this.notes,
  });

  final DateTime? loggedAt;
  final String timeText;

  /// Every column's text, including [vitalsExportMissingValue] where the
  /// measurement was not recorded.
  final Map<VitalMeasurement, String> values;

  /// The comparison under each measurement, for measurements that have a
  /// target. Empty when the recipient has no targets at all.
  final Map<VitalMeasurement, String> comparisons;

  final String author;
  final String notes;

  bool get hasNotes => notes.isNotEmpty;

  String valueFor(VitalMeasurement measurement) =>
      values[measurement] ?? vitalsExportMissingValue;

  /// The comparison word for [measurement], or a dash where there is none.
  String comparisonFor(VitalMeasurement measurement) =>
      comparisons[measurement] ?? vitalsExportMissingValue;
}

/// One day of the export: its heading and that day's readings, oldest first.
class VitalsExportDay {
  const VitalsExportDay({
    required this.date,
    required this.heading,
    required this.readings,
  });

  final DateTime date;
  final String heading;
  final List<VitalsExportReading> readings;
}

/// Everything the export renders — assembled from records and the numbers a
/// human entered, nothing else.
class VitalsExportData {
  const VitalsExportData({
    required this.recipientName,
    required this.range,
    required this.generatedAt,
    required this.days,
    required this.targets,
    this.undatedCount = 0,
    this.totalInPeriod,
    this.capped = false,
  });

  final String recipientName;
  final CareReportRange range;
  final DateTime generatedAt;
  final List<VitalsExportDay> days;

  /// The target ranges entered for this recipient, keyed by measurement. Empty
  /// means no indicator text appears anywhere in the report.
  final Map<String, VitalsTargetRange> targets;

  /// Readings the query returned that carry no timestamp, so they cannot be
  /// placed in a period. Normally 0: the read is ordered by `logDateTime`, and
  /// a document without that field is not returned at all.
  final int undatedCount;

  /// The real number of readings in the period, when the safety cap was
  /// reached; null otherwise.
  final int? totalInPeriod;

  /// True when the read itself hit the safety cap, so the report is short of
  /// the period's readings whatever the count query managed to return. The
  /// notice is printed from this, never from the count alone: a capped report
  /// is always stated, even when the total is unknown.
  final bool capped;

  int get readingCount =>
      days.fold(0, (sum, day) => sum + day.readings.length);

  bool get hasReadings => readingCount > 0;

  bool get hasTargets => targets.isNotEmpty;

  /// True when the cap cut the report short, so the "showing N of M" line
  /// prints.
  bool get isTruncated =>
      capped || (totalInPeriod != null && totalInPeriod! > readingCount);

  /// The measurements that actually have a target, in display order — the
  /// report lists them so a dash is never a mystery.
  List<VitalsTargetMeasurement> get targetMeasurements =>
      <VitalsTargetMeasurement>[
        for (final measurement in kVitalsTargetMeasurements)
          if (targets.containsKey(measurement.key)) measurement,
      ];
}

int _oldestFirst(DateTime? a, DateTime? b) {
  if (a == null && b == null) {
    return 0;
  }
  if (a == null) {
    return 1;
  }
  if (b == null) {
    return -1;
  }
  return a.compareTo(b);
}

/// Builds the export content from already-read records.
///
/// Pure: it does no I/O. Readings outside [range] are dropped (a reading with no
/// timestamp cannot be placed in a period either), the rest are ordered oldest
/// first and grouped by local day. [authorNames] maps a uid to the name that was
/// resolved for it; an unresolved author falls back to `vitalsUnknownAuthor`.
VitalsExportData assembleVitalsExport({
  required String recipientName,
  required CareReportRange range,
  required DateTime generatedAt,
  required List<VitalLogsRecord> logs,
  required Map<String, String> authorNames,
  Map<String, VitalsTargetRange> targets = const <String, VitalsTargetRange>{},
  int? totalInPeriod,
  bool capped = false,
}) {
  var undated = 0;
  final inRange = <VitalLogsRecord>[];
  for (final log in logs) {
    if (log.logDateTime == null) {
      undated++;
      continue;
    }
    if (!range.includes(log.logDateTime)) {
      continue;
    }
    inRange.add(log);
  }
  inRange.sort((a, b) => _oldestFirst(a.logDateTime, b.logDateTime));

  final days = <VitalsExportDay>[];
  final byDay = <String, List<VitalLogsRecord>>{};
  final dayDates = <String, DateTime>{};
  for (final log in inRange) {
    final local = log.logDateTime!.toLocal();
    final day = CareReportRange.dayOnly(local);
    final key = '${day.year}-${day.month}-${day.day}';
    byDay.putIfAbsent(key, () => <VitalLogsRecord>[]).add(log);
    dayDates[key] = day;
  }
  for (final key in byDay.keys) {
    final dayLogs = byDay[key]!;
    final readings = <VitalsExportReading>[];
    for (final log in dayLogs) {
      final values = <VitalMeasurement, String>{};
      final comparisons = <VitalMeasurement, String>{};
      for (final measurement in vitalsExportMeasurements) {
        values[measurement] = vitalsExportValueText(log, measurement);
        if (targets.isNotEmpty) {
          final comparison =
              vitalsExportComparisonText(log, measurement, targets);
          if (comparison != null) {
            comparisons[measurement] = comparison;
          }
        }
      }
      final author = (authorNames[log.loggedByUid] ?? '').trim();
      readings.add(VitalsExportReading(
        loggedAt: log.logDateTime,
        timeText: vitalsExportTimeText(log.logDateTime!),
        values: values,
        comparisons: comparisons,
        author: author.isEmpty ? vitalsUnknownAuthor : author,
        notes: log.notes.trim(),
      ));
    }
    final date = dayDates[key]!;
    days.add(VitalsExportDay(
      date: date,
      heading: vitalsExportDayHeading(date, readings.length),
      readings: readings,
    ));
  }
  days.sort((a, b) => a.date.compareTo(b.date));

  return VitalsExportData(
    recipientName: recipientName,
    range: range,
    generatedAt: generatedAt,
    days: days,
    targets: targets,
    undatedCount: undated,
    totalInPeriod: totalInPeriod,
    capped: capped,
  );
}

/// The line naming which measurements have a target, so a dash under another
/// measurement is explained rather than mysterious.
String vitalsExportTargetsLine(VitalsExportData data) {
  final labels = data.targetMeasurements.map((m) => m.label).join(', ');
  return labels.isEmpty
      ? vitalsExportTargetsNotice
      : '$vitalsExportTargetsNotice Measurements with a target: $labels.';
}

/// The line printed when the safety cap was reached — never a silent
/// truncation.
String vitalsExportTruncatedNotice(VitalsExportData data) {
  final shown = data.readingCount;
  final total = data.totalInPeriod;
  if (total == null) {
    final label = shown == 1 ? 'reading' : 'readings';
    return 'Showing the first $shown $label. There are more readings in this '
        'period than one report can show.';
  }
  return 'Showing the first $shown of $total readings in this period.';
}

/// The line printed when readings could not be placed in the period.
String vitalsExportUndatedNotice(int count) => count == 1
    ? '1 reading has no date and is not shown.'
    : '$count readings have no date and are not shown.';

/// A filesystem-safe name for the generated PDF:
/// `vitals-<recipient>-<range>.pdf`.
String vitalsExportFileName(VitalsExportData data) {
  final who = data.recipientName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  var range = data.range.label
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (range.isEmpty) {
    range = 'vitals';
  }
  final parts = <String>['vitals'];
  if (who.isNotEmpty) {
    parts.add(who);
  }
  parts.add(range);
  return '${parts.join('-')}.pdf';
}

/// Reads one recipient's readings over [range] and assembles the export.
///
/// The read is recipient-scoped (the field the rules gate a list on) and
/// range-bounded, ordered oldest first. A failure is rethrown so the caller
/// shows a real error and produces no file, rather than an empty report.
Future<VitalsExportData> loadVitalsExportData({
  required DocumentReference recipientRef,
  required CareReportRange range,
  DateTime? generatedAt,
  int maxRows = kVitalsExportMaxRows,
}) async {
  final recipient = await CareRecipientsRecord.getDocumentOnce(recipientRef);
  final orgId = recipient.orgId.trim();

  final start = range.start == null ? null : CareReportRange.dayOnly(range.start!);
  final end = range.end == null
      ? null
      : DateTime(range.end!.year, range.end!.month, range.end!.day, 23, 59, 59,
          999);

  Query bounded(Query query) {
    var q = query.where('careRecipientRef', isEqualTo: recipientRef);
    if (start != null) {
      q = q.where('logDateTime', isGreaterThanOrEqualTo: start);
    }
    if (end != null) {
      q = q.where('logDateTime', isLessThanOrEqualTo: end);
    }
    return q;
  }

  // One row more than the cap, so reaching it is detectable.
  final read = await queryVitalLogsRecordOnce(
    queryBuilder: (query) => bounded(query).orderBy('logDateTime'),
    limit: maxRows + 1,
  );

  final truncated = read.length > maxRows;
  final logs = truncated ? read.take(maxRows).toList() : read;

  int? totalInPeriod;
  if (truncated) {
    try {
      totalInPeriod = await queryVitalLogsRecordCount(
        queryBuilder: (query) => bounded(query),
      );
    } catch (_) {
      // The count is only used for the "of M" half of the notice; without it
      // the report still says plainly that it is showing the first N.
      totalInPeriod = null;
    }
  }

  final authorNames = <String, String>{};
  if (orgId.isNotEmpty) {
    for (final uid in {for (final log in logs) log.loggedByUid}) {
      if (uid.isEmpty) {
        continue;
      }
      final member = await getMembership(orgId, uid);
      final name = (member?.displayName ?? '').trim();
      if (name.isNotEmpty) {
        authorNames[uid] = name;
        continue;
      }
      final email = (member?.email ?? '').trim();
      if (email.isNotEmpty) {
        authorNames[uid] = email;
      }
    }
  }

  return assembleVitalsExport(
    recipientName: recipient.name.trim(),
    range: range,
    generatedAt: generatedAt ?? DateTime.now(),
    logs: logs,
    authorNames: authorNames,
    targets: vitalsTargetsFromRecord(
      recipient.hasVitalsTargets() ? recipient.vitalsTargets : null,
    ),
    totalInPeriod: totalInPeriod,
    capped: truncated,
  );
}
