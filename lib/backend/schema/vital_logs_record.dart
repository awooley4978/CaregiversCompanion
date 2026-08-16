import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class VitalLogsRecord extends FirestoreRecord {
  VitalLogsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "careRecipientRef" field.
  DocumentReference? _careRecipientRef;
  DocumentReference? get careRecipientRef => _careRecipientRef;
  bool hasCareRecipientRef() => _careRecipientRef != null;

  // "logDateTime" field.
  DateTime? _logDateTime;
  DateTime? get logDateTime => _logDateTime;
  bool hasLogDateTime() => _logDateTime != null;

  // "bloodPressureSystolic" field.
  int? _bloodPressureSystolic;
  int get bloodPressureSystolic => _bloodPressureSystolic ?? 0;
  bool hasBloodPressureSystolic() => _bloodPressureSystolic != null;

  // "bloodPressureDiastolic" field.
  int? _bloodPressureDiastolic;
  int get bloodPressureDiastolic => _bloodPressureDiastolic ?? 0;
  bool hasBloodPressureDiastolic() => _bloodPressureDiastolic != null;

  // "heartRate" field.
  int? _heartRate;
  int get heartRate => _heartRate ?? 0;
  bool hasHeartRate() => _heartRate != null;

  // "bloodGlucose" field.
  int? _bloodGlucose;
  int get bloodGlucose => _bloodGlucose ?? 0;
  bool hasBloodGlucose() => _bloodGlucose != null;

  // "oxygenSaturation" field.
  int? _oxygenSaturation;
  int get oxygenSaturation => _oxygenSaturation ?? 0;
  bool hasOxygenSaturation() => _oxygenSaturation != null;

  // "temperature" field.
  double? _temperature;
  double get temperature => _temperature ?? 0.0;
  bool hasTemperature() => _temperature != null;

  // "weight" field.
  double? _weight;
  double get weight => _weight ?? 0.0;
  bool hasWeight() => _weight != null;

  // "painLevel" field.
  int? _painLevel;
  int get painLevel => _painLevel ?? 0;
  bool hasPainLevel() => _painLevel != null;

  // "notes" field.
  String? _notes;
  String get notes => _notes ?? '';
  bool hasNotes() => _notes != null;

  // "createdAt" field.
  String? _createdAt;
  String get createdAt => _createdAt ?? '';
  bool hasCreatedAt() => _createdAt != null;

  // "updatedAt" field.
  String? _updatedAt;
  String get updatedAt => _updatedAt ?? '';
  bool hasUpdatedAt() => _updatedAt != null;

  void _initializeFields() {
    _careRecipientRef = snapshotData['careRecipientRef'] as DocumentReference?;
    _logDateTime = snapshotData['logDateTime'] as DateTime?;
    _bloodPressureSystolic =
        castToType<int>(snapshotData['bloodPressureSystolic']);
    _bloodPressureDiastolic =
        castToType<int>(snapshotData['bloodPressureDiastolic']);
    _heartRate = castToType<int>(snapshotData['heartRate']);
    _bloodGlucose = castToType<int>(snapshotData['bloodGlucose']);
    _oxygenSaturation = castToType<int>(snapshotData['oxygenSaturation']);
    _temperature = castToType<double>(snapshotData['temperature']);
    _weight = castToType<double>(snapshotData['weight']);
    _painLevel = castToType<int>(snapshotData['painLevel']);
    _notes = snapshotData['notes'] as String?;
    _createdAt = snapshotData['createdAt'] as String?;
    _updatedAt = snapshotData['updatedAt'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('vitalLogs');

  static Stream<VitalLogsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => VitalLogsRecord.fromSnapshot(s));

  static Future<VitalLogsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => VitalLogsRecord.fromSnapshot(s));

  static VitalLogsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      VitalLogsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static VitalLogsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      VitalLogsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'VitalLogsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is VitalLogsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createVitalLogsRecordData({
  DocumentReference? careRecipientRef,
  DateTime? logDateTime,
  int? bloodPressureSystolic,
  int? bloodPressureDiastolic,
  int? heartRate,
  int? bloodGlucose,
  int? oxygenSaturation,
  double? temperature,
  double? weight,
  int? painLevel,
  String? notes,
  String? createdAt,
  String? updatedAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'careRecipientRef': careRecipientRef,
      'logDateTime': logDateTime,
      'bloodPressureSystolic': bloodPressureSystolic,
      'bloodPressureDiastolic': bloodPressureDiastolic,
      'heartRate': heartRate,
      'bloodGlucose': bloodGlucose,
      'oxygenSaturation': oxygenSaturation,
      'temperature': temperature,
      'weight': weight,
      'painLevel': painLevel,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class VitalLogsRecordDocumentEquality implements Equality<VitalLogsRecord> {
  const VitalLogsRecordDocumentEquality();

  @override
  bool equals(VitalLogsRecord? e1, VitalLogsRecord? e2) {
    return e1?.careRecipientRef == e2?.careRecipientRef &&
        e1?.logDateTime == e2?.logDateTime &&
        e1?.bloodPressureSystolic == e2?.bloodPressureSystolic &&
        e1?.bloodPressureDiastolic == e2?.bloodPressureDiastolic &&
        e1?.heartRate == e2?.heartRate &&
        e1?.bloodGlucose == e2?.bloodGlucose &&
        e1?.oxygenSaturation == e2?.oxygenSaturation &&
        e1?.temperature == e2?.temperature &&
        e1?.weight == e2?.weight &&
        e1?.painLevel == e2?.painLevel &&
        e1?.notes == e2?.notes &&
        e1?.createdAt == e2?.createdAt &&
        e1?.updatedAt == e2?.updatedAt;
  }

  @override
  int hash(VitalLogsRecord? e) => const ListEquality().hash([
        e?.careRecipientRef,
        e?.logDateTime,
        e?.bloodPressureSystolic,
        e?.bloodPressureDiastolic,
        e?.heartRate,
        e?.bloodGlucose,
        e?.oxygenSaturation,
        e?.temperature,
        e?.weight,
        e?.painLevel,
        e?.notes,
        e?.createdAt,
        e?.updatedAt
      ]);

  @override
  bool isValidKey(Object? o) => o is VitalLogsRecord;
}
