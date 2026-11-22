// Water history — the read-only derivation behind the Daily Water card's
// "History" screen.
//
// Owner direction of 2026-11-22 (water-history-spec.md, unit 1 of 2): a
// READ-ONLY view of the recipient's water entries with intake amounts, local
// times, authors, corrections and per-day totals, reaching previous days by
// scrolling.
//
// The rules this file follows:
//  * nothing here writes, edits, deletes or migrates a `waterLogs` document —
//    every function is a pure read of records the app already stores;
//  * a day is the DEVICE-LOCAL calendar day (the same rule the card's total
//    follows, see `isSameLocalDay` in water_intake.dart);
//  * an adjustment is NEVER presented as water that was drunk: it carries the
//    wording contract from water_intake.dart
//    ("Adjusted −16 fl oz (to 32 fl oz)") and is excluded from the intake
//    figure;
//  * the day's INTAKE (sum of positive `amountFlOz`) and its NET figure (sum of
//    every `amountFlOz`, what the card shows) are kept apart, and both are
//    shown whenever they differ;
//  * an author that cannot be resolved degrades to the app's existing
//    "Unknown user" convention — no invented name and never a uid;
//  * the read is bounded: the most recent [waterHistoryWindowDays] days and at
//    most [waterHistoryReadLimit] documents, so the screen can never issue an
//    unbounded collection query.
//
// The functions are pure so they can be tested without a widget tree.
import 'package:intl/intl.dart';

import '/backend/backend.dart';
import '/backend/symptoms/symptom_history.dart' show symptomLocalTimeLabel;
import '/backend/vitals/vitals_entry.dart' show vitalsUnknownAuthor;
import '/backend/water/water_intake.dart';

/// How many device-local days of history the screen reads. The window is what
/// makes the read bounded: anything older than the oldest day in it is not
/// requested (see the page's query) and is not listed here either.
const int waterHistoryWindowDays = 90;

/// Upper bound on the documents one history read may return. A recipient with
/// more entries than this inside the window sees the newest
/// [waterHistoryReadLimit] of them; the query is ordered `intakeAt` descending,
/// so the entries that fall off are the oldest ones.
const int waterHistoryReadLimit = 200;

/// The screen's title.
const String waterHistoryTitle = 'Water History';

/// Shown when the recipient has no water entries in the window.
const String waterHistoryEmpty = 'No water logged yet.';

/// Shown when there is no care recipient to address.
const String waterHistoryNoRecipient =
    'Select a care recipient to see their water history.';

/// Shown when the read fails — never a fallback to an empty list, which would
/// disguise a failed read as "no water logged".
const String waterHistoryLoadError =
    'Could not load the water history for this care recipient. Please check '
    'your connection and try again.';

/// The Retry control on the error state.
const String waterHistoryRetry = 'Retry';

/// The card's affordance that opens this screen.
const String waterHistoryLink = 'History';

/// The oldest device-local day the history covers, as local midnight.
///
/// A record whose `intakeAt` falls before this instant is outside the window.
DateTime waterHistoryWindowStart(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: waterHistoryWindowDays - 1));
}

/// The bounded, recipient-scoped read behind the history screen.
///
/// * recipient-scoped — `careRecipientRef == recipientRef`, which is what the
///   deployed `waterLogs` rules require (an unconstrained list is denied);
/// * bounded twice — `intakeAt >= waterHistoryWindowStart(now)` keeps the read
///   inside the window, and [limit] caps the documents returned, newest first,
///   using the `careRecipientRef` + `intakeAt` index the rules expect.
///
/// With no recipient nothing is queried and the result is empty.
Future<List<WaterLogsRecord>> waterHistoryEntriesForRecipient({
  required DocumentReference? recipientRef,
  required DateTime now,
  int limit = waterHistoryReadLimit,
}) {
  if (recipientRef == null) {
    return Future.value(const <WaterLogsRecord>[]);
  }
  return queryWaterLogsRecordOnce(
    queryBuilder: (query) => query
        .where('careRecipientRef', isEqualTo: recipientRef)
        .where('intakeAt', isGreaterThanOrEqualTo: waterHistoryWindowStart(now))
        .orderBy('intakeAt', descending: true),
    limit: limit,
  );
}

/// True when [log] is a correction rather than intake.
///
/// A correction is written with `adjustment: true` and a NEGATIVE
/// `amountFlOz`; either marker is enough, so a correction can never be counted
/// as water that was drunk.
bool isWaterAdjustment(WaterLogsRecord log) =>
    log.adjustment || log.amountFlOz < 0;

/// The day label: 'Today', 'Yesterday', else a human date ('Nov 20', with the
/// year when it is not this year).
///
/// Produced only by comparing the stored day to [now] — never typed into the
/// code — following the conventions of `symptomEntryWhenLabel`.
String waterHistoryDayLabel(DateTime day, {DateTime? now}) {
  final local = day.toLocal();
  final current = now ?? DateTime.now();
  final reference = DateTime(current.year, current.month, current.day);
  final date = DateTime(local.year, local.month, local.day);
  if (date == reference) {
    return 'Today';
  }
  if (date == reference.subtract(const Duration(days: 1))) {
    return 'Yesterday';
  }
  return date.year == reference.year
      ? DateFormat('MMM d').format(date)
      : DateFormat('MMM d, y').format(date);
}

/// The entry's device-local clock time ('8:00 PM'), through the app's existing
/// time helper. A record with no `intakeAt` has nothing truthful to show and
/// returns ''.
String waterHistoryTimeLabel(DateTime? when) =>
    when == null ? '' : symptomLocalTimeLabel(when);

/// What one entry row reads.
///
/// Intake reads as intake ("16 fl oz"). An adjustment reads
/// "Adjusted −16 fl oz (to 32 fl oz)" — the wording contract recorded in
/// water_intake.dart — and never as water that was drunk. A legacy adjustment
/// with no stored `targetFlOz` drops the parenthetical rather than inventing a
/// figure.
String waterHistoryAmountLabel(WaterLogsRecord log) {
  if (!isWaterAdjustment(log)) {
    return formatWaterFlOz(log.amountFlOz);
  }
  final target = log.targetFlOz;
  if (log.hasTargetFlOz() && target > 0) {
    return formatWaterAdjustment(log.amountFlOz, target);
  }
  return 'Adjusted −${formatWaterFlOz(log.amountFlOz.abs())}';
}

/// The row's author: the resolved display name, or the app's existing
/// "Unknown user" when the author could not be resolved. Never a uid.
String waterHistoryAuthorLabel(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? vitalsUnknownAuthor : trimmed;
}

/// The day header's totals.
///
/// The day's INTAKE (sum of positive amounts) is the honest "how much water was
/// drunk" figure; the NET figure (what the card shows) answers a different
/// question. When they differ both are shown, plainly labelled — "Intake 48 fl
/// oz · Net 32 fl oz". When they agree one figure is enough. Neither is ever
/// shown below zero.
String waterHistoryDayTotalsLabel(double intakeFlOz, double netFlOz) {
  final intake = intakeFlOz > 0 ? intakeFlOz : 0.0;
  final net = netFlOz > 0 ? netFlOz : 0.0;
  if ((intake - net).abs() < 0.001) {
    return formatWaterFlOz(intake);
  }
  return 'Intake ${formatWaterFlOz(intake)} · Net ${formatWaterFlOz(net)}';
}

/// One row of the history: one stored `waterLogs` document.
class WaterHistoryRow {
  const WaterHistoryRow({
    required this.at,
    required this.timeLabel,
    required this.amountLabel,
    required this.authorLabel,
    required this.isAdjustment,
  });

  /// The stored instant (null when the record carries none).
  final DateTime? at;

  /// Device-local clock time ('8:00 PM').
  final String timeLabel;

  /// '16 fl oz' for intake, 'Adjusted −16 fl oz (to 32 fl oz)' for a
  /// correction.
  final String amountLabel;

  /// Who logged it, or 'Unknown user'.
  final String authorLabel;

  /// True for a correction, so the row can be drawn differently.
  final bool isAdjustment;
}

/// One device-local day of history.
class WaterHistoryDay {
  const WaterHistoryDay({
    required this.day,
    required this.label,
    required this.rows,
    required this.intakeFlOz,
    required this.netFlOz,
  });

  /// Local midnight of the day.
  final DateTime day;

  /// 'Today' / 'Yesterday' / 'Nov 20'.
  final String label;

  /// That day's entries, newest first.
  final List<WaterHistoryRow> rows;

  /// The day's INTAKE only (sum of positive amounts).
  final double intakeFlOz;

  /// The day's NET figure (sum of every amount, corrections included).
  final double netFlOz;

  /// 'Intake 48 fl oz · Net 32 fl oz', or a single figure when they agree.
  String get totalsLabel => waterHistoryDayTotalsLabel(intakeFlOz, netFlOz);
}

/// The records, grouped by DEVICE-LOCAL day, newest day first and newest entry
/// first inside each day.
///
/// [authorNames] maps a uid to the name resolved for it; an unresolved author
/// reads as 'Unknown user'. A record with no `intakeAt` cannot be placed in a
/// day and is left out (the same rule the card's total follows), and so is one
/// older than the window — the page's query already excludes both, so this is
/// the second, testable statement of the same bound.
List<WaterHistoryDay> groupWaterHistory(
  Iterable<WaterLogsRecord> logs, {
  required DateTime now,
  Map<String, String> authorNames = const {},
}) {
  final windowStart = waterHistoryWindowStart(now);
  final inWindow = logs.where((log) {
    final at = log.intakeAt;
    return at != null && !at.toLocal().isBefore(windowStart);
  }).toList()
    ..sort((a, b) => b.intakeAt!.compareTo(a.intakeAt!));

  final byDay = <DateTime, List<WaterLogsRecord>>{};
  for (final log in inWindow) {
    final at = log.intakeAt!.toLocal();
    final day = DateTime(at.year, at.month, at.day);
    byDay.putIfAbsent(day, () => []).add(log);
  }

  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final day in days)
      _dayOf(day, byDay[day]!, now: now, authorNames: authorNames),
  ];
}

WaterHistoryDay _dayOf(
  DateTime day,
  List<WaterLogsRecord> logs, {
  required DateTime now,
  required Map<String, String> authorNames,
}) {
  var intake = 0.0;
  var net = 0.0;
  final rows = <WaterHistoryRow>[];
  for (final log in logs) {
    if (log.amountFlOz > 0) {
      intake += log.amountFlOz;
    }
    net += log.amountFlOz;
    rows.add(
      WaterHistoryRow(
        at: log.intakeAt,
        timeLabel: waterHistoryTimeLabel(log.intakeAt),
        amountLabel: waterHistoryAmountLabel(log),
        authorLabel: waterHistoryAuthorLabel(authorNames[log.loggedByUid] ?? ''),
        isAdjustment: isWaterAdjustment(log),
      ),
    );
  }
  return WaterHistoryDay(
    day: day,
    label: waterHistoryDayLabel(day, now: now),
    rows: rows,
    intakeFlOz: intake,
    netFlOz: net,
  );
}
