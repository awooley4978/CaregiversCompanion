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
  await set('mealEntries/meal1',   { patientRef: F1ref,    mealName: 'Soup', orgId: ORG_FAM });
  await set('mealEntries/meal_other', { patientRef: OTHERref, mealName: 'X', orgId: ORG_OTHER });
  await set('symptomEntries/sym1', { patientRef: F1ref });
  // medications — ref-linked via careRecipientRef (enabled for the tracker).
  // Each carries its owner org's orgId (written from the app's active group on
  // create) so the LIST query-compatible read path can gate on it without a
  // get() (see canListRecipientsInOrg in the rules).
  await set('medications/med1',    { careRecipientRef: F1ref,    medicationName: 'Lisinopril', taken: true,  orgId: ORG_FAM });
  await set('medications/med_other',{ careRecipientRef: OTHERref, medicationName: 'X', taken: false, orgId: ORG_OTHER });
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
      orgId: ORG_FAM,
    }));
  });
  it('create WITHOUT orgId is DENIED (every doc must carry the LIST rule field)', async () => {
    await assertFails(dbFor(OWNER).doc('medications/med_noorg').set({
      careRecipientRef: F1ref, medicationName: 'NoOrg', taken: false,
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
  // (`queryMedicationsRecord`), NOT a single-doc GET. It filters on BOTH
  // `orgId == <caller's active group>` AND `careRecipientRef == <selected
  // recipient>` — the same shape as the careRecipients list query
  // (`careRecipientsForActiveGroup`: `q.where('orgId', isEqualTo: activeGroupId)`).
  // The orgId filter is REQUIRED, not cosmetic: Firestore only exposes a
  // candidate document's field to a list rule when the QUERY constrains that
  // field, so without the orgId filter `resource.data.orgId` evaluates as
  // undefined in LIST evaluation and `canListRecipientsInOrg` denies the whole
  // query — a saved medication would then never appear in the tracker despite
  // the "Medication added." success. (A get()-based `read` rule fails here for
  // the same reason once ≥1 matching doc exists.) These cases pin the tracker's
  // real query verbatim.
  it('owner tracker LIST (orgId + careRecipientRef) is ALLOWED', async () => {
    const q = dbFor(OWNER)
      .collection('medications')
      .where('orgId', '==', ORG_FAM)
      .where('careRecipientRef', '==', F1ref);
    await assertSucceeds(q.get());
  });
  it('stranger (other-org member) tracker LIST against the family org is DENIED', async () => {
    const q = dbFor(STRANGER)
      .collection('medications')
      .where('orgId', '==', ORG_FAM)
      .where('careRecipientRef', '==', F1ref);
    await assertFails(q.get());
  });
  it('stranger tracker LIST in their OWN org returns no family med (no cross-org leak)', async () => {
    const q = dbFor(STRANGER)
      .collection('medications')
      .where('orgId', '==', ORG_OTHER)
      .where('careRecipientRef', '==', OTHERref);
    const snap = await assertSucceeds(q.get());
    const ids = snap.docs.map((d) => d.id);
    if (ids.includes('med1')) {
      throw new Error('cross-org leak in medications LIST: ' + ids.join(','));
    }
  });
  // Known, deliberate limitation inherited from the Phase-4 careRecipients
  // get/list split: LIST is MEMBERSHIP-based (canListRecipientsInOrg on the
  // doc's orgId), while single-doc GET additionally honours a grantee share.
  // A grantee therefore still GETs a medication (above) but a tracker LIST over
  // the sharing org's id is denied, and a grantee-own-org LIST returns nothing
  // for the shared recipient (no leak). Same shape as careRecipients today.
  it('grantee tracker LIST over the sharing org is DENIED (list path is membership-based)', async () => {
    await assertFails(dbFor(GRANTEE)
      .collection('medications')
      .where('orgId', '==', ORG_FAM)
      .where('careRecipientRef', '==', F1ref)
      .get());
  });
  it('grantee tracker LIST scoped to their own org returns nothing (no leak, no error)', async () => {
    const snap = await assertSucceeds(dbFor(GRANTEE)
      .collection('medications')
      .where('orgId', '==', ORG_GRNT)
      .where('careRecipientRef', '==', F1ref)
      .get());
    if (snap.docs.length !== 0) {
      throw new Error('grantee LIST leaked ' + snap.docs.length + ' docs');
    }
  });
});

// ---------------------------------------------------------------------------
// MEALENTRIES (ref-linked via patientRef — read split 2026-09-23).
// The Daily Dashboard's 'Meals and Hydration' card now lists the resolved
// recipient's meals with a LIVE LIST query
// (`queryMealEntriesRecord`: where orgId == active group AND patientRef ==
// recipient) — the same shape as the medications tracker query, and for the same
// reason: Firestore evaluates LIST rules WITHOUT loading candidate documents, so
// the rule can only gate on a stored field the QUERY constrains (orgId via the
// exists()-only canListRecipientsInOrg check). These cases pin that query
// verbatim; a get()-based `read` rule denies it live, which would leave a
// confirmed "Meal saved." invisible on the card.
// ---------------------------------------------------------------------------
describe('MEALENTRIES (ref-linked via patientRef — read split)', () => {
  it('owner of recipient org can GET a meal doc (full gate kept)', async () => {
    await assertSucceeds(dbFor(OWNER).doc('mealEntries/meal1').get());
  });
  it('owner dashboard LIST (orgId + patientRef) is ALLOWED', async () => {
    const q = dbFor(OWNER)
      .collection('mealEntries')
      .where('orgId', '==', ORG_FAM)
      .where('patientRef', '==', F1ref);
    await assertSucceeds(q.get());
  });
  it('owner LIST sees only their own org\'s meals', async () => {
    const snap = await assertSucceeds(dbFor(OWNER)
      .collection('mealEntries')
      .where('orgId', '==', ORG_FAM)
      .where('patientRef', '==', F1ref)
      .get());
    const ids = snap.docs.map((d) => d.id);
    if (ids.includes('meal_other')) {
      throw new Error('cross-org leak in mealEntries LIST: ' + ids.join(','));
    }
  });
  it('stranger (other-org member) LIST against the family org is DENIED', async () => {
    await assertFails(dbFor(STRANGER)
      .collection('mealEntries')
      .where('orgId', '==', ORG_FAM)
      .where('patientRef', '==', F1ref)
      .get());
  });
  it('stranger LIST in their OWN org returns no family meal (no cross-org leak)', async () => {
    const snap = await assertSucceeds(dbFor(STRANGER)
      .collection('mealEntries')
      .where('orgId', '==', ORG_OTHER)
      .where('patientRef', '==', OTHERref)
      .get());
    const ids = snap.docs.map((d) => d.id);
    if (ids.includes('meal1')) {
      throw new Error('cross-org leak in mealEntries LIST: ' + ids.join(','));
    }
  });
  it('stranger single GET of a family meal stays DENIED', async () => {
    await assertFails(dbFor(STRANGER).doc('mealEntries/meal1').get());
  });
  it('family caregiver LIST (orgId + patientRef) is ALLOWED', async () => {
    await assertSucceeds(dbFor(CAREGIVER)
      .collection('mealEntries')
      .where('orgId', '==', ORG_FAM)
      .where('patientRef', '==', F1ref)
      .get());
  });
  // Deliberate limitation inherited from the careRecipients/medications
  // get-vs-list split: LIST is MEMBERSHIP-based, so a grantee still GETs a meal
  // through their share but cannot LIST over the sharing org.
  it('grantee LIST over the sharing org is DENIED (list path is membership-based)', async () => {
    await assertFails(dbFor(GRANTEE)
      .collection('mealEntries')
      .where('orgId', '==', ORG_FAM)
      .where('patientRef', '==', F1ref)
      .get());
  });
  it('grantee single GET of the shared meal still SUCCEEDS (share path intact)', async () => {
    await assertSucceeds(dbFor(GRANTEE).doc('mealEntries/meal1').get());
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
    await assertSucceeds(db.doc('mealEntries/cg_meal').set({ patientRef: F1ref, orgId: ORG_FAM }));
    await assertSucceeds(db.doc('symptomEntries/cg_sym').set({ patientRef: F1ref }));
    await assertSucceeds(db.doc('medications/cg_med').set({ careRecipientRef: F1ref, medicationName: 'Y', taken: false, orgId: ORG_FAM }));
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
// "stay denied": emerencyinfo, appointments, dashboardNotes and iconname have
// NO functional read/write path anywhere in lib/ (their pages are static
// mockups / print-stubs), so they keep the Phase-4 `allow read, write: if
// false` blocks. These pins make an accidental future enable FAIL CI even if no
// UI work lands with it. Even the OWNER (who legitimately accesses every
// functional collection) is denied here. (vitalLogs was enabled 2026-11-13 —
// owner-approved v2 design — and has its own suite below.)
// ---------------------------------------------------------------------------
describe('DEAD COLLECTIONS stay denied (V1 consolidated decision)', () => {
  const dead = ['emerencyinfo', 'appointments', 'dashboardNotes', 'iconname'];
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
// VITALLOGS — enabled 2026-11-13 from the dead-collection deny (owner-approved
// v2 design; see vitals-rules-proposal-v2-2026-11-13.md §7 for the case list).
//
// Reads are RECIPIENT-SCOPED for get AND list (the list rule uses a get() on
// the stored careRecipientRef, which only resolves when the query constrains
// that field). Writes are attributed: create stamps loggedByUid == caller, a
// non-future logDateTime, and an orgId strictly matching the recipient's own
// org; orgId / loggedByUid / careRecipientRef are immutable; edits and deletes
// are the author's or an owner/admin of the recipient's org.
// ---------------------------------------------------------------------------
describe('VITALLOGS (owner-approved v2: recipient-scoped reads, attributed writes)', () => {
  const CG2    = 'uid_caregiver2'; // second family caregiver in org_fam
  const ADMIN  = 'uid_admin';      // admin in org_fam
  const VIEWER = 'uid_viewer';     // viewer in org_fam (read-only role)
  const REC_F2   = 'rec_f2';       // second recipient in org_fam (list scoping)
  const REC_BULK = 'rec_bulk';     // org_fam recipient with a 300-reading history
  const REC_GONE = 'rec_gone';     // referenced by a reading but never created

  // request.time is server time, so "past"/"future" are computed per call.
  const past   = () => new Date(Date.now() - 60 * 60 * 1000);
  const future = () => new Date(Date.now() + 24 * 60 * 60 * 1000);

  let F2ref, BULKref, GONEref;

  // A reading authored by AUTHOR (CAREGIVER) on the given recipient ref.
  const reading = (ref, extra) => ({
    careRecipientRef: ref, orgId: ORG_FAM, logDateTime: past(),
    loggedByUid: CAREGIVER, value: 120, ...extra,
  });

  before(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      const set = (p, d) => db.doc(p).set(d);
      F2ref   = db.doc('careRecipients/' + REC_F2);
      BULKref = db.doc('careRecipients/' + REC_BULK);
      GONEref = db.doc('careRecipients/' + REC_GONE); // never written
      await set('careRecipients/' + REC_F2,   { orgId: ORG_FAM });
      await set('careRecipients/' + REC_BULK, { orgId: ORG_FAM });
      // extra org_fam members the vitals matrix needs
      await set('users/' + CG2,    { activeGroupId: ORG_FAM });
      await set('users/' + ADMIN,  { activeGroupId: ORG_FAM });
      await set('users/' + VIEWER, { activeGroupId: ORG_FAM });
      await set(`organizations/${ORG_FAM}/members/${CG2}`,    { uid: CG2, role: 'caregiver', status: 'active' });
      await set(`organizations/${ORG_FAM}/members/${ADMIN}`,  { uid: ADMIN, role: 'admin', status: 'active' });
      await set(`organizations/${ORG_FAM}/members/${VIEWER}`, { uid: VIEWER, role: 'viewer', status: 'active' });
      // readings on the shared org_fam recipient (vital_read1) and a second one
      await set('vitalLogs/vital_read1', reading(F1ref));
      await set('vitalLogs/vital_f2_1',  reading(F2ref));
      // one reading on the professional org's recipient (unassigned-staff case)
      await set('vitalLogs/vital_prof_1', {
        careRecipientRef: PROFref, orgId: ORG_PROF, logDateTime: past(),
        loggedByUid: PROFOWNER, value: 98,
      });
      // per-case docs so no test mutates another test's fixture
      for (const id of ['vital_upd_author', 'vital_upd_cg2', 'vital_upd_owner',
                        'vital_upd_admin', 'vital_upd_uid', 'vital_upd_org',
                        'vital_upd_ref', 'vital_upd_future', 'vital_del_author',
                        'vital_del_cg2', 'vital_del_owner', 'vital_del_stranger']) {
        await set('vitalLogs/' + id, reading(F1ref));
      }
      // orphan: a reading whose careRecipientRef was never created
      await set('vitalLogs/vital_orphan', reading(GONEref));
      // 300-reading history for the read-budget / large-result case
      const batch = db.batch();
      for (let i = 0; i < 300; i++) {
        batch.set(db.doc('vitalLogs/bulk_' + i), reading(BULKref));
      }
      await batch.commit();
    });
  });

  // ---------------------------------------------------------------- create
  describe('create — attributed, org-matched, non-future', () => {
    it('family caregiver create SUCCEEDS', async () => {
      await assertSucceeds(dbFor(CAREGIVER).doc('vitalLogs/vital_new_cg').set(reading(F1ref)));
    });
    it('back-dated logDateTime SUCCEEDS', async () => {
      await assertSucceeds(dbFor(CAREGIVER).doc('vitalLogs/vital_new_backdated').set({
        careRecipientRef: F1ref, orgId: ORG_FAM, loggedByUid: CAREGIVER,
        logDateTime: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000), value: 110,
      }));
    });
    it('missing orgId is DENIED', async () => {
      const d = reading(F1ref); delete d.orgId;
      await assertFails(dbFor(CAREGIVER).doc('vitalLogs/vital_new_noorg').set(d));
    });
    it('another org\'s orgId is DENIED (strict org match)', async () => {
      await assertFails(dbFor(CAREGIVER).doc('vitalLogs/vital_new_wrongorg').set(
        reading(F1ref, { orgId: ORG_OTHER })));
    });
    it('loggedByUid != caller is DENIED (no impersonation)', async () => {
      await assertFails(dbFor(CAREGIVER).doc('vitalLogs/vital_new_imposter').set(
        reading(F1ref, { loggedByUid: OWNER })));
    });
    it('future-dated logDateTime is DENIED', async () => {
      await assertFails(dbFor(CAREGIVER).doc('vitalLogs/vital_new_future').set(
        reading(F1ref, { logDateTime: future() })));
    });
    it('family VIEWER is DENIED', async () => {
      await assertFails(dbFor(VIEWER).doc('vitalLogs/vital_new_viewer').set(
        reading(F1ref, { loggedByUid: VIEWER })));
    });
    it('stranger (other org) is DENIED', async () => {
      await assertFails(dbFor(STRANGER).doc('vitalLogs/vital_new_stranger').set(
        reading(F1ref, { loggedByUid: STRANGER })));
    });
    it('unassigned professional caregiver is DENIED', async () => {
      await assertFails(dbFor(PROFCARE).doc('vitalLogs/vital_new_prof').set({
        careRecipientRef: PROFref, orgId: ORG_PROF, logDateTime: past(),
        loggedByUid: PROFCARE, value: 100,
      }));
    });
    it('grantee with a caregiver-level share SUCCEEDS on the shared recipient', async () => {
      await assertSucceeds(dbFor(GRANTEE).doc('vitalLogs/vital_new_grantee').set({
        careRecipientRef: F1ref, orgId: ORG_FAM, logDateTime: past(),
        loggedByUid: GRANTEE, value: 118,
      }));
    });
  });

  // ---------------------------------------------------------------- get
  describe('get — recipient-scoped single-doc reads', () => {
    it('owner of the recipient org SUCCEEDS', async () => {
      await assertSucceeds(dbFor(OWNER).doc('vitalLogs/vital_read1').get());
    });
    it('stranger (other org) is DENIED', async () => {
      await assertFails(dbFor(STRANGER).doc('vitalLogs/vital_read1').get());
    });
    it('grantee SUCCEEDS on the shared recipient', async () => {
      await assertSucceeds(dbFor(GRANTEE).doc('vitalLogs/vital_read1').get());
    });
    it('grantee is DENIED on a NON-shared recipient', async () => {
      await assertFails(dbFor(GRANTEE).doc('vitalLogs/vital_f2_1').get());
    });
  });

  // ---------------------------------------------------------------- list
  describe('list — query must constrain careRecipientRef', () => {
    it('where careRecipientRef == recipient SUCCEEDS and returns only that recipient', async () => {
      const snap = await dbFor(CAREGIVER)
        .collection('vitalLogs').where('careRecipientRef', '==', F1ref).get();
      const ids = snap.docs.map((d) => d.id);
      if (!ids.includes('vital_read1')) {
        throw new Error('recipient vitals LIST returned none of its own docs: ' + ids.join(','));
      }
      if (ids.includes('vital_f2_1') || ids.includes('bulk_0')) {
        throw new Error('cross-recipient leak in vitalLogs LIST: ' + ids.join(','));
      }
    });
    it('bare collection list is DENIED (no org-wide vitals read)', async () => {
      await assertFails(dbFor(OWNER).collection('vitalLogs').get());
    });
    it('where orgId ONLY is DENIED (careRecipientRef unconstrained)', async () => {
      await assertFails(dbFor(OWNER)
        .collection('vitalLogs').where('orgId', '==', ORG_FAM).get());
    });
    it('grantee list on a NON-shared recipient is DENIED', async () => {
      await assertFails(dbFor(GRANTEE)
        .collection('vitalLogs').where('careRecipientRef', '==', F2ref).get());
    });
    it('unassigned professional caregiver list is DENIED', async () => {
      await assertFails(dbFor(PROFCARE)
        .collection('vitalLogs').where('careRecipientRef', '==', PROFref).get());
    });
    it('a 300-document result is still ALLOWED', async () => {
      const snap = await dbFor(OWNER)
        .collection('vitalLogs').where('careRecipientRef', '==', BULKref).get();
      if (snap.docs.length !== 300) {
        throw new Error('expected 300 readings, got ' + snap.docs.length);
      }
    });
  });

  // ---------------------------------------------------------------- update
  describe('update — author or owner/admin, immutable attribution', () => {
    it('author (the caregiver who wrote it) SUCCEEDS', async () => {
      await assertSucceeds(dbFor(CAREGIVER).doc('vitalLogs/vital_upd_author').update({ value: 125 }));
    });
    it('a SECOND caregiver is DENIED', async () => {
      await assertFails(dbFor(CG2).doc('vitalLogs/vital_upd_cg2').update({ value: 130 }));
    });
    it('owner of the recipient org SUCCEEDS', async () => {
      await assertSucceeds(dbFor(OWNER).doc('vitalLogs/vital_upd_owner').update({ value: 131 }));
    });
    it('admin of the recipient org SUCCEEDS', async () => {
      await assertSucceeds(dbFor(ADMIN).doc('vitalLogs/vital_upd_admin').update({ value: 132 }));
    });
    it('rewriting loggedByUid is DENIED (attribution immutable)', async () => {
      await assertFails(dbFor(CAREGIVER).doc('vitalLogs/vital_upd_uid').update({ loggedByUid: OWNER }));
    });
    it('changing orgId is DENIED', async () => {
      await assertFails(dbFor(CAREGIVER).doc('vitalLogs/vital_upd_org').update({ orgId: ORG_OTHER }));
    });
    it('changing careRecipientRef is DENIED', async () => {
      await assertFails(dbFor(CAREGIVER).doc('vitalLogs/vital_upd_ref').update({ careRecipientRef: F2ref }));
    });
    it('moving logDateTime into the future is DENIED', async () => {
      await assertFails(dbFor(CAREGIVER).doc('vitalLogs/vital_upd_future').update({ logDateTime: future() }));
    });
  });

  // ---------------------------------------------------------------- delete
  describe('delete — author or owner/admin only', () => {
    it('author SUCCEEDS', async () => {
      await assertSucceeds(dbFor(CAREGIVER).doc('vitalLogs/vital_del_author').delete());
    });
    it('a SECOND caregiver is DENIED', async () => {
      await assertFails(dbFor(CG2).doc('vitalLogs/vital_del_cg2').delete());
    });
    it('owner of the recipient org SUCCEEDS', async () => {
      await assertSucceeds(dbFor(OWNER).doc('vitalLogs/vital_del_owner').delete());
    });
    it('stranger (other org) is DENIED', async () => {
      await assertFails(dbFor(STRANGER).doc('vitalLogs/vital_del_stranger').delete());
    });
  });

  // ---------------------------------------------------------------- orphan
  describe('orphan — reading pointing at a non-existent recipient', () => {
    // Deliberate limitation (proposal v2 §6.1): the rule resolves access from
    // the referenced recipient, so an orphaned reading is unreachable through
    // the client — pinned here so a future change to that is intentional.
    it('is UNREADABLE', async () => {
      await assertFails(dbFor(OWNER).doc('vitalLogs/vital_orphan').get());
    });
    it('is UNDELETABLE, even by the owner', async () => {
      await assertFails(dbFor(OWNER).doc('vitalLogs/vital_orphan').delete());
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
    // The doc must carry the caller's orgId: the mealEntries LIST rule (read
    // split, 2026-09-23) gates on the STORED orgId, so a doc without one is
    // rejected at create rather than poisoning the dashboard's meal query.
    await assertSucceeds(dbFor(OWNER).doc('mealEntries/meal_new').set({
      patientRef: F1ref, mealName: 'Soup', orgId: ORG_FAM,
    }));
    await assertFails(dbFor(OWNER).doc('mealEntries/meal_noorg').set({
      patientRef: F1ref, mealName: 'Soup',
    }));
    await assertFails(dbFor(STRANGER).doc('mealEntries/meal_mal').set({
      patientRef: F1ref, mealName: 'Soup', orgId: ORG_FAM,
    }));
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
