// Calendar page (appointments unit, part 2): the display layer for REAL
// `appointments` records.
//
// Everything on the Calendar is a care appointment for the selected recipient
// (owner decision 2026-11-16, proposal §7/§10 item 10), read from ONE query —
// `where careRecipientRef == recipient, orderBy appointmentDateTime` — and then
// derived here: the month header, the week strip's dots, the selected day's
// agenda, the count line and the "Upcoming" card.
//
// Rules this file follows:
//  * nothing is invented — every string is produced from a stored field or
//    from the device's own clock; an empty day says so;
//  * "Today"/"Tomorrow" are produced only by COMPARING the stored date to
//    today, never typed in;
//  * appointments are device-local calendar days, so a stored UTC timestamp
//    lands on the day the caregiver sees on their phone;
//  * a record with no `appointmentDateTime` (a legacy document from before the
//    field existed) simply never matches a day — the same way Firestore's
//    orderBy drops it — and never crashes the screen.
//
// The functions are pure so they can be tested without a widget tree.
import 'package:intl/intl.dart';

import '/backend/backend.dart';

/// Shown when the selected day has no appointments.
const String calendarNoAppointmentsForDay = 'No appointments on this day.';

/// Shown when a search term excludes every loaded appointment.
const String calendarNoAppointmentsMatchSearch =
    'No appointments match your search.';

/// Shown when the recipient has no appointments at all.
const String calendarNoAppointmentsAtAll =
    'No appointments scheduled for this care recipient.';

/// Shown on the "Upcoming" card when nothing is scheduled from now on.
const String calendarNoUpcomingAppointment = 'No upcoming appointment scheduled';

/// Shown when the read fails — never a fallback to invented events.
const String calendarLoadError =
    'Could not load the appointments for this care recipient. '
    'Please check your connection and try again.';

/// Shown when no care recipient is selected at all.
const String calendarNoRecipient =
    'Select a care recipient to see their appointments.';

/// The device-local calendar day a timestamp falls on (midnight local).
DateTime appointmentDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Today, as a device-local calendar day.
DateTime appointmentToday([DateTime? now]) => appointmentDay(now ?? DateTime.now());

bool isSameAppointmentDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The Monday-first week containing [day] — the strip's labels are M T W T F S
/// S, so the week has to start on a Monday.
List<DateTime> weekDaysFor(DateTime day) {
  final start = appointmentDay(day);
  final monday =
      start.subtract(Duration(days: start.weekday - DateTime.monday));
  return List<DateTime>.generate(
    7,
    (index) => monday.add(Duration(days: index)),
  );
}

/// The header line, e.g. 'November 2026' — the real month of the visible day.
String calendarMonthHeading(DateTime day) =>
    DateFormat('MMMM yyyy').format(appointmentDay(day));

/// The selected-day heading, e.g. 'Thursday, November 20'.
String calendarDayHeading(DateTime day) =>
    DateFormat('EEEE, MMMM d').format(appointmentDay(day));

/// The header's second line, e.g. 'You have 2 appointments today'.
String calendarCountLine(
  int count, {
  required DateTime day,
  required DateTime today,
}) {
  final noun = count == 1 ? 'appointment' : 'appointments';
  final when = isSameAppointmentDay(day, today)
      ? 'today'
      : 'on ${DateFormat('EEE, MMM d').format(appointmentDay(day))}';
  return 'You have $count $noun $when';
}

/// '9:30 AM', or '9:30 AM - 10:30 AM' when an end time is stored after the
/// start. An end time that is missing or not after the start is not shown.
String appointmentTimeLabel(AppointmentsRecord record) {
  final start = record.appointmentDateTime?.toLocal();
  if (start == null) {
    return '';
  }
  final startText = DateFormat('h:mm a').format(start);
  final end = record.endDateTime?.toLocal();
  if (end == null || !end.isAfter(start)) {
    return startText;
  }
  return '$startText - ${DateFormat('h:mm a').format(end)}';
}

/// 'Today at 9:30 AM' / 'Tomorrow at 9:30 AM' / 'Nov 20 at 9:30 AM'.
///
/// The words are produced only by comparing the stored date to [now]; they are
/// never typed into the code. Doctor Visit Prep shows the same record with the
/// same helper, so the two screens cannot disagree.
String appointmentWhenLabel(DateTime when, {DateTime? now}) {
  final local = when.toLocal();
  final today = appointmentToday(now);
  final day = appointmentDay(local);
  final time = DateFormat('h:mm a').format(local);
  if (isSameAppointmentDay(day, today)) {
    return 'Today at $time';
  }
  if (isSameAppointmentDay(day, today.add(const Duration(days: 1)))) {
    return 'Tomorrow at $time';
  }
  return '${DateFormat('MMM d').format(day)} at $time';
}

int _compareStart(AppointmentsRecord a, AppointmentsRecord b) {
  final left = a.appointmentDateTime;
  final right = b.appointmentDateTime;
  if (left == null && right == null) {
    return a.appointmentTitle.compareTo(b.appointmentTitle);
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return left.compareTo(right);
}

/// The appointments stored on one device-local day, earliest first.
List<AppointmentsRecord> appointmentsOnDay(
  Iterable<AppointmentsRecord> records,
  DateTime day,
) {
  final target = appointmentDay(day);
  final matching = records.where((record) {
    final at = record.appointmentDateTime;
    return at != null && isSameAppointmentDay(appointmentDay(at), target);
  }).toList();
  matching.sort(_compareStart);
  return matching;
}

/// Every appointment, earliest first — the order the query already asks for,
/// re-applied so the display is correct whatever order the documents arrive in.
List<AppointmentsRecord> sortAppointmentsByStart(
  Iterable<AppointmentsRecord> records,
) {
  final sorted = records.toList();
  sorted.sort(_compareStart);
  return sorted;
}

/// The earliest appointment that has not started yet and is not marked
/// completed — the same record Doctor Visit Prep shows as "Next Appointment".
AppointmentsRecord? nextUpcomingAppointment(
  Iterable<AppointmentsRecord> records,
  DateTime now,
) {
  final candidates = records.where((record) {
    final at = record.appointmentDateTime;
    return at != null && !at.isBefore(now) && !record.completed;
  }).toList();
  if (candidates.isEmpty) {
    return null;
  }
  candidates.sort(_compareStart);
  return candidates.first;
}

/// Client-side filter of the loaded appointments by title, provider or type.
/// An empty (or whitespace-only) term matches everything.
bool appointmentMatchesSearch(AppointmentsRecord record, String term) {
  final query = term.trim().toLowerCase();
  if (query.isEmpty) {
    return true;
  }
  return [
    record.appointmentTitle,
    record.providerName,
    record.appointmentType,
  ].any((value) => value.trim().toLowerCase().contains(query));
}

/// The colour tone for an appointment type. The theme colours live in the
/// widget layer; this only decides which one is used.
///
/// A record with no type gets the single neutral tone, so the strip never
/// implies a category that was not stored.
String appointmentTone(String type) {
  final value = type.trim().toLowerCase();
  if (value.isEmpty) {
    return 'neutral';
  }
  if (value.contains('therapy') || value.contains('rehab')) {
    return 'tertiary';
  }
  if (value.contains('lab') ||
      value.contains('test') ||
      value.contains('imaging') ||
      value.contains('scan') ||
      value.contains('x-ray')) {
    return 'warning';
  }
  if (value.contains('dental') || value.contains('dentist')) {
    return 'success';
  }
  return 'primary';
}

/// The dot colour for one day of the strip: the tone of the day's first
/// appointment that has a type, the neutral tone when none does, and
/// 'transparent' (no dot) when the day has no appointments at all.
String dayDotTone(
  Iterable<AppointmentsRecord> records,
  DateTime day,
) {
  final dayRecords = appointmentsOnDay(records, day);
  if (dayRecords.isEmpty) {
    return 'transparent';
  }
  for (final record in dayRecords) {
    if (record.appointmentType.trim().isNotEmpty) {
      return appointmentTone(record.appointmentType);
    }
  }
  return 'neutral';
}
