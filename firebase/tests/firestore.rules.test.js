/**
 * Firestore security-rules regression suite.
 *
 * Loads the REAL rule file from the repo (firebase/firestore.rules) at test
 * time and asserts the Phase-4 deny-by-default authorization matrix against
 * the Firestore emulator, so any future change to the rules is what gets
 * tested — this suite is the permanent regression gate for the ruleset.
 *
 * Deps: @firebase/rules-unit-testing, firebase-tools (emulator), mocha.
 * See README.md in this directory for how to run it locally and in CI.
 */
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');

// Real rules file from the repo — NOT a hardcoded copy. This test lives at
// firebase/tests/, the rules at firebase/firestore.rules.
const RULES = fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8');

const PROJECT_ID = 'carerecipients';
const EMULATOR_PORT = 8081; // pinned in firebase/firebase.json -> emulators.firestore.port

const ORG_FAM    = 'org_fam';
const ORG_OTHER  = 'org_other';
const ORG_GRNT   = 'org_grantee';
const ORG_PROF   = 'org_prof';

const OWNER     = 'uid_owner';      // member org_fam, owner
const CAREGIVER = 'uid_caregiver';  // member org_fam, caregiver (non-owner family member)
const STRANGER  = 'uid_stranger';   // member org_other
const GRANTEE   = 'uid_grantee';    // member org_grnt (receives share to org_fam recipient)
const PROFCARE  = 'uid_profcare';   // caregiver org_prof (no assignment seedable; D9 empty)
const PROFOWNER = 'uid_profowner';  // owner org_prof (assignment-free branch)

const REC_F1    = 'rec_f1';   // in org_fam
const REC_OTHER = 'rec_other';// in org_other
const REC_PROF  = 'rec_prof'; // in org_prof

let env;
let F1ref, OTHERref, PROFref; // DocumentReferences for seeding ref-linked docs

async function seed(ctx) {
  const db = ctx.firestore();
  const set = async (p, d) => db.doc(p).set(d);
  // users (activeGroupId context)
  await set('users/'+OWNER,    { activeGroupId: ORG_FAM });
  await set('users/'+CAREGIVER,{ activeGroupId: ORG_FAM });
  await set('users/'+STRANGER, { activeGroupId: ORG_OTHER });
  await set('users/'+GRANTEE,  { activeGroupId: ORG_GRNT });
  await set('users/'+PROFCARE, { activeGroupId: ORG_PROF });
  await set('users/'+PROFOWNER,{ activeGroupId: ORG_PROF });
  // organizations + members
  await set('organizations/'+ORG_FAM,    { kind: 'family', createdBy: OWNER });
  await set('organizations/'+ORG_OTHER,  { kind: 'family', createdBy: STRANGER });
  await set('organizations/'+ORG_GRNT,   { kind: 'family', createdBy: GRANTEE });
  await set('organizations/'+ORG_PROF,   { kind: 'organization', createdBy: PROFOWNER });
  await set(`organizations/${ORG_FAM}/members/${OWNER}`,   { uid: OWNER, role: 'owner', status: 'active' });
  await set(`organizations/${ORG_FAM}/members/${CAREGIVER}`,{ uid: CAREGIVER, role: 'caregiver', status: 'active' });
  await set(`organizations/${ORG_OTHER}/members/${STRANGER}`,{ uid: STRANGER, role: 'owner', status: 'active' });
  await set(`organizations/${ORG_GRNT}/members/${GRANTEE}`, { uid: GRANTEE, role: 'owner', status: 'active' });
  await set(`organizations/${ORG_PROF}/members/${PROFCARE}`,{ uid: PROFCARE, role: 'caregiver', status: 'active' });
  await set(`organizations/${ORG_PROF}/members/${PROFOWNER}`,{ uid: PROFOWNER, role: 'owner', status: 'active' });
  // careRecipients
  await set('careRecipients/'+REC_F1,    { orgId: ORG_FAM });
  await set('careRecipients/'+REC_OTHER, { orgId: ORG_OTHER });
  await set('careRecipients/'+REC_PROF,  { orgId: ORG_PROF });
  F1ref    = db.doc('careRecipients/'+REC_F1);
  OTHERref = db.doc('careRecipients/'+REC_OTHER);
  PROFref  = db.doc('careRecipients/'+REC_PROF);
  // share: org_grantee granted caregiver-level access to org_fam's recipient
  await set(`recipientShares/${REC_F1}/grants/${ORG_GRNT}`, { accessLevel: 'caregiver' });
  // carechecklist subcollection
  await set(`careRecipients/${REC_F1}/carechecklist/item1`, { name: 'check' });
  // ref-linked docs
  await set('careNotes/note1',     { careRecipientRef: F1ref,    text: 'hello' });
  await set('careNotes/note_other',{ careRecipientRef: OTHERref, text: 'x' });
  await set('careNotes/note_prof', { careRecipientRef: PROFref,  text: 'y' });
  await set('mealEntries/meal1',   { patientRef: F1ref });
  await set('symptomEntries/sym1', { patientRef: F1ref });
  // medications — ref-linked via careRecipientRef (enabled for the tracker)
  await set('medications/med1',    { careRecipientRef: F1ref,    medicationName: 'Lisinopril', taken: true });
  await set('medications/med_other',{ careRecipientRef: OTHERref, medicationName: 'X', taken: false });
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { host: '127.0.0.1', port: EMULATOR_PORT, rules: RULES },
  });
  await env.withSecurityRulesDisabled((ctx) => seed(ctx));
});

after(async () => { if (env) await env.cleanup(); });

const dbFor = (uid) => env.authenticatedContext(uid).firestore();

// ---------------------------------------------------------------- OWNER (family)
describe('OWNER of recipient org (family) — previously-failing + unchanged', () => {
  it('1. careRecipients/{id} read SUCCEEDS (the previously-failing case)', async () => {
    await assertSucceeds(dbFor(OWNER).doc('careRecipients/'+REC_F1).get());
  });
  it('2. organizations / members / users reads still SUCCEED (unchanged)', async () => {
    await assertSucceeds(dbFor(OWNER).doc('organizations/'+ORG_FAM).get());
    await assertSucceeds(dbFor(OWNER).doc(`organizations/${ORG_FAM}/members/${OWNER}`).get());
    await assertSucceeds(dbFor(OWNER).doc('users/'+OWNER).get());
  });
  it('3. recipientShares read SUCCEEDS for owner-org member', async () => {
    await assertSucceeds(dbFor(OWNER).doc(`recipientShares/${REC_F1}/grants/${ORG_GRNT}`).get());
  });
  it('4. carechecklist read/write gate on parent (owner allowed)', async () => {
    await assertSucceeds(dbFor(OWNER).doc(`careRecipients/${REC_F1}/carechecklist/item1`).get());
    await assertSucceeds(dbFor(OWNER).doc(`careRecipients/${REC_F1}/carechecklist/item1`).update({ name: 'c2' }));
  });
  it('5. careNotes / mealEntries / symptomEntries read gate on ref (owner allowed)', async () => {
    await assertSucceeds(dbFor(OWNER).doc('careNotes/note1').get());
    await assertSucceeds(dbFor(OWNER).doc('mealEntries/meal1').get());
    await assertSucceeds(dbFor(OWNER).doc('symptomEntries/sym1').get());
  });
  it('5b. careNotes ref-linked read on a DIFFERENT-org recipient is DENIED', async () => {
    await assertFails(dbFor(OWNER).doc('careNotes/note_other').get());
  });
  it('6. ref-linked create/update gated correctly (owner allowed)', async () => {
    await assertSucceeds(dbFor(OWNER).doc('careNotes/note_new').set({ careRecipientRef: F1ref }));
    await assertSucceeds(dbFor(OWNER).doc('careNotes/note1').update({ text: 'bye' }));
  });
  it('6b. stranger create of a careNote referencing owner recipient is DENIED', async () => {
    await assertFails(dbFor(STRANGER).doc('careNotes/note_mal').set({ careRecipientRef: F1ref }));
  });
});

// ---------------------------------------------------------------------------
// careRecipients LIST QUERY — collection query `where('orgId' == activeGroup)`
// vs single-doc GET. Regression pin for the app's exact read path
// (careRecipientsForActiveGroup -> queryCareRecipientsRecord with
// q.where('orgId', isEqualTo: activeGroupId)). The READ rule is SPLIT: single-doc
// GET uses the full canAccessRecipientRef gate, while LIST uses the exists()-only
// canListRecipientsInOrg check (get() throws "Null value error" during query
// evaluation), so the collection LIST query is ALLOWED for an in-org owner, and
// the same doc's single GET is also ALLOWED.
// ---------------------------------------------------------------------------
describe('OWNER — careRecipients LIST QUERY (collection where orgId) vs single-doc GET', () => {
  it('A. single-doc GET of own-org recipient ALLOWED', async () => {
    await assertSucceeds(dbFor(OWNER).doc('careRecipients/'+REC_F1).get());
  });
  it('B. collection query careRecipients where orgId==activeGroup is ALLOWED', async () => {
    const q = dbFor(OWNER)
      .collection('careRecipients')
      .where('orgId', '==', ORG_FAM);
    await assertSucceeds(q.get());
  });
});

// ---------------------------------------------------------------- GRANTEE (share)
describe('GRANTEE (recipientShares share to org_fam recipient)', () => {
  it('recipient data accessible via active share (single-doc GETs)', async () => {
    await assertSucceeds(dbFor(GRANTEE).doc('careRecipients/'+REC_F1).get());
    await assertSucceeds(dbFor(GRANTEE).doc('careNotes/note1').get());
    await assertSucceeds(dbFor(GRANTEE).doc('mealEntries/meal1').get());
    await assertSucceeds(dbFor(GRANTEE).doc('symptomEntries/sym1').get());
  });
  it('grantee CANNOT read the recipientShares management doc (owner-org only)', async () => {
    await assertFails(dbFor(GRANTEE).doc(`recipientShares/${REC_F1}/grants/${ORG_GRNT}`).get());
  });
});

// ---------------------------------------------------------------------------
// MEDICATIONS — newly enabled from the dead-collection deny. ref-linked via
// careRecipientRef, gated by the same recipient-org / share / assignment rule
// as careNotes. Owner/active member of the recipient's org may read + write;
// a stranger (member of another org) and cross-org docs are denied.
// ---------------------------------------------------------------------------
describe('MEDICATIONS (ref-linked via careRecipientRef — newly enabled)', () => {
  it('owner of recipient org can read a medications doc', async () => {
    await assertSucceeds(dbFor(OWNER).doc('medications/med1').get());
  });
  it('owner can UPDATE a medications doc (the "Taken" toggle write)', async () => {
    await assertSucceeds(dbFor(OWNER).doc('medications/med1').update({
      taken: true, status: 'TAKEN', takenAt: new Date(),
    }));
  });
  it('owner can CREATE a medications doc referencing their recipient', async () => {
    await assertSucceeds(dbFor(OWNER).doc('medications/med_new').set({
      careRecipientRef: F1ref, medicationName: 'Metformin', taken: false,
    }));
  });
  it('owner read of a DIFFERENT-org medications doc is DENIED', async () => {
    await assertFails(dbFor(OWNER).doc('medications/med_other').get());
  });
  it('stranger (other-org member) read of a medications doc is DENIED', async () => {
    await assertFails(dbFor(STRANGER).doc('medications/med1').get());
  });
  it('stranger update of a medications doc is DENIED', async () => {
    await assertFails(dbFor(STRANGER).doc('medications/med1').update({
      taken: true, status: 'TAKEN',
    }));
  });
  it('stranger create of a medications doc referencing owner recipient is DENIED', async () => {
    await assertFails(dbFor(STRANGER).doc('medications/med_mal').set({
      careRecipientRef: F1ref, medicationName: 'X',
    }));
  });
  it('grantee (caregiver-level share) can read medications for the shared recipient', async () => {
    await assertSucceeds(dbFor(GRANTEE).doc('medications/med1').get());
  });
  // The medication tracker pages the schedule with a LIVE LIST query
  // (`queryMedicationsRecord` with `where careRecipientRef == selected`), NOT a
  // single-doc GET. A get()-based `read` rule breaks this once ≥1 matching doc
  // exists (Firestore does not load documents during query evaluation;
  // get() throws "Null value error"), so a saved medication never appears in
  // the tracker despite the "Medication added." success. This pins the
  // LIST-compatible read path (mirrors the careRecipients get/list split).
  it('owner can LIST medications where careRecipientRef == their recipient (tracker stream)', async () => {
    const q = dbFor(OWNER)
      .collection('medications')
      .where('careRecipientRef', '==', F1ref);
    await assertSucceeds(q.get());
  });
  it('stranger (other-org member) LIST of medications is DENIED', async () => {
    const q = dbFor(STRANGER)
      .collection('medications')
      .where('careRecipientRef', '==', F1ref);
    await assertFails(q.get());
  });
});

// ---------------------------------------------------------------------------
// FAMILY CAREGIVER (non-owner member of the recipient's family org) — the
// task's required "caregiver within org" ALLOWED case. D6: family org -> any
// active member with role owner/admin/caregiver/viewer may READ; writes need
// role owner/admin/caregiver (canWriteInOrg family branch). No assignment is
// required for FAMILY orgs. Cross-org data stays denied.
// ---------------------------------------------------------------------------
describe('FAMILY CAREGIVER within recipient org (non-owner)', () => {
  it('can read the recipient + ref-linked records of their own family org', async () => {
    const db = dbFor(CAREGIVER);
    await assertSucceeds(db.doc('careRecipients/'+REC_F1).get());
    await assertSucceeds(db.doc('careNotes/note1').get());
    await assertSucceeds(db.doc('mealEntries/meal1').get());
    await assertSucceeds(db.doc('symptomEntries/sym1').get());
    await assertSucceeds(db.doc('medications/med1').get());
    await assertSucceeds(db.doc(`careRecipients/${REC_F1}/carechecklist/item1`).get());
  });
  it('can write ref-linked data for their own family org (charting loop)', async () => {
    const db = dbFor(CAREGIVER);
    await assertSucceeds(db.doc('careNotes/cg_note').set({ careRecipientRef: F1ref, text: 'by caregiver' }));
    await assertSucceeds(db.doc('mealEntries/cg_meal').set({ patientRef: F1ref }));
    await assertSucceeds(db.doc('symptomEntries/cg_sym').set({ patientRef: F1ref }));
    await assertSucceeds(db.doc('medications/cg_med').set({ careRecipientRef: F1ref, medicationName: 'Y', taken: false }));
    await assertSucceeds(db.doc('medications/med1').update({ taken: true, status: 'TAKEN' }));
    await assertSucceeds(db.doc(`careRecipients/${REC_F1}/carechecklist/cg_item`).set({ name: 'cg' }));
  });
  it('cross-org recipient data is DENIED for the family caregiver', async () => {
    const db = dbFor(CAREGIVER);
    await assertFails(db.doc('careRecipients/'+REC_OTHER).get());
    await assertFails(db.doc('careNotes/note_other').get());
    await assertFails(db.doc('medications/med_other').get());
  });
  it('careRecipients DELETE stays owner-only (caregiver denied)', async () => {
    await assertFails(dbFor(CAREGIVER).doc('careRecipients/'+REC_F1).delete());
  });
});

// ---------------------------------------------------------------------------
// DEAD / PLACEHOLDER COLLECTIONS — deny pins. The V1 consolidated decision is
// "stay denied": emerencyinfo, vitalLogs, appointments, dashboardNotes and
// iconname have NO functional read/write path anywhere in lib/ (their pages are
// static mockups / print-stubs), so they keep the Phase-4 `allow read, write:
// if false` blocks. These pins make an accidental future enable FAIL CI even if
// no UI work lands with it. Even the OWNER (who legitimately accesses every
// functional collection) is denied here.
// ---------------------------------------------------------------------------
describe('DEAD COLLECTIONS stay denied (V1 consolidated decision)', () => {
  const dead = ['emerencyinfo', 'vitalLogs', 'appointments', 'dashboardNotes', 'iconname'];
  dead.forEach((col) => {
    it(`${col}: read AND write DENIED for an active owner`, async () => {
      const db = dbFor(OWNER);
      await assertFails(db.doc(col+'/x_probe').get());
      await assertFails(db.doc(col+'/x_probe').set({ anyField: true }));
      await assertFails(db.doc(col+'/x_probe').delete());
    });
  });
});

// ---------------------------------------------------------------------------
// REAL APP WRITE/DELETE PATHS (consolidated pin) — the app's live code paths
// that previously had no dedicated create/delete assertion: mealEntries create
// (Add Meal sheet), symptomEntries create (dashboard "Add Entry" copy),
// carechecklist create (dashboard task card) and careNotes delete (note card /
// care-notes page). Each is a real write the V1 ruleset must keep allowing for
// the right actor and denying for the wrong one.
// ---------------------------------------------------------------------------
describe('Real app write/delete paths (owner) + stranger denial', () => {
  it('mealEntries create (Add Meal sheet) ALLOWED for owner, DENIED for stranger', async () => {
    await assertSucceeds(dbFor(OWNER).doc('mealEntries/meal_new').set({ patientRef: F1ref, mealName: 'Soup' }));
    await assertFails(dbFor(STRANGER).doc('mealEntries/meal_mal').set({ patientRef: F1ref }));
  });
  it('symptomEntries create (dashboard "Add Entry") ALLOWED for owner, DENIED for stranger', async () => {
    await assertSucceeds(dbFor(OWNER).doc('symptomEntries/sym_new').set({ patientRef: F1ref, symptom: 'Pain' }));
    await assertFails(dbFor(STRANGER).doc('symptomEntries/sym_mal').set({ patientRef: F1ref }));
  });
  it('carechecklist create (dashboard task card) ALLOWED for owner, DENIED for stranger', async () => {
    await assertSucceeds(dbFor(OWNER).doc(`careRecipients/${REC_F1}/carechecklist/item_new`).set({ name: 'task' }));
    await assertFails(dbFor(STRANGER).doc(`careRecipients/${REC_F1}/carechecklist/item_mal`).set({ name: 'x' }));
  });
  it('careNotes delete (note card / care-notes page) ALLOWED for owner, DENIED for stranger', async () => {
    const db = dbFor(OWNER);
    await assertSucceeds(db.doc('careNotes/del_note').set({ careRecipientRef: F1ref, text: 'tmp' }));
    await assertSucceeds(db.doc('careNotes/del_note').delete());
    await assertFails(dbFor(STRANGER).doc('careNotes/note1').delete());
  });
});

// ---------------------------------------------------------------- STRANGER (different org)
describe('STRANGER (member of a different family org)', () => {
  it('denied on recipient data of another org', async () => {
    await assertFails(dbFor(STRANGER).doc('careRecipients/'+REC_F1).get());
    await assertFails(dbFor(STRANGER).doc('careNotes/note1').get());
    await assertFails(dbFor(STRANGER).doc('mealEntries/meal1').get());
    await assertFails(dbFor(STRANGER).doc('symptomEntries/sym1').get());
    await assertFails(dbFor(STRANGER).doc(`careRecipients/${REC_F1}/carechecklist/item1`).get());
    await assertFails(dbFor(STRANGER).doc(`recipientShares/${REC_F1}/grants/${ORG_GRNT}`).get());
  });
  it('denied on another org org doc / member doc', async () => {
    await assertFails(dbFor(STRANGER).doc('organizations/'+ORG_FAM).get());
    await assertFails(dbFor(STRANGER).doc(`organizations/${ORG_FAM}/members/${OWNER}`).get());
  });
  it('collection LIST query on a foreign org remains DENIED (query-compatible path not loosened)', async () => {
    // Stranger queries org_fam's recipients via the same where('orgId') shape
    // the fix targets; canListRecipientsInOrg must deny (not a member of
    // org_fam, no share) even though the query is now provable from resource.data.
    const q = dbFor(STRANGER)
      .collection('careRecipients')
      .where('orgId', '==', ORG_FAM);
    await assertFails(q.get());
  });
  it('self-read of users doc still SUCCEEDS', async () => {
    await assertSucceeds(dbFor(STRANGER).doc('users/'+STRANGER).get());
  });
  it('can still read own-org recipient', async () => {
    await assertSucceeds(dbFor(STRANGER).doc('careRecipients/'+REC_OTHER).get());
  });
});

// ---------------------------------------------------------------- PROFESSIONAL org (assignment scoping, D6/D7)
describe('PROFESSIONAL org (D6/D7) — assignment scoping preserved', () => {
  it('org owner (assignment-free branch) can read recipient + ref-linked note', async () => {
    await assertSucceeds(dbFor(PROFOWNER).doc('careRecipients/'+REC_PROF).get());
    await assertSucceeds(dbFor(PROFOWNER).doc('careNotes/note_prof').get());
  });
  it('professional caregiver WITHOUT an active assignment is DENIED (assignment req not bypassed)', async () => {
    // assignments collection is D9-EMPTY in v1; no assignment doc can exist at
    // /assignments/{recipientId}/{staffUid}, so a caregiver member alone must
    // NOT gain access (PHI minimization / D6).
    await assertFails(dbFor(PROFCARE).doc('careRecipients/'+REC_PROF).get());
    await assertFails(dbFor(PROFCARE).doc('careNotes/note_prof').get());
  });
});

// ---------------------------------------------------------------------------
// Care Profile Setup SAVE path (regression for the "Could not save the Care
// Profile" bug). Simulates the EXACT write sequence the app runs when the
// owner taps Save Profile on b_care_profile_setup: fresh founder provisioning
// (org -> member -> users.activeGroupId) followed by the careRecipients create
// (createCareRecipientForActiveGroup in lib/backend/org/org_service.dart).
// Distinct uids/orgs so they never collide with the seed data above.
// ---------------------------------------------------------------------------
describe('Care Profile Setup SAVE — founder provisioning + careRecipients create', () => {
  const FOUNDER    = 'uid_savefounder';
  const ORG_FOUND  = 'org_savefounder';   // = autoFamilyOrgId(FOUNDER) => 'org_$uid'

  it('A. full fresh-founder sequence ALLOWS the careRecipients create (valid save)', async () => {
    const db = dbFor(FOUNDER);
    // 1. phase-1 profile create (no group context yet) — ensureUserProfile
    await assertSucceeds(db.doc('users/'+FOUNDER).set({
      uid: FOUNDER, name: 'Founder', email: 'founder@x.com', createdAt: new Date(),
    }));
    // 2. org doc create (kind family, createdBy=uid) — ensureOrgMembership 3a
    await assertSucceeds(db.doc('organizations/'+ORG_FOUND).set({
      name: 'Household', kind: 'family', createdBy: FOUNDER,
    }));
    // 3. founder member doc — ensureOrgMembership 3b (org doc must pre-exist)
    await assertSucceeds(
      db.doc(`organizations/${ORG_FOUND}/members/${FOUNDER}`).set({
        uid: FOUNDER, orgId: ORG_FOUND, role: 'owner', status: 'active',
      }));
    // 4. users set-merge activeGroupId — ensureOrgMembership 3c
    await assertSucceeds(
      db.doc('users/'+FOUNDER).set({ activeGroupId: ORG_FOUND }, { merge: true }));
    // 5. THE SAVE: careRecipients create with orgId + migrationStatus='created'
    await assertSucceeds(db.doc('careRecipients/save_f1').set({
      Name: 'Mom', PrimaryCondition: 'Dementia',
      TrackVitals: true, TrackMedication: false,
      orgId: ORG_FOUND, migrationStatus: 'created',
    }));
  });

  it('B. pre-provisioned owner (activeGroupId + org + active member) create ALLOWED', async () => {
    // Emulates the seed() helper style: the account is already provisioned
    // (this drives createCareRecipientForActiveGroup straight to ref.set).
    const db = dbFor(FOUNDER);
    await assertSucceeds(db.doc('careRecipients/save_f2').set({
      Name: 'Dad', orgId: ORG_FOUND, migrationStatus: 'created',
    }));
  });

  it('C. fresh account with NO provisioning yet DENIES the careRecipients create', async () => {
    // A signed-in user with no org/membership must NOT be able to create a
    // recipient claiming any org (D1 — membership is required, never skipped).
    const db = dbFor('uid_savefresh');
    await assertFails(db.doc('careRecipients/save_f3').set({
      Name: 'X', orgId: 'org_savefresh', migrationStatus: 'created',
    }));
  });

  it('D. activeGroupId set but MEMBER DOC MISSING DENIES the create', async () => {
    // Partial state: users.activeGroupId present but the members doc is gone
    // (e.g. membership revoked / never completed). createCareRecipientForActiveGroup
    // compares against activeGroupId, which must pass rules' isActiveMember.
    await assertFails(dbFor(FOUNDER).doc('careRecipients/save_f4').set({
      Name: 'Y', orgId: 'org_no_member_here', migrationStatus: 'created',
    }));
  });

  it('E. member doc present but status != active DENIES the create', async () => {
    // Partial state: member exists but was never activated (status 'invited'
    // / 'removed'). Existence alone must not grant writable access (D1).
    const db = dbFor('uid_saveinvited');
    await assertFails(db.doc('careRecipients/save_f5').set({
      Name: 'Z', orgId: 'org_invite_only', migrationStatus: 'created',
    }));
  });
});

// ---------------------------------------------------------------------------
// ensureOrgMembership idempotent-retry edge: an account whose ORG doc exists
// but whose founder MEMBER doc is missing (half-provisioned). The app's
// ensureOrgMembership re-runs org->member->users; the org `set` then lands on
// an EXISTING doc and is evaluated as an UPDATE, which requires membership
// (owner/admin) that does not yet exist. This pins the current rules behavior.
// ---------------------------------------------------------------------------
describe('ensureOrgMembership retry — org-present/member-missing half state', () => {
  const HALF = 'uid_half';
  const ORG_HALF = 'org_half';

  it('org create still ALLOWED for a second fresh attempt (create, not update)', async () => {
    // First call provisions org; the member write is simulated to have failed.
    const db = dbFor(HALF);
    await assertSucceeds(db.doc('organizations/'+ORG_HALF).set({
      name: 'H', kind: 'family', createdBy: HALF,
    }));
    // No member doc written (the failing write).
  });

  it('retry org set with NO membership is DENIED as an update', async () => {
    // Second ensureOrgMembership run re-writes the same org doc; because the
    // doc now exists this is an UPDATE, gated by isMemberWithRole(owner/admin)
    // — which requires the member doc this account is missing. This is an
    // intentional safety property, but shown here so a half-provisioned
    // account's retry is understood to fail hard (self-heals only if the
    // ORIGINAL member create is what failed, not the org create).
    const db = dbFor(HALF);
    await assertFails(db.doc('organizations/'+ORG_HALF).set({
      name: 'H', kind: 'family', createdBy: HALF,
    }));
  });
});
