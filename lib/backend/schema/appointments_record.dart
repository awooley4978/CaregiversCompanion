import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class AppointmentsRecord extends FirestoreRecord {
  AppointmentsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "careRecipientRef" field.
  DocumentReference? _careRecipientRef;
  DocumentReference? get careRecipientRef => _careRecipientRef;
  bool hasCareRecipientRef() => _careRecipientRef != null;

  // "appointmentTitle" field.
  String? _appointmentTitle;
  String get appointmentTitle => _appointmentTitle ?? '';
  bool hasAppointmentTitle() => _appointmentTitle != null;

  // "appointmentType" field.
  String? _appointmentType;
  String get appointmentType => _appointmentType ?? '';
  bool hasAppointmentType() => _appointmentType != null;

  // "appointmentDateTime" field.
  DateTime? _appointmentDateTime;
  DateTime? get appointmentDateTime => _appointmentDateTime;
  bool hasAppointmentDateTime() => _appointmentDateTime != null;

  // "endDateTime" field.
  DateTime? _endDateTime;
  DateTime? get endDateTime => _endDateTime;
  bool hasEndDateTime() => _endDateTime != null;

  // "providerName" field.
  String? _providerName;
  String get providerName => _providerName ?? '';
  bool hasProviderName() => _providerName != null;

  // "location" field.
  String? _location;
  String get location => _location ?? '';
  bool hasLocation() => _location != null;

  // "reason" field.
  String? _reason;
  String get reason => _reason ?? '';
  bool hasReason() => _reason != null;

  // "questionsToAsk" field.
  String? _questionsToAsk;
  String get questionsToAsk => _questionsToAsk ?? '';
  bool hasQuestionsToAsk() => _questionsToAsk != null;

  // "notes" field.
  String? _notes;
  String get notes => _notes ?? '';
  bool hasNotes() => _notes != null;

  // "followUpNeeded" field.
  bool? _followUpNeeded;
  bool get followUpNeeded => _followUpNeeded ?? false;
  bool hasFollowUpNeeded() => _followUpNeeded != null;

  // "completed" field.
  bool? _completed;
  bool get completed => _completed ?? false;
  bool hasCompleted() => _completed != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "updatedAt" field.
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  bool hasUpdatedAt() => _updatedAt != null;

  void _initializeFields() {
    _careRecipientRef = snapshotData['careRecipientRef'] as DocumentReference?;
    _appointmentTitle = snapshotData['appointmentTitle'] as String?;
    _appointmentType = snapshotData['appointmentType'] as String?;
    _appointmentDateTime = snapshotData['appointmentDateTime'] as DateTime?;
    _endDateTime = snapshotData['endDateTime'] as DateTime?;
    _providerName = snapshotData['providerName'] as String?;
    _location = snapshotData['location'] as String?;
    _reason = snapshotData['reason'] as String?;
    _questionsToAsk = snapshotData['questionsToAsk'] as String?;
    _notes = snapshotData['notes'] as String?;
    _followUpNeeded = snapshotData['followUpNeeded'] as bool?;
    _completed = snapshotData['completed'] as bool?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _updatedAt = snapshotData['updatedAt'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('appointments');

  static Stream<AppointmentsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => AppointmentsRecord.fromSnapshot(s));

  static Future<AppointmentsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => AppointmentsRecord.fromSnapshot(s));

  static AppointmentsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      AppointmentsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static AppointmentsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      AppointmentsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'AppointmentsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is AppointmentsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createAppointmentsRecordData({
  DocumentReference? careRecipientRef,
  String? appointmentTitle,
  String? appointmentType,
  DateTime? appointmentDateTime,
  DateTime? endDateTime,
  String? providerName,
  String? location,
  String? reason,
  String? questionsToAsk,
  String? notes,
  bool? followUpNeeded,
  bool? completed,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'careRecipientRef': careRecipientRef,
      'appointmentTitle': appointmentTitle,
      'appointmentType': appointmentType,
      'appointmentDateTime': appointmentDateTime,
      'endDateTime': endDateTime,
      'providerName': providerName,
      'location': location,
      'reason': reason,
      'questionsToAsk': questionsToAsk,
      'notes': notes,
      'followUpNeeded': followUpNeeded,
      'completed': completed,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class AppointmentsRecordDocumentEquality
    implements Equality<AppointmentsRecord> {
  const AppointmentsRecordDocumentEquality();

  @override
  bool equals(AppointmentsRecord? e1, AppointmentsRecord? e2) {
    return e1?.careRecipientRef == e2?.careRecipientRef &&
        e1?.appointmentTitle == e2?.appointmentTitle &&
        e1?.appointmentType == e2?.appointmentType &&
        e1?.appointmentDateTime == e2?.appointmentDateTime &&
        e1?.endDateTime == e2?.endDateTime &&
        e1?.providerName == e2?.providerName &&
        e1?.location == e2?.location &&
        e1?.reason == e2?.reason &&
        e1?.questionsToAsk == e2?.questionsToAsk &&
        e1?.notes == e2?.notes &&
        e1?.followUpNeeded == e2?.followUpNeeded &&
        e1?.completed == e2?.completed &&
        e1?.createdAt == e2?.createdAt &&
        e1?.updatedAt == e2?.updatedAt;
  }

  @override
  int hash(AppointmentsRecord? e) => const ListEquality().hash([
        e?.careRecipientRef,
        e?.appointmentTitle,
        e?.appointmentType,
        e?.appointmentDateTime,
        e?.endDateTime,
        e?.providerName,
        e?.location,
        e?.reason,
        e?.questionsToAsk,
        e?.notes,
        e?.followUpNeeded,
        e?.completed,
        e?.createdAt,
        e?.updatedAt
      ]);

  @override
  bool isValidKey(Object? o) => o is AppointmentsRecord;
}
