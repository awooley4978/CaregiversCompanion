# Security Manual Checklist (§5.3)

**Phase 5 hardening — document deliverable.** This checklist operationalizes
§5.3 of the security design (`/home/team/shared/security-design-proposal.md`)
so an **engineer or the owner** can run it by hand against the **Firebase
console**, the **Rules Playground**, and the **local Firestore emulator**
(equivalently, `@firebase/rules-unit-testing` or the REST API). It is a
*verification* playbook for the Phase-4 rules lockdown — **run nothing here
against production data unless you have an explicit, owner-approved window and
a backup-first plan** (see the rollback one-liner at the end and
`docs/security/rules-rollback.md` / `docs/security/rules-deploy.md`).

> Status: this is a **document**. The Phase-4 rules flip is still
> owner-gated, and executing any of these steps against the live project is
> out of scope until the flip is approved and the app release ships in the
> same window (§5.2 item 6).

---

## 0. Before you start

- Confirm the currently deployed ruleset matches the repo file
  (`firebase/firestore.rules`) **before and after** the flip — the deployed
  rules drifted from git historically (§5.2 item 8 / §6.3 item 8), so diff
  first.
- Record the current counts you can read: `careRecipients` (2 live, claimed),
  `symptomEntries` (1 live), `mealEntries` (unreadable pre-flip).
- Emulator / tooling: run the automated suite first — it is the fast, complete
  gate — then use this checklist for the human-verifiable, console-visible
  outcomes. The automated equivalent is `firebase/tests/firestore.rules.test.js`
  (wired into CI as a permanent gate, PR #8).

---

## 1. Rules Playground: unauthenticated reads → DENIED

For **every** collection below, open the Firestore console → **Rules →
Playground**, set auth to **unauthenticated**, and simulate a `get`/`list` on
a sample path. All must be **DENIED**.

| Collection | Sample path to simulate | Expected |
|---|---|---|
| `careRecipients` | `careRecipients/any` | DENIED |
| `careNotes` | `careNotes/any` | DENIED |
| `symptomEntries` | `symptomEntries/any` | DENIED |
| `mealEntries` | `mealEntries/any` | DENIED |
| `carechecklist` | `carechecklist` (subcollection) | DENIED |
| `users` | `users/any` | DENIED |
| `organizations` | `organizations/any` | DENIED |
| members | `organizations/any/members/any` | DENIED |
| `recipientShares` | `recipientShares/any/grants/any` | DENIED |
| `assignments` | `assignments/any/any` | DENIED |

All six dead domains (`medications`, `vitalLogs`, `appointments`,
`emergencyInfo`, `dashboardNotes`, `calendar`/dead schemas) are explicitly
denied until wired (§4.2) — add them to the list the same way.

## 2. Rules Playground: member vs non-member reads

Pick a real or seeded recipient and its org. Hold the org/member setup fixed;
vary only the simulated caller.

| Simulated caller | Query | Expected |
|---|---|---|
| Active member of the recipient's org | `get careRecipients/{id}` | ALLOWED |
| Active member of the recipient's org | `list careRecipients where orgId == <their activeGroupId>` | ALLOWED (only that org's docs) |
| Non-member (signed-in user of another org) | `get careRecipients/{id}` (different org) | DENIED |
| Non-member cross-org | `list careRecipients where orgId == <other org>` | DENIED |
| Grantee-org member with an active share | `get careRecipients/{id}` | ALLOWED |
| Same caller **after the share doc is deleted** | `get careRecipients/{id}` | **DENIED** (grant revocation, §3.3) |

## 3. Two-account isolation test

Create two accounts **A** and **B**, each with its own auto-provisioned family
org (sign in → profile + org + `activeGroupId`).

Using the REST API with the project's **web API key** (unauthenticated
request) or the Rules Playground, verify:

- **A cannot read B's recipient** or its `careNotes` / `symptomEntries`
  (recipient-scoped child data) → all must return `PERMISSION_DENIED`.
- **A cannot list B's recipients** via `where('orgId', isEqualTo: <B's org>)`
  → empty result, no data leak.
- The reverse (B vs A) holds symmetrically.

This is the "public database hole is closed" proof.

## 4. Legacy-claim test

Baseline (2026-08-18): `careRecipients` = 2 docs claimed to
`org_RS3ViLLrypPFo6EJh9kFrAkI2983` (`migrationStatus: 'claimed'`),
`symptomEntries` = 1 doc, backed up at
`/home/team/shared/legacy-backup-20260818-032740`.

- **Owner** (member of the claiming org): sees their **2 recipients** and the
  **1 symptom entry** → ALLOWED.
- **Non-member** of that org: sees **none** (empty list / DENIED per doc).

## 5. Member-invite + role behavior

- Owner/admin invites `member@example.com` as **caregiver** → pending invite
  doc created (`organizations/{orgId}/members/{email}`,
  `status: 'invited'`).
- Non-owner/non-admin cannot create/revoke invites → DENIED.
- Invitee signs in with the exact invited email; app auto-accepts → the
  `email`-keyed invite is replaced by a `uid`-keyed `status: 'active'` member
  doc with the **invited role** (caregiver).
- A caregiver **cannot** be granted/used as owner via invite; roles are locked
  to the invite (admin/caregiver/viewer only).
- **Role behavior:** viewer = read-only (writes DENIED); caregiver = read +
  care-data edit but not org/owner/delete-recipient operations; owner-only
  operations (transfer, delete org) DENIED for everyone else.
- **Revocation:** owner/admin deletes the member doc → that member's next read
  of org data is **DENIED** and the app routes per §1.1 (stale-group → the
  Household / group picker). See §8 below for the app-side path.

## 6. Grant-revocation test

- Owner of a recipient's org creates `recipientShares/{recipientId}/grants/{granteeOrgId}`
  → grantee-org member read ALLOWED.
- Owner **deletes the share doc** → grantee-org member read **DENIED**
  immediately (§3.3, §6.3 item 3).
- App-side expectation: the grantee sees a clear "access was revoked" message
  and is returned to the recipient list — no crash (§1.1). (Grant *management*
  UI ships with the Professional product; the handler is model-ready.)

## 7. Group-switch test (D1)

For a user with **two memberships** in orgs A and B:

- While `users/{uid}.activeGroupId == A`, the app shows **only A's data**
  (all org-scoped queries filter by `activeGroupId`).
- Switch `activeGroupId` to B → **only B's data** is shown.
- Attempting to set `activeGroupId` to an org the user **does not belong to**
  → DENIED on write (rules validate the context against a real active
  membership).
- Stale-context behavior: after the user is removed from A but
  `activeGroupId` still reads A, a read of A's data is DENIED and the app
  routes to the Household picker rather than showing a raw error (§1.1,
  §6.3 item 4).

## 8. Sign-out / auth-state test

- Signed-in user signs out → app lands on `/login`; **no data screen is
  reachable** (the global router redirect denies every non-auth route).
- Signed-out user cannot deep-link to `/household`, `/aClientDirectory`, or
  any data route → redirected to `/login`.
- Sign-in moves the user away from `/login` onto the client directory.
- Covered by the automated widget tests: `test/auth_state_test.dart` and
  `test/widget_test.dart`.

## 9. App-side permission-denied UX (§1.1)

After a rules denial surfaces in the app (as a stream or write error), the
central handler (`lib/backend/permissions/permission_router.dart`) routes
consistently:

| Denial source (AccessSurface) | Routed destination |
|---|---|
| Care Circle group data (stale/deleted membership, bad `activeGroupId`) | Household / group picker |
| Professional assignment (revoked, or D7 `validUntil` passed) | "Assignment ended" state (`/assignment-ended`) |
| Revoked cross-org share | Recipient list + clear message |

Non-permission errors are surfaced normally (no special routing). Successful
paths are unchanged. Covered by `test/permission_errors_test.dart` and
`test/permission_router_test.dart`.

---

## Deferred until the Professional product exercises them (D6 / D7)

The following are **model-ready and rule-enforced in Phase 4** but have no
Professional UI yet, so they are **deferred to the Professional product
phase** — do not run them as pass/fail now:

- **D6 professional assignment matrix:** professional-org owner/admin reads
  any org recipient; a caregiver/viewer reads **only assigned** recipients
  (`assignments/{recipientId}/{staffUid}`, `status: 'active'`) — unassigned →
  DENIED; after the assignment doc is deleted → DENIED.
- **D7 temporary-team bounds:** a temporary assignment read **before
  `validUntil`** → ALLOWED; **after `validUntil`** → DENIED (hard cutoff),
  with the app routing to the "assignment ended" state.
- **Assignments write validation:** owner/admin of the recipient's org only;
  `staffUid` == path segment; `orgId` == recipient's orgId; recipient org
  `kind == 'organization'` (assignments rejected in family orgs);
  `status: 'active'` on create; under D7, `validUntil` (if present) > `request.time`
  at create.

Until the Professional product ships, the automated rules suite
(`firebase/tests/firestore.rules.test.js`) already asserts these matrix
branches so a regression is caught even though no human workflow exercises
them yet (design §6.3 item 9 / §5.3 CI additions).

---

## Rollback (one-liner from §5.3)

If the lockdown must be reverted (e.g. the app and rules did not ship in the
same window, §5.2 item 6), roll back to the previous **open** ruleset from
git, then redeploy:

```sh
git checkout <commit-before-flip> -- firebase/firestore.rules firebase/storage.rules \
  && firebase deploy --only firestore:rules,storage
```

Where `<commit-before-flip>` is the commit **before** the Phase-4 rules flip
(PR #5 `0df8ce0` is the flip; the parent `a6e611c` is the last pre-flip
state). Full context in `docs/security/rules-rollback.md`.
