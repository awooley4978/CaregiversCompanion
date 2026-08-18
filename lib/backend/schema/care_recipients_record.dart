import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CareRecipientsRecord extends FirestoreRecord {
  CareRecipientsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "Name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "Conditions" field.
  List<String>? _conditions;
  List<String> get conditions => _conditions ?? const [];
  bool hasConditions() => _conditions != null;

  // "Allergies" field.
  List<String>? _allergies;
  List<String> get allergies => _allergies ?? const [];
  bool hasAllergies() => _allergies != null;

  // "Photo" field.
  String? _photo;
  String get photo => _photo ?? '';
  bool hasPhoto() => _photo != null;

  // "CreatedAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "UpdatedAt" field.
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  bool hasUpdatedAt() => _updatedAt != null;

  // "MobilityNotes" field.
  String? _mobilityNotes;
  String get mobilityNotes => _mobilityNotes ?? '';
  bool hasMobilityNotes() => _mobilityNotes != null;

  // "Initials" field.
  String? _initials;
  String get initials => _initials ?? '';
  bool hasInitials() => _initials != null;

  // "PrimaryCondition" field.
  String? _primaryCondition;
  String get primaryCondition => _primaryCondition ?? '';
  bool hasPrimaryCondition() => _primaryCondition != null;

  // "EmergencyContactName" field.
  String? _emergencyContactName;
  String get emergencyContactName => _emergencyContactName ?? '';
  bool hasEmergencyContactName() => _emergencyContactName != null;

  // "EmergencyContactPhone" field.
  String? _emergencyContactPhone;
  String get emergencyContactPhone => _emergencyContactPhone ?? '';
  bool hasEmergencyContactPhone() => _emergencyContactPhone != null;

  // "PrimaryCarePhysicianName" field.
  String? _primaryCarePhysicianName;
  String get primaryCarePhysicianName => _primaryCarePhysicianName ?? '';
  bool hasPrimaryCarePhysicianName() => _primaryCarePhysicianName != null;

  // "PrimaryCarePhysicianPhone" field.
  String? _primaryCarePhysicianPhone;
  String get primaryCarePhysicianPhone => _primaryCarePhysicianPhone ?? '';
  bool hasPrimaryCarePhysicianPhone() => _primaryCarePhysicianPhone != null;

  // "TrackVitals" field.
  bool? _trackVitals;
  bool get trackVitals => _trackVitals ?? false;
  bool hasTrackVitals() => _trackVitals != null;

  // "TrackGlucose" field.
  bool? _trackGlucose;
  bool get trackGlucose => _trackGlucose ?? false;
  bool hasTrackGlucose() => _trackGlucose != null;

  // "TrackMedication" field.
  bool? _trackMedication;
  bool get trackMedication => _trackMedication ?? false;
  bool hasTrackMedication() => _trackMedication != null;

  // "TrackSymptoms" field.
  bool? _trackSymptoms;
  bool get trackSymptoms => _trackSymptoms ?? false;
  bool hasTrackSymptoms() => _trackSymptoms != null;

  // "TracksMealsHydration" field.
  bool? _tracksMealsHydration;
  bool get tracksMealsHydration => _tracksMealsHydration ?? false;
  bool hasTracksMealsHydration() => _tracksMealsHydration != null;

  // "DateOfBirth" field.
  String? _dateOfBirth;
  String get dateOfBirth => _dateOfBirth ?? '';
  bool hasDateOfBirth() => _dateOfBirth != null;

  // "orgId" field (security phase 3 — the owning org; set at create from the
  // user's VERIFIED active group id, see org_service. Legacy/unclaimed docs
  // have no orgId; the getter falls back to '' so the read path never
  // crashes on pre-claim docs (design §5.1 Path B). Phase-4 rules derive
  // access from this field — every careRecipients doc must carry it).
  String? _orgId;
  String get orgId => _orgId ?? '';
  bool hasOrgId() => _orgId != null;

  void _initializeFields() {
    _name = snapshotData['Name'] as String?;
    _conditions = getDataList(snapshotData['Conditions']);
    _allergies = getDataList(snapshotData['Allergies']);
    _photo = snapshotData['Photo'] as String?;
    _createdAt = snapshotData['CreatedAt'] as DateTime?;
    _updatedAt = snapshotData['UpdatedAt'] as DateTime?;
    _mobilityNotes = snapshotData['MobilityNotes'] as String?;
    _initials = snapshotData['Initials'] as String?;
    _primaryCondition = snapshotData['PrimaryCondition'] as String?;
    _emergencyContactName = snapshotData['EmergencyContactName'] as String?;
    _emergencyContactPhone = snapshotData['EmergencyContactPhone'] as String?;
    _primaryCarePhysicianName =
        snapshotData['PrimaryCarePhysicianName'] as String?;
    _primaryCarePhysicianPhone =
        snapshotData['PrimaryCarePhysicianPhone'] as String?;
    _trackVitals = snapshotData['TrackVitals'] as bool?;
    _trackGlucose = snapshotData['TrackGlucose'] as bool?;
    _trackMedication = snapshotData['TrackMedication'] as bool?;
    _trackSymptoms = snapshotData['TrackSymptoms'] as bool?;
    _tracksMealsHydration = snapshotData['TracksMealsHydration'] as bool?;
    _dateOfBirth = snapshotData['DateOfBirth'] as String?;
    _orgId = snapshotData['orgId'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('careRecipients');

  static Stream<CareRecipientsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => CareRecipientsRecord.fromSnapshot(s));

  static Future<CareRecipientsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => CareRecipientsRecord.fromSnapshot(s));

  static CareRecipientsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      CareRecipientsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static CareRecipientsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      CareRecipientsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'CareRecipientsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is CareRecipientsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createCareRecipientsRecordData({
  String? name,
  String? photo,
  DateTime? createdAt,
  DateTime? updatedAt,
  String? mobilityNotes,
  String? initials,
  String? primaryCondition,
  String? emergencyContactName,
  String? emergencyContactPhone,
  String? primaryCarePhysicianName,
  String? primaryCarePhysicianPhone,
  bool? trackVitals,
  bool? trackGlucose,
  bool? trackMedication,
  bool? trackSymptoms,
  bool? tracksMealsHydration,
  String? dateOfBirth,
  String? orgId,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'Name': name,
      'Photo': photo,
      'CreatedAt': createdAt,
      'UpdatedAt': updatedAt,
      'MobilityNotes': mobilityNotes,
      'Initials': initials,
      'PrimaryCondition': primaryCondition,
      'EmergencyContactName': emergencyContactName,
      'EmergencyContactPhone': emergencyContactPhone,
      'PrimaryCarePhysicianName': primaryCarePhysicianName,
      'PrimaryCarePhysicianPhone': primaryCarePhysicianPhone,
      'TrackVitals': trackVitals,
      'TrackGlucose': trackGlucose,
      'TrackMedication': trackMedication,
      'TrackSymptoms': trackSymptoms,
      'TracksMealsHydration': tracksMealsHydration,
      'DateOfBirth': dateOfBirth,
      'orgId': orgId,
    }.withoutNulls,
  );

  return firestoreData;
}

class CareRecipientsRecordDocumentEquality
    implements Equality<CareRecipientsRecord> {
  const CareRecipientsRecordDocumentEquality();

  @override
  bool equals(CareRecipientsRecord? e1, CareRecipientsRecord? e2) {
    const listEquality = ListEquality();
    return e1?.name == e2?.name &&
        listEquality.equals(e1?.conditions, e2?.conditions) &&
        listEquality.equals(e1?.allergies, e2?.allergies) &&
        e1?.photo == e2?.photo &&
        e1?.createdAt == e2?.createdAt &&
        e1?.updatedAt == e2?.updatedAt &&
        e1?.mobilityNotes == e2?.mobilityNotes &&
        e1?.initials == e2?.initials &&
        e1?.primaryCondition == e2?.primaryCondition &&
        e1?.emergencyContactName == e2?.emergencyContactName &&
        e1?.emergencyContactPhone == e2?.emergencyContactPhone &&
        e1?.primaryCarePhysicianName == e2?.primaryCarePhysicianName &&
        e1?.primaryCarePhysicianPhone == e2?.primaryCarePhysicianPhone &&
        e1?.trackVitals == e2?.trackVitals &&
        e1?.trackGlucose == e2?.trackGlucose &&
        e1?.trackMedication == e2?.trackMedication &&
        e1?.trackSymptoms == e2?.trackSymptoms &&
        e1?.tracksMealsHydration == e2?.tracksMealsHydration &&
        e1?.dateOfBirth == e2?.dateOfBirth &&
        e1?.orgId == e2?.orgId;
  }

  @override
  int hash(CareRecipientsRecord? e) => const ListEquality().hash([
        e?.name,
        e?.conditions,
        e?.allergies,
        e?.photo,
        e?.createdAt,
        e?.updatedAt,
        e?.mobilityNotes,
        e?.initials,
        e?.primaryCondition,
        e?.emergencyContactName,
        e?.emergencyContactPhone,
        e?.primaryCarePhysicianName,
        e?.primaryCarePhysicianPhone,
        e?.trackVitals,
        e?.trackGlucose,
        e?.trackMedication,
        e?.trackSymptoms,
        e?.tracksMealsHydration,
        e?.dateOfBirth,
        e?.orgId
      ]);

  @override
  bool isValidKey(Object? o) => o is CareRecipientsRecord;
}
