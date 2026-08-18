# Security Phase 4 — Rules Rollback & Pre-Flip Checklist

**Applies to:** `firebase/firestore.rules` + `firebase/storage.rules` (the Phase-4
lockdown). Design reference: security-design-proposal.md §5.3 (rollback + safe
testing). Companion doc: `docs/security/rules-deploy.md` (the flip itself).

Both rules files are committed in git. The PRE-FLIP (allow-all) ruleset is in git
history on `main` (last pre-Phase-4 commit: `27ea454`, file unchanged by
Phases 1–3). Rolling back is a 2-command operation.

---

## 1. The rollback (2 commands)

```bash
# 1. Restore the old (open) ruleset from git — replaces the working-tree files
#    with the last committed pre-lockdown version:
git checkout <commit> -- firebase/firestore.rules firebase/storage.rules

# 2. Publish the restored ruleset:
firebase deploy --only firestore:rules,storage
#    (or: Firebase console -> Firestore -> Rules -> paste file contents -> Publish)
```

`<commit>` = the commit the rules are reverted to (e.g. `27ea454` for the
original allow-all ruleset, or any later commit whose rules you want to restore).
Deploying the old open ruleset reopens the database — that is the point of a
rollback: restore service immediately, then fix forward on a branch.

> **Console-only rollback:** console -> Firestore -> Rules -> paste the old file
> from `git show <commit>:firebase/firestore.rules` -> Publish. Same for
> Storage -> Rules.

**Why it works:** rules live in Firestore/Storage configuration, not in the app.
There is no app rollout and no data migration involved; the old ruleset is
exactly as it was before the flip.

---

## 2. Pre-flip manual checklist (§5.3 items 1–6, condensed)

Run all of these BEFORE publishing the locked-down ruleset. Any failure = stop
the flip, fix, re-run.

1. **Rules Playground** (Firestore console -> Rules -> Playground), with the NEW
   ruleset staged:
   - Unauthenticated read of each collection -> **DENIED**.
   - A member reading an owned recipient -> **allowed**.
   - A non-member reading that recipient -> **DENIED**.
   - A grantee-org member reading a shared recipient -> **allowed**; after
     deleting the share doc -> **DENIED**.
   - (Professional org, when exercised: owner/admin read any org recipient;
     caregiver reads only an assigned one — unassigned DENIED; after deleting
     the assignment doc DENIED; temporary assignment before `validUntil`
     allowed, after DENIED.)
2. **Two-account isolation:** accounts A and B each with their own family org —
   A cannot read B's recipient or its notes. An UNAUTHENTICATED request (REST
   curl with the public web API key) returns `PERMISSION_DENIED` — proves the
   public hole is closed.
3. **Legacy-claim test:** after the claim ran, the owner sees their 2 recipients
   (and the 1 symptom entry); a non-member sees none.
4. **Revocation tests:** invite member B -> B has access -> delete B's member doc
   -> B's next read errors (app handles it). Create a share -> grantee access
   works -> delete the share doc -> grantee denied.
5. **Group-switch test (D1):** a user with two memberships switches
   `activeGroupId` -> sees org A's data only while A is active, org B's only
   while B is active; the write rule rejects a switch to an org they do not
   belong to.
6. **Sign-out test:** signed-in user signs out -> app lands on `/login`, no data
   screens reachable.

Also confirm before the flip (deployment prerequisites):

- [ ] Legacy claim has RUN (§5.1(c): the 2 `careRecipients` docs carry
      `orgId` + `migrationStatus: 'claimed'`) **and** the orphaned
      `symptomEntries` doc decision is resolved.
- [ ] Owner sign-off for the flip is recorded.
- [ ] The app release carrying the auth UI (Phases 1–3) is deployed alongside
      the rules flip (§5.2 item 6 — otherwise the published web app breaks for
      unauthenticated visitors).
- [ ] Deployed-vs-git divergence is reviewed (see rules-deploy.md §3) and the
      console's CURRENT deployed ruleset is diffed before publishing.

---

## 3. If something goes wrong after the flip

1. Run the 2-command rollback above (or console paste) — service is restored
   immediately; the app needs no change.
2. Keep the locked-down ruleset on the feature branch; do not delete it.
3. Reproduce, fix forward on a branch, re-run the checklist, re-flip.

The deployed ruleset is the live contract. Git is the source of record for what
was deployed and how to return to any prior state.
