import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Firestore record for ACTIVE membership documents in the
/// `organizations/{orgId}/members` subcollection (security phase 2, §2.1).
///
/// Active members are keyed by uid and exist only while active — revocation
/// is a single doc delete, so `exists()` *is* the active-membership check
/// (this is what keeps the Phase-4 rules read budget at <=3 reads).
/// Pending invites live in the SAME subcollection keyed by the lowercase
/// invitee email — see [InviteRecord].
///
/// Roles (per-member `role` field): owner / admin / caregiver / viewer.
class MembersRecord extends FirestoreRecord {
  MembersRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "uid" field — the member's auth uid (also the document id).
  String? _uid;
  String get uid => _uid ?? '';
  bool hasUid() => _uid != null;

  // "orgId" field — the parent organization id.
  String? _orgId;
  String get orgId => _orgId ?? '';
  bool hasOrgId() => _orgId != null;

  // "role" field — 'owner' | 'admin' | 'caregiver' | 'viewer'.
  String? _role;
  String get role => _role ?? 'viewer';
  bool hasRole() => _role != null;

  // "status" field — 'active' for members, 'invited' for invites.
  String? _status;
  String get status => _status ?? 'active';
  bool hasStatus() => _status != null;

  // "displayName" field — optional caregiver display name.
  String? _displayName;
  String get displayName => _displayName ?? '';
  bool hasDisplayName() => _displayName != null;

  // "email" field — optional member email.
  String? _email;
  String get email => _email ?? '';
  bool hasEmail() => _email != null;

  // "joinedAt" field — server timestamp of when the membership became active.
  DateTime? _joinedAt;
  DateTime? get joinedAt => _joinedAt;
  bool hasJoinedAt() => _joinedAt != null;

  // "invitedBy" field — uid of the member who invited this member (optional).
  String? _invitedBy;
  String get invitedBy => _invitedBy ?? '';
  bool hasInvitedBy() => _invitedBy != null;

  void _initializeFields() {
    _uid = snapshotData['uid'] as String?;
    _orgId = snapshotData['orgId'] as String?;
    _role = snapshotData['role'] as String?;
    _status = snapshotData['status'] as String?;
    _displayName = snapshotData['displayName'] as String?;
    _email = snapshotData['email'] as String?;
    _joinedAt = snapshotData['joinedAt'] as DateTime?;
    _invitedBy = snapshotData['invitedBy'] as String?;
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('members')
          : FirebaseFirestore.instance.collectionGroup('members');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('members').doc(id);

  static Stream<MembersRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => MembersRecord.fromSnapshot(s));

  static Future<MembersRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => MembersRecord.fromSnapshot(s));

  static MembersRecord fromSnapshot(DocumentSnapshot snapshot) =>
      MembersRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static MembersRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      MembersRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'MembersRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is MembersRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createMembersRecordData({
  String? uid,
  String? orgId,
  String? role,
  String? status,
  String? displayName,
  String? email,
  DateTime? joinedAt,
  String? invitedBy,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'uid': uid,
      'orgId': orgId,
      'role': role,
      'status': status,
      'displayName': displayName,
      'email': email,
      'joinedAt': joinedAt,
      'invitedBy': invitedBy,
    }.withoutNulls,
  );

  return firestoreData;
}

class MembersRecordDocumentEquality implements Equality<MembersRecord> {
  const MembersRecordDocumentEquality();

  @override
  bool equals(MembersRecord? e1, MembersRecord? e2) {
    return e1?.uid == e2?.uid &&
        e1?.orgId == e2?.orgId &&
        e1?.role == e2?.role &&
        e1?.status == e2?.status &&
        e1?.displayName == e2?.displayName &&
        e1?.email == e2?.email &&
        e1?.joinedAt == e2?.joinedAt &&
        e1?.invitedBy == e2?.invitedBy;
  }

  @override
  int hash(MembersRecord? e) => const ListEquality().hash([
        e?.uid,
        e?.orgId,
        e?.role,
        e?.status,
        e?.displayName,
        e?.email,
        e?.joinedAt,
        e?.invitedBy
      ]);

  @override
  bool isValidKey(Object? o) => o is MembersRecord;
}
