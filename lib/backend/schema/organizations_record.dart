import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Firestore record for the `organizations` collection (security phase 2 —
/// the ownership/sharing unit, design §2.1).
///
/// An organization is either a Care Circle household (`kind: 'family'`,
/// auto-created at first sign-in, labeled "Household" in the UI) or a
/// Professional org (`kind: 'organization'`, created by the later
/// Professional onboarding flow). Per D8/§2.5 this record deliberately has
/// NO plan/billing/member-cap fields — entitlements live outside
/// authorization and never appear in the security model.
class OrganizationsRecord extends FirestoreRecord {
  OrganizationsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "name" field — display label ("Household" for auto-created family orgs).
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "kind" field — 'family' (Care Circle, default) | 'organization' (Professional).
  String? _kind;
  String get kind => _kind ?? 'family';
  bool hasKind() => _kind != null;

  // "createdBy" field — uid of the founding member.
  String? _createdBy;
  String get createdBy => _createdBy ?? '';
  bool hasCreatedBy() => _createdBy != null;

  // "createdAt" field — server timestamp.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  /// The organization id (document id, also the value stored in
  /// `users/{uid}.activeGroupId` and `careRecipients.orgId`).
  String get id => reference.id;

  void _initializeFields() {
    _name = snapshotData['name'] as String?;
    _kind = snapshotData['kind'] as String?;
    _createdBy = snapshotData['createdBy'] as String?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('organizations');

  static Stream<OrganizationsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => OrganizationsRecord.fromSnapshot(s));

  static Future<OrganizationsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => OrganizationsRecord.fromSnapshot(s));

  static OrganizationsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      OrganizationsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static OrganizationsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      OrganizationsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'OrganizationsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is OrganizationsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createOrganizationsRecordData({
  String? name,
  String? kind,
  String? createdBy,
  DateTime? createdAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'name': name,
      'kind': kind,
      'createdBy': createdBy,
      'createdAt': createdAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class OrganizationsRecordDocumentEquality
    implements Equality<OrganizationsRecord> {
  const OrganizationsRecordDocumentEquality();

  @override
  bool equals(OrganizationsRecord? e1, OrganizationsRecord? e2) {
    return e1?.name == e2?.name &&
        e1?.kind == e2?.kind &&
        e1?.createdBy == e2?.createdBy &&
        e1?.createdAt == e2?.createdAt;
  }

  @override
  int hash(OrganizationsRecord? e) =>
      const ListEquality().hash([e?.name, e?.kind, e?.createdBy, e?.createdAt]);

  @override
  bool isValidKey(Object? o) => o is OrganizationsRecord;
}
