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

// ---------------------------------------------------------------- GRANTEE (share)
describe('GRANTEE (recipientShares share to org_fam recipient)', () => {
  it('recipient data accessible via active share', async () => {
    await assertSucceeds(dbFor(GRANTEE).doc('careRecipients/'+REC_F1).get());
    await assertSucceeds(dbFor(GRANTEE).doc('careNotes/note1').get());
    await assertSucceeds(dbFor(GRANTEE).doc('mealEntries/meal1').get());
    await assertSucceeds(dbFor(GRANTEE).doc('symptomEntries/sym1').get());
  });
  it('grantee CANNOT read the recipientShares management doc (owner-org only)', async () => {
    await assertFails(dbFor(GRANTEE).doc(`recipientShares/${REC_F1}/grants/${ORG_GRNT}`).get());
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
