import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class SymptomEntriesRecord extends FirestoreRecord {
  SymptomEntriesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "symptomName" field.
  String? _symptomName;
  String get symptomName => _symptomName ?? '';
  bool hasSymptomName() => _symptomName != null;

  // "note" field.
  String? _note;
  String get note => _note ?? '';
  bool hasNote() => _note != null;

  // "timeLogged" field.
  DateTime? _timeLogged;
  DateTime? get timeLogged => _timeLogged;
  bool hasTimeLogged() => _timeLogged != null;

  // "patientRef" field.
  DocumentReference? _patientRef;
  DocumentReference? get patientRef => _patientRef;
  bool hasPatientRef() => _patientRef != null;

  // "isResolved" field.
  bool? _isResolved;
  bool get isResolved => _isResolved ?? false;
  bool hasIsResolved() => _isResolved != null;

  void _initializeFields() {
    _symptomName = snapshotData['symptomName'] as String?;
    _note = snapshotData['note'] as String?;
    _timeLogged = snapshotData['timeLogged'] as DateTime?;
    _patientRef = snapshotData['patientRef'] as DocumentReference?;
    _isResolved = snapshotData['isResolved'] as bool?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('symptomEntries');

  static Stream<SymptomEntriesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => SymptomEntriesRecord.fromSnapshot(s));

  static Future<SymptomEntriesRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => SymptomEntriesRecord.fromSnapshot(s));

  static SymptomEntriesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      SymptomEntriesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static SymptomEntriesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      SymptomEntriesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'SymptomEntriesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is SymptomEntriesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createSymptomEntriesRecordData({
  String? symptomName,
  String? note,
  DateTime? timeLogged,
  DocumentReference? patientRef,
  bool? isResolved,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'symptomName': symptomName,
      'note': note,
      'timeLogged': timeLogged,
      'patientRef': patientRef,
      'isResolved': isResolved,
    }.withoutNulls,
  );

  return firestoreData;
}

class SymptomEntriesRecordDocumentEquality
    implements Equality<SymptomEntriesRecord> {
  const SymptomEntriesRecordDocumentEquality();

  @override
  bool equals(SymptomEntriesRecord? e1, SymptomEntriesRecord? e2) {
    return e1?.symptomName == e2?.symptomName &&
        e1?.note == e2?.note &&
        e1?.timeLogged == e2?.timeLogged &&
        e1?.patientRef == e2?.patientRef &&
        e1?.isResolved == e2?.isResolved;
  }

  @override
  int hash(SymptomEntriesRecord? e) => const ListEquality().hash(
      [e?.symptomName, e?.note, e?.timeLogged, e?.patientRef, e?.isResolved]);

  @override
  bool isValidKey(Object? o) => o is SymptomEntriesRecord;
}
