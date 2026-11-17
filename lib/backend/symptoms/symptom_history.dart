// Doctor Visit Prep's "Recent Observations" — the recipient's REAL symptoms.
//
// Appointments unit, part 3 (owner decision 2026-11-16, proposal §7 item 9 =
// option (a): the history icon opens the recipient's real `symptomEntries`
// history). Before this the page showed three invented observations ("High
// Blood Pressure", "Shortness of Breath", "Increased Fatigue") with invented
// notes and times, while the collection they belong to was already written by
// the dashboard's symptom flow.
//
// The rules this file follows:
//  * nothing is invented — every row comes from a stored `symptomEntries`
//    document (`symptomName`, `note`, `timeLogged`, `isResolved`);
//  * "Today"/"Yesterday" are produced only by comparing the stored time to
//    today, never typed into the code;
//  * entries with no `timeLogged` still show (they are sorted last) instead of
//    silently disappearing, the same rule the dashboard's list follows.
//
// The functions are pure so they can be tested without a widget tree.
import 'package:intl/intl.dart';

import '/backend/backend.dart';

/// Shown when the recipient has no symptom entries at all.
const String symptomHistoryEmpty =
    'No symptoms logged for this care recipient yet.';

/// Shown when no care recipient is selected.
const String symptomHistoryNoRecipient =
    'Select a care recipient to see their symptoms.';

/// Shown when the read fails — never a fallback to invented observations.
const String symptomHistoryLoadError =
    'Could not load the symptoms for this care recipient. Please check your '
    'connection and try again.';

/// The heading of the sheet the "Recent Observations" history icon opens.
const String symptomHistoryTitle = 'Symptom History';

/// How many observations Doctor Visit Prep lists before the history icon: the
/// section is a short recent summary, the sheet is the full history.
const int recentObservationCount = 3;

/// Newest first, entries without a logged time last (they are not dropped).
int symptomHistoryNewestFirst(SymptomEntriesRecord a, SymptomEntriesRecord b) {
  final ta = a.timeLogged;
  final tb = b.timeLogged;
  if (ta == null && tb == null) {
    return 0;
  }
  if (ta == null) {
    return 1;
  }
  if (tb == null) {
    return -1;
  }
  return tb.compareTo(ta);
}

/// The stored symptoms, newest first.
List<SymptomEntriesRecord> sortSymptomsNewestFirst(
  Iterable<SymptomEntriesRecord> records,
) {
  final sorted = records.toList();
  sorted.sort(symptomHistoryNewestFirst);
  return sorted;
}

/// At most [limit] of the newest stored symptoms.
List<SymptomEntriesRecord> recentSymptoms(
  Iterable<SymptomEntriesRecord> records, {
  int limit = recentObservationCount,
}) {
  final sorted = sortSymptomsNewestFirst(records);
  return sorted.length <= limit ? sorted : sorted.sublist(0, limit);
}

/// The row's headline: the stored symptom name, or 'Symptom' when the caregiver
/// saved the entry without one.
String symptomEntryHeadline(SymptomEntriesRecord record) {
  final name = record.symptomName.trim();
  return name.isEmpty ? 'Symptom' : name;
}

/// The row's note, exactly as it was stored ('' when none was written).
String symptomEntryNote(SymptomEntriesRecord record) => record.note.trim();

/// 'Today at 8:00 PM' / 'Yesterday at 8:00 PM' / 'Nov 18 at 9:15 AM'.
///
/// Produced only by comparing the stored time to [now]; an entry with no
/// logged time has nothing truthful to show and returns ''.
String symptomEntryWhenLabel(DateTime? when, {DateTime? now}) {
  if (when == null) {
    return '';
  }
  final local = when.toLocal();
  final current = now ?? DateTime.now();
  final reference = DateTime(current.year, current.month, current.day);
  final day = DateTime(local.year, local.month, local.day);
  final time = DateFormat('h:mm a').format(local);
  if (day == reference) {
    return 'Today at $time';
  }
  if (day == reference.subtract(const Duration(days: 1))) {
    return 'Yesterday at $time';
  }
  return '${DateFormat('MMM d').format(day)} at $time';
}

/// The row's second line: when it was logged and whether it is resolved, both
/// read from the record ('Nov 18 at 9:15 AM • Resolved').
String symptomEntrySubtitle(SymptomEntriesRecord record, {DateTime? now}) {
  final when = symptomEntryWhenLabel(record.timeLogged, now: now);
  final status = symptomEntryStatusLabel(record);
  return [when, status].where((part) => part.isNotEmpty).join(' • ');
}

/// 'Resolved' / 'Unresolved' — the stored `isResolved` flag, never inferred.
String symptomEntryStatusLabel(SymptomEntriesRecord record) =>
    record.isResolved ? 'Resolved' : 'Unresolved';
