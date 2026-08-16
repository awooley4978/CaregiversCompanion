import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class EmerencyinfoRecord extends FirestoreRecord {
  EmerencyinfoRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "careRecipientRef" field.
  DocumentReference? _careRecipientRef;
  DocumentReference? get careRecipientRef => _careRecipientRef;
  bool hasCareRecipientRef() => _careRecipientRef != null;

  // "primaryContactName" field.
  String? _primaryContactName;
  String get primaryContactName => _primaryContactName ?? '';
  bool hasPrimaryContactName() => _primaryContactName != null;

  // "primaryDoctorName" field.
  String? _primaryDoctorName;
  String get primaryDoctorName => _primaryDoctorName ?? '';
  bool hasPrimaryDoctorName() => _primaryDoctorName != null;

  // "primaryDoctorPhone" field.
  String? _primaryDoctorPhone;
  String get primaryDoctorPhone => _primaryDoctorPhone ?? '';
  bool hasPrimaryDoctorPhone() => _primaryDoctorPhone != null;

  // "pharmacyName" field.
  String? _pharmacyName;
  String get pharmacyName => _pharmacyName ?? '';
  bool hasPharmacyName() => _pharmacyName != null;

  // "pharmacyPhone" field.
  String? _pharmacyPhone;
  String get pharmacyPhone => _pharmacyPhone ?? '';
  bool hasPharmacyPhone() => _pharmacyPhone != null;

  // "preferredHospital" field.
  String? _preferredHospital;
  String get preferredHospital => _preferredHospital ?? '';
  bool hasPreferredHospital() => _preferredHospital != null;

  // "advanceDirectives" field.
  String? _advanceDirectives;
  String get advanceDirectives => _advanceDirectives ?? '';
  bool hasAdvanceDirectives() => _advanceDirectives != null;

  void _initializeFields() {
    _careRecipientRef = snapshotData['careRecipientRef'] as DocumentReference?;
    _primaryContactName = snapshotData['primaryContactName'] as String?;
    _primaryDoctorName = snapshotData['primaryDoctorName'] as String?;
    _primaryDoctorPhone = snapshotData['primaryDoctorPhone'] as String?;
    _pharmacyName = snapshotData['pharmacyName'] as String?;
    _pharmacyPhone = snapshotData['pharmacyPhone'] as String?;
    _preferredHospital = snapshotData['preferredHospital'] as String?;
    _advanceDirectives = snapshotData['advanceDirectives'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('emerencyinfo');

  static Stream<EmerencyinfoRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => EmerencyinfoRecord.fromSnapshot(s));

  static Future<EmerencyinfoRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => EmerencyinfoRecord.fromSnapshot(s));

  static EmerencyinfoRecord fromSnapshot(DocumentSnapshot snapshot) =>
      EmerencyinfoRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static EmerencyinfoRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      EmerencyinfoRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'EmerencyinfoRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is EmerencyinfoRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createEmerencyinfoRecordData({
  DocumentReference? careRecipientRef,
  String? primaryContactName,
  String? primaryDoctorName,
  String? primaryDoctorPhone,
  String? pharmacyName,
  String? pharmacyPhone,
  String? preferredHospital,
  String? advanceDirectives,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'careRecipientRef': careRecipientRef,
      'primaryContactName': primaryContactName,
      'primaryDoctorName': primaryDoctorName,
      'primaryDoctorPhone': primaryDoctorPhone,
      'pharmacyName': pharmacyName,
      'pharmacyPhone': pharmacyPhone,
      'preferredHospital': preferredHospital,
      'advanceDirectives': advanceDirectives,
    }.withoutNulls,
  );

  return firestoreData;
}

class EmerencyinfoRecordDocumentEquality
    implements Equality<EmerencyinfoRecord> {
  const EmerencyinfoRecordDocumentEquality();

  @override
  bool equals(EmerencyinfoRecord? e1, EmerencyinfoRecord? e2) {
    return e1?.careRecipientRef == e2?.careRecipientRef &&
        e1?.primaryContactName == e2?.primaryContactName &&
        e1?.primaryDoctorName == e2?.primaryDoctorName &&
        e1?.primaryDoctorPhone == e2?.primaryDoctorPhone &&
        e1?.pharmacyName == e2?.pharmacyName &&
        e1?.pharmacyPhone == e2?.pharmacyPhone &&
        e1?.preferredHospital == e2?.preferredHospital &&
        e1?.advanceDirectives == e2?.advanceDirectives;
  }

  @override
  int hash(EmerencyinfoRecord? e) => const ListEquality().hash([
        e?.careRecipientRef,
        e?.primaryContactName,
        e?.primaryDoctorName,
        e?.primaryDoctorPhone,
        e?.pharmacyName,
        e?.pharmacyPhone,
        e?.preferredHospital,
        e?.advanceDirectives
      ]);

  @override
  bool isValidKey(Object? o) => o is EmerencyinfoRecord;
}
