import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CareNotesRecord extends FirestoreRecord {
  CareNotesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "careRecipientRef" field.
  DocumentReference? _careRecipientRef;
  DocumentReference? get careRecipientRef => _careRecipientRef;
  bool hasCareRecipientRef() => _careRecipientRef != null;

  // "Symptoms" field.
  List<String>? _symptoms;
  List<String> get symptoms => _symptoms ?? const [];
  bool hasSymptoms() => _symptoms != null;

  // "Mood" field.
  List<String>? _mood;
  List<String> get mood => _mood ?? const [];
  bool hasMood() => _mood != null;

  // "caregiverObservations" field.
  List<String>? _caregiverObservations;
  List<String> get caregiverObservations => _caregiverObservations ?? const [];
  bool hasCaregiverObservations() => _caregiverObservations != null;

  // "noteDateTime" field.
  DateTime? _noteDateTime;
  DateTime? get noteDateTime => _noteDateTime;
  bool hasNoteDateTime() => _noteDateTime != null;

  // "noteText" field.
  String? _noteText;
  String get noteText => _noteText ?? '';
  bool hasNoteText() => _noteText != null;

  // "category" field.
  String? _category;
  String get category => _category ?? '';
  bool hasCategory() => _category != null;

  // "mealNotes" field.
  String? _mealNotes;
  String get mealNotes => _mealNotes ?? '';
  bool hasMealNotes() => _mealNotes != null;

  // "followUpNeeded" field.
  bool? _followUpNeeded;
  bool get followUpNeeded => _followUpNeeded ?? false;
  bool hasFollowUpNeeded() => _followUpNeeded != null;

  // "important" field.
  bool? _important;
  bool get important => _important ?? false;
  bool hasImportant() => _important != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "updatedAt" field.
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  bool hasUpdatedAt() => _updatedAt != null;

  // "otherSymptom" field.
  String? _otherSymptom;
  String get otherSymptom => _otherSymptom ?? '';
  bool hasOtherSymptom() => _otherSymptom != null;

  // "createdBy" field.
  String? _createdBy;
  String get createdBy => _createdBy ?? '';
  bool hasCreatedBy() => _createdBy != null;

  void _initializeFields() {
    _careRecipientRef = snapshotData['careRecipientRef'] as DocumentReference?;
    _symptoms = getDataList(snapshotData['Symptoms']);
    _mood = getDataList(snapshotData['Mood']);
    _caregiverObservations = getDataList(snapshotData['caregiverObservations']);
    _noteDateTime = snapshotData['noteDateTime'] as DateTime?;
    _noteText = snapshotData['noteText'] as String?;
    _category = snapshotData['category'] as String?;
    _mealNotes = snapshotData['mealNotes'] as String?;
    _followUpNeeded = snapshotData['followUpNeeded'] as bool?;
    _important = snapshotData['important'] as bool?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _updatedAt = snapshotData['updatedAt'] as DateTime?;
    _otherSymptom = snapshotData['otherSymptom'] as String?;
    _createdBy = snapshotData['createdBy'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('careNotes');

  static Stream<CareNotesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => CareNotesRecord.fromSnapshot(s));

  static Future<CareNotesRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => CareNotesRecord.fromSnapshot(s));

  static CareNotesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      CareNotesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static CareNotesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      CareNotesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'CareNotesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is CareNotesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createCareNotesRecordData({
  DocumentReference? careRecipientRef,
  DateTime? noteDateTime,
  String? noteText,
  String? category,
  String? mealNotes,
  bool? followUpNeeded,
  bool? important,
  DateTime? createdAt,
  DateTime? updatedAt,
  String? otherSymptom,
  String? createdBy,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'careRecipientRef': careRecipientRef,
      'noteDateTime': noteDateTime,
      'noteText': noteText,
      'category': category,
      'mealNotes': mealNotes,
      'followUpNeeded': followUpNeeded,
      'important': important,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'otherSymptom': otherSymptom,
      'createdBy': createdBy,
    }.withoutNulls,
  );

  return firestoreData;
}

class CareNotesRecordDocumentEquality implements Equality<CareNotesRecord> {
  const CareNotesRecordDocumentEquality();

  @override
  bool equals(CareNotesRecord? e1, CareNotesRecord? e2) {
    const listEquality = ListEquality();
    return e1?.careRecipientRef == e2?.careRecipientRef &&
        listEquality.equals(e1?.symptoms, e2?.symptoms) &&
        listEquality.equals(e1?.mood, e2?.mood) &&
        listEquality.equals(
            e1?.caregiverObservations, e2?.caregiverObservations) &&
        e1?.noteDateTime == e2?.noteDateTime &&
        e1?.noteText == e2?.noteText &&
        e1?.category == e2?.category &&
        e1?.mealNotes == e2?.mealNotes &&
        e1?.followUpNeeded == e2?.followUpNeeded &&
        e1?.important == e2?.important &&
        e1?.createdAt == e2?.createdAt &&
        e1?.updatedAt == e2?.updatedAt &&
        e1?.otherSymptom == e2?.otherSymptom &&
        e1?.createdBy == e2?.createdBy;
  }

  @override
  int hash(CareNotesRecord? e) => const ListEquality().hash([
        e?.careRecipientRef,
        e?.symptoms,
        e?.mood,
        e?.caregiverObservations,
        e?.noteDateTime,
        e?.noteText,
        e?.category,
        e?.mealNotes,
        e?.followUpNeeded,
        e?.important,
        e?.createdAt,
        e?.updatedAt,
        e?.otherSymptom,
        e?.createdBy
      ]);

  @override
  bool isValidKey(Object? o) => o is CareNotesRecord;
}
