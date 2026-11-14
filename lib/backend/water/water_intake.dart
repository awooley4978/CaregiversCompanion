// Water tracking: the derivation, formatting and input-sanity rules behind the
// Dashboard's "Daily Water Intake" card.
//
// Owner decisions of 2026-11-13 (proposal §9) that shape this file:
//  * D1 — a glass tap quick-adds 8 fl oz; a custom amount is typed in fl oz.
//  * D3 — the nine glasses are NOT a target: each filled glass is 8 fl oz of
//    intake actually logged today, `min(9, floor(total / 8))`. Nine is only the
//    number of icons the existing design draws, so past 72 fl oz all nine stay
//    filled and the total keeps counting. No goal language exists here.
//  * D5 — "today" is the DEVICE-LOCAL day, computed in the app.
//  * D6 — every entry is "now"; backdating is deferred.
//
// The bounds below are input-sanity checks ONLY. They are never shown as a
// health assessment and no clinical interpretation of an amount exists.
import 'dart:math' as math;

import '/backend/backend.dart';

/// The unit every record created by this unit is written in. `mL` is already
/// accepted by the security rules and stored unchanged, so mL can be added
/// later without a migration or a rules change.
const String waterUnitFlOz = 'fl_oz';

/// One glass: the amount a glass tap logs, and the amount one filled glass
/// icon represents.
const double waterGlassFlOz = 8.0;

/// The number of glass icons the card draws. A display cap on the drawing,
/// never a ceiling on intake and never a goal.
const int waterGlassCount = 9;

/// Plausibility ceiling for a single entry (200 fl oz ≈ 5.9 L). Input sanity
/// only.
const double waterMaxEntryFlOz = 200.0;

/// How long the Undo affordance stays on screen after a quick-add.
const Duration waterUndoWindow = Duration(seconds: 5);

/// Shown when the recipient's intake cannot be read. The card then shows no
/// total at all — never a fabricated zero.
const String waterCouldNotLoad = "Could not load today's water intake";

/// Shown when there is no care recipient to address.
const String waterSelectRecipient = 'Select a care recipient to track water.';

/// Shown when an Undo could not remove the record it created.
const String waterUndoKept = 'Could not undo — the entry was kept';

/// True when [a] and [b] fall on the same day in the DEVICE's local timezone.
bool isSameLocalDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The records that were logged on the device-local day containing [now].
///
/// A record with no `intakeAt` cannot be placed in a day, so it is left out of
/// the total rather than guessed at.
List<WaterLogsRecord> waterLogsForLocalDay(
  List<WaterLogsRecord> logs,
  DateTime now,
) {
  return logs.where((log) {
    final at = log.intakeAt;
    return at != null && isSameLocalDay(at, now);
  }).toList();
}

/// Today's real intake in fluid ounces: the sum of the canonical `amountFlOz`
/// over the records logged on the device-local day containing [now].
///
/// `amountFlOz` is written alongside `amount`/`unit`, so a future mL entry
/// cannot inflate or deflate this total.
double waterTotalFlOz(List<WaterLogsRecord> logs, DateTime now) {
  var total = 0.0;
  for (final log in waterLogsForLocalDay(logs, now)) {
    total += log.amountFlOz;
  }
  return total;
}

/// How many of the nine glass icons are filled: 8 fl oz of real intake each,
/// capped at the number of icons the design draws.
int waterGlassesFilled(double totalFlOz) {
  if (totalFlOz <= 0) {
    return 0;
  }
  return math.min(waterGlassCount, (totalFlOz / waterGlassFlOz).floor());
}

/// Formats an amount in fluid ounces for display ("24 fl oz", "0 fl oz",
/// "12.5 fl oz") — trailing zeros are dropped, the value is never rounded away.
String formatWaterFlOz(double flOz) {
  final text = flOz == flOz.roundToDouble()
      ? flOz.toStringAsFixed(0)
      : flOz.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  final trimmed = text.endsWith('.')
      ? text.substring(0, text.length - 1)
      : text;
  return '$trimmed fl oz';
}

/// The outcome of validating a typed custom amount.
class WaterAmountValidation {
  const WaterAmountValidation._({this.amount, this.error});

  const WaterAmountValidation.valid(double amount) : this._(amount: amount);

  const WaterAmountValidation.invalid(String error) : this._(error: error);

  /// The amount to write, in fluid ounces. Null when [error] is set.
  final double? amount;

  /// Names the field and its accepted range. Null when the input is valid.
  final String? error;

  bool get isValid => amount != null;
}

/// Validates a typed custom amount in fluid ounces.
///
/// Invalid input names the field and its range and writes nothing: the app
/// never guesses a value and never interprets whether an amount is clinically
/// appropriate.
WaterAmountValidation validateWaterAmount(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) {
    return const WaterAmountValidation.invalid(
        'Amount (fl oz) is required.');
  }
  final parsed = double.tryParse(text);
  if (parsed == null) {
    return const WaterAmountValidation.invalid(
        'Amount (fl oz) must be a number between 0 and 200.');
  }
  if (parsed <= 0 || parsed > waterMaxEntryFlOz) {
    return const WaterAmountValidation.invalid(
        'Amount (fl oz) must be greater than 0 and no more than 200.');
  }
  return WaterAmountValidation.valid(parsed);
}
