# Security Phase 4 — Deployment Instructions (the rules flip)

**Applies to:** `firebase/firestore.rules` + `firebase/storage.rules`.
**Gated:** the flip is the LAST step of the migration (§5.1(d)) — it must NOT
run until (a) the legacy claim has run, (b) the owner signs off, and (c) the app
release with the auth UI is deployed. See `docs/security/rules-rollback.md` for
the pre-flip checklist and the 2-command rollback.

The flip itself is a 2-command / 1-publish operation. There is no app rebuild:
Firestore rules live in project configuration, not in the app.

---

## 1. What the flip publishes

- **`firebase/firestore.rules`** — the Phase-4 deny-by-default ruleset
  (owner-approved design §4: org membership gates, `activeGroupId` validation,
  `recipientShares` grants, `assignments` model-ready, dead collections denied).
- **`firebase/storage.rules`** — deny-by-default alignment (§4.4). Inert (the
  app does not use Cloud Storage) but safe to publish alongside.
- **Indexes: UNCHANGED.** `firebase/firestore.indexes.json` is untouched by this
  phase — the rules use only direct `get()`/`exists()` calls, never queries, so
  no new index is implied (§4.4). The two existing indexes (careNotes
  `careRecipientRef, createdAt DESC`; symptomEntries `patientRef, timeLogged
  DESC`) remain as-is. Future indexes (grants collectionGroup, assignments
  collectionGroup) are needed only when their queries ship (D4/D9) — NOT now.

---

## 2. Option A — Firebase console (no CLI, no service account)

1. Open the Firebase console for project **carerecipients**.
2. **Firestore Database -> Rules** tab.
3. **READ THE CURRENT DEPLOYED RULES** and diff them against this repo's file
   (see §3 — they are known to differ; do not skip this).
4. Replace the editor contents with the exact contents of
   `firebase/firestore.rules` (from git, `main` or this PR's branch).
5. Click **Publish**.
6. **Storage -> Rules**: repeat steps 3–5 with `firebase/storage.rules`.
   (Skip if the project has no Storage bucket — storage is unused by the app.)
7. Sanity-check with the Rules Playground and the checklist in
   `rules-rollback.md` §2 before leaving.

## 3. Option B — Firebase CLI (service account)

```bash
# Requires: firebase CLI installed, a service account or owner login with
# Firestore/Rules permission, and firebase.json pointing at these files
# (it already does: "firestore": { "rules": "firestore.rules" }).
firebase login            # or: export GOOGLE_APPLICATION_CREDENTIALS=...
firebase use carerecipients
firebase deploy --only firestore:rules   # publishes firebase/firestore.rules
firebase deploy --only storage           # publishes firebase/storage.rules
# If storage is unused in this project, firebase deploy --only firestore:rules
# alone is sufficient.
```

The **rollback** is the same 2 commands with the old file contents restored
(`git checkout <commit> -- firebase/firestore.rules` then deploy — full one-pager
in `rules-rollback.md`).

---

## 4. ⚠️ Deployed-vs-git divergence — read before publishing

**The rules currently DEPLOYED in the console differ from the rules committed in
git.** This was behavior-probed during the audit (2026-08-16): the deployed
ruleset returns **403 on `mealEntries`** even though the git file
(`27ea454`..`main`, allow-all) allows it — i.e. production has been running a
ruleset that is *stricter* than the repo in at least that one collection, and we
have no copy of its text.

**Consequences for the flipper:**

- **You cannot fetch the deployed rules text programmatically with the web API
  key** (reads of rules config are not exposed to web clients), so the diff must
  be done by eye in the console:
  1. Open Firestore -> Rules in the console and read the currently deployed
     ruleset.
  2. Diff it against `git show 27ea454:firebase/firestore.rules` (the committed
     allow-all baseline) and against this PR's `firebase/firestore.rules`.
  3. Any custom ruleset found (e.g. the mealEntries deny) is not owned by this
     repo — before overwriting it, note what it does and confirm it is safe to
     replace (the Phase-4 ruleset denies mealEntries to non-privileged users by
     design, so the known 403 behavior is preserved under the new rules for
     outsiders; org members gain read access through the ref-linked gates).
- After publishing, the deployed state and git agree again — the divergence is
  closed by this flip.

---

## 5. Sequencing reminder (what must already be true — §5.2)

| # | Prerequisite | Status |
|---|---|---|
| 1 | careRecipients queries org-scoped (`where('orgId','==',activeGroupId)`) | ✅ Phase 3 |
| 2 | careRecipients create writes `orgId` | ✅ Phase 3 |
| 3 | symptomEntries query recipient-scoped | ✅ Phase 3 |
| 4 | carechecklist create gated on a selected recipient | ✅ Phase 3 |
| 5 | null-ref writes gated (note_card / add_meal) | ✅ Phase 3 |
| 6 | **App release with auth UI deployed alongside the flip** | ⏳ RELEASE STEP |
| 7 | Legacy claim ran (`orgId` + `migrationStatus:'claimed'` on the 2 recipients) | ⏳ CLAIM STEP |
| 8 | Owner sign-off for the flip | ⏳ GATE |

Items 6–8 are the remaining gates. Do not publish this ruleset until 7 and 8 are
done and 6 is deployed in the same release (§5.2 item 6 — an auth-less web build
behind locked rules breaks for visitors).
