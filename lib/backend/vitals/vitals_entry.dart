// Vitals recording: input validation, display formatting and the
// last-reading/history view model for the Vitals & Health screen.
//
// Owner decisions of 2026-11-13 (proposal §9) that shape this file:
//  * all seven measurements the `vitalLogs` model already carries are
//    recordable — blood pressure, heart rate, glucose, oxygen saturation,
//    temperature, weight, pain — plus optional free-text notes;
//  * units are fixed once: °F, lb, mg/dL, bpm, %, and pain on a 0–10 scale
//    where 0 is a VALID value;
//  * the plausibility bounds below are input-sanity checks ONLY. They are
//    never shown as a health assessment, and no clinical classification
//    ("Normal", "Elevated", …) exists anywhere in this unit.
import 'package:intl/intl.dart';

import '/backend/backend.dart';

/// Longest free-text note the screen accepts.
const int vitalsNotesMaxLength = 1000;

/// Shown wherever a measurement has no recorded value yet. Never a
/// placeholder number.
const String vitalsNoReadings = 'No readings yet';

/// Shown for a reading whose author cannot be resolved to a member of the
/// recipient's org.
const String vitalsUnknownAuthor = 'Unknown user';

/// The measurements this screen records, in display order.
enum VitalMeasurement {
  bloodPressure('Blood pressure', 'mmHg'),
  heartRate('Heart rate', 'bpm'),
  bloodGlucose('Blood glucose', 'mg/dL'),
  oxygenSaturation('Oxygen saturation', '%'),
  temperature('Temperature', '°F'),
  weight('Weight', 'lb'),
  painLevel('Pain', '0–10');

  const VitalMeasurement(this.label, this.unit);

  final String label;
  final String unit;
}

/// One validated set of values to write into a `vitalLogs` document. Every
/// measurement is optional: a saved log holds only what was entered.
class VitalsDraft {
  const VitalsDraft({
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.heartRate,
    this.bloodGlucose,
    this.oxygenSaturation,
    this.temperature,
    this.weight,
    this.painLevel,
    this.notes = '',
  });

  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final int? heartRate;
  final int? bloodGlucose;
  final int? oxygenSaturation;
  final double? temperature;
  final double? weight;
  final int? painLevel;
  final String notes;

  /// True when at least one measurement was entered. Notes alone are not a
  /// reading.
  bool get hasMeasurement =>
      bloodPressureSystolic != null ||
      bloodPressureDiastolic != null ||
      heartRate != null ||
      bloodGlucose != null ||
      oxygenSaturation != null ||
      temperature != null ||
      weight != null ||
      painLevel != null;
}

/// The outcome of [validateVitalsInput]: either a draft to save, or one clear
/// message naming the field and its accepted range.
class VitalsValidation {
  const VitalsValidation.valid(VitalsDraft this.draft) : error = null;
  const VitalsValidation.invalid(String this.error) : draft = null;

  final VitalsDraft? draft;
  final String? error;

  bool get isValid => draft != null;
}

String _blankToNull(String? value) {
  final trimmed = (value ?? '').trim();
  return trimmed.isEmpty ? null : trimmed;
}

VitalsValidation _invalid(String message) => VitalsValidation.invalid(message);

/// Parses and bounds-checks the raw text of every field on the screen.
///
/// The first problem found is returned as a single message that names the
/// field and the accepted range, so the screen can announce it to a screen
/// reader instead of relying on colour.
VitalsValidation validateVitalsInput({
  String? systolic,
  String? diastolic,
  String? heartRate,
  String? bloodGlucose,
  String? oxygenSaturation,
  String? temperature,
  String? weight,
  String? painLevel,
  String? notes,
}) {
  final notesText = (notes ?? '').trim();
  if (notesText.length > vitalsNotesMaxLength) {
    return _invalid('Additional observations must be '
        '$vitalsNotesMaxLength characters or fewer.');
  }

  final systolicText = _blankToNull(systolic);
  final diastolicText = _blankToNull(diastolic);
  if ((systolicText == null) != (diastolicText == null)) {
    return _invalid('Enter both blood pressure numbers: systolic and '
        'diastolic.');
  }

  int? parseInt(String? raw, String label, int min, int max) {
    final text = _blankToNull(raw);
    if (text == null) {
      return null;
    }
    final value = int.tryParse(text);
    if (value == null) {
      throw FormatException('$label must be a whole number between $min and '
          '$max.');
    }
    if (value < min || value > max) {
      throw FormatException('$label must be a whole number between $min and '
          '$max.');
    }
    return value;
  }

  double? parseDouble(String? raw, String label, double min, double max) {
    final text = _blankToNull(raw);
    if (text == null) {
      return null;
    }
    final value = double.tryParse(text);
    if (value == null) {
      throw FormatException('$label must be a number between '
          '${_bound(min)} and ${_bound(max)}.');
    }
    if (value < min || value > max) {
      throw FormatException('$label must be a number between '
          '${_bound(min)} and ${_bound(max)}.');
    }
    return value;
  }

  try {
    final draft = VitalsDraft(
      bloodPressureSystolic:
          parseInt(systolicText, 'Blood pressure systolic (mmHg)', 40, 300),
      bloodPressureDiastolic:
          parseInt(diastolicText, 'Blood pressure diastolic (mmHg)', 20, 200),
      heartRate: parseInt(heartRate, 'Heart rate (bpm)', 20, 300),
      bloodGlucose: parseInt(bloodGlucose, 'Blood glucose (mg/dL)', 20, 800),
      oxygenSaturation:
          parseInt(oxygenSaturation, 'Oxygen saturation (%)', 50, 100),
      temperature:
          parseDouble(temperature, 'Temperature (°F)', 80.0, 115.0),
      weight: parseDouble(weight, 'Weight (lb)', 20.0, 1000.0),
      // 0 is a valid pain value: the check is on null, never on truthiness.
      painLevel: parseInt(painLevel, 'Pain level (0–10)', 0, 10),
      notes: notesText,
    );
    if (!draft.hasMeasurement) {
      return _invalid('Enter at least one measurement before saving.');
    }
    return VitalsValidation.valid(draft);
  } on FormatException catch (error) {
    return _invalid('${error.message}');
  }
}

String _bound(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';

/// '120/80 mmHg', '72 bpm', '98.6 °F', '0 / 10' — the recorded value for
/// [measurement], or null when this log does not hold it.
String? vitalValueText(VitalLogsRecord log, VitalMeasurement measurement) {
  switch (measurement) {
    case VitalMeasurement.bloodPressure:
      if (!log.hasBloodPressureSystolic() && !log.hasBloodPressureDiastolic()) {
        return null;
      }
      return '${log.bloodPressureSystolic}/${log.bloodPressureDiastolic} mmHg';
    case VitalMeasurement.heartRate:
      return log.hasHeartRate() ? '${log.heartRate} bpm' : null;
    case VitalMeasurement.bloodGlucose:
      return log.hasBloodGlucose() ? '${log.bloodGlucose} mg/dL' : null;
    case VitalMeasurement.oxygenSaturation:
      return log.hasOxygenSaturation() ? '${log.oxygenSaturation} %' : null;
    case VitalMeasurement.temperature:
      return log.hasTemperature() ? '${_decimal(log.temperature)} °F' : null;
    case VitalMeasurement.weight:
      return log.hasWeight() ? '${_decimal(log.weight)} lb' : null;
    case VitalMeasurement.painLevel:
      return log.hasPainLevel() ? '${log.painLevel} / 10' : null;
  }
}

String _decimal(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);

/// The date AND time a reading was logged, e.g. 'Nov 13, 2026 at 8:30 AM'.
String formatVitalDateTime(DateTime at) {
  final local = at.toLocal();
  return '${DateFormat('MMM d, yyyy').format(local)} at '
      '${DateFormat('h:mm a').format(local)}';
}

/// The header's date line, e.g. 'Monday, Oct 23'.
String formatVitalsToday(DateTime now) =>
    DateFormat('EEEE, MMM d').format(now.toLocal());

/// The card's time, e.g. '8:30 AM'.
String formatVitalsClock(DateTime now) =>
    DateFormat('h:mm a').format(now.toLocal());

/// Newest reading first. The query already asks for this order; sorting here
/// keeps the display correct whatever order the documents arrive in.
List<VitalLogsRecord> sortVitalsNewestFirst(List<VitalLogsRecord> logs) {
  final sorted = List<VitalLogsRecord>.from(logs);
  sorted.sort((a, b) {
    final aTime = a.logDateTime;
    final bTime = b.logDateTime;
    if (aTime == null && bTime == null) {
      return 0;
    }
    if (aTime == null) {
      return 1;
    }
    if (bTime == null) {
      return -1;
    }
    return bTime.compareTo(aTime);
  });
  return sorted;
}

/// The line under each card: the recipient's most recent recorded value for
/// that measurement with its date and time, or [vitalsNoReadings].
String lastReadingText(
  List<VitalLogsRecord> newestFirst,
  VitalMeasurement measurement,
) {
  for (final log in newestFirst) {
    final value = vitalValueText(log, measurement);
    if (value == null) {
      continue;
    }
    final at = log.logDateTime;
    return at == null ? 'Last: $value' : 'Last: $value · '
        '${formatVitalDateTime(at)}';
  }
  return vitalsNoReadings;
}

/// One history row: what was recorded, when, by whom.
class VitalsHistoryEntry {
  const VitalsHistoryEntry({
    required this.log,
    required this.dateTimeText,
    required this.valueLines,
    required this.notes,
    required this.authorName,
  });

  final VitalLogsRecord log;
  final String dateTimeText;

  /// 'Heart rate: 72 bpm' for each measurement this log actually holds.
  final List<String> valueLines;
  final String notes;
  final String authorName;

  bool get hasNotes => notes.isNotEmpty;
}

/// Builds the history rows for [logs] (newest first), resolving author names
/// through [authorNames] (uid → name).
List<VitalsHistoryEntry> buildVitalsHistory({
  required List<VitalLogsRecord> logs,
  required Map<String, String> authorNames,
}) {
  return sortVitalsNewestFirst(logs).map((log) {
    final at = log.logDateTime;
    final author = (authorNames[log.loggedByUid] ?? '').trim();
    return VitalsHistoryEntry(
      log: log,
      dateTimeText: at == null ? 'Time not recorded' : formatVitalDateTime(at),
      valueLines: [
        for (final measurement in VitalMeasurement.values)
          if (vitalValueText(log, measurement) != null)
            '${measurement.label}: ${vitalValueText(log, measurement)}',
      ],
      notes: log.notes.trim(),
      authorName: author.isEmpty ? vitalsUnknownAuthor : author,
    );
  }).toList();
}
