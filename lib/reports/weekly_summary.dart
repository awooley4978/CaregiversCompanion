// Weekly Summary — the data layer behind the Weekly Summary screen
// (`lib/pages/h_weekly_summary_report/`).
//
// The owner approved all eleven decisions of
// `/home/team/shared/weekly-summary-proposal-2026-11-17.md` (§13) on
// 2026-11-17. Everything below implements that contract and nothing else:
//
//  * the page's range is a real range (default: Last 7 days) resolved by the
//    existing `careReportRangeFor` / `CareReportRange`, so every record is
//    placed by its OWN stored timestamp inside the period;
//  * Vitals Overview shows averages for blood pressure and heart rate with the
//    number of readings behind them, and the LATEST reading for weight and
//    blood glucose; oxygen saturation, temperature and pain level stay off the
//    screen because the design has four tiles;
//  * the line chart is one point per day — that day's mean systolic — with
//    GAPS on days with no reading (never a zero) and axis bounds computed from
//    the real points;
//  * Care Logs are real care notes, vitals, water entries and appointments,
//    newest first, each with its real author; symptom entries are excluded
//    because they store no author (they are already in the Doctor Prep PDF);
//  * the Medications card is the recipient's real CURRENT medication list plus
//    a real count — adherence, missed doses and most-frequent are dropped
//    because the app stores no dose history at all;
//  * Notes for Doctor is the period's `important` / `followUpNeeded` care note
//    (else the most recent one), verbatim, with its real author and date;
//  * the PDF is the same care report Doctor Prep exports, over this page's
//    range (`loadCareReportData` + `buildCareReportPdf`).
//
// No new collection, field, rule or index: every read below is one a shipped
// screen already performs, with the same recipient scoping the merged rules
// require (`careRecipientRef` on vitals / water / appointments / care notes,
// plus `orgId` on medications). Nothing is written here.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '/app_state.dart';
import '/backend/backend.dart';
import '/backend/org/org_service.dart';
import '/reports/care_report.dart';

/// Bounds on the per-recipient reads.
///
/// The vitals tracker reads the newest 50 readings and the water card the
/// newest 200 entries, so this page uses the same bounds (the composite indexes
/// serve exactly these queries). If a bound is actually reached the page says
/// so instead of quietly under-counting an average.
const int weeklySummaryVitalsLimit = 50;
const int weeklySummaryWaterLimit = 200;

/// The design draws four Care Log rows.
const int weeklySummaryLogRows = 4;

/// Where a Care Log row came from — used for its dot colour and nothing else.
enum WeeklySummaryLogSource { careNote, vitals, water, appointment }

/// The four Vitals Overview tiles, computed from the period's readings.
///
/// A null value means "nothing was recorded" — the page shows an honest dash
/// for it, never a placeholder number.
class WeeklySummaryVitals {
  const WeeklySummaryVitals({
    this.averageSystolic,
    this.averageDiastolic,
    this.bloodPressureReadings = 0,
    this.averageHeartRate,
    this.heartRateReadings = 0,
    this.latestWeight,
    this.latestWeightAt,
    this.latestGlucose,
    this.latestGlucoseAt,
  });

  final int? averageSystolic;
  final int? averageDiastolic;
  final int bloodPressureReadings;
  final int? averageHeartRate;
  final int heartRateReadings;
  final double? latestWeight;
  final DateTime? latestWeightAt;
  final int? latestGlucose;
  final DateTime? latestGlucoseAt;

  bool get hasBloodPressure => averageSystolic != null && averageDiastolic != null;
  bool get hasHeartRate => averageHeartRate != null;
  bool get hasWeight => latestWeight != null;
  bool get hasGlucose => latestGlucose != null;
  bool get isEmpty => !hasBloodPressure && !hasHeartRate && !hasWeight && !hasGlucose;
}

/// One plotted day: that day's mean systolic value.
class WeeklySummaryDayPoint {
  const WeeklySummaryDayPoint({
    required this.day,
    required this.systolic,
    required this.x,
  });

  final DateTime day;
  final double systolic;

  /// The day's index in the chart, counted from the period's first day.
  final int x;
}

/// One Care Log row: what happened, who recorded it, when.
class WeeklySummaryLogEntry {
  const WeeklySummaryLogEntry({
    required this.source,
    required this.text,
    required this.author,
    required this.at,
  });

  final WeeklySummaryLogSource source;
  final String text;

  /// The real author's display name, or '' when it could not be resolved.
  final String author;
  final DateTime? at;
}

/// The Notes for Doctor card: one real care note, verbatim.
class WeeklySummaryNote {
  const WeeklySummaryNote({
    required this.text,
    required this.author,
    required this.at,
    required this.flagged,
  });

  final String text;
  final String author;
  final DateTime? at;

  /// True when the note carries the record's own `important` or
  /// `followUpNeeded` flag (the reason this note was chosen).
  final bool flagged;
}

/// Everything the Weekly Summary screen renders — assembled from records.
class WeeklySummaryData {
  const WeeklySummaryData({
    required this.recipientName,
    required this.range,
    required this.vitals,
    required this.dailySystolic,
    required this.chartDayCount,
    required this.chartStart,
    required this.logEntries,
    required this.medications,
    required this.doctorNote,
    this.vitalsCapped = false,
    this.waterCapped = false,
  });

  final String recipientName;
  final CareReportRange range;
  final WeeklySummaryVitals vitals;

  /// Days with a systolic reading, in chart order. Days that are missing from
  /// this list are GAPS in the line — they are never zero.
  final List<WeeklySummaryDayPoint> dailySystolic;

  /// How many days the chart's x-axis spans.
  final int chartDayCount;
  final DateTime? chartStart;
  final List<WeeklySummaryLogEntry> logEntries;

  /// The recipient's CURRENT medication list — not limited to the period.
  final List<CareReportMedication> medications;
  final WeeklySummaryNote? doctorNote;

  /// True when a read hit its bound, so the page can say it is showing only
  /// the most recent entries.
  final bool vitalsCapped;
  final bool waterCapped;

  /// True when the period holds no records of any kind.
  bool get isEmpty =>
      vitals.isEmpty &&
      dailySystolic.isEmpty &&
      logEntries.isEmpty &&
      doctorNote == null;

  /// The line is drawn as one series per run of consecutive days, so a day
  /// with no reading breaks the line instead of being plotted as zero.
  List<List<WeeklySummaryDayPoint>> get systolicSegments {
    final segments = <List<WeeklySummaryDayPoint>>[];
    List<WeeklySummaryDayPoint>? current;
    int? previousX;
    for (final point in dailySystolic) {
      if (current != null && previousX != null && point.x == previousX + 1) {
        current.add(point);
      } else {
        current = [point];
        segments.add(current);
      }
      previousX = point.x;
    }
    return segments;
  }

  /// The y-axis lower bound, from the real points (padded so the line is not
  /// pinned to the frame). 0 when nothing was recorded.
  double get chartMinY {
    if (dailySystolic.isEmpty) {
      return 0;
    }
    final lowest = dailySystolic
        .map((point) => point.systolic)
        .reduce((a, b) => a < b ? a : b);
    final padded = lowest - 10;
    return padded < 0 ? 0 : padded;
  }

  /// The y-axis upper bound, from the real points.
  double get chartMaxY {
    if (dailySystolic.isEmpty) {
      return 0;
    }
    final highest = dailySystolic
        .map((point) => point.systolic)
        .reduce((a, b) => a > b ? a : b);
    return highest + 10;
  }

  /// The x-axis upper bound.
  double get chartMaxX =>
      chartDayCount <= 0 ? 0 : (chartDayCount - 1).toDouble();

  /// Weekday initials for the days the chart spans ('M', 'T', ...). Empty when
  /// the period is too long to label one letter per day.
  List<String> get chartXLabels {
    final start = chartStart;
    if (start == null || chartDayCount <= 0 || chartDayCount > 14) {
      return const [];
    }
    return [
      for (var i = 0; i < chartDayCount; i++)
        DateFormat('E').format(_addDays(start, i)).substring(0, 1),
    ];
  }
}

/// Builds the Weekly Summary from already-read records.
///
/// Pure: it does no I/O, so the aggregates, the chart points and the honest
/// empty states are all testable without Firestore. Every ranged section is
/// filtered on the record's OWN stored timestamp; a record with none cannot be
/// placed in a period and is left out.
WeeklySummaryData assembleWeeklySummary({
  required String recipientName,
  required CareReportRange range,
  required List<VitalLogsRecord> vitals,
  required List<WaterLogsRecord> water,
  required List<AppointmentsRecord> appointments,
  required List<CareNotesRecord> notes,
  required List<MedicationsRecord> medications,
  required Map<String, String> authorNames,
  bool vitalsCapped = false,
  bool waterCapped = false,
}) {
  final rangedVitals =
      vitals.where((log) => range.includes(log.logDateTime)).toList()
        ..sort((a, b) => _newestFirst(a.logDateTime, b.logDateTime));
  final rangedWater =
      water.where((entry) => range.includes(entry.intakeAt)).toList()
        ..sort((a, b) => _newestFirst(a.intakeAt, b.intakeAt));
  final rangedAppointments = appointments
      .where((entry) => range.includes(entry.appointmentDateTime))
      .toList()
    ..sort(
        (a, b) => _newestFirst(a.appointmentDateTime, b.appointmentDateTime));
  final rangedNotes = notes
      .where((note) => range.includes(careNoteTimestamp(note)))
      .toList()
    ..sort((a, b) => _newestFirst(
        careNoteTimestamp(a), careNoteTimestamp(b)));

  // --- Vitals Overview -----------------------------------------------------
  final bpReadings = rangedVitals
      .where((log) => log.bloodPressureSystolic > 0 && log.bloodPressureDiastolic > 0)
      .toList();
  final hrReadings =
      rangedVitals.where((log) => log.heartRate > 0).toList();
  final weightReadings =
      rangedVitals.where((log) => log.weight > 0).toList();
  final glucoseReadings =
      rangedVitals.where((log) => log.bloodGlucose > 0).toList();

  final vitalsSummary = WeeklySummaryVitals(
    averageSystolic: bpReadings.isEmpty
        ? null
        : _mean(bpReadings.map((log) => log.bloodPressureSystolic.toDouble())),
    averageDiastolic: bpReadings.isEmpty
        ? null
        : _mean(bpReadings.map((log) => log.bloodPressureDiastolic.toDouble())),
    bloodPressureReadings: bpReadings.length,
    averageHeartRate: hrReadings.isEmpty
        ? null
        : _mean(hrReadings.map((log) => log.heartRate.toDouble())),
    heartRateReadings: hrReadings.length,
    // rangedVitals is newest first, so the first match is the latest reading.
    latestWeight: weightReadings.isEmpty ? null : weightReadings.first.weight,
    latestWeightAt:
        weightReadings.isEmpty ? null : weightReadings.first.logDateTime,
    latestGlucose:
        glucoseReadings.isEmpty ? null : glucoseReadings.first.bloodGlucose,
    latestGlucoseAt:
        glucoseReadings.isEmpty ? null : glucoseReadings.first.logDateTime,
  );

  // --- The daily systolic line --------------------------------------------
  final systolicByDay = <DateTime, List<int>>{};
  for (final log in rangedVitals) {
    final at = log.logDateTime;
    if (at == null || log.bloodPressureSystolic <= 0) {
      continue;
    }
    final day = CareReportRange.dayOnly(at.toLocal());
    systolicByDay.putIfAbsent(day, () => []).add(log.bloodPressureSystolic);
  }
  final chartStart = range.start ??
      (systolicByDay.isEmpty
          ? null
          : systolicByDay.keys.reduce((a, b) => a.isBefore(b) ? a : b));
  final dailyPoints = <WeeklySummaryDayPoint>[];
  if (chartStart != null) {
    final days = systolicByDay.keys.toList()..sort();
    for (final day in days) {
      dailyPoints.add(WeeklySummaryDayPoint(
        day: day,
        systolic:
            _mean(systolicByDay[day]!.map((value) => value.toDouble()))
                .toDouble(),
        x: day.difference(chartStart).inDays,
      ));
    }
  }
  var chartDayCount = dailyPoints.isEmpty
      ? 0
      : dailyPoints.last.x + 1;
  final rangeEnd = range.end;
  if (chartStart != null && rangeEnd != null) {
    final spanned = CareReportRange.dayOnly(rangeEnd)
            .difference(chartStart)
            .inDays +
        1;
    if (spanned > chartDayCount) {
      chartDayCount = spanned;
    }
  }

  // --- Care Logs -----------------------------------------------------------
  final entries = <WeeklySummaryLogEntry>[
    for (final note in rangedNotes)
      if (note.noteText.trim().isNotEmpty)
        WeeklySummaryLogEntry(
          source: WeeklySummaryLogSource.careNote,
          text: note.noteText.trim(),
          author: note.createdBy.trim(),
          at: careNoteTimestamp(note),
        ),
    for (final log in rangedVitals)
      if (_vitalsLogText(log).isNotEmpty)
        WeeklySummaryLogEntry(
          source: WeeklySummaryLogSource.vitals,
          text: _vitalsLogText(log),
          author: _authorFor(authorNames, log.loggedByUid),
          at: log.logDateTime,
        ),
    for (final entry in rangedWater)
      if (_waterLogText(entry).isNotEmpty)
        WeeklySummaryLogEntry(
          source: WeeklySummaryLogSource.water,
          text: _waterLogText(entry),
          author: _authorFor(authorNames, entry.loggedByUid),
          at: entry.intakeAt,
        ),
    for (final appointment in rangedAppointments)
      if (_appointmentLogText(appointment).isNotEmpty)
        WeeklySummaryLogEntry(
          source: WeeklySummaryLogSource.appointment,
          text: _appointmentLogText(appointment),
          author: _authorFor(authorNames, appointment.createdByUid),
          at: appointment.appointmentDateTime,
        ),
  ]..sort((a, b) => _newestFirst(a.at, b.at));
  final logEntries = entries.take(weeklySummaryLogRows).toList();

  // --- Medications (the CURRENT list, not date-ranged) --------------------
  final medicationList = medications
      .map((record) => CareReportMedication(
            name: record.medicationName.trim(),
            dose: record.dose.trim(),
            schedule: careReportMedicationSchedule(record),
            status: careReportMedicationStatus(record),
          ))
      .where((medication) => medication.name.isNotEmpty)
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  // --- Notes for Doctor ----------------------------------------------------
  final flaggedNotes = rangedNotes
      .where((note) =>
          (note.important || note.followUpNeeded) &&
          note.noteText.trim().isNotEmpty)
      .toList();
  final notesWithText =
      rangedNotes.where((note) => note.noteText.trim().isNotEmpty).toList();
  final chosenNote = flaggedNotes.isNotEmpty
      ? flaggedNotes.first
      : (notesWithText.isEmpty ? null : notesWithText.first);
  final doctorNote = chosenNote == null
      ? null
      : WeeklySummaryNote(
          text: chosenNote.noteText.trim(),
          author: chosenNote.createdBy.trim(),
          at: careNoteTimestamp(chosenNote),
          flagged: chosenNote.important || chosenNote.followUpNeeded,
        );

  return WeeklySummaryData(
    recipientName: recipientName,
    range: range,
    vitals: vitalsSummary,
    dailySystolic: dailyPoints,
    chartDayCount: chartDayCount,
    chartStart: chartStart,
    logEntries: logEntries,
    medications: medicationList,
    doctorNote: doctorNote,
    vitalsCapped: vitalsCapped,
    waterCapped: waterCapped,
  );
}

/// Reads the recipient's records and assembles the Weekly Summary for [range].
///
/// Each read is recipient-scoped exactly as the merged rules require (a bare
/// list or an `orgId`-only query is denied), and medications also filter the
/// stored `orgId` because that list rule gates on it. Reads happen first and a
/// failure is rethrown, so the page shows a real error instead of a fabricated
/// zero.
Future<WeeklySummaryData> loadWeeklySummary({
  required DocumentReference recipientRef,
  required CareReportRange range,
}) async {
  final recipient = await CareRecipientsRecord.getDocumentOnce(recipientRef);
  final activeGroupId = (FFAppState().activeGroupId ?? '').trim();
  final orgId =
      activeGroupId.isNotEmpty ? activeGroupId : recipient.orgId.trim();

  final vitals = await queryVitalLogsRecordOnce(
    queryBuilder: (query) => query
        .where('careRecipientRef', isEqualTo: recipientRef)
        .orderBy('logDateTime', descending: true),
    limit: weeklySummaryVitalsLimit,
  );
  final water = await queryWaterLogsRecordOnce(
    queryBuilder: (query) => query
        .where('careRecipientRef', isEqualTo: recipientRef)
        .orderBy('intakeAt', descending: true),
    limit: weeklySummaryWaterLimit,
  );
  final appointments = await queryAppointmentsRecordOnce(
    queryBuilder: (query) => query
        .where('careRecipientRef', isEqualTo: recipientRef)
        .orderBy('appointmentDateTime'),
  );
  final notes = await queryCareNotesRecordOnce(
    queryBuilder: (query) =>
        query.where('careRecipientRef', isEqualTo: recipientRef),
  );
  final medications = await queryMedicationsRecordOnce(
    queryBuilder: (query) => orgId.isEmpty
        ? query.where('careRecipientRef', isEqualTo: recipientRef)
        : query
            .where('orgId', isEqualTo: orgId)
            .where('careRecipientRef', isEqualTo: recipientRef),
  );

  // Real author names: vitals and water store a uid, appointments too; care
  // notes already carry a display name. Same membership lookup the Vitals
  // tracker's history runs.
  final authorNames = <String, String>{};
  if (orgId.isNotEmpty) {
    final uids = <String>{
      for (final log in vitals) log.loggedByUid,
      for (final entry in water) entry.loggedByUid,
      for (final appointment in appointments) appointment.createdByUid,
    };
    for (final uid in uids) {
      if (uid.trim().isEmpty) {
        continue;
      }
      final member = await getMembership(orgId, uid);
      final name = (member?.displayName ?? '').trim();
      authorNames[uid] = name.isNotEmpty ? name : (member?.email ?? '').trim();
    }
  }

  return assembleWeeklySummary(
    recipientName: recipient.name.trim(),
    range: range,
    vitals: vitals,
    water: water,
    appointments: appointments,
    notes: notes,
    medications: medications,
    authorNames: authorNames,
    vitalsCapped: vitals.length >= weeklySummaryVitalsLimit,
    waterCapped: water.length >= weeklySummaryWaterLimit,
  );
}

/// '132/84' for the tiles, or null when nothing was recorded.
String? bloodPressureLabel(WeeklySummaryVitals vitals) =>
    vitals.hasBloodPressure
        ? '${vitals.averageSystolic}/${vitals.averageDiastolic}'
        : null;

/// '72 bpm' for the tiles, or null.
String? heartRateLabel(WeeklySummaryVitals vitals) => vitals.hasHeartRate
    ? '${vitals.averageHeartRate} bpm'
    : null;

/// '164.2 lbs' for the tiles, or null.
String? weightLabel(WeeklySummaryVitals vitals) => vitals.hasWeight
    ? '${vitals.latestWeight!.toStringAsFixed(1)} lbs'
    : null;

/// '114 mg/dL' for the tiles, or null.
String? glucoseLabel(WeeklySummaryVitals vitals) => vitals.hasGlucose
    ? '${vitals.latestGlucose} mg/dL'
    : null;

/// '4 readings' / '1 reading' — the count behind an average.
String readingsLabel(int count) => count == 1 ? '1 reading' : '$count readings';

String _authorFor(Map<String, String> authorNames, String uid) =>
    uid.trim().isEmpty ? '' : (authorNames[uid] ?? '');

String _vitalsLogText(VitalLogsRecord log) {
  final parts = <String>[];
  if (log.bloodPressureSystolic > 0 && log.bloodPressureDiastolic > 0) {
    parts.add('BP ${log.bloodPressureSystolic}/${log.bloodPressureDiastolic}');
  }
  if (log.heartRate > 0) {
    parts.add('HR ${log.heartRate} bpm');
  }
  if (log.oxygenSaturation > 0) {
    parts.add('O2 ${log.oxygenSaturation}%');
  }
  if (log.temperature > 0) {
    parts.add('Temp ${log.temperature.toStringAsFixed(1)} F');
  }
  if (log.weight > 0) {
    parts.add('Weight ${log.weight.toStringAsFixed(1)} lbs');
  }
  if (log.bloodGlucose > 0) {
    parts.add('Glucose ${log.bloodGlucose} mg/dL');
  }
  if (log.painLevel > 0) {
    parts.add('Pain ${log.painLevel}/10');
  }
  return parts.join(', ');
}

String _waterLogText(WaterLogsRecord entry) {
  if (entry.amountFlOz > 0) {
    return '${_trimNumber(entry.amountFlOz)} fl oz of water';
  }
  if (entry.amount > 0) {
    final unit = entry.unit.trim();
    return '${_trimNumber(entry.amount)}${unit.isEmpty ? '' : ' $unit'} of water';
  }
  return '';
}

String _appointmentLogText(AppointmentsRecord appointment) {
  final title = appointment.appointmentTitle.trim();
  final type = appointment.appointmentType.trim();
  final label = title.isNotEmpty ? title : type;
  if (label.isEmpty) {
    return '';
  }
  return appointment.completed
      ? 'Completed appointment: $label'
      : 'Appointment: $label';
}

/// 8.0 -> '8', 8.5 -> '8.5' — no invented decimals.
String _trimNumber(double value) {
  final rounded = value.roundToDouble();
  return (value - rounded).abs() < 0.001
      ? rounded.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

int _mean(Iterable<double> values) {
  var total = 0.0;
  var count = 0;
  for (final value in values) {
    total += value;
    count++;
  }
  return count == 0 ? 0 : (total / count).round();
}

DateTime _addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

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
