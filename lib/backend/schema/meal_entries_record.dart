import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class MealEntriesRecord extends FirestoreRecord {
  MealEntriesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "amountEaten" field.
  String? _amountEaten;
  String get amountEaten => _amountEaten ?? '';
  bool hasAmountEaten() => _amountEaten != null;

  // "caregiveNote" field.
  String? _caregiveNote;
  String get caregiveNote => _caregiveNote ?? '';
  bool hasCaregiveNote() => _caregiveNote != null;

  // "mealName" field.
  String? _mealName;
  String get mealName => _mealName ?? '';
  bool hasMealName() => _mealName != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "patientRef" field.
  DocumentReference? _patientRef;
  DocumentReference? get patientRef => _patientRef;
  bool hasPatientRef() => _patientRef != null;

  // "mealType" field.
  String? _mealType;
  String get mealType => _mealType ?? '';
  bool hasMealType() => _mealType != null;

  void _initializeFields() {
    _amountEaten = snapshotData['amountEaten'] as String?;
    _caregiveNote = snapshotData['caregiveNote'] as String?;
    _mealName = snapshotData['mealName'] as String?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _patientRef = snapshotData['patientRef'] as DocumentReference?;
    _mealType = snapshotData['mealType'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('mealEntries');

  static Stream<MealEntriesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => MealEntriesRecord.fromSnapshot(s));

  static Future<MealEntriesRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => MealEntriesRecord.fromSnapshot(s));

  static MealEntriesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      MealEntriesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static MealEntriesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      MealEntriesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'MealEntriesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is MealEntriesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createMealEntriesRecordData({
  String? amountEaten,
  String? caregiveNote,
  String? mealName,
  DateTime? createdAt,
  DocumentReference? patientRef,
  String? mealType,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'amountEaten': amountEaten,
      'caregiveNote': caregiveNote,
      'mealName': mealName,
      'createdAt': createdAt,
      'patientRef': patientRef,
      'mealType': mealType,
    }.withoutNulls,
  );

  return firestoreData;
}

class MealEntriesRecordDocumentEquality implements Equality<MealEntriesRecord> {
  const MealEntriesRecordDocumentEquality();

  @override
  bool equals(MealEntriesRecord? e1, MealEntriesRecord? e2) {
    return e1?.amountEaten == e2?.amountEaten &&
        e1?.caregiveNote == e2?.caregiveNote &&
        e1?.mealName == e2?.mealName &&
        e1?.createdAt == e2?.createdAt &&
        e1?.patientRef == e2?.patientRef &&
        e1?.mealType == e2?.mealType;
  }

  @override
  int hash(MealEntriesRecord? e) => const ListEquality().hash([
        e?.amountEaten,
        e?.caregiveNote,
        e?.mealName,
        e?.createdAt,
        e?.patientRef,
        e?.mealType
      ]);

  @override
  bool isValidKey(Object? o) => o is MealEntriesRecord;
}
