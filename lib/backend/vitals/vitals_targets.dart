// Vitals target ranges — optional, per-recipient numbers a caregiver enters
// from what the care recipient's clinician has said.
//
// Owner decisions of 2026-11-18 (vitals-export proposal §13, items 2b/3/4):
//  * targets live on `careRecipients` in one optional `VitalsTargets` map,
//    keyed by measurement, each entry holding an independent `min` and `max`;
//  * a separate minimum and maximum per measurement, so a one-sided
//    instruction ("keep systolic under 140") is representable without
//    inventing a lower bound;
//  * blood pressure carries a systolic AND a diastolic target; pain (0–10) has
//    no target at all — it is a self-reported score, not a threshold;
//  * the app NEVER supplies a number: no default, no "normal" range, no
//    age-based auto-fill from DateOfBirth, no pre-filled field. A blank box
//    means no target for that measurement and nothing is stored;
//  * nothing here interprets a reading. This file only stores and returns the
//    numbers a human typed, and rejects input that is not a number or that has
//    the minimum above the maximum. No clinical wording ("normal", "high") and
//    no plausibility/health bounds exist anywhere in it.
//
// Stored shape (one field on the careRecipients document, no new collection,
// no migration — a recipient written before this field existed simply has no
// targets):
//
//   VitalsTargets: {
//     'bloodPressureSystolic': {'min': 90, 'max': 140},
//     'heartRate': {'min': 60},              // one-sided: only a floor
//     'temperature': {'max': 99.5},          // decimals where they apply
//   }
//
// Reading is defensive: an unknown key, a value that is not a map, or a
// min/max that is not a number is ignored rather than thrown on.

/// One measurement that can carry a target range.
class VitalsTargetMeasurement {
  const VitalsTargetMeasurement({
    required this.key,
    required this.label,
    required this.unit,
    required this.wholeNumbersOnly,
  });

  /// The key this measurement's range is stored under in `VitalsTargets`.
  final String key;

  /// The caregiver-facing name of the measurement.
  final String label;

  /// The unit the numbers are in — the same units the Vitals screen records.
  final String unit;

  /// True when the measurement is only ever recorded as a whole number
  /// (bpm, mg/dL, %, mmHg, 0–10), so a decimal target is a typo, not a value.
  final bool wholeNumbersOnly;
}

const VitalsTargetMeasurement kVitalsTargetBloodPressureSystolic =
    VitalsTargetMeasurement(
  key: 'bloodPressureSystolic',
  label: 'Blood pressure (systolic)',
  unit: 'mmHg',
  wholeNumbersOnly: true,
);

const VitalsTargetMeasurement kVitalsTargetBloodPressureDiastolic =
    VitalsTargetMeasurement(
  key: 'bloodPressureDiastolic',
  label: 'Blood pressure (diastolic)',
  unit: 'mmHg',
  wholeNumbersOnly: true,
);

const VitalsTargetMeasurement kVitalsTargetHeartRate = VitalsTargetMeasurement(
  key: 'heartRate',
  label: 'Heart rate',
  unit: 'bpm',
  wholeNumbersOnly: true,
);

const VitalsTargetMeasurement kVitalsTargetBloodGlucose =
    VitalsTargetMeasurement(
  key: 'bloodGlucose',
  label: 'Blood glucose',
  unit: 'mg/dL',
  wholeNumbersOnly: true,
);

const VitalsTargetMeasurement kVitalsTargetOxygenSaturation =
    VitalsTargetMeasurement(
  key: 'oxygenSaturation',
  label: 'Oxygen saturation',
  unit: '%',
  wholeNumbersOnly: true,
);

const VitalsTargetMeasurement kVitalsTargetTemperature =
    VitalsTargetMeasurement(
  key: 'temperature',
  label: 'Temperature',
  unit: '°F',
  wholeNumbersOnly: false,
);

const VitalsTargetMeasurement kVitalsTargetWeight = VitalsTargetMeasurement(
  key: 'weight',
  label: 'Weight',
  unit: 'lb',
  wholeNumbersOnly: false,
);

/// Every measurement that can carry a target, in display order. Pain is
/// deliberately absent (owner decision 2026-11-18, item 4).
const List<VitalsTargetMeasurement> kVitalsTargetMeasurements =
    <VitalsTargetMeasurement>[
  kVitalsTargetBloodPressureSystolic,
  kVitalsTargetBloodPressureDiastolic,
  kVitalsTargetHeartRate,
  kVitalsTargetBloodGlucose,
  kVitalsTargetOxygenSaturation,
  kVitalsTargetTemperature,
  kVitalsTargetWeight,
];

/// The `careRecipients` field the targets are stored in.
const String kVitalsTargetsField = 'VitalsTargets';

/// Which of a measurement's two boxes a message belongs to.
enum VitalsTargetSide { min, max }

/// One measurement's target: each side independently optional.
class VitalsTargetRange {
  const VitalsTargetRange({this.min, this.max});

  /// The lowest value the caregiver was told to stay at or above, or null when
  /// there is no lower target.
  final num? min;

  /// The highest value the caregiver was told to stay at or below, or null
  /// when there is no upper target.
  final num? max;

  bool get hasAny => min != null || max != null;

  /// The map stored for this measurement. A side with no target is omitted
  /// entirely — never written as a zero.
  Map<String, dynamic> toStore() => <String, dynamic>{
        if (min != null) 'min': min,
        if (max != null) 'max': max,
      };
}

/// The outcome of reading one measurement's two boxes.
class VitalsTargetPairResult {
  const VitalsTargetPairResult({this.range, this.error, this.errorSide});

  /// The range to store, or null when both boxes are blank (no target).
  final VitalsTargetRange? range;

  /// The message to show, or null when the input is acceptable.
  final String? error;

  /// Which box [error] belongs to, when there is an error.
  final VitalsTargetSide? errorSide;
}

/// Reads and validates one measurement's two boxes.
///
/// Blank means no target: two blank boxes give [VitalsTargetPairResult.range]
/// null and no error, and one blank box leaves that side of the range null.
/// A box is rejected when it is not a number, when a whole-number measurement
/// gets a decimal, when it is negative, or when the minimum is above the
/// maximum. Nothing is defaulted or filled in.
VitalsTargetPairResult readVitalsTargetPair({
  required VitalsTargetMeasurement measurement,
  required String? minText,
  required String? maxText,
}) {
  final min = _readVitalsTargetBox(measurement, VitalsTargetSide.min, minText);
  if (min.error != null) {
    return VitalsTargetPairResult(error: min.error, errorSide: VitalsTargetSide.min);
  }
  final max = _readVitalsTargetBox(measurement, VitalsTargetSide.max, maxText);
  if (max.error != null) {
    return VitalsTargetPairResult(error: max.error, errorSide: VitalsTargetSide.max);
  }
  if (min.value != null && max.value != null && min.value! > max.value!) {
    return VitalsTargetPairResult(
      error: '${measurement.label} minimum cannot be greater than the maximum.',
      errorSide: VitalsTargetSide.max,
    );
  }
  if (min.value == null && max.value == null) {
    return const VitalsTargetPairResult();
  }
  return VitalsTargetPairResult(
    range: VitalsTargetRange(min: min.value, max: max.value),
  );
}

class _BoxResult {
  const _BoxResult({this.value, this.error});

  final num? value;
  final String? error;
}

_BoxResult _readVitalsTargetBox(
  VitalsTargetMeasurement measurement,
  VitalsTargetSide side,
  String? text,
) {
  final trimmed = text?.trim() ?? '';
  if (trimmed.isEmpty) {
    return const _BoxResult();
  }
  final sideName = side == VitalsTargetSide.min ? 'minimum' : 'maximum';
  final parsed = num.tryParse(trimmed);
  if (parsed == null) {
    return _BoxResult(
      error: '${measurement.label} $sideName must be a number.',
    );
  }
  if (parsed < 0) {
    return _BoxResult(
      error: '${measurement.label} $sideName cannot be negative.',
    );
  }
  if (measurement.wholeNumbersOnly && parsed is! int) {
    return _BoxResult(
      error: '${measurement.label} $sideName must be a whole number.',
    );
  }
  return _BoxResult(value: parsed);
}

/// The text shown in a target box for a stored number: a whole value prints
/// without a trailing ".0", a decimal keeps its decimals.
String formatVitalsTargetNumber(num value) {
  if (value is int) {
    return '$value';
  }
  if (value == value.roundToDouble()) {
    return '${value.round()}';
  }
  return '$value';
}

/// Reads the stored `VitalsTargets` map defensively.
///
/// A missing map, an unknown key, a value that is not a map, or a min/max that
/// is not a number is ignored — this never throws, so an old or hand-edited
/// document cannot break the editor. Only ranges with at least one side set
/// are returned.
Map<String, VitalsTargetRange> vitalsTargetsFromRecord(
    Map<String, dynamic>? stored) {
  final ranges = <String, VitalsTargetRange>{};
  if (stored == null) {
    return ranges;
  }
  for (final measurement in kVitalsTargetMeasurements) {
    final raw = stored[measurement.key];
    if (raw is! Map) {
      continue;
    }
    final min = raw['min'];
    final max = raw['max'];
    final range = VitalsTargetRange(
      min: min is num ? min : null,
      max: max is num ? max : null,
    );
    if (range.hasAny) {
      ranges[measurement.key] = range;
    }
  }
  return ranges;
}
