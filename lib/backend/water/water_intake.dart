// Water tracking: the derivation, formatting and input-sanity rules behind the
// Dashboard's "Daily Water Intake" card.
//
// Owner decisions of 2026-11-13 (proposal §9) that shape this file:
//  * D1 — a glass tap fills every glass up to the one tapped (tap N adds
//    `N * 8 - todayTotal`, as ONE record); a custom amount is typed in fl oz.
//  * D3 — the nine glasses are NOT a target: each filled glass is 8 fl oz of
//    intake actually logged today, `min(9, floor(total / 8))`. Nine is only the
//    number of icons the existing design draws, so past 72 fl oz all nine stay
//    filled and the total keeps counting. No goal language exists here.
//  * D5 — "today" is the DEVICE-LOCAL day, computed in the app.
//  * D6 — every entry is "now"; backdating is deferred.
//
// Owner decisions of 2026-11-22 (water-tap-to-empty-spec.md) that shape the
// correction half of this file:
//  * tapping a drop BELOW today's total writes ONE adjustment document whose
//    `amountFlOz` is negative, so `sum(amountFlOz)` stays the honest net figure
//    with no special-casing in any consumer;
//  * a correction is capped at the caller's OWN positive intake today, so one
//    caregiver's tap can never reduce another caregiver's legitimate intake,
//    and the total can never go negative;
//  * nothing existing is ever edited or deleted to reduce the total — an
//    adjustment is a new record, and Undo deletes exactly that record;
//  * `adjustment: true` keeps a correction distinguishable from intake, for a
//    future history screen and for any report (see the wording contract below).
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

/// Shown when a tap on a lower drop has nothing of the caller's own to give
/// back, so nothing is written and no total moves.
const String waterNothingToReduce =
    "Nothing to reduce — all of today's water was logged by someone else.";

/// Shown when the caller HAS logged water today but has already corrected all of
/// it away, so there is still nothing of their own left to give back.
const String waterNothingLeftToReduce =
    "Nothing to reduce — you've already removed your own entries for today.";

/// Shown when a correction had to stop short of the tapped drop because the
/// rest of the intake belongs to another caregiver. [flOz] is the total the
/// card now shows.
String waterReducedToMessage(double flOz) =>
    'Reduced to ${formatWaterFlOz(flOz)} — the rest was logged by another '
    'caregiver.';

/// True when [a] and [b] fall on the same day in the DEVICE's local timezone.
///
/// Firestore hands back UTC instants while "today" comes from `DateTime.now()`
/// (local), so both sides are converted to local time before their calendar
/// fields are compared. `toLocal()` is a no-op for an already-local value, and
/// nothing about the stored instant changes.
bool isSameLocalDay(DateTime a, DateTime b) {
  final localA = a.toLocal();
  final localB = b.toLocal();
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}

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

/// The amount a tap on glass [glassNumber] (1-based) adds, given today's real
/// total [totalFlOz]: the difference up to that glass's position, so one tap
/// fills every glass up to the one tapped (tap 4 with 8 fl oz already logged
/// adds 24 fl oz → 32 fl oz).
///
/// Returns 0 — meaning "write nothing at all" — when there is nothing to add:
/// the tapped glass is already filled (`glassNumber * 8 <= totalFlOz`), the
/// total is already past it, or the number is outside the nine drawn glasses.
/// A filled glass is never emptied by rewriting or deleting a record.
///
/// The largest amount a tap can add is 72 fl oz (glass 9 from an empty day), so
/// the 200 fl oz per-entry sanity ceiling is never reachable here.
double waterAmountToAddForGlass(int glassNumber, double totalFlOz) {
  if (glassNumber < 1 || glassNumber > waterGlassCount) {
    return 0;
  }
  final difference = glassNumber * waterGlassFlOz - totalFlOz;
  return difference > 0 ? difference : 0;
}

/// Today's INTAKE only: the sum of the positive `amountFlOz` values logged on
/// the device-local day containing [now].
///
/// Adjustments are excluded, so this is the honest "how much water was drunk"
/// figure a report needs — the net figure ([waterTotalFlOz]) answers a
/// different question. Nothing is ever presented as intake that is not intake.
double waterIntakeOnlyFlOz(List<WaterLogsRecord> logs, DateTime now) {
  var total = 0.0;
  for (final log in waterLogsForLocalDay(logs, now)) {
    if (log.amountFlOz > 0) {
      total += log.amountFlOz;
    }
  }
  return total;
}

/// The caller's OWN gross intake today: the sum of their positive `amountFlOz`
/// values. Another caregiver's entries are never counted here, which is what
/// stops one person's tap from reducing someone else's legitimate intake.
double waterOwnLoggedFlOz(
  List<WaterLogsRecord> logs,
  DateTime now,
  String uid,
) {
  if (uid.isEmpty) {
    return 0;
  }
  var total = 0.0;
  for (final log in waterLogsForLocalDay(logs, now)) {
    if (log.loggedByUid == uid && log.amountFlOz > 0) {
      total += log.amountFlOz;
    }
  }
  return total;
}

/// The caller's own NET contribution today: their own entries plus their own
/// corrections (which are negative).
///
/// This — not the gross figure — is the most a tap may give back. It is what
/// makes repeated corrections safe: `T = A + B` keeps holding with `A` the
/// caller's net and `B` everyone else's net, so once a caregiver has given back
/// everything they logged, further taps can never reach another caregiver's
/// water, and `T` can never fall below `B` or below zero.
double waterOwnNetFlOz(
  List<WaterLogsRecord> logs,
  DateTime now,
  String uid,
) {
  if (uid.isEmpty) {
    return 0;
  }
  var total = 0.0;
  for (final log in waterLogsForLocalDay(logs, now)) {
    if (log.loggedByUid == uid) {
      total += log.amountFlOz;
    }
  }
  return total;
}

/// What a tap on a drop does.
enum WaterTapKind {
  /// The drop is above the total: one positive intake record is written.
  fill,

  /// The drop is below the total: one negative adjustment record is written.
  correction,

  /// Nothing is written.
  noOp,
}

/// The outcome of a tap on one of the nine drops.
class WaterTapOutcome {
  const WaterTapOutcome._({
    required this.kind,
    required this.amountFlOz,
    required this.targetFlOz,
    required this.newTotalFlOz,
    this.clamped = false,
    this.message,
  });

  /// What the tap does.
  final WaterTapKind kind;

  /// The MAGNITUDE to write, in fluid ounces. Zero for [WaterTapKind.noOp].
  final double amountFlOz;

  /// The drop's position in fluid ounces (`N * 8`).
  final double targetFlOz;

  /// The total the card shows once the write lands.
  final double newTotalFlOz;

  /// True when a correction had to stop at the caller's own intake instead of
  /// reaching [targetFlOz], because the rest belongs to another caregiver.
  final bool clamped;

  /// The snackbar line for this tap. Null when there is nothing to say.
  final String? message;

  /// True when the tap writes a document.
  bool get writes => kind != WaterTapKind.noOp;

  /// True when the tap writes a negative adjustment rather than intake.
  bool get isCorrection => kind == WaterTapKind.correction;
}

/// What a tap on drop [glassNumber] (1-based) does, given today's records
/// [logs], the device-local day containing [now], and the caller's [uid].
///
/// * `N * 8 > T` — fill: add the difference up to N (unchanged behaviour).
/// * `N * 8 == T` — no-op: already exactly at that drop.
/// * `N * 8 < T` — correction of `T - N * 8`, capped at the caller's own net
///   intake today (`A`: their entries plus their own corrections). If the
///   caller has nothing of their own left to give back, nothing is written and
///   the honest reason is returned.
///
/// `T` can never fall below `B` (everyone else's net entries) and can never go
/// negative: a correction never exceeds `A`, and a hard clamp at the current
/// total sits behind that as a second guard.
WaterTapOutcome waterTapOutcome({
  required int glassNumber,
  required List<WaterLogsRecord> logs,
  required DateTime now,
  required String uid,
}) {
  final total = waterTotalFlOz(logs, now);
  final target = glassNumber * waterGlassFlOz;

  WaterTapOutcome noOp({String? message}) => WaterTapOutcome._(
        kind: WaterTapKind.noOp,
        amountFlOz: 0,
        targetFlOz: target,
        newTotalFlOz: total,
        message: message,
      );

  if (glassNumber < 1 || glassNumber > waterGlassCount) {
    return noOp();
  }

  final difference = total - target;
  // Within a hundredth of a fluid ounce is "exactly there": amounts are typed
  // in fl oz and the day is summed from doubles.
  if (difference.abs() < 0.001) {
    return noOp();
  }
  if (difference < 0) {
    final amount = -difference;
    return WaterTapOutcome._(
      kind: WaterTapKind.fill,
      amountFlOz: amount,
      targetFlOz: target,
      newTotalFlOz: total + amount,
      message: '${formatWaterFlOz(amount)} added',
    );
  }

  final ownNet = waterOwnNetFlOz(logs, now, uid);
  if (ownNet <= 0) {
    return noOp(
      message: waterOwnLoggedFlOz(logs, now, uid) > 0
          ? waterNothingLeftToReduce
          : waterNothingToReduce,
    );
  }
  final correction = math.min(math.min(difference, ownNet), total);
  if (correction <= 0) {
    return noOp(message: waterNothingToReduce);
  }
  final newTotal = total - correction;
  final clamped = correction < difference - 0.001;
  return WaterTapOutcome._(
    kind: WaterTapKind.correction,
    amountFlOz: correction,
    targetFlOz: target,
    newTotalFlOz: newTotal,
    clamped: clamped,
    message: clamped
        ? waterReducedToMessage(newTotal)
        : '${formatWaterFlOz(correction)} removed',
  );
}

/// The wording contract for a correction on any future water history screen or
/// report row: **"Adjusted −16 fl oz (to 32 fl oz)"**.
///
/// An adjustment is never shown as "16 fl oz of water" — it is a correction of
/// the tracked figure, with its own time and author, and it is visually
/// distinct from intake. Reports sum intake from positive `amountFlOz` only
/// ([waterIntakeOnlyFlOz]) and list adjustments separately under this label.
String formatWaterAdjustment(double amountFlOz, double targetFlOz) =>
    'Adjusted −${formatWaterFlOz(amountFlOz.abs())} '
    '(to ${formatWaterFlOz(targetFlOz)})';

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
