import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// One `waterLogs` document: a single, individually timestamped water intake.
///
/// Owner decisions of 2026-11-13 (proposal §2/§9) that shape this record:
///  * one document per intake — there is no cumulative total on the care
///    recipient and no goal/target field anywhere;
///  * `amount` is what was entered, `unit` is the unit it was entered in, and
///    `amountFlOz` is the canonical fl-oz normalisation computed at write, so a
///    total can never mix units;
///  * `intakeAt` is when the water was drunk and is always "now" in this unit;
///  * `orgId` and `loggedByUid` are the attribution the rules require.
class WaterLogsRecord extends FirestoreRecord {
  WaterLogsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "careRecipientRef" field.
  DocumentReference? _careRecipientRef;
  DocumentReference? get careRecipientRef => _careRecipientRef;
  bool hasCareRecipientRef() => _careRecipientRef != null;

  // "orgId" field.
  String? _orgId;
  String get orgId => _orgId ?? '';
  bool hasOrgId() => _orgId != null;

  // "loggedByUid" field.
  String? _loggedByUid;
  String get loggedByUid => _loggedByUid ?? '';
  bool hasLoggedByUid() => _loggedByUid != null;

  // "intakeAt" field.
  DateTime? _intakeAt;
  DateTime? get intakeAt => _intakeAt;
  bool hasIntakeAt() => _intakeAt != null;

  // "amount" field.
  double? _amount;
  double get amount => _amount ?? 0.0;
  bool hasAmount() => _amount != null;

  // "unit" field.
  String? _unit;
  String get unit => _unit ?? '';
  bool hasUnit() => _unit != null;

  // "amountFlOz" field.
  double? _amountFlOz;
  double get amountFlOz => _amountFlOz ?? 0.0;
  bool hasAmountFlOz() => _amountFlOz != null;

  // "notes" field.
  String? _notes;
  String get notes => _notes ?? '';
  bool hasNotes() => _notes != null;

  void _initializeFields() {
    _careRecipientRef = snapshotData['careRecipientRef'] as DocumentReference?;
    _orgId = castToType<String>(snapshotData['orgId']);
    _loggedByUid = castToType<String>(snapshotData['loggedByUid']);
    _intakeAt = snapshotData['intakeAt'] as DateTime?;
    _amount = castToType<double>(snapshotData['amount']);
    _unit = castToType<String>(snapshotData['unit']);
    _amountFlOz = castToType<double>(snapshotData['amountFlOz']);
    _notes = snapshotData['notes'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('waterLogs');

  static Stream<WaterLogsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => WaterLogsRecord.fromSnapshot(s));

  static Future<WaterLogsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => WaterLogsRecord.fromSnapshot(s));

  static WaterLogsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      WaterLogsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static WaterLogsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      WaterLogsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'WaterLogsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is WaterLogsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createWaterLogsRecordData({
  DocumentReference? careRecipientRef,
  String? orgId,
  String? loggedByUid,
  DateTime? intakeAt,
  double? amount,
  String? unit,
  double? amountFlOz,
  String? notes,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'careRecipientRef': careRecipientRef,
      'orgId': orgId,
      'loggedByUid': loggedByUid,
      // The security rules require `intakeAt` to be a real timestamp, so it is
      // converted here rather than relying on the value's Dart type.
      'intakeAt': intakeAt == null ? null : Timestamp.fromDate(intakeAt),
      'amount': amount,
      'unit': unit,
      'amountFlOz': amountFlOz,
      'notes': notes,
    }.withoutNulls,
  );

  return firestoreData;
}

class WaterLogsRecordDocumentEquality implements Equality<WaterLogsRecord> {
  const WaterLogsRecordDocumentEquality();

  @override
  bool equals(WaterLogsRecord? e1, WaterLogsRecord? e2) {
    return e1?.careRecipientRef == e2?.careRecipientRef &&
        e1?.orgId == e2?.orgId &&
        e1?.loggedByUid == e2?.loggedByUid &&
        e1?.intakeAt == e2?.intakeAt &&
        e1?.amount == e2?.amount &&
        e1?.unit == e2?.unit &&
        e1?.amountFlOz == e2?.amountFlOz &&
        e1?.notes == e2?.notes;
  }

  @override
  int hash(WaterLogsRecord? e) => const ListEquality().hash([
        e?.careRecipientRef,
        e?.orgId,
        e?.loggedByUid,
        e?.intakeAt,
        e?.amount,
        e?.unit,
        e?.amountFlOz,
        e?.notes
      ]);

  @override
  bool isValidKey(Object? o) => o is WaterLogsRecord;
}
