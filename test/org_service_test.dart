// Security phase 2 — organization ownership service tests.
//
// Covers the four required scenarios plus the role/context edge cases the
// design calls out (D1 context-only, D5 provisioning idempotency):
//
//  (a) first sign-in auto-provisions org + owner member + activeGroupId
//  (b) re-sign-in does not duplicate (and restores a missing activeGroupId)
//  (c) invite → accept creates a member with the invited role
//  (d) role gating: viewer cannot run admin actions; non-member cannot load
//      org data; activeGroupId cannot be set to an org the user is not in
//
// All tests run against the in-memory Firestore fake in
// firebase_test_setup.dart — no network, no emulator, no real backend.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/backend/auth/auth_service.dart';
import 'package:new_project/backend/org/org_service.dart';

import 'firebase_test_setup.dart';

Future<User> signIn(String uid, {String? email, String? displayName}) async {
  fakeAuthPlatform.emitSignedIn(
      uid: uid, email: email, displayName: displayName);
  return FirebaseAuth.instance.currentUser!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initFirebaseForTest();
  });

  setUp(() {
    fakeFirestore.clear();
  });

  Map<String, dynamic>? docData(String path) => fakeFirestore.dataAt(path);

  int orgCount() => fakeFirestore.docs.keys
      .where((p) => RegExp(r'^organizations/[^/]+$').hasMatch(p))
      .length;

  group('auto-provisioning (D5)', () {
    test('first sign-in creates the family org, owner member, activeGroupId',
        () async {
      final user = await signIn('u1',
          email: 'founder@example.com', displayName: 'Founder');

      // Mirrors the real sign-in flow: the auth-state listener provisions the
      // profile (phase 1) before org membership (phase 2).
      await ensureUserProfile(user);

      final orgId = await ensureOrgMembership(user);

      expect(orgId, 'org_u1');
      // Org doc: name 'Household', kind 'family', createdBy, server timestamp.
      final org = docData('organizations/org_u1');
      expect(org, isNotNull);
      expect(org!['name'], 'Household');
      expect(org['kind'], 'family');
      expect(org['createdBy'], 'u1');
      expect(org['createdAt'], isA<DateTime>());
      // Owner membership (uid-keyed, status active, role owner).
      final member = docData('organizations/org_u1/members/u1');
      expect(member, isNotNull);
      expect(member!['role'], 'owner');
      expect(member['status'], 'active');
      expect(member['uid'], 'u1');
      expect(member['displayName'], 'Founder');
      expect(member['email'], 'founder@example.com');
      expect(member['joinedAt'], isA<DateTime>());
      // Profile context set (merge — other profile fields untouched).
      final profile = docData('users/u1');
      expect(profile!['activeGroupId'], 'org_u1');
      expect(profile['uid'], 'u1');
      expect(orgCount(), 1);
      // App-layer view of the role.
      final membership = await getMembership('org_u1', 'u1');
      expect(membership, isNotNull);
      expect(membership!.role, 'owner');
    });

    test('re-sign-in does not duplicate the org', () async {
      final user = await signIn('u1', email: 'founder@example.com');
      await ensureOrgMembership(user);

      // Second sign-in (e.g. fresh app launch, session restore).
      final again = await signIn('u1', email: 'founder@example.com');
      final orgId = await ensureOrgMembership(again);

      expect(orgId, 'org_u1');
      expect(orgCount(), 1);
      expect(docData('organizations/org_u1/members/u1'), isNotNull);
      expect(docData('users/u1')!['activeGroupId'], 'org_u1');
    });

    test('restores activeGroupId when the profile lost it but membership '
        'exists', () async {
      final user = await signIn('u1', email: 'founder@example.com');
      await ensureOrgMembership(user);

      // Simulate the profile's context field being missing/stale (a previous
      // crash between steps, or manual cleanup): membership still exists.
      fakeFirestore.docs['users/u1'] = {'uid': 'u1', 'email': 'founder@example.com'};

      final orgId = await ensureOrgMembership(await signIn('u1',
          email: 'founder@example.com'));

      expect(orgId, 'org_u1');
      expect(docData('users/u1')!['activeGroupId'], 'org_u1');
      expect(orgCount(), 1);
    });

    test('still provisions the deterministic own org even when already a '
        'member of another org (no membership enumeration)', () async {
      // Seed: user u9 was already added to someone else's org (e.g. accepted
      // an invite) but has no activeGroupId.
      final owner = await signIn('u8', email: 'owner8@example.com');
      await ensureOrgMembership(owner);
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc('org_u8')
          .collection('members')
          .doc('u9')
          .set({
        'uid': 'u9',
        'orgId': 'org_u8',
        'role': 'caregiver',
        'status': 'active',
        'email': 'invitee9@example.com',
      });

      final orgId =
          await ensureOrgMembership(await signIn('u9', email: 'invitee9@example.com'));

      // Provisioning is purely deterministic via org_<uid>: the Phase-4 rules
      // deny membership-enumeration queries, so ensureOrgMembership does NOT
      // discover the external org_u8 membership. It creates u9's own org and
      // sets activeGroupId to it. The external membership is preserved as-is
      // and is reconciled separately by the invite-acceptance path.
      expect(orgId, 'org_u9');
      expect(orgCount(), 2); // org_u8 (seeded) + org_u9 (provisioned here).
      expect(docData('users/u9')!['activeGroupId'], 'org_u9');
      // Existing external membership is untouched.
      expect(docData('organizations/org_u8/members/u9'), isNotNull);
    });

    test('self-heals a partially provisioned org (member write lost)', () async {
      final user = await signIn('u1', email: 'founder@example.com');
      // Crash between org write and member write.
      fakeFirestore.docs['organizations/org_u1'] = {
        'name': 'Household',
        'kind': 'family',
        'createdBy': 'u1',
        'createdAt': DateTime.now(),
      };

      final orgId = await ensureOrgMembership(user);

      expect(orgId, 'org_u1');
      expect(docData('organizations/org_u1/members/u1'), isNotNull);
      expect(docData('users/u1')!['activeGroupId'], 'org_u1');
      expect(orgCount(), 1);
    });
  });

  group('invites (owner/admin)', () {
    test('invite → accept creates a member with the invited role', () async {
      final owner = await signIn('u1',
          email: 'founder@example.com', displayName: 'Founder');
      final orgId = await ensureOrgMembership(owner);

      await createInvite(
        orgId: orgId,
        email: 'Carol@Example.com', // case/space normalization exercised
        role: 'viewer',
        invitedByUid: 'u1',
        invitedByName: 'Founder',
      );

      // Invite doc keyed by the LOWERCASE email, status invited.
      final invite = docData('organizations/org_u1/members/carol@example.com');
      expect(invite, isNotNull);
      expect(invite!['invitedEmail'], 'carol@example.com');
      expect(invite['role'], 'viewer');
      expect(invite['status'], 'invited');
      expect(invite['invitedBy'], 'u1');
      expect(invite['orgId'], 'org_u1');

      // Invitee signs in for the first time: provisioning creates their own
      // org; the email-match accept flow adds them to the inviting org.
      final carol = await signIn('u2', email: 'carol@example.com');
      await ensureOrgMembership(carol);
      final accepted = await acceptInvitesForUser(carol);

      expect(accepted, 1);
      final member =
          docData('organizations/org_u1/members/u2');
      expect(member, isNotNull);
      expect(member!['role'], 'viewer'); // invited role, not default
      expect(member['status'], 'active');
      expect(member['uid'], 'u2');
      expect(member['invitedBy'], 'u1');
      // The email-keyed invite doc is gone (accept = set + delete batch).
      expect(docData('organizations/org_u1/members/carol@example.com'), isNull);
      // And carol still has her own org (invites are additive).
      expect(docData('organizations/org_u2/members/u2'), isNotNull);
    });

    test('accept is refused when the auth email does not match the invite',
        () async {
      final owner = await signIn('u1', email: 'founder@example.com');
      final orgId = await ensureOrgMembership(owner);
      await createInvite(
          orgId: orgId,
          email: 'carol@example.com',
          role: 'caregiver',
          invitedByUid: 'u1');

      final intruder = await signIn('u3', email: 'mallory@example.com');
      await expectLater(
        acceptInvite(
            orgId: orgId, inviteEmail: 'carol@example.com', user: intruder),
        throwsA(isA<OrgAccessDeniedException>()),
      );
      // Invite still pending; no member doc created.
      expect(docData('organizations/org_u1/members/u3'), isNull);
      expect(docData('organizations/org_u1/members/carol@example.com'),
          isNotNull);
    });

    test('only owner/admin can invite; admin cannot invite as owner',
        () async {
      final owner = await signIn('u1', email: 'founder@example.com');
      final orgId = await ensureOrgMembership(owner);
      final members = FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .collection('members');
      // Seed u2 (admin) and u4 (viewer) as members of org_u1.
      await members.doc('u2').set({
        'uid': 'u2',
        'orgId': orgId,
        'role': 'caregiver',
        'status': 'active',
        'email': 'admin@example.com',
      });
      await members.doc('u4').set({
        'uid': 'u4',
        'orgId': orgId,
        'role': 'viewer',
        'status': 'active',
        'email': 'viewer@example.com',
      });
      await setMemberRole(
          orgId: orgId, actingUid: 'u1', targetUid: 'u2', newRole: 'admin');

      // Admin can invite with a non-owner role.
      await createInvite(
          orgId: orgId,
          email: 'a@example.com',
          role: 'caregiver',
          invitedByUid: 'u2');
      expect(docData('organizations/org_u1/members/a@example.com'), isNotNull);
      // Admin cannot invite with the owner role.
      await expectLater(
        createInvite(
            orgId: orgId,
            email: 'b@example.com',
            role: 'owner',
            invitedByUid: 'u2'),
        throwsA(isA<OrgAccessDeniedException>()),
      );
      // A viewer cannot invite at all.
      await expectLater(
        createInvite(
            orgId: orgId,
            email: 'c@example.com',
            role: 'viewer',
            invitedByUid: 'u4'),
        throwsA(isA<OrgAccessDeniedException>()),
      );
    });
  });

  group('role gating (app-layer; rules land in phase 4)', () {
    test('viewer cannot remove members or change roles', () async {
      final owner = await signIn('u1', email: 'founder@example.com');
      final orgId = await ensureOrgMembership(owner);
      // Members: u2 (caregiver), u4 (viewer).
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .collection('members')
          .doc('u2')
          .set({'uid': 'u2', 'role': 'caregiver', 'status': 'active'});
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .collection('members')
          .doc('u4')
          .set({'uid': 'u4', 'role': 'viewer', 'status': 'active'});

      await expectLater(
        removeMember(orgId: orgId, actingUid: 'u4', targetUid: 'u2'),
        throwsA(isA<OrgAccessDeniedException>()),
      );
      await expectLater(
        setMemberRole(
            orgId: orgId,
            actingUid: 'u4',
            targetUid: 'u2',
            newRole: 'admin'),
        throwsA(isA<OrgAccessDeniedException>()),
      );
      expect(docData('organizations/org_u1/members/u2')!['role'], 'caregiver');
    });

    test('non-member cannot load org data even with a matching '
        'activeGroupId', () async {
      final owner = await signIn('u1', email: 'founder@example.com');
      final orgId = await ensureOrgMembership(owner);

      // u3 is NOT a member but their profile claims the org as context.
      fakeFirestore.docs['users/u3'] = {
        'uid': 'u3',
        'activeGroupId': orgId,
      };

      final snapshot = await loadOrgSnapshot('u3');
      expect(snapshot, isNull); // denied — context alone never authorizes
      expect(await getMembership(orgId, 'u3'), isNull);
    });

    test('activeGroupId cannot be set to an org the user is not in (D1)',
        () async {
      final owner = await signIn('u1', email: 'founder@example.com');
      final orgId = await ensureOrgMembership(owner);

      final switched =
          await setActiveGroupId('u1', 'someone-elses-org');
      expect(switched, isFalse);
      expect(docData('users/u1')!['activeGroupId'], orgId);
    });

    test('active member can load org data; viewer sees no admin actions '
        'available through the service', () async {
      final owner = await signIn('u1', email: 'founder@example.com');
      final orgId = await ensureOrgMembership(owner);
      // Seed u4 as a viewer member of org_u1 with the org as their context.
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .collection('members')
          .doc('u4')
          .set({'uid': 'u4', 'role': 'viewer', 'status': 'active'});
      fakeFirestore.docs['users/u4'] = {'uid': 'u4', 'activeGroupId': orgId};

      final viewerSnapshot = await loadOrgSnapshot('u4');
      expect(viewerSnapshot, isNotNull);
      expect(viewerSnapshot!.org.name, 'Household');
      expect(viewerSnapshot.activeMembers.map((m) => m.uid),
          containsAll(['u1', 'u4']));
      // The service-level gate: viewer role cannot perform admin actions
      // (the UI additionally hides the buttons).
      await expectLater(
        createInvite(
            orgId: orgId,
            email: 'x@example.com',
            role: 'viewer',
            invitedByUid: 'u4'),
        throwsA(isA<OrgAccessDeniedException>()),
      );
    });
  });

  group('owner model flows (minimal, UI-gated)', () {
    test('transferOwnership makes the target owner and the acting owner admin',
        () async {
      final owner = await signIn('u1', email: 'founder@example.com');
      final orgId = await ensureOrgMembership(owner);
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .collection('members')
          .doc('u2')
          .set({'uid': 'u2', 'role': 'caregiver', 'status': 'active'});

      await transferOwnership(
          orgId: orgId, actingUid: 'u1', newOwnerUid: 'u2');

      expect(docData('organizations/org_u1/members/u2')!['role'], 'owner');
      expect(docData('organizations/org_u1/members/u1')!['role'], 'admin');
    });

    test('non-owner cannot transfer or delete the org', () async {
      final owner = await signIn('u1', email: 'founder@example.com');
      final orgId = await ensureOrgMembership(owner);
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .collection('members')
          .doc('u2')
          .set({'uid': 'u2', 'role': 'caregiver', 'status': 'active'});

      await expectLater(
        transferOwnership(orgId: orgId, actingUid: 'u2', newOwnerUid: 'u1'),
        throwsA(isA<OrgAccessDeniedException>()),
      );
      await expectLater(
        deleteOrg(orgId: orgId, actingUid: 'u2'),
        throwsA(isA<OrgAccessDeniedException>()),
      );
      expect(docData('organizations/org_u1'), isNotNull);
    });

    test('the last owner cannot be demoted or removed', () async {
      final owner = await signIn('u1', email: 'founder@example.com');
      final orgId = await ensureOrgMembership(owner);

      await expectLater(
        setMemberRole(
            orgId: orgId,
            actingUid: 'u1',
            targetUid: 'u1',
            newRole: 'caregiver'),
        throwsA(isA<OrgAccessDeniedException>()),
      );
      await expectLater(
        removeMember(orgId: orgId, actingUid: 'u1', targetUid: 'u1'),
        throwsA(isA<OrgAccessDeniedException>()),
      );
    });

    test('deleteOrg removes the org and all member/invite docs', () async {
      final owner = await signIn('u1', email: 'founder@example.com');
      final orgId = await ensureOrgMembership(owner);
      await createInvite(
          orgId: orgId,
          email: 'carol@example.com',
          role: 'viewer',
          invitedByUid: 'u1');

      await deleteOrg(orgId: orgId, actingUid: 'u1');

      expect(docData('organizations/org_u1'), isNull);
      expect(docData('organizations/org_u1/members/u1'), isNull);
      expect(docData('organizations/org_u1/members/carol@example.com'), isNull);
    });

    test('removeMember deletes the member doc (revocation)', () async {
      final owner = await signIn('u1', email: 'founder@example.com');
      final orgId = await ensureOrgMembership(owner);
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .collection('members')
          .doc('u2')
          .set({'uid': 'u2', 'role': 'caregiver', 'status': 'active'});

      await removeMember(orgId: orgId, actingUid: 'u1', targetUid: 'u2');

      expect(docData('organizations/org_u1/members/u2'), isNull);
      expect(await getMembership(orgId, 'u2'), isNull);
    });
  });
}
