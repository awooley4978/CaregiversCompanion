import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class MedicationsRecord extends FirestoreRecord {
  MedicationsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "careRecipientRef" field.
  DocumentReference? _careRecipientRef;
  DocumentReference? get careRecipientRef => _careRecipientRef;
  bool hasCareRecipientRef() => _careRecipientRef != null;

  // "medicationName" field.
  String? _medicationName;
  String get medicationName => _medicationName ?? '';
  bool hasMedicationName() => _medicationName != null;

  // "dose" field.
  String? _dose;
  String get dose => _dose ?? '';
  bool hasDose() => _dose != null;

  // "directions" field.
  String? _directions;
  String get directions => _directions ?? '';
  bool hasDirections() => _directions != null;

  // "timeOfDay" field.
  String? _timeOfDay;
  String get timeOfDay => _timeOfDay ?? '';
  bool hasTimeOfDay() => _timeOfDay != null;

  // "scheduledTime" field.
  DateTime? _scheduledTime;
  DateTime? get scheduledTime => _scheduledTime;
  bool hasScheduledTime() => _scheduledTime != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "active" field.
  bool? _active;
  bool get active => _active ?? false;
  bool hasActive() => _active != null;

  // "refillNeeded" field.
  bool? _refillNeeded;
  bool get refillNeeded => _refillNeeded ?? false;
  bool hasRefillNeeded() => _refillNeeded != null;

  // "quatityLeft" field.
  int? _quatityLeft;
  int get quatityLeft => _quatityLeft ?? 0;
  bool hasQuatityLeft() => _quatityLeft != null;

  // "refillByDate" field.
  DateTime? _refillByDate;
  DateTime? get refillByDate => _refillByDate;
  bool hasRefillByDate() => _refillByDate != null;

  // "pharmacy" field.
  String? _pharmacy;
  String get pharmacy => _pharmacy ?? '';
  bool hasPharmacy() => _pharmacy != null;

  // "instructions" field.
  String? _instructions;
  String get instructions => _instructions ?? '';
  bool hasInstructions() => _instructions != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "UpdateAt" field.
  DateTime? _updateAt;
  DateTime? get updateAt => _updateAt;
  bool hasUpdateAt() => _updateAt != null;

  // "taken" field.
  bool? _taken;
  bool get taken => _taken ?? false;
  bool hasTaken() => _taken != null;

  // "takenAt" field.
  DateTime? _takenAt;
  DateTime? get takenAt => _takenAt;
  bool hasTakenAt() => _takenAt != null;

  void _initializeFields() {
    _careRecipientRef = snapshotData['careRecipientRef'] as DocumentReference?;
    _medicationName = snapshotData['medicationName'] as String?;
    _dose = snapshotData['dose'] as String?;
    _directions = snapshotData['directions'] as String?;
    _timeOfDay = snapshotData['timeOfDay'] as String?;
    _scheduledTime = snapshotData['scheduledTime'] as DateTime?;
    _status = snapshotData['status'] as String?;
    _active = snapshotData['active'] as bool?;
    _refillNeeded = snapshotData['refillNeeded'] as bool?;
    _quatityLeft = castToType<int>(snapshotData['quatityLeft']);
    _refillByDate = snapshotData['refillByDate'] as DateTime?;
    _pharmacy = snapshotData['pharmacy'] as String?;
    _instructions = snapshotData['instructions'] as String?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _updateAt = snapshotData['UpdateAt'] as DateTime?;
    _taken = snapshotData['taken'] as bool?;
    _takenAt = snapshotData['takenAt'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('medications');

  static Stream<MedicationsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => MedicationsRecord.fromSnapshot(s));

  static Future<MedicationsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => MedicationsRecord.fromSnapshot(s));

  static MedicationsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      MedicationsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static MedicationsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      MedicationsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'MedicationsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is MedicationsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createMedicationsRecordData({
  DocumentReference? careRecipientRef,
  String? medicationName,
  String? dose,
  String? directions,
  String? timeOfDay,
  DateTime? scheduledTime,
  String? status,
  bool? active,
  bool? refillNeeded,
  int? quatityLeft,
  DateTime? refillByDate,
  String? pharmacy,
  String? instructions,
  DateTime? createdAt,
  DateTime? updateAt,
  bool? taken,
  DateTime? takenAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'careRecipientRef': careRecipientRef,
      'medicationName': medicationName,
      'dose': dose,
      'directions': directions,
      'timeOfDay': timeOfDay,
      'scheduledTime': scheduledTime,
      'status': status,
      'active': active,
      'refillNeeded': refillNeeded,
      'quatityLeft': quatityLeft,
      'refillByDate': refillByDate,
      'pharmacy': pharmacy,
      'instructions': instructions,
      'createdAt': createdAt,
      'UpdateAt': updateAt,
      'taken': taken,
      'takenAt': takenAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class MedicationsRecordDocumentEquality implements Equality<MedicationsRecord> {
  const MedicationsRecordDocumentEquality();

  @override
  bool equals(MedicationsRecord? e1, MedicationsRecord? e2) {
    return e1?.careRecipientRef == e2?.careRecipientRef &&
        e1?.medicationName == e2?.medicationName &&
        e1?.dose == e2?.dose &&
        e1?.directions == e2?.directions &&
        e1?.timeOfDay == e2?.timeOfDay &&
        e1?.scheduledTime == e2?.scheduledTime &&
        e1?.status == e2?.status &&
        e1?.active == e2?.active &&
        e1?.refillNeeded == e2?.refillNeeded &&
        e1?.quatityLeft == e2?.quatityLeft &&
        e1?.refillByDate == e2?.refillByDate &&
        e1?.pharmacy == e2?.pharmacy &&
        e1?.instructions == e2?.instructions &&
        e1?.createdAt == e2?.createdAt &&
        e1?.updateAt == e2?.updateAt &&
        e1?.taken == e2?.taken &&
        e1?.takenAt == e2?.takenAt;
  }

  @override
  int hash(MedicationsRecord? e) => const ListEquality().hash([
        e?.careRecipientRef,
        e?.medicationName,
        e?.dose,
        e?.directions,
        e?.timeOfDay,
        e?.scheduledTime,
        e?.status,
        e?.active,
        e?.refillNeeded,
        e?.quatityLeft,
        e?.refillByDate,
        e?.pharmacy,
        e?.instructions,
        e?.createdAt,
        e?.updateAt,
        e?.taken,
        e?.takenAt
      ]);

  @override
  bool isValidKey(Object? o) => o is MedicationsRecord;
}
