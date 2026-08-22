# Firestore security-rules regression tests

This is the permanent CI regression gate for the Firestore security ruleset
([`firebase/firestore.rules`](../firestore.rules)). It exercises the
Phase-4 deny-by-default authorization matrix against the **Firestore
emulator**, using [`@firebase/rules-unit-testing`](https://www.npmjs.com/package/@firebase/rules-unit-testing)
and **mocha**.

The test suite ([`firestore.rules.test.js`](./firestore.rules.test.js))
**loads the real rules file from the repo at runtime**
(`fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'))`) — there is
no hardcoded copy, so whatever the rules say is exactly what gets tested.
Any future edit to the rules is automatically covered and must keep all 16
assertions green or CI fails.

The test runner (`firebase/package.json`) lives at the **`firebase/` root**
(beside `firebase/firestore.rules` and the real `firebase/firebase.json`) so
`firebase emulators:exec` resolves the rules from within the project directory.

## What it covers (16 assertions)

- **Owner of a family org** — `careRecipients` read succeeds (the
  previously-failing path-legacy case); `organizations`/`members`/`users`
  self-reads still succeed; `recipientShares` manager read; `carechecklist`
  subcollection read/write gated on parent; ref-linked
  `careNotes`/`mealEntries`/`symptomEntries` reads gated on their
  `careRecipientRef`/`patientRef`; a careNote referencing a **different-org**
  recipient is denied; ref-linked create/update gated; a **stranger** creating
  a careNote against the owner recipient is denied.
- **Grantee** (via `recipientShares`) — shared recipient + ref-linked data
  accessible; the grantee cannot read the `recipientShares` management doc
  (owner-org only).
- **Stranger / non-member** (member of a different org) — denied on another
  org's careRecipients, careNotes, mealEntries, symptomEntries, carechecklist,
  recipientShares, org doc, and member doc; self `users` read still works; own-
  org recipient still readable.
- **Professional org (D6/D7 assignment scoping)** — org **owner** (assignment-
  free branch) reads recipient + ref-linked note; professional **caregiver
  without an active assignment is denied** (assignment requirement is not
  bypassed; the `assignments` collection is D9-empty in v1).

Deny-by-default holds throughout.

## Requirements

- Node.js 18+ (CI uses Node 20; local dev boxes use 18/20).
- Java 11+ (the Firestore emulator runs as a JVM jar; firebase-tools
  auto-downloads it on first use).
- No Flutter/firebase project login needed — the emulator runs fully offline
  against the fake project id `carerecipients`.

## Run locally

```bash
cd firebase
npm install
npm test
```

`npm test` runs
`firebase emulators:exec --only firestore --project carerecipients "mocha tests/firestore.rules.test.js --timeout 60000"`.
It starts the Firestore emulator on **port 8081** (pinned by
`emulators.firestore.port` in [`firebase/firebase.json`](../firebase.json); the
test connects to the same port via `initializeTestEnvironment`), runs the
suite, and shuts the emulator down. The 60s mocha timeout accommodates the
cold-start emulator + rules-push in `before()`; the individual assertions run
in milliseconds.

### Manual emulator (optional, for debugging)

```bash
cd firebase
npx firebase emulators:start --only firestore --project carerecipients
# in a second shell:
cd firebase && npx mocha tests/firestore.rules.test.js
```

## CI

`.github/workflows/ci.yml` has a dedicated `rules-tests` job that checks out
the repo, installs the `firebase` dev dependencies, and runs `npm test` from
`firebase`. It runs alongside (and independently of) the existing `build` job
(flutter analyze / test / build web) — a rules regression fails the build
without touching the Flutter gate.

## Notes

- The `.firebaserc` / project login is deliberately avoided: `--project
  carerecipients` + `--only firestore` is sufficient for a fully offline,
  hermetic emulator run.
- If the Firestore emulator port ever changes, update `EMULATOR_PORT` in
  [`firestore.rules.test.js`](./firestore.rules.test.js) to match.
