// Organization / membership service (security phase 2).
//
// Implements the approved ownership model (design §2.1, §2.2, D1, D5, D8)
// entirely at the APP layer. Firestore rules stay open (allow-all) this
// phase by design — Phase 4 flips them into a pure lockdown, so every
// membership / role / context decision the app makes today is written to
// mirror the rule predicates that will enforce it later.
//
// Key invariants implemented here (each one will be a rules predicate in
// Phase 4):
//
//  * Membership is the unit of access. `organizations/{orgId}/members/{uid}`
//    exists with status 'active' <=> the user may access org data. Revocation
//    is a doc delete.
//  * activeGroupId is a REQUEST/CONTEXT SELECTOR ONLY (D1) — never
//    authorization by itself. Every org-scoped read/write in this service
//    FIRST verifies active membership in the referenced org (and Phase 4
//    rules will independently verify membership AND the per-doc condition).
//    `activeGroupId` never appears as a standalone allow condition.
//  * Roles: owner > admin > caregiver > viewer. Owner-only: transfer/delete
//    org. Owner/admin: invite, remove, promote/demote (admin cannot create
//    owners). Caregiver: full data access. Viewer: read-only.
//  * NO plan/billing/member-cap fields anywhere (D8) — entitlements live
//    outside authorization.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '/app_state.dart';
import '/backend/backend.dart';
import '/backend/schema/invites_record.dart';
import '/backend/schema/members_record.dart';
import '/backend/schema/organizations_record.dart';

/// Display label for the auto-created Care Circle org (D5: family-facing
/// label is "Care Circle"; the org doc name is "Household").
const String kFamilyOrgName = 'Household';
/// Auto-created org `kind` (D5): always 'family' for Care Circle.
const String kFamilyOrgKind = 'family';

/// Role constants (design §2.1 — 4 tiers).
const String kRoleOwner = 'owner';
const String kRoleAdmin = 'admin';
const String kRoleCaregiver = 'caregiver';
const String kRoleViewer = 'viewer';

/// Membership status constants (§2.1 — active members keyed by uid, pending
/// invites keyed by email with status 'invited').
const String kMemberStatusActive = 'active';
const String kMemberStatusInvited = 'invited';

/// migrationStatus values (design §5.1(c).5): 'claimed' = migrated legacy
/// doc, 'created' = new post-migration doc (the app writes this), 'unclaimed'
/// = legacy before claim. Read by the app only for UI hints; Phase-4 rules
/// ignore the field.
const String kMigrationStatusClaimed = 'claimed';
const String kMigrationStatusCreated = 'created';
const String kMigrationStatusUnclaimed = 'unclaimed';

/// Roles that may be assigned via invite (owner is never inviteable).
const Set<String> kInviteableRoles = {kRoleAdmin, kRoleCaregiver, kRoleViewer};

/// Thrown when the caller is not an active member of the org, or lacks the
/// role the action requires. App-layer denial mirroring the Phase-4 rules;
/// callers surface this as a permission-denied message.
class OrgAccessDeniedException implements Exception {
  OrgAccessDeniedException(this.message);
  final String message;
  @override
  String toString() => 'OrgAccessDeniedException: $message';
}

/// Thrown by the instrumented save path when a specific Firestore operation
/// fails, carrying the step label and the underlying cause so the UI can
/// surface EXACTLY which step was denied (with code + message) without needing
/// devtools. `toString()` renders `SaveStepException[<step>]: <code>: <message>`
/// when the cause is a `FirebaseException`, else `SaveStepException[<step>]: <cause>`.
class SaveStepException implements Exception {
  SaveStepException(this.step, this.cause);
  final String step;
  final Object cause;
  @override
  String toString() {
    if (cause is FirebaseException) {
      final e = cause as FirebaseException;
      return 'SaveStepException[$step]: ${e.code}: ${e.message}';
    }
    return 'SaveStepException[$step]: $cause';
  }
}

/// Deterministic org id for the auto-provisioned family org.
///
/// Deriving the id from the founder's uid is what makes provisioning
/// race-safe across concurrent first sign-ins (two devices): every writer
/// computes the SAME org id, so the "two orgs for one user" duplicate is
/// structurally impossible and all three writes converge on identical state.
String autoFamilyOrgId(String uid) => 'org_$uid';

String _normalizeEmail(String email) => email.trim().toLowerCase();

/// Returns `users/{uid}.activeGroupId` (null when the profile is missing or
/// has no group context yet).
Future<String?> getActiveGroupId(String uid) async {
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  return doc.data()?['activeGroupId'] as String?;
}

/// The ACTIVE membership of [uid] in [orgId], or null when they are not an
/// active member. This doc `exists()` check IS the membership check — it is
/// what every org-scoped access in this phase runs before showing/writing
/// org data (and what Phase-4 rules will run per request).
Future<MembersRecord?> getMembership(String orgId, String uid) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('organizations')
      .doc(orgId)
      .collection('members')
      .doc(uid)
      .get();
  if (!snapshot.exists) {
    return null;
  }
  final record = MembersRecord.fromSnapshot(snapshot);
  if (record.status != kMemberStatusActive) {
    return null;
  }
  return record;
}

/// True when [uid] is an active member of [orgId].
Future<bool> isActiveMember(String orgId, String uid) async =>
    (await getMembership(orgId, uid)) != null;

/// The org doc at [orgId], or null when it does not exist.
Future<OrganizationsRecord?> getOrganization(String orgId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('organizations')
      .doc(orgId)
      .get();
  if (!snapshot.exists) {
    return null;
  }
  return OrganizationsRecord.fromSnapshot(snapshot);
}

// ---------------------------------------------------------------------------
// Provisioning (D5 — auto-provision a family org on first sign-in)
// ---------------------------------------------------------------------------

/// Ensures the signed-in [user] has exactly one auto-provisioned family org
/// (created on first sign-in) and a valid `activeGroupId` on their profile.
/// Idempotent and race-safe; call on every sign-in from the auth-state
/// callback (Phase 1's `ensureUserProfile` seam).
///
/// Returns the orgId the user's active group resolves to.
///
/// Idempotency / race-safety design (why set-merge and NOT a transaction):
///
///  * The org id is DETERMINISTIC (`org_<uid>`), so two devices that race
///    the first sign-in compute the same path and their writes converge on
///    identical state — a duplicate org is structurally impossible.
///  * Each write is content-fixed and idempotent: re-running any step is a
///    no-op. A crash between steps self-heals on the next sign-in (org
///    exists but member missing -> the create path completes the missing
///    docs).
///  * Provisioning is purely DETERMINISTIC via the user's own org
///    (`org_<uid>`): restore or create that org and its founder membership,
///    then set `users/{uid}.activeGroupId`. There is deliberately NO
///    membership-enumeration query — a collection-group `members` query is
///    structurally denied by the Phase-4 read rules (rules cannot enumerate
///    memberships — §2.2), so step 2 settles to the user's own deterministic
///    org rather than querying for any other membership. Transfers into orgs
///    outside the user's own are handled by the separate invite-acceptance
///    path. Sequencing is also required by the Phase-4 rules: the org doc
///    is written BEFORE the founder member doc (two sequential writes, not
///    one batch), because rules evaluate batch writes against pre-batch
///    state and each create rule must see the sibling doc it depends on.
///  * `users/{uid}.activeGroupId` is set with set-merge so provisioning never
///    clobbers other profile fields (name/email/createdAt from Phase 1).
Future<String> ensureOrgMembership(User user) async {
  final uid = user.uid;
  if (uid.isEmpty) {
    throw OrgAccessDeniedException('Cannot provision for an empty uid.');
  }
  final db = FirebaseFirestore.instance;
  final usersDoc = db.collection('users').doc(uid);
  final orgs = db.collection('organizations');

  // 1. Fast path: the profile already carries a group context. Verify it is
  //    still backed by an active membership (a stale context after removal
  //    must not be trusted on its own — D1: context is never authorization).
  // E1: fast-path getActiveGroupId.
  try {
    print('SAVE-STEP E1 getActiveGroupId: uid=$uid');
    final activeGroupId = await getActiveGroupId(uid);
    print('SAVE-STEP E1 getActiveGroupId -> activeGroupId=$activeGroupId');
    if (activeGroupId != null && activeGroupId.isNotEmpty) {
      // E2: verify that group context is backed by an active membership.
      try {
        print('SAVE-STEP E2 isActiveMember: orgId=$activeGroupId uid=$uid');
        final ok = await isActiveMember(activeGroupId, uid);
        print('SAVE-STEP E2 isActiveMember -> $ok');
        if (ok) {
          print('SAVE-STEP E2 fast-path RETURN orgId=$activeGroupId');
          return activeGroupId;
        }
      } on FirebaseException catch (e) {
        print('SAVE-STEP E2 FAILED: ${e.code} — ${e.message}');
        throw SaveStepException('E2', e);
      }
    }
  } on FirebaseException catch (e) {
    print('SAVE-STEP E1 FAILED: ${e.code} — ${e.message}');
    throw SaveStepException('E1', e);
  }

  // 2. activeGroupId missing (or stale): restore from an existing membership.
  //    a. Our own deterministic family org (the common case).
  final ownOrgId = autoFamilyOrgId(uid);
  try {
    print('SAVE-STEP E2 isActiveMember: orgId=$ownOrgId uid=$uid');
    if (await isActiveMember(ownOrgId, uid)) {
      print('SAVE-STEP E2 isActiveMember -> true');
      // E6: users/{uid} set-merge (activeGroupId).
      print('SAVE-STEP E6 users set-merge activeGroupId=$ownOrgId');
      await usersDoc.set({'activeGroupId': ownOrgId}, SetOptions(merge: true));
      print('SAVE-STEP E6 users set-merge -> OK RETURN orgId=$ownOrgId');
      return ownOrgId;
    }
    print('SAVE-STEP E2 isActiveMember -> false');
  } on FirebaseException catch (e) {
    print('SAVE-STEP E2 FAILED: ${e.code} — ${e.message}');
    throw SaveStepException('E2', e);
  }

  // 3. No membership anywhere: this is a genuine first sign-in. Provision
  //    the family org. Never auto-create orgs for users who already belong
  //    to one — we only reach here when steps 1-2 found no membership.
  final orgId = ownOrgId;
  final orgRef = orgs.doc(orgId);

  try {
    // E4: org doc first (two sequential writes, not a batch — see above).
    print('SAVE-STEP E4 org create: orgId=$orgId');
    await orgRef.set({
      ...createOrganizationsRecordData(
        name: kFamilyOrgName,
        kind: kFamilyOrgKind,
        createdBy: uid,
      ),
      'createdAt': FieldValue.serverTimestamp(),
    });
    print('SAVE-STEP E4 org create -> OK');

    // E5: founder membership second (org doc visible to rules by now).
    print('SAVE-STEP E5 member create: orgId=$orgId uid=$uid');
    await orgRef.collection('members').doc(uid).set({
      ...createMembersRecordData(
        uid: uid,
        orgId: orgId,
        role: kRoleOwner,
        status: kMemberStatusActive,
        displayName: (user.displayName ?? '').trim().isNotEmpty
            ? user.displayName!.trim()
            : null,
        email: (user.email ?? '').trim().isNotEmpty
            ? user.email!.trim()
            : null,
      ),
      'joinedAt': FieldValue.serverTimestamp(),
    });
    print('SAVE-STEP E5 member create -> OK');

    // E6: set the group context (merge — never clobber the profile).
    print('SAVE-STEP E6 users set-merge activeGroupId=$orgId');
    await usersDoc.set({'activeGroupId': orgId}, SetOptions(merge: true));
    print('SAVE-STEP E6 users set-merge -> OK RETURN orgId=$orgId');
  } on FirebaseException catch (e) {
    print('SAVE-STEP E4/E5/E6 FAILED: ${e.code} — ${e.message}');
    throw SaveStepException('E4/E5/E6', e);
  }

  return orgId;
}

// ---------------------------------------------------------------------------
// Group context (D1 — activeGroupId is a context selector only)
// ---------------------------------------------------------------------------

/// Switches the user's active group context to [orgId].
///
/// Context is a selector, not a credential: the switch is REFUSED unless the
/// user is an active member of [orgId] (mirrors the Phase-4 write rule that
/// validates `activeGroupId` on write). A malicious client can therefore
/// only ever switch to an org they genuinely belong to — the worst they can
/// do is deny themselves data.
Future<bool> setActiveGroupId(String uid, String orgId) async {
  if (!await isActiveMember(orgId, uid)) {
    return false;
  }
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .set({'activeGroupId': orgId}, SetOptions(merge: true));
  FFAppState().activeGroupId = orgId;
  return true;
}

// ---------------------------------------------------------------------------
// Phase 3 — org-scoped careRecipients access (D1: context is a selector,
// rules verify; child data stays recipient-scoped, no orgId on child docs)
// ---------------------------------------------------------------------------

/// THE single shared careRecipients list stream for the app (phase 3).
///
/// Every careRecipients collection query must go through this helper (or add
/// the identical `where('orgId', isEqualTo: activeGroupId)` filter): an
/// unscoped read would mix other orgs' recipients into the UI today and is
/// denied outright under the Phase-4 rules.
///
/// The filter value is the CACHED activeGroupId (FFAppState). The cache is
/// only ever set after a VERIFIED membership check (`ensureOrgMembership` /
/// `setActiveGroupId` — D1), and the Phase-4 rules independently verify
/// membership AND the doc's orgId on every request, so relying on the cache
/// as the *selector* is safe. Returns an EMPTY stream (never a raw unscoped
/// query) when there is no group context — signed out, or a profile that
/// never resolved one.
Stream<List<CareRecipientsRecord>> careRecipientsForActiveGroup({
  Query Function(Query)? queryBuilder,
  int limit = -1,
}) {
  final orgId = FFAppState().activeGroupId;
  if (orgId == null || orgId.isEmpty) {
    return Stream.value(const []);
  }
  final stream = queryCareRecipientsRecord(
    queryBuilder: (q) {
      final scoped = q.where('orgId', isEqualTo: orgId);
      return queryBuilder == null ? scoped : queryBuilder(scoped);
    },
    limit: limit,
  );
  // Instrument the list/search read path so a rules-permission failure is
  // VISIBLE instead of a silent spin/empty state. Errors are logged with the
  // FirebaseException code+message (e.g. permission-denied) and re-emitted so
  // the consuming StreamBuilder's snapshot.hasError path can render them.
  return stream.transform(
    StreamTransformer<List<CareRecipientsRecord>,
        List<CareRecipientsRecord>>.fromHandlers(
      handleData: (data, sink) => sink.add(data),
      handleError: (error, stack, sink) {
        if (error is FirebaseException) {
          print('[careRecipientsForActiveGroup] Firestore error '
              'code=${error.code} message=${error.message}');
        } else {
          print('[careRecipientsForActiveGroup] error: $error');
        }
        sink.addError(error, stack);
      },
    ),
  );
}

/// Recipient-scoped symptomEntries stream for the SELECTED recipient.
///
/// Child data (symptomEntries, careNotes, mealEntries, carechecklist, ...)
/// stays recipient-scoped — NO orgId field on child docs; Phase-4 rules
/// derive access from the recipient's orgId. This fixes the dashboard's
/// cross-recipient-mix bug (audit part 3 item 7) AND the unscoped read that
/// Phase-4 rules would deny.
///
/// Returns an empty stream when no recipient is selected — the data layer
/// must never build `where('patientRef', isEqualTo: null)` (a null-selection
/// UI gate is an audit-fix workstream item).
Stream<List<SymptomEntriesRecord>> symptomEntriesForSelectedRecipient({
  Query Function(Query)? queryBuilder,
  int limit = -1,
}) =>
    symptomEntriesForRecipient(
      recipientRef: FFAppState().selectedCareRecipient,
      queryBuilder: queryBuilder,
      limit: limit,
    );

/// Recipient-scoped symptomEntries stream for an EXPLICIT recipient reference.
///
/// Same scoping contract as [symptomEntriesForSelectedRecipient] (child data
/// carries `patientRef`; Phase-4 rules derive access from the recipient's
/// orgId) but the caller decides which recipient, instead of the function
/// reading the app-wide selection. The dashboard's actions run on BOTH the
/// route-param path (a directory card tap pushes the page with the recipient)
/// and the nav-menu path (no param, the app-wide selection is the working
/// recipient), so it resolves the recipient once and passes it in — a stream
/// that silently reads a *stale or null* selection is how the section ends up
/// permanently empty.
///
/// A null reference streams an empty list: the data layer must never build
/// `where('patientRef', isEqualTo: null)`.
Stream<List<SymptomEntriesRecord>> symptomEntriesForRecipient({
  required DocumentReference? recipientRef,
  Query Function(Query)? queryBuilder,
  int limit = -1,
}) {
  if (recipientRef == null) {
    return Stream.value(const []);
  }
  return querySymptomEntriesRecord(
    queryBuilder: (q) {
      final scoped = q.where('patientRef', isEqualTo: recipientRef);
      return queryBuilder == null ? scoped : queryBuilder(scoped);
    },
    limit: limit,
  );
}

/// Creates a careRecipients doc in [user]'s VERIFIED active group (phase 3).
///
/// The orgId is resolved from `users/{uid}.activeGroupId` — read FRESH, never
/// the in-memory cache alone for a WRITE — and the caller's active membership
/// in that org is verified BEFORE the write (the app-layer mirror of the
/// Phase-4 create rule). An unverified create is refused with a clean
/// [OrgAccessDeniedException] so the UI can show a real message instead of a
/// silent failure (which is what an unscoped create would be once rules
/// flip).
///
/// Active-group resolution (the Care Profile save blocker, P1):
///
/// The active group context is written by the auth-state listener on sign-in
/// (`attachAuthStateListener` -> `_onSignedIn` -> `ensureOrgMembership`), but
/// that provisioning is FIRE-AND-FORGET (`unawaited`) and error-SWALLOWED, so
/// a signed-in user can reach this save with `users/{uid}.activeGroupId` not
/// yet (or, after a failed provisioning step, not at all) persisted. Reading
/// it alone would then throw the old "No active care circle yet".
///
/// To fix this, when the fresh `users/{uid}.activeGroupId` is missing we
/// resolve it through [ensureOrgMembership] — the canonical, idempotent,
/// race-safe resolver that (a) restores the user's EXISTING org/membership if
/// one already exists (it never creates a duplicate org; the org id is
/// deterministic `org_<uid>`), (b) verifies active membership, and (c)
/// persists the restored context back to `users/{uid}.activeGroupId` for
/// subsequent reads. This does NOT delete, reset, or recreate any existing
/// careRecipient — it only ever writes THIS one new doc. It also does not
/// weaken authorization: it runs the exact same membership-verifying path the
/// Phase-4 rules encode server-side.
///
/// [data] is the caller's `createCareRecipientsRecordData(...)` map WITHOUT
/// orgId; this function adds orgId after verification so no future caller can
/// forget it. Returns the created document reference.
Future<DocumentReference<Map<String, dynamic>>> createCareRecipientForActiveGroup({
  required User user,
  required Map<String, dynamic> data,
}) async {
  final uid = user.uid;
  if (uid.isEmpty) {
    throw OrgAccessDeniedException('Sign in to save a care recipient.');
  }
  // Resolve the active group, falling back to ensureOrgMembership (which both
  // verifies membership AND persists `users/{uid}.activeGroupId`) whenever the
  // profile is missing its group context.
  final String orgId;
  try {
    // S1: getActiveGroupId (fresh read of users/{uid}.activeGroupId).
    print('SAVE-STEP S1 getActiveGroupId: uid=$uid');
    final existing = await getActiveGroupId(uid);
    print('SAVE-STEP S1 getActiveGroupId -> activeGroupId=$existing');
    if (existing != null && existing.isNotEmpty) {
      orgId = existing;
    } else {
      // S2: ensureOrgMembership (restore an existing org/membership, or
      // provision a new family org on genuine first sign-in).
      print('SAVE-STEP S2 ensureOrgMembership: uid=$uid (activeGroupId missing)');
      orgId = await ensureOrgMembership(user);
      print('SAVE-STEP S2 ensureOrgMembership -> orgId=$orgId');
    }
  } on FirebaseException catch (e) {
    print('SAVE-STEP S1/S2 FAILED: ${e.code} — ${e.message}');
    throw SaveStepException('S1/S2', e);
  }
  try {
    // S3: isActiveMember — verify active membership in [orgId] BEFORE write.
    print('SAVE-STEP S3 isActiveMember: orgId=$orgId uid=$uid');
    final active = await isActiveMember(orgId, uid);
    print('SAVE-STEP S3 isActiveMember -> $active');
    if (!active) {
      throw OrgAccessDeniedException(
          'Your membership in this care circle could not be verified, so the '
          'profile was not saved.');
    }
  } on FirebaseException catch (e) {
    print('SAVE-STEP S3 FAILED: ${e.code} — ${e.message}');
    throw SaveStepException('S3', e);
  }
  try {
    // S4: careRecipients doc create. Go through FirebaseFirestore directly
    // (NOT the record's raw-typed `collection` getter) so the reference is
    // DocumentReference<Map<String, dynamic>> and matches the declared type.
    final ref = FirebaseFirestore.instance.collection('careRecipients').doc();
    print('SAVE-STEP S4 careRecipients.create: orgId=$orgId docId=${ref.id}');
    await ref.set({
      ...data,
      'orgId': orgId,
      // §5.1(c).5: the app writes 'created' on every NEW doc (rules ignore it;
      // read by the app only for UI hints). Legacy docs get 'claimed' from the
      // one-time claim script (scripts/claim_legacy_data.dart).
      'migrationStatus': kMigrationStatusCreated,
    });
    print('SAVE-STEP S4 careRecipients.create -> OK docId=${ref.id}');
    return ref;
  } on FirebaseException catch (e) {
    print('SAVE-STEP S4 FAILED: ${e.code} — ${e.message}');
    throw SaveStepException('S4', e);
  }
}

// ---------------------------------------------------------------------------
// Org-scoped data loading (every load re-verifies membership — D1)
// ---------------------------------------------------------------------------

/// Loads the active org's data for [uid]: resolves `users/{uid}.activeGroupId`
/// and returns the org + its members + pending invites.
///
/// Deny-by-default at the app layer: returns null when the user has no group
/// context OR is not an active member of it (stale context after removal) —
/// the caller shows a permission-denied / empty state. Phase 4 rules enforce
/// the same checks server-side.
class OrgSnapshot {
  OrgSnapshot({
    required this.org,
    required this.activeMembers,
    required this.pendingInvites,
  });

  final OrganizationsRecord org;
  final List<MembersRecord> activeMembers;
  final List<InviteRecord> pendingInvites;

  List<String> get memberUids => activeMembers.map((m) => m.uid).toList();
}

Future<OrgSnapshot?> loadOrgSnapshot(String uid) async {
  final activeGroupId = await getActiveGroupId(uid);
  if (activeGroupId == null || activeGroupId.isEmpty) {
    return null;
  }
  // Context-only rule: the membership check below is what actually authorizes
  // the load. activeGroupId merely selects WHICH org to load.
  if (!await isActiveMember(activeGroupId, uid)) {
    return null;
  }
  final org = await getOrganization(activeGroupId);
  if (org == null) {
    return null;
  }
  final membersSnapshot = await FirebaseFirestore.instance
      .collection('organizations')
      .doc(activeGroupId)
      .collection('members')
      .get();
  final activeMembers = <MembersRecord>[];
  final pendingInvites = <InviteRecord>[];
  for (final doc in membersSnapshot.docs) {
    final data = doc.data();
    if (data['status'] == kMemberStatusInvited) {
      pendingInvites.add(InviteRecord.fromSnapshot(doc));
    } else {
      activeMembers.add(MembersRecord.fromSnapshot(doc));
    }
  }
  return OrgSnapshot(org: org, activeMembers: activeMembers, pendingInvites: pendingInvites);
}

// ---------------------------------------------------------------------------
// Member management (owner/admin — app-layer role gating)
// ---------------------------------------------------------------------------

/// Creates a pending invite for [email] with [role] in [orgId].
/// Caller must be an active owner/admin of [orgId] (admin cannot invite as
/// owner — owner is not inviteable at all). Idempotent: writing the invite
/// doc keyed by the lowercase email re-invites with the new role.
Future<void> createInvite({
  required String orgId,
  required String email,
  required String role,
  required String invitedByUid,
  String? invitedByName,
}) async {
  final caller = await getMembership(orgId, invitedByUid);
  if (caller == null ||
      (caller.role != kRoleOwner && caller.role != kRoleAdmin)) {
    throw OrgAccessDeniedException('Only owners and admins can invite members.');
  }
  if (!kInviteableRoles.contains(role)) {
    throw OrgAccessDeniedException('Role "$role" cannot be granted by invite.');
  }
  final normalized = _normalizeEmail(email);
  if (normalized.isEmpty) {
    throw OrgAccessDeniedException('A valid email is required to invite.');
  }
  await FirebaseFirestore.instance
      .collection('organizations')
      .doc(orgId)
      .collection('members')
      .doc(normalized)
      .set({
    ...createInviteRecordData(
      invitedEmail: normalized,
      email: normalized,
      role: role,
      invitedBy: invitedByUid,
      invitedByName: invitedByName,
      orgId: orgId,
      status: kMemberStatusInvited,
    ),
    'createdAt': FieldValue.serverTimestamp(),
  });
}

/// Revokes a pending invite (owner/admin only). No-op when the invite does
/// not exist (idempotent — matches a double-tap on the revoke button).
Future<void> revokeInvite({
  required String orgId,
  required String email,
  required String actingUid,
}) async {
  final caller = await getMembership(orgId, actingUid);
  if (caller == null ||
      (caller.role != kRoleOwner && caller.role != kRoleAdmin)) {
    throw OrgAccessDeniedException('Only owners and admins can revoke invites.');
  }
  await FirebaseFirestore.instance
      .collection('organizations')
      .doc(orgId)
      .collection('members')
      .doc(_normalizeEmail(email))
      .delete();
}

/// Accepts a pending invite on behalf of [user] (the invitee).
///
/// The invitee's auth email must match the invite email (lowercased) — the
/// app-layer mirror of the Phase-4 rule. Accepting atomically creates the
/// uid-keyed active member doc with the INVITED role and deletes the
/// email-keyed invite (one batch, per §2.1: both writes read only
/// pre-existing docs, which is what keeps the batch valid under rules).
/// Returns false when no matching pending invite exists.
Future<bool> acceptInvite({
  required String orgId,
  required String inviteEmail,
  required User user,
}) async {
  final normalized = _normalizeEmail(inviteEmail);
  final inviteRef = FirebaseFirestore.instance
      .collection('organizations')
      .doc(orgId)
      .collection('members')
      .doc(normalized);
  final inviteDoc = await inviteRef.get();
  if (!inviteDoc.exists ||
      inviteDoc.data()?['status'] != kMemberStatusInvited) {
    return false;
  }
  final myEmail = _normalizeEmail(user.email ?? '');
  if (myEmail != normalized) {
    throw OrgAccessDeniedException(
        'This invite is addressed to $normalized, not ${user.email}.');
  }
  final invite = InviteRecord.fromSnapshot(inviteDoc);
  final batch = FirebaseFirestore.instance.batch();
  batch.set(
    FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .doc(user.uid),
    {
      ...createMembersRecordData(
        uid: user.uid,
        orgId: orgId,
        role: invite.role,
        status: kMemberStatusActive,
        displayName: (user.displayName ?? '').trim().isNotEmpty
            ? user.displayName!.trim()
            : null,
        email: (user.email ?? '').trim().isNotEmpty ? user.email!.trim() : null,
        invitedBy: invite.invitedBy,
      ),
      'joinedAt': FieldValue.serverTimestamp(),
    },
  );
  batch.delete(inviteRef);
  await batch.commit();
  return true;
}

/// Accepts every pending invite addressed to [user]'s auth email (the
/// "by email match on sign-in" accept flow). Safe to call on every sign-in:
/// returns the number of invites accepted. Per-invite errors are swallowed
/// so one bad invite never blocks the session.
Future<int> acceptInvitesForUser(User user) async {
  final myEmail = _normalizeEmail(user.email ?? '');
  if (myEmail.isEmpty) {
    return 0;
  }
  final snapshot = await FirebaseFirestore.instance
      .collectionGroup('members')
      .where('invitedEmail', isEqualTo: myEmail)
      .where('status', isEqualTo: kMemberStatusInvited)
      .get();
  var accepted = 0;
  for (final doc in snapshot.docs) {
    final memberPath = doc.reference.path;
    final orgId = memberPath.split('/')[1];
    try {
      if (await acceptInvite(orgId: orgId, inviteEmail: myEmail, user: user)) {
        accepted++;
      }
    } catch (_) {
      // Never fail the session because of an invite accept failure.
    }
  }
  return accepted;
}

/// Removes [targetUid] from [orgId] (owner/admin only).
///
/// An owner cannot be removed this way — transfer ownership first (guards
/// the "at least one owner" invariant at the app layer; §6.3 item 2 notes
/// rules cannot enforce it).
Future<void> removeMember({
  required String orgId,
  required String actingUid,
  required String targetUid,
}) async {
  final caller = await getMembership(orgId, actingUid);
  if (caller == null ||
      (caller.role != kRoleOwner && caller.role != kRoleAdmin)) {
    throw OrgAccessDeniedException('Only owners and admins can remove members.');
  }
  if (targetUid == actingUid) {
    throw OrgAccessDeniedException('Remove yourself via a transfer, or delete the org.');
  }
  final target = await getMembership(orgId, targetUid);
  if (target == null) {
    return; // already gone — idempotent
  }
  if (target.role == kRoleOwner) {
    throw OrgAccessDeniedException(
        'The owner cannot be removed — transfer ownership first.');
  }
  await FirebaseFirestore.instance
      .collection('organizations')
      .doc(orgId)
      .collection('members')
      .doc(targetUid)
      .delete();
}

/// Promotes/demotes [targetUid] to [newRole] (owner/admin only; admin cannot
/// create owners; demoting the last owner is refused).
Future<void> setMemberRole({
  required String orgId,
  required String actingUid,
  required String targetUid,
  required String newRole,
}) async {
  const validRoles = {kRoleOwner, kRoleAdmin, kRoleCaregiver, kRoleViewer};
  if (!validRoles.contains(newRole)) {
    throw OrgAccessDeniedException('Unknown role "$newRole".');
  }
  final caller = await getMembership(orgId, actingUid);
  if (caller == null ||
      (caller.role != kRoleOwner && caller.role != kRoleAdmin)) {
    throw OrgAccessDeniedException('Only owners and admins can change roles.');
  }
  if (newRole == kRoleOwner && caller.role != kRoleOwner) {
    throw OrgAccessDeniedException('Admins cannot grant the owner role.');
  }
  final target = await getMembership(orgId, targetUid);
  if (target == null) {
    return; // idempotent
  }
  if (target.role == kRoleOwner && newRole != kRoleOwner) {
    // Last-owner guard (app-layer best effort; §6.3 item 2).
    final owners = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .where('role', isEqualTo: kRoleOwner)
        .get();
    if (owners.docs.length <= 1) {
      throw OrgAccessDeniedException(
          'Cannot demote the last owner — transfer ownership first.');
    }
  }
  await FirebaseFirestore.instance
      .collection('organizations')
      .doc(orgId)
      .collection('members')
      .doc(targetUid)
      .set({'role': newRole}, SetOptions(merge: true));
}

/// Transfers ownership of [orgId] from the acting owner to [newOwnerUid]
/// (owner-only). The acting owner becomes an admin — a transfer, not a
/// co-owner grant. Model-level flow; the UI gates it behind the owner role.
Future<void> transferOwnership({
  required String orgId,
  required String actingUid,
  required String newOwnerUid,
}) async {
  final caller = await getMembership(orgId, actingUid);
  if (caller == null || caller.role != kRoleOwner) {
    throw OrgAccessDeniedException('Only the owner can transfer ownership.');
  }
  if (newOwnerUid == actingUid) {
    return; // no-op
  }
  final newOwner = await getMembership(orgId, newOwnerUid);
  if (newOwner == null) {
    throw OrgAccessDeniedException('The new owner must be an active member.');
  }
  final batch = FirebaseFirestore.instance.batch();
  final members = FirebaseFirestore.instance
      .collection('organizations')
      .doc(orgId)
      .collection('members');
  batch.set(members.doc(newOwnerUid), {'role': kRoleOwner},
      SetOptions(merge: true));
  batch.set(members.doc(actingUid), {'role': kRoleAdmin},
      SetOptions(merge: true));
  await batch.commit();
}

/// Deletes [orgId] and all of its member/invite docs (owner-only).
///
/// Firestore does not cascade subcollection deletes, so members are removed
/// first, then the org doc. Model-level flow; the UI requires confirmation.
Future<void> deleteOrg({
  required String orgId,
  required String actingUid,
}) async {
  final caller = await getMembership(orgId, actingUid);
  if (caller == null || caller.role != kRoleOwner) {
    throw OrgAccessDeniedException('Only the owner can delete the org.');
  }
  final members = await FirebaseFirestore.instance
      .collection('organizations')
      .doc(orgId)
      .collection('members')
      .get();
  final batch = FirebaseFirestore.instance.batch();
  for (final doc in members.docs) {
    batch.delete(doc.reference);
  }
  batch.delete(FirebaseFirestore.instance
      .collection('organizations')
      .doc(orgId));
  await batch.commit();
}
