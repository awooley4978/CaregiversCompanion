import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class DashboardNotesRecord extends FirestoreRecord {
  DashboardNotesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "patientRef" field.
  DocumentReference? _patientRef;
  DocumentReference? get patientRef => _patientRef;
  bool hasPatientRef() => _patientRef != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "noteText" field.
  String? _noteText;
  String get noteText => _noteText ?? '';
  bool hasNoteText() => _noteText != null;

  // "updatedAt" field.
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  bool hasUpdatedAt() => _updatedAt != null;

  // "noteDay" field.
  DateTime? _noteDay;
  DateTime? get noteDay => _noteDay;
  bool hasNoteDay() => _noteDay != null;

  // "createdBy" field.
  String? _createdBy;
  String get createdBy => _createdBy ?? '';
  bool hasCreatedBy() => _createdBy != null;

  void _initializeFields() {
    _patientRef = snapshotData['patientRef'] as DocumentReference?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _noteText = snapshotData['noteText'] as String?;
    _updatedAt = snapshotData['updatedAt'] as DateTime?;
    _noteDay = snapshotData['noteDay'] as DateTime?;
    _createdBy = snapshotData['createdBy'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('dashboardNotes');

  static Stream<DashboardNotesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => DashboardNotesRecord.fromSnapshot(s));

  static Future<DashboardNotesRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => DashboardNotesRecord.fromSnapshot(s));

  static DashboardNotesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      DashboardNotesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static DashboardNotesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      DashboardNotesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'DashboardNotesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is DashboardNotesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createDashboardNotesRecordData({
  DocumentReference? patientRef,
  DateTime? createdAt,
  String? noteText,
  DateTime? updatedAt,
  DateTime? noteDay,
  String? createdBy,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'patientRef': patientRef,
      'createdAt': createdAt,
      'noteText': noteText,
      'updatedAt': updatedAt,
      'noteDay': noteDay,
      'createdBy': createdBy,
    }.withoutNulls,
  );

  return firestoreData;
}

class DashboardNotesRecordDocumentEquality
    implements Equality<DashboardNotesRecord> {
  const DashboardNotesRecordDocumentEquality();

  @override
  bool equals(DashboardNotesRecord? e1, DashboardNotesRecord? e2) {
    return e1?.patientRef == e2?.patientRef &&
        e1?.createdAt == e2?.createdAt &&
        e1?.noteText == e2?.noteText &&
        e1?.updatedAt == e2?.updatedAt &&
        e1?.noteDay == e2?.noteDay &&
        e1?.createdBy == e2?.createdBy;
  }

  @override
  int hash(DashboardNotesRecord? e) => const ListEquality().hash([
        e?.patientRef,
        e?.createdAt,
        e?.noteText,
        e?.updatedAt,
        e?.noteDay,
        e?.createdBy
      ]);

  @override
  bool isValidKey(Object? o) => o is DashboardNotesRecord;
}
