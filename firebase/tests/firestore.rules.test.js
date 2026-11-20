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
// Client-side sentinel: the appointments create/update rules pin
// createdAt/updatedAt to the SERVER time, so every client write in this file
// must send serverTimestamp() for those two fields.
const { serverTimestamp } = require('@firebase/firestore');

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
  // LEGACY docs: the shape of the owner's existing live records — the recipient
  // reference and nothing else. They carry no orgId and must still be listable.
  await set('mealEntries/meal_legacy', { patientRef: F1ref, mealName: 'Eggs' });
  await set('symptomEntries/sym1', { patientRef: F1ref });
  // medications — ref-linked via careRecipientRef (enabled for the tracker).
  // Reads are recipient-scoped through that reference (2026-11-19), so a doc's
  // stored orgId is not needed for listing; med1/med_other still carry it (the
  // create rule requires it) and med_legacy deliberately does not.
  await set('medications/med1',    { careRecipientRef: F1ref,    medicationName: 'Lisinopril', taken: true,  orgId: ORG_FAM });
  await set('medications/med_other',{ careRecipientRef: OTHERref, medicationName: 'X', taken: false, orgId: ORG_OTHER });
  // LEGACY medication: the owner's existing record shape — no orgId field.
  await set('medications/med_legacy', { careRecipientRef: F1ref, medicationName: 'Amlodipine', taken: false });
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
// MEDICATIONS — ref-linked via careRecipientRef. Reads are recipient-scoped for
// BOTH get and list (2026-11-19): the LIST rule resolves each candidate
// document's own careRecipientRef with get() and applies the full
// canAccessRecipientRef gate (within-org kind-branched + grantee share +
// caregiver/viewer assignment). That is legal because the app's query
// constrains exactly the field the rule reads — verified in the emulator on
// 2026-11-18. Consequence: a medication needs NO stored orgId to be listable,
// so the owner's existing records are listed exactly as they are, while a
// stranger stays denied.
// ---------------------------------------------------------------------------
describe('MEDICATIONS (recipient-scoped reads; legacy docs with no orgId)', () => {
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
  it('create WITHOUT orgId is DENIED (create rule unchanged)', async () => {
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
  // The tracker and the dose card page their schedule with a LIVE LIST query
  // (`queryMedicationsRecord`), which filters on the selected recipient ONLY:
  //   where('careRecipientRef', '==', <selected recipient>)
  // That single filter is what makes the recipient-scoped LIST rule work AND
  // what makes a LEGACY doc (no orgId) visible. These cases pin that query
  // verbatim for every actor.
  it('owner tracker LIST (careRecipientRef only) lists the LEGACY doc with no orgId', async () => {
    const snap = await assertSucceeds(dbFor(OWNER)
      .collection('medications')
      .where('careRecipientRef', '==', F1ref)
      .get());
    const ids = snap.docs.map((d) => d.id);
    if (!ids.includes('med_legacy')) {
      throw new Error('legacy medication (no orgId) missing from the owner LIST: ' + ids.join(','));
    }
    if (ids.includes('med_other')) {
      throw new Error('cross-org leak in medications LIST: ' + ids.join(','));
    }
  });
  it('family caregiver tracker LIST (careRecipientRef only) lists the LEGACY doc with no orgId', async () => {
    const snap = await assertSucceeds(dbFor(CAREGIVER)
      .collection('medications')
      .where('careRecipientRef', '==', F1ref)
      .get());
    const ids = snap.docs.map((d) => d.id);
    if (!ids.includes('med_legacy')) {
      throw new Error('legacy medication (no orgId) missing from the caregiver LIST: ' + ids.join(','));
    }
  });
  it('grantee tracker LIST (careRecipientRef only) lists the LEGACY doc with no orgId', async () => {
    const snap = await assertSucceeds(dbFor(GRANTEE)
      .collection('medications')
      .where('careRecipientRef', '==', F1ref)
      .get());
    const ids = snap.docs.map((d) => d.id);
    if (!ids.includes('med_legacy')) {
      throw new Error('legacy medication (no orgId) missing from the grantee LIST: ' + ids.join(','));
    }
  });
  it('stranger tracker LIST (careRecipientRef only) is DENIED', async () => {
    await assertFails(dbFor(STRANGER)
      .collection('medications')
      .where('careRecipientRef', '==', F1ref)
      .get());
  });
  it('stranger LIST of their own recipient returns no family medication', async () => {
    const snap = await assertSucceeds(dbFor(STRANGER)
      .collection('medications')
      .where('careRecipientRef', '==', OTHERref)
      .get());
    const ids = snap.docs.map((d) => d.id);
    if (ids.includes('med1') || ids.includes('med_legacy')) {
      throw new Error('cross-org leak in medications LIST: ' + ids.join(','));
    }
  });
  // A bare collection LIST stays denied: the query must constrain the field the
  // rule reads, so there is no org-wide medication read.
  it('owner bare LIST without the recipient filter is DENIED', async () => {
    await assertFails(dbFor(OWNER).collection('medications').get());
  });
});

// ---------------------------------------------------------------------------
// MEDICATIONS — DELETE is owner/admin of the recipient's OWN org only
// (owner decision 2026-11-20). `update` keeps the full canWriteRecipientData
// gate, so caregivers keep add / edit / mark-taken; `delete` requires
// owner or admin of the org that owns the recipient, resolved from the
// document's own careRecipientRef (legacy medications carry no orgId, so a
// stored field could not be used). The grantee case is the sharp one: the
// grantee IS owner of their own org (org_grantee), so a delete rule that read
// the caller's active group instead of the recipient's org would let them
// through — it must stay denied. Every mutation case gets its own fixture doc
// so no test mutates another's.
// ---------------------------------------------------------------------------
describe('MEDICATIONS (delete = owner/admin of the recipient org only)', () => {
  const ADMIN  = 'uid_med_admin';   // admin in org_fam
  const VIEWER = 'uid_med_viewer';  // viewer in org_fam (read-only role)

  before(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      const set = (p, d) => db.doc(p).set(d);
      await set('users/' + ADMIN,  { activeGroupId: ORG_FAM });
      await set('users/' + VIEWER, { activeGroupId: ORG_FAM });
      await set(`organizations/${ORG_FAM}/members/${ADMIN}`,
        { uid: ADMIN, role: 'admin', status: 'active' });
      await set(`organizations/${ORG_FAM}/members/${VIEWER}`,
        { uid: VIEWER, role: 'viewer', status: 'active' });
      // per-case fixtures on the shared org_fam recipient
      for (const id of ['med_upd_owner', 'med_upd_admin', 'med_upd_caregiver',
                        'med_upd_viewer', 'med_upd_grantee', 'med_upd_stranger',
                        'med_upd_anon', 'med_del_owner', 'med_del_admin',
                        'med_del_caregiver', 'med_del_viewer', 'med_del_grantee',
                        'med_del_stranger', 'med_del_anon']) {
        await set('medications/' + id,
          { careRecipientRef: F1ref, medicationName: 'Fixture', taken: false, orgId: ORG_FAM });
      }
      // LEGACY fixtures: the owner's live record shape — careRecipientRef only.
      await set('medications/med_legacy_upd',
        { careRecipientRef: F1ref, medicationName: 'Amlodipine', taken: false });
      await set('medications/med_legacy_del',
        { careRecipientRef: F1ref, medicationName: 'Amlodipine', taken: false });
    });
  });

  const anon = () => env.unauthenticatedContext().firestore();
  const listFam = (db) => db.collection('medications')
    .where('careRecipientRef', '==', F1ref).get();

  // ------------------------------------------------------------------ get
  it('GET: owner, admin, caregiver, viewer and grantee can read; stranger and signed-out cannot', async () => {
    await assertSucceeds(dbFor(OWNER).doc('medications/med1').get());
    await assertSucceeds(dbFor(ADMIN).doc('medications/med1').get());
    await assertSucceeds(dbFor(CAREGIVER).doc('medications/med1').get());
    await assertSucceeds(dbFor(VIEWER).doc('medications/med1').get());
    await assertSucceeds(dbFor(GRANTEE).doc('medications/med1').get());
    await assertFails(dbFor(STRANGER).doc('medications/med1').get());
    await assertFails(anon().doc('medications/med1').get());
  });

  // ------------------------------------------------------------------ list
  it('LIST (careRecipientRef only): owner, admin, caregiver, viewer and grantee succeed; stranger and signed-out denied', async () => {
    await assertSucceeds(listFam(dbFor(OWNER)));
    await assertSucceeds(listFam(dbFor(ADMIN)));
    await assertSucceeds(listFam(dbFor(CAREGIVER)));
    await assertSucceeds(listFam(dbFor(VIEWER)));
    await assertSucceeds(listFam(dbFor(GRANTEE)));
    await assertFails(listFam(dbFor(STRANGER)));
    await assertFails(listFam(anon()));
  });

  // ---------------------------------------------------------------- update
  it('UPDATE: owner, admin, caregiver and grantee succeed (edit / mark-taken kept)', async () => {
    await assertSucceeds(dbFor(OWNER).doc('medications/med_upd_owner').update({ taken: true }));
    await assertSucceeds(dbFor(ADMIN).doc('medications/med_upd_admin').update({ taken: true }));
    await assertSucceeds(dbFor(CAREGIVER).doc('medications/med_upd_caregiver').update({ taken: true }));
    await assertSucceeds(dbFor(GRANTEE).doc('medications/med_upd_grantee').update({ taken: true }));
  });
  it('UPDATE: viewer, stranger and signed-out are DENIED', async () => {
    await assertFails(dbFor(VIEWER).doc('medications/med_upd_viewer').update({ taken: true }));
    await assertFails(dbFor(STRANGER).doc('medications/med_upd_stranger').update({ taken: true }));
    await assertFails(anon().doc('medications/med_upd_anon').update({ taken: true }));
  });

  // ---------------------------------------------------------------- delete
  it('DELETE: owner of the recipient org SUCCEEDS', async () => {
    await assertSucceeds(dbFor(OWNER).doc('medications/med_del_owner').delete());
  });
  it('DELETE: admin of the recipient org SUCCEEDS', async () => {
    await assertSucceeds(dbFor(ADMIN).doc('medications/med_del_admin').delete());
  });
  it('DELETE: caregiver is DENIED (can still edit, cannot remove)', async () => {
    await assertFails(dbFor(CAREGIVER).doc('medications/med_del_caregiver').delete());
  });
  it('DELETE: viewer is DENIED', async () => {
    await assertFails(dbFor(VIEWER).doc('medications/med_del_viewer').delete());
  });
  it('DELETE: share-grantee is DENIED even though they own their own org', async () => {
    await assertFails(dbFor(GRANTEE).doc('medications/med_del_grantee').delete());
  });
  it('DELETE: stranger and signed-out are DENIED', async () => {
    await assertFails(dbFor(STRANGER).doc('medications/med_del_stranger').delete());
    await assertFails(anon().doc('medications/med_del_anon').delete());
  });

  // ---------------------------------------------------------------- legacy
  it('LEGACY (no orgId): caregiver can READ it', async () => {
    await assertSucceeds(dbFor(CAREGIVER).doc('medications/med_legacy').get());
  });
  it('LEGACY (no orgId): caregiver can UPDATE it', async () => {
    await assertSucceeds(dbFor(CAREGIVER).doc('medications/med_legacy_upd').update({
      taken: true, status: 'TAKEN',
    }));
  });
  it('LEGACY (no orgId): caregiver DELETE is DENIED', async () => {
    await assertFails(dbFor(CAREGIVER).doc('medications/med_legacy_upd').delete());
  });
  it('LEGACY (no orgId): owner DELETE SUCCEEDS (org resolved from careRecipientRef)', async () => {
    await assertSucceeds(dbFor(OWNER).doc('medications/med_legacy_del').delete());
  });
  it('LEGACY (no orgId): stranger DELETE is DENIED', async () => {
    await assertFails(dbFor(STRANGER).doc('medications/med_legacy_upd').delete());
  });
});

// ---------------------------------------------------------------------------
// MEALENTRIES (ref-linked via patientRef — recipient-scoped reads, 2026-11-19).
// Same shape as medications: the Daily Dashboard's 'Meals and Hydration' card
// lists the resolved recipient's meals with a LIVE LIST query
// (`queryMealEntriesRecord`: where patientRef == recipient, and nothing else).
// A meal therefore needs no stored orgId to be listable — the owner's existing
// meal records are listed as-is — and a stranger is still denied.
// ---------------------------------------------------------------------------
describe('MEALENTRIES (recipient-scoped reads; legacy docs with no orgId)', () => {
  it('owner of recipient org can GET a meal doc (full gate kept)', async () => {
    await assertSucceeds(dbFor(OWNER).doc('mealEntries/meal1').get());
  });
  it('owner dashboard LIST (patientRef only) lists the LEGACY doc with no orgId', async () => {
    const snap = await assertSucceeds(dbFor(OWNER)
      .collection('mealEntries')
      .where('patientRef', '==', F1ref)
      .get());
    const ids = snap.docs.map((d) => d.id);
    if (!ids.includes('meal_legacy')) {
      throw new Error('legacy meal (no orgId) missing from the owner LIST: ' + ids.join(','));
    }
    if (ids.includes('meal_other')) {
      throw new Error('cross-org leak in mealEntries LIST: ' + ids.join(','));
    }
  });
  it('family caregiver dashboard LIST (patientRef only) lists the LEGACY doc with no orgId', async () => {
    const snap = await assertSucceeds(dbFor(CAREGIVER)
      .collection('mealEntries')
      .where('patientRef', '==', F1ref)
      .get());
    const ids = snap.docs.map((d) => d.id);
    if (!ids.includes('meal_legacy')) {
      throw new Error('legacy meal (no orgId) missing from the caregiver LIST: ' + ids.join(','));
    }
  });
  it('grantee dashboard LIST (patientRef only) lists the LEGACY doc with no orgId', async () => {
    const snap = await assertSucceeds(dbFor(GRANTEE)
      .collection('mealEntries')
      .where('patientRef', '==', F1ref)
      .get());
    const ids = snap.docs.map((d) => d.id);
    if (!ids.includes('meal_legacy')) {
      throw new Error('legacy meal (no orgId) missing from the grantee LIST: ' + ids.join(','));
    }
  });
  it('stranger (other-org member) dashboard LIST (patientRef only) is DENIED', async () => {
    await assertFails(dbFor(STRANGER)
      .collection('mealEntries')
      .where('patientRef', '==', F1ref)
      .get());
  });
  it('stranger LIST of their own recipient returns no family meal', async () => {
    const snap = await assertSucceeds(dbFor(STRANGER)
      .collection('mealEntries')
      .where('patientRef', '==', OTHERref)
      .get());
    const ids = snap.docs.map((d) => d.id);
    if (ids.includes('meal1') || ids.includes('meal_legacy')) {
      throw new Error('cross-org leak in mealEntries LIST: ' + ids.join(','));
    }
  });
  it('stranger single GET of a family meal stays DENIED', async () => {
    await assertFails(dbFor(STRANGER).doc('mealEntries/meal1').get());
  });
  it('grantee single GET of the shared meal still SUCCEEDS (share path intact)', async () => {
    await assertSucceeds(dbFor(GRANTEE).doc('mealEntries/meal1').get());
  });
  it('owner bare LIST without the recipient filter is DENIED', async () => {
    await assertFails(dbFor(OWNER).collection('mealEntries').get());
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
// "stay denied": emerencyinfo, dashboardNotes and iconname have NO functional
// read/write path anywhere in lib/ (their pages are static mockups /
// print-stubs), so they keep the Phase-4 `allow read, write: if false` blocks.
// These pins make an accidental future enable FAIL CI even if no UI work lands
// with it. Even the OWNER (who legitimately accesses every functional
// collection) is denied here. (vitalLogs was enabled 2026-11-13, waterLogs
// 2026-11-13 and appointments 2026-11-16 — each has its own suite below.)
// ---------------------------------------------------------------------------
describe('DEAD COLLECTIONS stay denied (V1 consolidated decision)', () => {
  const dead = ['emerencyinfo', 'dashboardNotes', 'iconname'];
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
// WATERLOGS — enabled 2026-11-13 (owner-approved water tracking unit; see
// water-tracking-proposal-2026-11-13.md §3 for the block and §7 for the case
// list). One document per individually timestamped intake.
//
// Same access model as vitalLogs: recipient-scoped reads for get AND list (so
// a bare or orgId-only list is DENIED), attributed creates (loggedByUid ==
// caller, orgId == the recipient's real org, non-future intakeAt, positive
// amount, unit in [fl_oz, mL]) and author-or-owner/admin edit/delete — the last
// of which is exactly what the dashboard's Undo relies on.
// ---------------------------------------------------------------------------
describe('WATERLOGS (water tracking: recipient-scoped reads, attributed writes)', () => {
  const CG2   = 'uid_water_cg2'; // second family caregiver in org_fam
  const ADMIN = 'uid_water_admin'; // admin in org_fam
  const REC_W2 = 'rec_w2';       // second org_fam recipient (list scoping)

  const past   = () => new Date(Date.now() - 60 * 1000);
  const future = () => new Date(Date.now() + 24 * 60 * 60 * 1000);

  let W2ref;

  // An 8 fl oz quick-add authored by AUTHOR on the given recipient ref.
  const intake = (ref, extra) => ({
    careRecipientRef: ref, orgId: ORG_FAM, intakeAt: past(),
    loggedByUid: CAREGIVER, amount: 8, unit: 'fl_oz', amountFlOz: 8, ...extra,
  });

  before(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      const set = (p, d) => db.doc(p).set(d);
      W2ref = db.doc('careRecipients/' + REC_W2);
      await set('careRecipients/' + REC_W2, { orgId: ORG_FAM });
      await set('users/' + CG2,   { activeGroupId: ORG_FAM });
      await set('users/' + ADMIN, { activeGroupId: ORG_FAM });
      await set(`organizations/${ORG_FAM}/members/${CG2}`,   { uid: CG2, role: 'caregiver', status: 'active' });
      await set(`organizations/${ORG_FAM}/members/${ADMIN}`, { uid: ADMIN, role: 'admin', status: 'active' });
      await set('waterLogs/water_read1', intake(F1ref));
      await set('waterLogs/water_w2_1',  intake(W2ref));
      await set('waterLogs/water_prof_1', {
        careRecipientRef: PROFref, orgId: ORG_PROF, intakeAt: past(),
        loggedByUid: PROFOWNER, amount: 8, unit: 'fl_oz', amountFlOz: 8,
      });
      for (const id of ['water_upd_author', 'water_upd_cg2', 'water_upd_owner',
                        'water_upd_admin', 'water_upd_uid', 'water_upd_org',
                        'water_upd_ref', 'water_upd_future', 'water_del_author',
                        'water_del_cg2', 'water_del_owner', 'water_del_stranger']) {
        await set('waterLogs/' + id, intake(F1ref));
      }
    });
  });

  // ---------------------------------------------------------------- create
  describe('create — attributed, org-matched, non-future, positive', () => {
    it('family caregiver quick-add SUCCEEDS', async () => {
      await assertSucceeds(dbFor(CAREGIVER).doc('waterLogs/water_new_cg').set(intake(F1ref)));
    });
    it('a second caregiver may log on the same recipient (attributed)', async () => {
      await assertSucceeds(dbFor(CG2).doc('waterLogs/water_new_cg2').set(
        intake(F1ref, { loggedByUid: CG2 })));
    });
    it('mL is already accepted (unit preserved for a later mL input)', async () => {
      await assertSucceeds(dbFor(CAREGIVER).doc('waterLogs/water_new_ml').set(
        intake(F1ref, { amount: 250, unit: 'mL', amountFlOz: 8.45 })));
    });
    it('back-dated intakeAt SUCCEEDS (backdating is deferred in the UI only)', async () => {
      await assertSucceeds(dbFor(CAREGIVER).doc('waterLogs/water_new_backdated').set(
        intake(F1ref, { intakeAt: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) })));
    });
    it('future intakeAt is DENIED', async () => {
      await assertFails(dbFor(CAREGIVER).doc('waterLogs/water_new_future').set(
        intake(F1ref, { intakeAt: future() })));
    });
    it('a non-positive amount is DENIED', async () => {
      await assertFails(dbFor(CAREGIVER).doc('waterLogs/water_new_zero').set(
        intake(F1ref, { amount: 0, amountFlOz: 0 })));
      await assertFails(dbFor(CAREGIVER).doc('waterLogs/water_new_negative').set(
        intake(F1ref, { amount: -8, amountFlOz: -8 })));
    });
    it('an unknown unit is DENIED', async () => {
      await assertFails(dbFor(CAREGIVER).doc('waterLogs/water_new_unit').set(
        intake(F1ref, { unit: 'cups' })));
    });
    it('missing orgId is DENIED', async () => {
      const d = intake(F1ref); delete d.orgId;
      await assertFails(dbFor(CAREGIVER).doc('waterLogs/water_new_noorg').set(d));
    });
    it('orgId that does not match the recipient org is DENIED', async () => {
      await assertFails(dbFor(CAREGIVER).doc('waterLogs/water_new_wrongorg').set(
        intake(F1ref, { orgId: ORG_OTHER })));
    });
    it('loggedByUid spoofing another user is DENIED', async () => {
      await assertFails(dbFor(CAREGIVER).doc('waterLogs/water_new_imposter').set(
        intake(F1ref, { loggedByUid: OWNER })));
    });
    it('a cross-org user is DENIED', async () => {
      await assertFails(dbFor(STRANGER).doc('waterLogs/water_new_stranger').set(
        intake(F1ref, { loggedByUid: STRANGER, orgId: ORG_OTHER })));
    });
    it('unassigned professional staff are DENIED', async () => {
      await assertFails(dbFor(PROFCARE).doc('waterLogs/water_new_prof').set({
        careRecipientRef: PROFref, orgId: ORG_PROF, intakeAt: past(),
        loggedByUid: PROFCARE, amount: 8, unit: 'fl_oz', amountFlOz: 8,
      }));
    });
  });

  // ---------------------------------------------------------------- read
  describe('read — recipient-scoped for get AND list', () => {
    it('owner GET of their org\'s entry SUCCEEDS', async () => {
      await assertSucceeds(dbFor(OWNER).doc('waterLogs/water_read1').get());
    });
    it('stranger GET is DENIED', async () => {
      await assertFails(dbFor(STRANGER).doc('waterLogs/water_read1').get());
    });
    it('grantee GET of the shared recipient\'s entry SUCCEEDS', async () => {
      await assertSucceeds(dbFor(GRANTEE).doc('waterLogs/water_read1').get());
    });
    it('recipient-scoped LIST SUCCEEDS and never leaks another recipient', async () => {
      const snap = await assertSucceeds(dbFor(OWNER)
        .collection('waterLogs').where('careRecipientRef', '==', F1ref).get());
      const ids = snap.docs.map((d) => d.id);
      if (ids.includes('water_w2_1') || ids.includes('water_prof_1')) {
        throw new Error('cross-recipient leak in waterLogs LIST: ' + ids.join(','));
      }
    });
    it('a bare collection LIST is DENIED', async () => {
      await assertFails(dbFor(OWNER).collection('waterLogs').get());
    });
    it('an orgId-only LIST is DENIED', async () => {
      await assertFails(dbFor(OWNER)
        .collection('waterLogs').where('orgId', '==', ORG_FAM).get());
    });
    it('a cross-org user LIST against the family recipient is DENIED', async () => {
      await assertFails(dbFor(STRANGER)
        .collection('waterLogs').where('careRecipientRef', '==', F1ref).get());
    });
  });

  // ---------------------------------------------------------------- update
  describe('update — author or owner/admin, immutable attribution', () => {
    it('author SUCCEEDS', async () => {
      await assertSucceeds(dbFor(CAREGIVER).doc('waterLogs/water_upd_author').update({ amount: 12, amountFlOz: 12 }));
    });
    it('a SECOND caregiver is DENIED', async () => {
      await assertFails(dbFor(CG2).doc('waterLogs/water_upd_cg2').update({ amount: 12 }));
    });
    it('owner SUCCEEDS', async () => {
      await assertSucceeds(dbFor(OWNER).doc('waterLogs/water_upd_owner').update({ amount: 12 }));
    });
    it('admin SUCCEEDS', async () => {
      await assertSucceeds(dbFor(ADMIN).doc('waterLogs/water_upd_admin').update({ amount: 12 }));
    });
    it('changing loggedByUid is DENIED', async () => {
      await assertFails(dbFor(CAREGIVER).doc('waterLogs/water_upd_uid').update({ loggedByUid: OWNER }));
    });
    it('changing orgId is DENIED', async () => {
      await assertFails(dbFor(CAREGIVER).doc('waterLogs/water_upd_org').update({ orgId: ORG_OTHER }));
    });
    it('changing careRecipientRef is DENIED', async () => {
      await assertFails(dbFor(CAREGIVER).doc('waterLogs/water_upd_ref').update({ careRecipientRef: W2ref }));
    });
    it('a future intakeAt is DENIED', async () => {
      await assertFails(dbFor(CAREGIVER).doc('waterLogs/water_upd_future').update({ intakeAt: future() }));
    });
  });

  // ---------------------------------------------------------------- delete (Undo)
  describe('delete — the dashboard Undo path: author or owner/admin only', () => {
    it('the author may undo their own quick-add', async () => {
      await assertSucceeds(dbFor(CAREGIVER).doc('waterLogs/water_del_author').delete());
    });
    it('a SECOND caregiver cannot delete another caregiver\'s entry', async () => {
      await assertFails(dbFor(CG2).doc('waterLogs/water_del_cg2').delete());
    });
    it('owner of the recipient org SUCCEEDS', async () => {
      await assertSucceeds(dbFor(OWNER).doc('waterLogs/water_del_owner').delete());
    });
    it('stranger (other org) is DENIED', async () => {
      await assertFails(dbFor(STRANGER).doc('waterLogs/water_del_stranger').delete());
    });
  });
});

// ---------------------------------------------------------------------------
// APPOINTMENTS — enabled 2026-11-16 (owner-approved appointments + calendar
// unit; proposal appointments-calendar-proposal-2026-11-15.md §2–§4).
//
// Same access model as vitalLogs/waterLogs: recipient-scoped reads for get AND
// list (so a bare or orgId-only list is DENIED), attributed creates
// (createdByUid == caller, orgId == the recipient's real org), immutable
// careRecipientRef / orgId / createdByUid, and author-or-owner/admin edits and
// deletes. ONE deliberate difference: FUTURE DATES ARE ALLOWED, because an
// appointment is by definition scheduled ahead of time — only createdAt /
// updatedAt are pinned to the server time.
//
// LEGACY (owner requirement 2026-11-16): appointments created before orgId /
// createdByUid existed must stay readable, must never be silently rewritten,
// and — because they record no author — may only be EDITED or DELETED by an
// owner/admin of the recipient's org. Those cases are pinned in the last block.
// ---------------------------------------------------------------------------
describe('APPOINTMENTS (recipient-scoped reads, attributed writes, future dates allowed)', () => {
  const CG2    = 'uid_appt_cg2';    // second family caregiver in org_fam
  const ADMIN  = 'uid_appt_admin';  // admin in org_fam
  const VIEWER = 'uid_appt_viewer'; // viewer in org_fam (read-only role)
  const REC_A2 = 'rec_a2';          // second org_fam recipient (list scoping)

  const past   = () => new Date(Date.now() - 24 * 60 * 60 * 1000);
  const future = () => new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

  let A2ref;

  // A SEEDED appointment (written with rules off, so plain Dates are fine).
  const seeded = (ref, extra) => ({
    careRecipientRef: ref, orgId: ORG_FAM, appointmentTitle: 'Cardiology follow-up',
    appointmentDateTime: future(), createdByUid: CAREGIVER,
    createdAt: new Date(), updatedAt: new Date(), ...extra,
  });

  // A CLIENT-created appointment — the shape the app's create helper writes.
  const clientAppt = (ref, extra) => ({
    careRecipientRef: ref, orgId: ORG_FAM, appointmentTitle: 'Cardiology follow-up',
    appointmentDateTime: future(), createdByUid: CAREGIVER,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...extra,
  });

  // A LEGACY appointment: created before orgId / createdByUid existed.
  const legacy = (extra) => ({
    careRecipientRef: F1ref, appointmentTitle: 'Old visit', providerName: 'Dr. Reyes',
    appointmentDateTime: past(), createdAt: new Date(), updatedAt: new Date(), ...extra,
  });

  before(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      const set = (p, d) => db.doc(p).set(d);
      A2ref = db.doc('careRecipients/' + REC_A2);
      await set('careRecipients/' + REC_A2, { orgId: ORG_FAM });
      await set('users/' + CG2,    { activeGroupId: ORG_FAM });
      await set('users/' + ADMIN,  { activeGroupId: ORG_FAM });
      await set('users/' + VIEWER, { activeGroupId: ORG_FAM });
      await set(`organizations/${ORG_FAM}/members/${CG2}`,    { uid: CG2, role: 'caregiver', status: 'active' });
      await set(`organizations/${ORG_FAM}/members/${ADMIN}`,  { uid: ADMIN, role: 'admin', status: 'active' });
      await set(`organizations/${ORG_FAM}/members/${VIEWER}`, { uid: VIEWER, role: 'viewer', status: 'active' });
      // readable fixtures
      await set('appointments/appt_read1', seeded(F1ref));
      await set('appointments/appt_a2_1',  seeded(A2ref));
      await set('appointments/appt_prof_1', seeded(PROFref, {
        orgId: ORG_PROF, createdByUid: PROFOWNER,
      }));
      // per-case docs so no test mutates another test's fixture
      for (const id of ['appt_upd_author', 'appt_upd_cg2', 'appt_upd_owner',
                        'appt_upd_admin', 'appt_upd_uid', 'appt_upd_org',
                        'appt_upd_ref', 'appt_upd_future', 'appt_upd_ts',
                        'appt_del_author', 'appt_del_cg2', 'appt_del_owner',
                        'appt_del_stranger']) {
        await set('appointments/' + id, seeded(F1ref));
      }
      // LEGACY fixtures — no orgId, no createdByUid anywhere
      await set('appointments/appt_legacy_read',        legacy());
      await set('appointments/appt_legacy_edit_owner',  legacy());
      await set('appointments/appt_legacy_edit_admin',  legacy());
      await set('appointments/appt_legacy_upd_cg',      legacy());
      await set('appointments/appt_legacy_upd_cg2',     legacy());
      await set('appointments/appt_legacy_backfill',    legacy());
      await set('appointments/appt_legacy_badorg',      legacy());
      await set('appointments/appt_legacy_badauthor',   legacy());
      await set('appointments/appt_legacy_del_cg',      legacy());
      await set('appointments/appt_legacy_del_cg2',     legacy());
      await set('appointments/appt_legacy_del_owner',   legacy());
      await set('appointments/appt_legacy_del_admin',   legacy());
    });
  });

  // ---------------------------------------------------------------- create
  describe('create — attributed, org-matched, FUTURE dates allowed', () => {
    it('family caregiver schedules a FUTURE appointment SUCCEEDS', async () => {
      await assertSucceeds(dbFor(CAREGIVER).doc('appointments/appt_new_future').set(clientAppt(F1ref)));
    });
    it('a PAST appointment (a visit already attended) SUCCEEDS', async () => {
      await assertSucceeds(dbFor(CAREGIVER).doc('appointments/appt_new_past').set(
        clientAppt(F1ref, { appointmentDateTime: past() })));
    });
    it('an endDateTime at or after the start SUCCEEDS', async () => {
      const start = future();
      await assertSucceeds(dbFor(CAREGIVER).doc('appointments/appt_new_end').set(
        clientAppt(F1ref, {
          appointmentDateTime: start,
          endDateTime: new Date(start.getTime() + 60 * 60 * 1000),
        })));
    });
    it('an endDateTime BEFORE the start is DENIED', async () => {
      const start = future();
      await assertFails(dbFor(CAREGIVER).doc('appointments/appt_new_badend').set(
        clientAppt(F1ref, {
          appointmentDateTime: start,
          endDateTime: new Date(start.getTime() - 60 * 60 * 1000),
        })));
    });
    it('an EMPTY title is DENIED', async () => {
      await assertFails(dbFor(CAREGIVER).doc('appointments/appt_new_notitle').set(
        clientAppt(F1ref, { appointmentTitle: '' })));
    });
    it('a missing start time is DENIED', async () => {
      const d = clientAppt(F1ref); delete d.appointmentDateTime;
      await assertFails(dbFor(CAREGIVER).doc('appointments/appt_new_nostart').set(d));
    });
    it('missing orgId is DENIED', async () => {
      const d = clientAppt(F1ref); delete d.orgId;
      await assertFails(dbFor(CAREGIVER).doc('appointments/appt_new_noorg').set(d));
    });
    it('an orgId that does not match the recipient org is DENIED', async () => {
      await assertFails(dbFor(CAREGIVER).doc('appointments/appt_new_wrongorg').set(
        clientAppt(F1ref, { orgId: ORG_OTHER })));
    });
    it('createdByUid spoofing another user is DENIED', async () => {
      await assertFails(dbFor(CAREGIVER).doc('appointments/appt_new_imposter').set(
        clientAppt(F1ref, { createdByUid: OWNER })));
    });
    it('a CLIENT createdAt (DateTime.now) is DENIED — createdAt is server-stamped', async () => {
      await assertFails(dbFor(CAREGIVER).doc('appointments/appt_new_clientts').set(
        clientAppt(F1ref, { createdAt: new Date() })));
    });
    it('a cross-org user is DENIED', async () => {
      await assertFails(dbFor(STRANGER).doc('appointments/appt_new_stranger').set(
        clientAppt(F1ref, { orgId: ORG_OTHER, createdByUid: STRANGER })));
    });
    it('a viewer (read-only role) is DENIED', async () => {
      await assertFails(dbFor(VIEWER).doc('appointments/appt_new_viewer').set(
        clientAppt(F1ref, { createdByUid: VIEWER })));
    });
    it('unassigned professional staff are DENIED', async () => {
      await assertFails(dbFor(PROFCARE).doc('appointments/appt_new_prof').set({
        careRecipientRef: PROFref, orgId: ORG_PROF, appointmentTitle: 'Wound care',
        appointmentDateTime: future(), createdByUid: PROFCARE,
        createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
      }));
    });
    it('a grantee with a caregiver-level share SUCCEEDS', async () => {
      await assertSucceeds(dbFor(GRANTEE).doc('appointments/appt_new_grantee').set(
        clientAppt(F1ref, { createdByUid: GRANTEE })));
    });
  });

  // ---------------------------------------------------------------- read
  describe('read — recipient-scoped for get AND list', () => {
    it('owner GET of their org\'s appointment SUCCEEDS', async () => {
      await assertSucceeds(dbFor(OWNER).doc('appointments/appt_read1').get());
    });
    it('stranger GET is DENIED', async () => {
      await assertFails(dbFor(STRANGER).doc('appointments/appt_read1').get());
    });
    it('grantee GET of the shared recipient\'s appointment SUCCEEDS', async () => {
      await assertSucceeds(dbFor(GRANTEE).doc('appointments/appt_read1').get());
    });
    it('recipient-scoped LIST SUCCEEDS and never leaks another recipient', async () => {
      const snap = await assertSucceeds(dbFor(OWNER)
        .collection('appointments').where('careRecipientRef', '==', F1ref).get());
      const ids = snap.docs.map((d) => d.id);
      if (ids.includes('appt_a2_1') || ids.includes('appt_prof_1')) {
        throw new Error('cross-recipient leak in appointments LIST: ' + ids.join(','));
      }
    });
    it('the CALENDAR month query (recipient + date range + orderBy) SUCCEEDS', async () => {
      const start = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
      const end   = new Date(Date.now() + 60 * 24 * 60 * 60 * 1000);
      const snap = await assertSucceeds(dbFor(OWNER)
        .collection('appointments')
        .where('careRecipientRef', '==', F1ref)
        .where('appointmentDateTime', '>=', start)
        .where('appointmentDateTime', '<', end)
        .orderBy('appointmentDateTime', 'asc')
        .get());
      if (!snap.docs.some((d) => d.id === 'appt_read1')) {
        throw new Error('month query did not return the seeded appointment');
      }
    });
    it('a bare collection LIST is DENIED', async () => {
      await assertFails(dbFor(OWNER).collection('appointments').get());
    });
    it('an orgId-only LIST is DENIED', async () => {
      await assertFails(dbFor(OWNER)
        .collection('appointments').where('orgId', '==', ORG_FAM).get());
    });
    it('a cross-org user LIST against the family recipient is DENIED', async () => {
      await assertFails(dbFor(STRANGER)
        .collection('appointments').where('careRecipientRef', '==', F1ref).get());
    });
  });

  // ---------------------------------------------------------------- update
  describe('update — author or owner/admin, immutable scope, future dates allowed', () => {
    it('the author SUCCEEDS', async () => {
      await assertSucceeds(dbFor(CAREGIVER).doc('appointments/appt_upd_author').update({
        appointmentTitle: 'Cardiology (rescheduled)', updatedAt: serverTimestamp(),
      }));
    });
    it('a SECOND caregiver is DENIED', async () => {
      await assertFails(dbFor(CG2).doc('appointments/appt_upd_cg2').update({
        appointmentTitle: 'Hijacked', updatedAt: serverTimestamp(),
      }));
    });
    it('owner SUCCEEDS', async () => {
      await assertSucceeds(dbFor(OWNER).doc('appointments/appt_upd_owner').update({
        appointmentTitle: 'Cardiology (owner edit)', updatedAt: serverTimestamp(),
      }));
    });
    it('admin SUCCEEDS', async () => {
      await assertSucceeds(dbFor(ADMIN).doc('appointments/appt_upd_admin').update({
        appointmentTitle: 'Cardiology (admin edit)', updatedAt: serverTimestamp(),
      }));
    });
    it('moving the date further into the FUTURE SUCCEEDS', async () => {
      await assertSucceeds(dbFor(CAREGIVER).doc('appointments/appt_upd_future').update({
        appointmentDateTime: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        updatedAt: serverTimestamp(),
      }));
    });
    it('changing createdByUid is DENIED', async () => {
      await assertFails(dbFor(CAREGIVER).doc('appointments/appt_upd_uid').update({
        createdByUid: OWNER, updatedAt: serverTimestamp(),
      }));
    });
    it('changing orgId is DENIED', async () => {
      await assertFails(dbFor(CAREGIVER).doc('appointments/appt_upd_org').update({
        orgId: ORG_OTHER, updatedAt: serverTimestamp(),
      }));
    });
    it('changing careRecipientRef is DENIED', async () => {
      await assertFails(dbFor(CAREGIVER).doc('appointments/appt_upd_ref').update({
        careRecipientRef: A2ref, updatedAt: serverTimestamp(),
      }));
    });
    it('a CLIENT updatedAt (DateTime.now) is DENIED — updatedAt is server-stamped', async () => {
      await assertFails(dbFor(CAREGIVER).doc('appointments/appt_upd_ts').update({
        appointmentTitle: 'x', updatedAt: new Date(),
      }));
    });
  });

  // ---------------------------------------------------------------- delete
  describe('delete — author or owner/admin only', () => {
    it('the author may delete their own appointment', async () => {
      await assertSucceeds(dbFor(CAREGIVER).doc('appointments/appt_del_author').delete());
    });
    it('a SECOND caregiver cannot delete another caregiver\'s appointment', async () => {
      await assertFails(dbFor(CG2).doc('appointments/appt_del_cg2').delete());
    });
    it('owner of the recipient org SUCCEEDS', async () => {
      await assertSucceeds(dbFor(OWNER).doc('appointments/appt_del_owner').delete());
    });
    it('stranger (other org) is DENIED', async () => {
      await assertFails(dbFor(STRANGER).doc('appointments/appt_del_stranger').delete());
    });
  });

  // ---------------------------------------------------------------- legacy
  describe('LEGACY records (no orgId / createdByUid): readable, owner/admin-only to write', () => {
    it('GET by an org member SUCCEEDS — reads never require the new fields', async () => {
      await assertSucceeds(dbFor(CAREGIVER).doc('appointments/appt_legacy_read').get());
    });
    it('appears in the recipient-scoped LIST and the calendar month query', async () => {
      const listed = await assertSucceeds(dbFor(OWNER)
        .collection('appointments').where('careRecipientRef', '==', F1ref).get());
      if (!listed.docs.some((d) => d.id === 'appt_legacy_read')) {
        throw new Error('legacy appointment missing from the recipient-scoped list');
      }
      const start = new Date(Date.now() - 400 * 24 * 60 * 60 * 1000);
      const end   = new Date(Date.now() + 60 * 24 * 60 * 60 * 1000);
      const windowed = await assertSucceeds(dbFor(OWNER)
        .collection('appointments')
        .where('careRecipientRef', '==', F1ref)
        .where('appointmentDateTime', '>=', start)
        .where('appointmentDateTime', '<', end)
        .orderBy('appointmentDateTime', 'asc')
        .get());
      if (!windowed.docs.some((d) => d.id === 'appt_legacy_read')) {
        throw new Error('legacy appointment missing from the calendar month query');
      }
    });

    // --- the 2026-11-16 tightening: NO recipient-write fallback on legacy docs
    it('a NON-AUTHOR caregiver cannot EDIT a legacy record (DENIED)', async () => {
      await assertFails(dbFor(CG2).doc('appointments/appt_legacy_upd_cg2').update({
        appointmentTitle: 'Hijacked', updatedAt: serverTimestamp(),
      }));
    });
    it('the recipient\'s own writer caregiver cannot EDIT a legacy record (DENIED)', async () => {
      await assertFails(dbFor(CAREGIVER).doc('appointments/appt_legacy_upd_cg').update({
        appointmentTitle: 'Old visit (rescheduled)', updatedAt: serverTimestamp(),
      }));
    });
    it('a NON-AUTHOR caregiver cannot DELETE a legacy record (DENIED)', async () => {
      await assertFails(dbFor(CG2).doc('appointments/appt_legacy_del_cg2').delete());
    });
    it('a caregiver cannot DELETE a legacy record (no recorded author) (DENIED)', async () => {
      await assertFails(dbFor(CAREGIVER).doc('appointments/appt_legacy_del_cg').delete());
    });

    // --- owner/admin carry the legacy write path
    it('the owner may EDIT a legacy record, and it is never silently rewritten', async () => {
      await assertSucceeds(dbFor(OWNER).doc('appointments/appt_legacy_edit_owner').update({
        appointmentTitle: 'Old visit (rescheduled)', updatedAt: serverTimestamp(),
      }));
      const snap = await assertSucceeds(dbFor(OWNER).doc('appointments/appt_legacy_edit_owner').get());
      const d = snap.data();
      if ('orgId' in d || 'createdByUid' in d) {
        throw new Error('legacy record was silently backfilled: ' + JSON.stringify(d));
      }
      if (d.appointmentTitle !== 'Old visit (rescheduled)') {
        throw new Error('the edit did not land: ' + JSON.stringify(d));
      }
      if (d.providerName !== 'Dr. Reyes') {
        throw new Error('unrelated data was lost on edit: ' + JSON.stringify(d));
      }
    });
    it('an ADMIN may EDIT a legacy record', async () => {
      await assertSucceeds(dbFor(ADMIN).doc('appointments/appt_legacy_edit_admin').update({
        appointmentTitle: 'Old visit (admin edit)', updatedAt: serverTimestamp(),
      }));
    });
    it('adding orgId with the recipient\'s REAL org SUCCEEDS (verified backfill, owner)', async () => {
      await assertSucceeds(dbFor(OWNER).doc('appointments/appt_legacy_backfill').update({
        orgId: ORG_FAM, updatedAt: serverTimestamp(),
      }));
    });
    it('adding a WRONG orgId to a legacy record is DENIED', async () => {
      await assertFails(dbFor(OWNER).doc('appointments/appt_legacy_badorg').update({
        orgId: ORG_OTHER, updatedAt: serverTimestamp(),
      }));
    });
    it('attributing a legacy record to another uid is DENIED', async () => {
      await assertFails(dbFor(OWNER).doc('appointments/appt_legacy_badauthor').update({
        createdByUid: CAREGIVER, updatedAt: serverTimestamp(),
      }));
    });
    it('a stranger cannot edit a legacy record', async () => {
      await assertFails(dbFor(STRANGER).doc('appointments/appt_legacy_read').update({
        appointmentTitle: 'Hijacked', updatedAt: serverTimestamp(),
      }));
    });
    it('the owner CAN delete a legacy record', async () => {
      await assertSucceeds(dbFor(OWNER).doc('appointments/appt_legacy_del_owner').delete());
    });
    it('an ADMIN CAN delete a legacy record', async () => {
      await assertSucceeds(dbFor(ADMIN).doc('appointments/appt_legacy_del_admin').delete());
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
    // The doc must still carry the caller's orgId: the create rule is unchanged
    // (2026-11-19). The LIST rule no longer reads it — a doc WITHOUT orgId is
    // listable if it exists (see the legacy cases above); this only pins the
    // create contract the Add Meal form writes.
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
// ---------------------------------------------------------------------------
// APP QUERY SHAPES — the EXACT queries the shipped pages run against the three
// get()-based LIST rules (vitalLogs / waterLogs / appointments).
//
// Those three collections allow `list` with the full canAccessRecipientRef gate,
// which reads the document via get(resource.data.careRecipientRef). A LIST rule
// may only read a field the QUERY ITSELF constrains, so the pages' queries all
// filter careRecipientRef and none of them filter orgId. The emulator probe of
// 2026-11-18 confirmed that a get()-based LIST rule PASSES for exactly that
// shape (a query that constrains careRecipientRef) and fails with
// "Property careRecipientRef is undefined on object" only when the query leaves
// it unconstrained. These cases pin the page-level shapes, including the
// orderBy/limit each page adds, so a future rules edit cannot quietly break a
// screen that currently works.
//
// Page sources:
//   lib/pages/e_vitals_tracker_log  -> careRecipientRef + orderBy logDateTime desc + limit 50
//   lib/components/daily_water_card -> careRecipientRef + orderBy intakeAt desc + limit
//   lib/calendar_page               -> careRecipientRef + orderBy appointmentDateTime asc
//   lib/reports/vitals_export       -> careRecipientRef + logDateTime range + orderBy logDateTime asc + limit
// ---------------------------------------------------------------------------
describe('APP QUERY SHAPES (exact where+orderBy+limit queries from the pages)', () => {
  const REC_QV = 'rec_qv'; // dedicated vitals recipient (isolation from other blocks)
  const REC_QW = 'rec_qw'; // dedicated water recipient
  const REC_QA = 'rec_qa'; // dedicated appointments recipient
  const VITALS_PAGE_LIMIT = 50;
  const WATER_CARD_LIMIT = 200;

  const minutesAgo = (m) => new Date(Date.now() - m * 60 * 1000);

  let QVref, QWref, QAvref;

  const vital = (ref, minutes, extra) => ({
    careRecipientRef: ref, orgId: ORG_FAM, logDateTime: minutesAgo(minutes),
    loggedByUid: CAREGIVER, systolic: 120, diastolic: 80, heartRate: 70, ...extra,
  });
  const intake = (ref, minutes) => ({
    careRecipientRef: ref, orgId: ORG_FAM, intakeAt: minutesAgo(minutes),
    loggedByUid: CAREGIVER, amount: 8, unit: 'fl_oz', amountFlOz: 8,
  });
  const appt = (ref, minutes, extra) => ({
    careRecipientRef: ref, orgId: ORG_FAM, appointmentTitle: 'Visit',
    appointmentDateTime: minutesAgo(minutes), createdByUid: CAREGIVER,
    createdAt: new Date(), updatedAt: new Date(), ...extra,
  });

  before(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      const set = (p, d) => db.doc(p).set(d);
      QVref = db.doc('careRecipients/' + REC_QV);
      QWref = db.doc('careRecipients/' + REC_QW);
      QAvref = db.doc('careRecipients/' + REC_QA);
      await set('careRecipients/' + REC_QV, { orgId: ORG_FAM });
      await set('careRecipients/' + REC_QW, { orgId: ORG_FAM });
      await set('careRecipients/' + REC_QA, { orgId: ORG_FAM });
      // the vitals recipient is also shared with the grantee org (share path)
      await set(`recipientShares/${REC_QV}/grants/${ORG_GRNT}`, { accessLevel: 'caregiver' });
      // three readings, oldest -> newest: qv_old (60m), qv_mid (30m), qv_new (5m)
      await set('vitalLogs/qv_old', vital(QVref, 60));
      await set('vitalLogs/qv_mid', vital(QVref, 30));
      await set('vitalLogs/qv_new', vital(QVref, 5));
      // three intakes: qw_old (60m), qw_mid (30m), qw_new (5m)
      await set('waterLogs/qw_old', intake(QWref, 60));
      await set('waterLogs/qw_mid', intake(QWref, 30));
      await set('waterLogs/qw_new', intake(QWref, 5));
      // two past visits + one FUTURE visit (the calendar must show it)
      await set('appointments/qa_old', appt(QAvref, 60 * 24));
      await set('appointments/qa_new', appt(QAvref, 60));
      await set('appointments/qa_future', appt(QAvref, -60 * 24 * 7));
    });
  });

  describe('vitals log page — careRecipientRef + orderBy logDateTime desc + limit 50', () => {
    it('family caregiver: the page query is ALLOWED and returns newest first', async () => {
      const snap = await dbFor(CAREGIVER)
        .collection('vitalLogs')
        .where('careRecipientRef', '==', QVref)
        .orderBy('logDateTime', 'desc')
        .limit(VITALS_PAGE_LIMIT)
        .get();
      const ids = snap.docs.map((d) => d.id);
      if (ids.join(',') !== 'qv_new,qv_mid,qv_old') {
        throw new Error('vitals page query did not return the 3 readings newest-first: ' + ids.join(','));
      }
    });

    it('the same shape with a smaller limit returns the newest N only', async () => {
      const snap = await dbFor(CAREGIVER)
        .collection('vitalLogs')
        .where('careRecipientRef', '==', QVref)
        .orderBy('logDateTime', 'desc')
        .limit(2)
        .get();
      const ids = snap.docs.map((d) => d.id);
      if (ids.join(',') !== 'qv_new,qv_mid') {
        throw new Error('limit did not take the newest 2: ' + ids.join(','));
      }
    });

    it('grantee (share, no org filter) can run the page query', async () => {
      await assertSucceeds(dbFor(GRANTEE)
        .collection('vitalLogs')
        .where('careRecipientRef', '==', QVref)
        .orderBy('logDateTime', 'desc')
        .limit(VITALS_PAGE_LIMIT)
        .get());
    });

    it('stranger (other org): the page query is DENIED', async () => {
      await assertFails(dbFor(STRANGER)
        .collection('vitalLogs')
        .where('careRecipientRef', '==', QVref)
        .orderBy('logDateTime', 'desc')
        .limit(VITALS_PAGE_LIMIT)
        .get());
    });

    it('vitals export shape (logDateTime range + orderBy asc + limit) is ALLOWED', async () => {
      const snap = await dbFor(OWNER)
        .collection('vitalLogs')
        .where('careRecipientRef', '==', QVref)
        .where('logDateTime', '>=', minutesAgo(45))
        .where('logDateTime', '<=', new Date())
        .orderBy('logDateTime', 'asc')
        .limit(2001) // kVitalsExportMaxRows + 1
        .get();
      const ids = snap.docs.map((d) => d.id);
      if (ids.join(',') !== 'qv_mid,qv_new') {
        throw new Error('bounded export query returned the wrong rows: ' + ids.join(','));
      }
    });
  });

  describe('daily water card — careRecipientRef + orderBy intakeAt desc + limit', () => {
    it('family caregiver: the card query is ALLOWED and returns newest first', async () => {
      const snap = await dbFor(CAREGIVER)
        .collection('waterLogs')
        .where('careRecipientRef', '==', QWref)
        .orderBy('intakeAt', 'desc')
        .limit(WATER_CARD_LIMIT)
        .get();
      const ids = snap.docs.map((d) => d.id);
      if (ids.join(',') !== 'qw_new,qw_mid,qw_old') {
        throw new Error('water card query did not return the 3 intakes newest-first: ' + ids.join(','));
      }
    });

    it('the same shape with limit 1 returns the newest intake (Undo target)', async () => {
      const snap = await dbFor(CAREGIVER)
        .collection('waterLogs')
        .where('careRecipientRef', '==', QWref)
        .orderBy('intakeAt', 'desc')
        .limit(1)
        .get();
      if (snap.docs.length !== 1 || snap.docs[0].id !== 'qw_new') {
        throw new Error('expected the newest intake qw_new, got ' + snap.docs.map((d) => d.id).join(','));
      }
    });

    it('stranger (other org): the card query is DENIED', async () => {
      await assertFails(dbFor(STRANGER)
        .collection('waterLogs')
        .where('careRecipientRef', '==', QWref)
        .orderBy('intakeAt', 'desc')
        .limit(WATER_CARD_LIMIT)
        .get());
    });
  });

  describe('calendar page — careRecipientRef + orderBy appointmentDateTime asc', () => {
    it('family caregiver: the calendar query is ALLOWED and returns ascending, future included', async () => {
      const snap = await dbFor(CAREGIVER)
        .collection('appointments')
        .where('careRecipientRef', '==', QAvref)
        .orderBy('appointmentDateTime', 'asc')
        .get();
      const ids = snap.docs.map((d) => d.id);
      if (ids.join(',') !== 'qa_old,qa_new,qa_future') {
        throw new Error('calendar query did not return the 3 visits ascending (future last): ' + ids.join(','));
      }
    });

    it('stranger (other org): the calendar query is DENIED', async () => {
      await assertFails(dbFor(STRANGER)
        .collection('appointments')
        .where('careRecipientRef', '==', QAvref)
        .orderBy('appointmentDateTime', 'asc')
        .get());
    });
  });
});

// ---------------------------------------------------------------------------
// careRecipients UPDATE — the VitalsTargets map (PR #63; owner-approved
// 2026-11-18, vitals-export proposal §13 item 2b). The per-recipient target
// ranges are ONE optional field on the existing careRecipients document, so
// they ride on the EXISTING update rule — `request.resource.data.orgId ==
// resource.data.orgId && canWriteRecipientData(docId)` — with no rules change.
// These cases pin that: whoever can already edit a recipient can set, change
// and clear the map; the rest of the document survives the merge update; a
// non-member and an unauthenticated caller cannot; and orgId stays immutable
// while targets are being written.
// ---------------------------------------------------------------------------
describe('careRecipients UPDATE — VitalsTargets (per-recipient target ranges)', () => {
  const assert = require('assert/strict');
  const ADMIN = 'uid_vt_admin'; // admin in org_fam

  const REC_SET      = 'rec_vt_set';      // no targets yet
  const REC_CHANGE   = 'rec_vt_change';   // already has targets
  const REC_CLEAR    = 'rec_vt_clear';    // already has targets
  const REC_ORG      = 'rec_vt_org';      // orgId immutability
  const REC_STRANGER = 'rec_vt_stranger'; // non-member write attempt
  const REC_UNAUTH   = 'rec_vt_unauth';   // unauthenticated write attempt

  // The stored shape: independent min/max per measurement, sides omitted when
  // the caregiver left the box blank (never written as 0).
  const targets = (over) => ({
    bloodPressureSystolic: { min: 90, max: 140 },
    heartRate: { min: 60 },
    temperature: { max: 99.5 },
    ...over,
  });

  const path = (id) => 'careRecipients/' + id;

  // Read the stored doc back as the org owner — used to prove a DENIED write
  // changed nothing and that a permitted merge left the other fields alone.
  const rawDoc = (id) => dbFor(OWNER).doc(path(id)).get().then((s) => s.data());

  before(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      const set = (p, d) => db.doc(p).set(d);
      await set('users/' + ADMIN, { activeGroupId: ORG_FAM });
      await set(`organizations/${ORG_FAM}/members/${ADMIN}`,
        { uid: ADMIN, role: 'admin', status: 'active' });
      // A recipient shaped like a real Care Profile: unrelated fields present
      // so a merge update can be shown to leave them untouched.
      const base = {
        Name: 'Margaret', orgId: ORG_FAM, TrackVitals: true,
        AdvanceDirectivesStatus: 'on_file', DateOfBirth: '1941-04-02',
      };
      await set(path(REC_SET), base);
      await set(path(REC_CHANGE), { ...base, VitalsTargets: targets() });
      await set(path(REC_CLEAR), { ...base, VitalsTargets: targets() });
      await set(path(REC_ORG), base);
      await set(path(REC_STRANGER), base);
      await set(path(REC_UNAUTH), base);
    });
  });

  // ---------------------------------------------------------------- set/change
  it('a family caregiver can SET VitalsTargets, and other fields survive', async () => {
    await assertSucceeds(dbFor(CAREGIVER).doc(path(REC_SET)).update({
      VitalsTargets: targets(),
    }));
    const d = await rawDoc(REC_SET);
    assert.deepEqual(d.VitalsTargets, targets());
    // The merge wrote only the target map.
    assert.equal(d.Name, 'Margaret');
    assert.equal(d.orgId, ORG_FAM);
    assert.equal(d.TrackVitals, true);
    assert.equal(d.AdvanceDirectivesStatus, 'on_file');
    assert.equal(d.DateOfBirth, '1941-04-02');
  });

  it('a family caregiver can CHANGE existing targets, other fields survive', async () => {
    await assertSucceeds(dbFor(CAREGIVER).doc(path(REC_CHANGE)).update({
      VitalsTargets: targets({ heartRate: { min: 55, max: 100 }, weight: { max: 150 } }),
    }));
    const d = await rawDoc(REC_CHANGE);
    assert.deepEqual(d.VitalsTargets,
      targets({ heartRate: { min: 55, max: 100 }, weight: { max: 150 } }));
    assert.equal(d.Name, 'Margaret');
    assert.equal(d.orgId, ORG_FAM);
  });

  it('a family caregiver can CLEAR targets by writing an empty map', async () => {
    await assertSucceeds(dbFor(CAREGIVER).doc(path(REC_CLEAR)).update({
      VitalsTargets: {},
    }));
    const d = await rawDoc(REC_CLEAR);
    assert.deepEqual(d.VitalsTargets, {});
    assert.equal(d.Name, 'Margaret');
  });

  it('the owner and an admin can also set targets', async () => {
    await assertSucceeds(dbFor(OWNER).doc(path(REC_ORG)).update({
      VitalsTargets: targets({ bloodGlucose: { min: 70, max: 180 } }),
    }));
    await assertSucceeds(dbFor(ADMIN).doc(path(REC_ORG)).update({
      VitalsTargets: targets({ bloodGlucose: { min: 70, max: 180 } }),
    }));
    const d = await rawDoc(REC_ORG);
    assert.deepEqual(d.VitalsTargets, targets({ bloodGlucose: { min: 70, max: 180 } }));
  });

  // ---------------------------------------------------------------- denials
  it('a NON-MEMBER cannot set targets (and nothing is written)', async () => {
    await assertFails(dbFor(STRANGER).doc(path(REC_STRANGER)).update({
      VitalsTargets: targets(),
    }));
    const d = await rawDoc(REC_STRANGER);
    assert.equal(d.VitalsTargets, undefined);
    assert.equal(d.Name, 'Margaret');
  });

  it('an UNAUTHENTICATED caller cannot set targets (and nothing is written)', async () => {
    const anon = env.unauthenticatedContext().firestore();
    await assertFails(anon.doc(path(REC_UNAUTH)).update({ VitalsTargets: targets() }));
    const d = await rawDoc(REC_UNAUTH);
    assert.equal(d.VitalsTargets, undefined);
    assert.equal(d.orgId, ORG_FAM);
  });

  // ---------------------------------------------------------------- orgId
  it('orgId stays IMMUTABLE — targets cannot be smuggled with an org transfer', async () => {
    await assertFails(dbFor(CAREGIVER).doc(path(REC_ORG)).update({
      VitalsTargets: targets({ weight: { max: 200 } }), orgId: ORG_OTHER,
    }));
    // …nor can orgId change on its own.
    await assertFails(dbFor(CAREGIVER).doc(path(REC_ORG)).update({ orgId: ORG_OTHER }));
    const d = await rawDoc(REC_ORG);
    assert.equal(d.orgId, ORG_FAM);
    // The denied writes left the previously-set targets exactly as they were.
    assert.deepEqual(d.VitalsTargets, targets({ bloodGlucose: { min: 70, max: 180 } }));
  });
});

// ---------------------------------------------------------------------------
// MEMBERSHIP STATUS HARDENING (owner-approved 2026-11-20).
//
// Existence of a member doc used to BE the active-membership test. A doc KEPT
// with status 'removed' (an owner/admin merge) or a uid-keyed doc with status
// 'invited' (which the members create rule permits) also exists, so both passed
// every gate: the recipient picker LIST, single-doc GET and write. These cases
// pin the ten identity classes against the four operations each could reach, and
// pin the two things that must NOT change: a LEGACY member doc with no `status`
// field keeps full access, and no role restriction moves (the change is
// narrowing-only — it can remove access, never grant it).
//
// Grantee/stranger orgs are deliberately distinct from each other: a grantee's
// activeGroupId is the org that HOLDS the share, so a stranger sharing it would
// inherit the grant.
// ---------------------------------------------------------------------------
describe('MEMBERSHIP STATUS — a non-active member doc grants nothing (2026-11-20)', () => {
  const assert = require('assert/strict');

  const ORG_MS       = 'org_ms';        // the org under test (family, owner: MS_OWNER)
  const ORG_MS_SHARE = 'org_ms_share';  // the grantee's own org — holds the share
  const ORG_MS_OUT   = 'org_ms_out';    // unrelated org — the stranger's

  const MS_OWNER     = 'uid_ms_owner';     // uid-keyed, owner,     status active
  const MS_ADMIN     = 'uid_ms_admin';     // uid-keyed, admin,     status active
  const MS_CAREGIVER = 'uid_ms_caregiver'; // uid-keyed, caregiver, status active
  const MS_VIEWER    = 'uid_ms_viewer';    // uid-keyed, viewer,    status active
  const MS_LEGACY    = 'uid_ms_legacy';    // uid-keyed, caregiver, NO status field
  const MS_INVITED   = 'uid_ms_invited';   // uid-keyed, caregiver, status invited
  const MS_REMOVED   = 'uid_ms_removed';   // uid-keyed, caregiver, status removed (KEPT)
  const MS_GRANTEE   = 'uid_ms_grantee';   // NO member doc; share to ORG_MS
  const MS_STRANGER  = 'uid_ms_stranger';  // member of ORG_MS_OUT only

  const MOM     = 'ms_mom';     // the recipient every identity tries to reach
  const MOM_DEL = 'ms_mom_del'; // owner-only delete target (deleted nowhere else)

  const momPath   = (id) => 'careRecipients/' + id;
  const memberPath = (uid) => `organizations/${ORG_MS}/members/${uid}`;
  // The app's exact picker query: no orderBy, no limit.
  const picker = (uid) =>
    dbFor(uid).collection('careRecipients').where('orgId', '==', ORG_MS);

  before(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      const set = (p, d) => db.doc(p).set(d);
      // users: every identity's activeGroupId is the org it acts from.
      for (const uid of [MS_OWNER, MS_ADMIN, MS_CAREGIVER, MS_VIEWER,
                         MS_LEGACY, MS_INVITED, MS_REMOVED]) {
        await set('users/' + uid, { activeGroupId: ORG_MS });
      }
      await set('users/' + MS_GRANTEE,  { activeGroupId: ORG_MS_SHARE });
      await set('users/' + MS_STRANGER, { activeGroupId: ORG_MS_OUT });
      // organizations
      await set('organizations/' + ORG_MS,       { kind: 'family', createdBy: MS_OWNER });
      await set('organizations/' + ORG_MS_SHARE, { kind: 'family', createdBy: MS_GRANTEE });
      await set('organizations/' + ORG_MS_OUT,   { kind: 'family', createdBy: MS_STRANGER });
      // members — the seven identity docs (the grantee has none)
      await set(memberPath(MS_OWNER),     { uid: MS_OWNER,     role: 'owner',     status: 'active' });
      await set(memberPath(MS_ADMIN),     { uid: MS_ADMIN,     role: 'admin',     status: 'active' });
      await set(memberPath(MS_CAREGIVER), { uid: MS_CAREGIVER, role: 'caregiver', status: 'active' });
      await set(memberPath(MS_VIEWER),    { uid: MS_VIEWER,    role: 'viewer',    status: 'active' });
      // LEGACY: written before the status field existed — no `status` key at all.
      await set(memberPath(MS_LEGACY),    { uid: MS_LEGACY,    role: 'caregiver' });
      // The two exploit states the current rules allow an owner/admin to create.
      await set(memberPath(MS_INVITED),   { uid: MS_INVITED,   role: 'caregiver', status: 'invited' });
      await set(memberPath(MS_REMOVED),   { uid: MS_REMOVED,   role: 'caregiver', status: 'removed' });
      await set(`organizations/${ORG_MS_SHARE}/members/${MS_GRANTEE}`,
        { uid: MS_GRANTEE, role: 'owner', status: 'active' });
      await set(`organizations/${ORG_MS_OUT}/members/${MS_STRANGER}`,
        { uid: MS_STRANGER, role: 'owner', status: 'active' });
      // recipients + the caregiver-level share to the grantee's org
      await set(momPath(MOM),     { orgId: ORG_MS });
      await set(momPath(MOM_DEL), { orgId: ORG_MS });
      await set(`recipientShares/${MOM}/grants/${ORG_MS_SHARE}`, { accessLevel: 'caregiver' });
    });
  });

  // --------------------------------------------------------------- ACTIVE roles
  it('owner (status active): picker list, GET, write and another member doc ALLOWED', async () => {
    await assertSucceeds(picker(MS_OWNER).get());
    await assertSucceeds(dbFor(MS_OWNER).doc(momPath(MOM)).get());
    await assertSucceeds(dbFor(MS_OWNER).doc(momPath(MOM)).update({ orgId: ORG_MS }));
    await assertSucceeds(dbFor(MS_OWNER).doc(memberPath(MS_CAREGIVER)).get());
  });

  it('admin (status active): picker list, GET, write and another member doc ALLOWED', async () => {
    await assertSucceeds(picker(MS_ADMIN).get());
    await assertSucceeds(dbFor(MS_ADMIN).doc(momPath(MOM)).get());
    await assertSucceeds(dbFor(MS_ADMIN).doc(momPath(MOM)).update({ orgId: ORG_MS }));
    await assertSucceeds(dbFor(MS_ADMIN).doc(memberPath(MS_OWNER)).get());
  });

  it('caregiver (status active): picker list, GET, write and another member doc ALLOWED', async () => {
    await assertSucceeds(picker(MS_CAREGIVER).get());
    await assertSucceeds(dbFor(MS_CAREGIVER).doc(momPath(MOM)).get());
    await assertSucceeds(dbFor(MS_CAREGIVER).doc(momPath(MOM)).update({ orgId: ORG_MS }));
    await assertSucceeds(dbFor(MS_CAREGIVER).doc(memberPath(MS_OWNER)).get());
  });

  it('viewer (status active): list and GET ALLOWED, WRITE DENIED (role restriction unchanged)', async () => {
    await assertSucceeds(picker(MS_VIEWER).get());
    await assertSucceeds(dbFor(MS_VIEWER).doc(momPath(MOM)).get());
    await assertFails(dbFor(MS_VIEWER).doc(momPath(MOM)).update({ orgId: ORG_MS }));
    await assertSucceeds(dbFor(MS_VIEWER).doc(memberPath(MS_OWNER)).get());
  });

  // ------------------------------------------------- THE regression that matters
  it('LEGACY member (no status field): list, GET, write and another member doc ALLOWED', async () => {
    const snap = await picker(MS_LEGACY).get().catch((e) => { throw e; });
    assert.ok(snap.docs.some((d) => d.id === MOM),
      'the legacy member must still see the recipient in the picker');
    await assertSucceeds(dbFor(MS_LEGACY).doc(momPath(MOM)).get());
    await assertSucceeds(dbFor(MS_LEGACY).doc(momPath(MOM)).update({ orgId: ORG_MS }));
    await assertSucceeds(dbFor(MS_LEGACY).doc(memberPath(MS_OWNER)).get());
  });

  it('LEGACY member (no status field) can still switch context INTO the org', async () => {
    // Start them out of context, then let them switch back in under the rules.
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('users/' + MS_LEGACY).set({ activeGroupId: ORG_MS_OUT });
    });
    await assertSucceeds(dbFor(MS_LEGACY).doc('users/' + MS_LEGACY)
      .update({ activeGroupId: ORG_MS }));
  });

  // ------------------------------------------------------- NON-ACTIVE (exploits)
  it('INVITED (uid-keyed, status invited): list, GET, write and member doc ALL DENIED', async () => {
    await assertFails(picker(MS_INVITED).get());
    await assertFails(dbFor(MS_INVITED).doc(momPath(MOM)).get());
    await assertFails(dbFor(MS_INVITED).doc(momPath(MOM)).update({ orgId: ORG_MS }));
    await assertFails(dbFor(MS_INVITED).doc(memberPath(MS_OWNER)).get());
  });

  it('REMOVED (kept doc, status removed): list, GET, write and member doc ALL DENIED', async () => {
    await assertFails(picker(MS_REMOVED).get());
    await assertFails(dbFor(MS_REMOVED).doc(momPath(MOM)).get());
    await assertFails(dbFor(MS_REMOVED).doc(momPath(MOM)).update({ orgId: ORG_MS }));
    await assertFails(dbFor(MS_REMOVED).doc(memberPath(MS_OWNER)).get());
  });

  it('REMOVED / INVITED keep their OWN member doc self-read (out of scope, unchanged)', async () => {
    await assertSucceeds(dbFor(MS_REMOVED).doc(memberPath(MS_REMOVED)).get());
    await assertSucceeds(dbFor(MS_INVITED).doc(memberPath(MS_INVITED)).get());
  });

  it('REMOVED / INVITED cannot switch context INTO the org (isValidGroupContext)', async () => {
    // Both start out of context, so the switch is a real diff (not a no-op).
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.doc('users/' + MS_REMOVED).set({ activeGroupId: ORG_MS_OUT });
      await db.doc('users/' + MS_INVITED).set({ activeGroupId: ORG_MS_OUT });
    });
    await assertFails(dbFor(MS_REMOVED).doc('users/' + MS_REMOVED)
      .update({ activeGroupId: ORG_MS }));
    await assertFails(dbFor(MS_INVITED).doc('users/' + MS_INVITED)
      .update({ activeGroupId: ORG_MS }));
  });

  // --------------------------------------------------------------- GRANTEE (share)
  it('grantee (no member doc) keeps GET and WRITE via the share branch', async () => {
    await assertSucceeds(dbFor(MS_GRANTEE).doc(momPath(MOM)).get());
    await assertSucceeds(dbFor(MS_GRANTEE).doc(momPath(MOM)).update({ orgId: ORG_MS }));
  });

  it('grantee still CANNOT list the org\'s recipients (unchanged: no member doc)', async () => {
    await assertFails(picker(MS_GRANTEE).get());
  });

  // ------------------------------------------------------ STRANGER / SIGNED OUT
  it('stranger (member of another org only): everything DENIED', async () => {
    await assertFails(picker(MS_STRANGER).get());
    await assertFails(dbFor(MS_STRANGER).doc(momPath(MOM)).get());
    await assertFails(dbFor(MS_STRANGER).doc(momPath(MOM)).update({ orgId: ORG_MS }));
    await assertFails(dbFor(MS_STRANGER).doc(memberPath(MS_OWNER)).get());
  });

  it('signed out: everything DENIED', async () => {
    const anon = env.unauthenticatedContext().firestore();
    await assertFails(anon.collection('careRecipients').where('orgId', '==', ORG_MS).get());
    await assertFails(anon.doc(momPath(MOM)).get());
    await assertFails(anon.doc(momPath(MOM)).update({ orgId: ORG_MS }));
    await assertFails(anon.doc(memberPath(MS_OWNER)).get());
  });

  // -------------------------------------------- role restrictions stay put (3)
  it('admin cannot create an OWNER member doc (role restriction unchanged)', async () => {
    await assertFails(dbFor(MS_ADMIN).doc(memberPath('uid_ms_new')).set({
      uid: 'uid_ms_new', role: 'owner', status: 'invited',
      invitedEmail: 'new@example.com',
    }));
    // …but the same invite as a caregiver is still permitted.
    await assertSucceeds(dbFor(MS_ADMIN).doc(memberPath('uid_ms_new2')).set({
      uid: 'uid_ms_new2', role: 'caregiver', status: 'invited',
      invitedEmail: 'new2@example.com',
    }));
  });

  it('owner retains DELETE of a recipient; caregiver still cannot', async () => {
    await assertFails(dbFor(MS_CAREGIVER).doc(momPath(MOM_DEL)).delete());
    await assertSucceeds(dbFor(MS_OWNER).doc(momPath(MOM_DEL)).delete());
  });

  it('a kept REMOVED owner/admin doc grants nothing (delete + org update DENIED)', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.doc(`organizations/${ORG_MS}/members/uid_ms_removed_owner`).set({
        uid: 'uid_ms_removed_owner', role: 'owner', status: 'removed',
      });
      await db.doc('users/uid_ms_removed_owner').set({ activeGroupId: ORG_MS });
    });
    await assertFails(dbFor('uid_ms_removed_owner').doc('organizations/' + ORG_MS)
      .update({ displayName: 'x' }));
    await assertFails(dbFor('uid_ms_removed_owner').doc(momPath(MOM)).delete());
  });
});
