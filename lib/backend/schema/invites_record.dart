import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Firestore record for PENDING INVITE documents (security phase 2, §2.1).
///
/// Pending invites live in the `organizations/{orgId}/members` subcollection,
/// keyed by the LOWERCASE invitee email, with `status: 'invited'` — they are
/// status docs in the same subcollection as active members, not a separate
/// collection. Accepting an invite atomically creates the uid-keyed active
/// member doc and deletes the email-keyed invite (one batch), per §2.1.
class InviteRecord extends FirestoreRecord {
  InviteRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "invitedEmail" field — the invitee email, normalized to lowercase.
  String? _invitedEmail;
  String get invitedEmail => _invitedEmail ?? '';
  bool hasInvitedEmail() => _invitedEmail != null;

  // "email" field — alias of invitedEmail (kept for query ergonomics).
  String? _email;
  String get email => _email ?? '';
  bool hasEmail() => _email != null;

  // "role" field — the role the invitee will receive on accept
  // (admin | caregiver | viewer — owner is never inviteable).
  String? _role;
  String get role => _role ?? 'viewer';
  bool hasRole() => _role != null;

  // "invitedBy" field — uid of the member who created the invite.
  String? _invitedBy;
  String get invitedBy => _invitedBy ?? '';
  bool hasInvitedBy() => _invitedBy != null;

  // "invitedByName" field — display name of the inviter (optional).
  String? _invitedByName;
  String get invitedByName => _invitedByName ?? '';
  bool hasInvitedByName() => _invitedByName != null;

  // "orgId" field — the organization the invite grants membership to.
  String? _orgId;
  String get orgId => _orgId ?? '';
  bool hasOrgId() => _orgId != null;

  // "status" field — 'invited' until accepted (acceptance deletes the doc).
  String? _status;
  String get status => _status ?? 'invited';
  bool hasStatus() => _status != null;

  // "createdAt" field — server timestamp of the invite.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  void _initializeFields() {
    _invitedEmail = snapshotData['invitedEmail'] as String?;
    _email = snapshotData['email'] as String?;
    _role = snapshotData['role'] as String?;
    _invitedBy = snapshotData['invitedBy'] as String?;
    _invitedByName = snapshotData['invitedByName'] as String?;
    _orgId = snapshotData['orgId'] as String?;
    _status = snapshotData['status'] as String?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('members')
          : FirebaseFirestore.instance.collectionGroup('members');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('members').doc(id);

  static Stream<InviteRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => InviteRecord.fromSnapshot(s));

  static Future<InviteRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => InviteRecord.fromSnapshot(s));

  static InviteRecord fromSnapshot(DocumentSnapshot snapshot) =>
      InviteRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static InviteRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      InviteRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'InviteRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is InviteRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createInviteRecordData({
  String? invitedEmail,
  String? email,
  String? role,
  String? invitedBy,
  String? invitedByName,
  String? orgId,
  String? status,
  DateTime? createdAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'invitedEmail': invitedEmail,
      'email': email,
      'role': role,
      'invitedBy': invitedBy,
      'invitedByName': invitedByName,
      'orgId': orgId,
      'status': status,
      'createdAt': createdAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class InviteRecordDocumentEquality implements Equality<InviteRecord> {
  const InviteRecordDocumentEquality();

  @override
  bool equals(InviteRecord? e1, InviteRecord? e2) {
    return e1?.invitedEmail == e2?.invitedEmail &&
        e1?.email == e2?.email &&
        e1?.role == e2?.role &&
        e1?.invitedBy == e2?.invitedBy &&
        e1?.invitedByName == e2?.invitedByName &&
        e1?.orgId == e2?.orgId &&
        e1?.status == e2?.status &&
        e1?.createdAt == e2?.createdAt;
  }

  @override
  int hash(InviteRecord? e) => const ListEquality().hash([
        e?.invitedEmail,
        e?.email,
        e?.role,
        e?.invitedBy,
        e?.invitedByName,
        e?.orgId,
        e?.status,
        e?.createdAt
      ]);

  @override
  bool isValidKey(Object? o) => o is InviteRecord;
}
