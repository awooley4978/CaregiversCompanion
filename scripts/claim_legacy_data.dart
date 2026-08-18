// scripts/claim_legacy_data.dart
//
// ONE-TIME LEGACY DATA CLAIM — Security Phase 3, Path B (design §5.1, Q14).
// Owner-executed, backup-first. NOT part of the app; a standalone script.
//
// RUN ORDER (owner review gate between each step):
//   1. BACKUP EXISTS:  the dump at /home/team/shared/legacy-backup-20260818-001046/
//      (manifest.json lists every collection + doc counts). The claim only
//      ever touches the doc ids IN THE BACKUP — nothing else.
//   2. DRY-RUN:        dart run scripts/claim_legacy_data.dart <ownerUid> --dry-run
//      (offline: prints exactly which docs would get orgId, from the backup).
//   3. OWNER APPROVAL: confirm the dry-run output matches the manifest
//      (2 careRecipients; the 1 symptomEntry is auto-claimed via patientRef).
//   4. RUN:            CLAIM_EMAIL=<owner-email> CLAIM_PASSWORD=<owner-password> \
//                        dart run scripts/claim_legacy_data.dart <ownerUid>
//
// WHAT IT DOES
//   * Sets orgId = 'org_<ownerUid>' AND migrationStatus = 'claimed' on the
//     backed-up careRecipients docs (design §5.1(c).2 — the claim writes BOTH
//     fields; §5.1(c).5: 'claimed' = migrated legacy doc). No other fields.
//   * The 1 symptomEntries doc is CHILD data: per design §5.1(c).3 it needs
//     NO orgId — it becomes visible automatically once its recipient is
//     claimed (rules derive access from the recipient's orgId). The script
//     cross-checks that the symptom doc's patientRef points at one of the
//     claimed recipients and reports "follows automatically" WITHOUT writing.
//   * Prints a before/after diff for every doc it touches. Idempotent:
//     already-claimed docs are reported and skipped; a doc already owned by a
//     DIFFERENT org is never overwritten.
//
// AUTH (no service account, no SDK)
//   * Signs in as the OWNER via the Firebase Auth REST API
//     (identitytoolkit, email/password from CLAIM_EMAIL / CLAIM_PASSWORD env)
//     and uses the returned ID token as the Bearer for Firestore REST.
//   * The script aborts if the signed-in account's uid != <ownerUid> — a
//     claim under the wrong account would mislabel every doc.
//   * The <ownerUid> argument is the owner's Firebase uid (shown in the app
//     after first sign-in). The org id derived from it is the SAME
//     deterministic id the app auto-provisions at first sign-in
//     (org_service.autoFamilyOrgId), so the claimed org must already exist
//     when the claim runs (sign into the app first).
//
// SAFETY
//   * Refuses to run without a readable backup dir.
//   * Dry-run makes NO network calls at all.
//   * In run mode every write is a two-field PATCH (updateMask=orgId +
//     migrationStatus); if the live doc no longer exists, it is skipped with
//     a warning (never recreated). A doc already carrying orgId +
//     migrationStatus='claimed' is skipped (idempotent).
//
// Environment: pure dart:io + dart:convert — no packages, no Flutter.
import 'dart:convert';
import 'dart:io';

const String kApiKey = 'AIzaSyDmnxlcnPGXUi4Sj1T7cbewRdgG9pB_4-k';
const String kProjectId = 'carerecipients';
const String kDefaultBackupDir = 'legacy-backup-20260818-001046';
/// The org id prefix — MUST match org_service.autoFamilyOrgId (=> 'org_$uid')
/// so the claimed org is exactly the one the owner's app auto-provisions.
const String kOrgPrefix = 'org_';
/// migrationStatus value written by this claim (design §5.1(c).5).
const String kMigrationStatusClaimed = 'claimed';
const String kDocBase =
    'https://firestore.googleapis.com/v1/projects/$kProjectId/'
    'databases/(default)/documents';
const String kAuthUrl =
    'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword';

void main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final ownerUid = args.firstWhere(
    (a) => !a.startsWith('--'),
    orElse: () => '',
  );
  var backupDir = kDefaultBackupDir;
  final dirIdx = args.indexOf('--backup-dir');
  if (dirIdx >= 0 && dirIdx + 1 < args.length) {
    backupDir = args[dirIdx + 1];
  }

  if (ownerUid.isEmpty) {
    _usage();
    exitCode = 64;
    return;
  }

  // 0. The backup is the source of truth for WHAT gets touched.
  final backup = _loadBackup(backupDir);
  if (backup == null) {
    stderr.writeln('ABORT: backup not readable at "$backupDir".');
    stderr.writeln(
        'The claim must run against the dump created at '
        '/home/team/shared/legacy-backup-20260818-001046/ (backup-first, '
        'design §5.1). Pass --backup-dir <path> if it lives elsewhere.');
    exitCode = 1;
    return;
  }

  final orgId = '${kOrgPrefix}$ownerUid';
  final recipients = backup['careRecipients']!;
  final symptomDoc = backup['symptomEntries'] != null &&
          (backup['symptomEntries'] as List).isNotEmpty
      ? (backup['symptomEntries'] as List).first as Map<String, dynamic>
      : null;

  stdout.writeln('=== Caregivers Companion — legacy data claim (Path B) ===');
  stdout.writeln('ownerUid : $ownerUid');
  stdout.writeln('orgId    : $orgId');
  stdout.writeln('backup   : $backupDir');
  stdout.writeln('mode     : ${dryRun ? 'DRY-RUN (no network, no writes)' : 'RUN'}');
  stdout.writeln('claimed careRecipients from backup: ${recipients.length}');
  for (final r in recipients) {
    stdout.writeln('  - ${r['id']}');
  }

  // 1. Symptom-entry link check FIRST (aborts a real run before any write).
  final check = _checkSymptomLink(symptomDoc, recipients);
  stdout.writeln('symptomEntries: ${check.message}');
  if (!check.ok) {
    stderr.writeln('ABORT: the backed-up symptom entry does not resolve to a '
        'claimed recipient — do NOT proceed until an engineer reviews the '
        'backup (design §5.1: child docs become visible via the recipient).');
    exitCode = 1;
    return;
  }

  if (dryRun) {
    stdout.writeln();
    stdout.writeln('DRY-RUN — would PATCH (two fields, '
        'updateMask=orgId,migrationStatus):');
    for (final r in recipients) {
      stdout.writeln('  PATCH careRecipients/${r['id']}');
      stdout.writeln('    orgId: (absent) -> $orgId');
      stdout.writeln('    migrationStatus: (absent) -> $kMigrationStatusClaimed');
    }
    stdout.writeln();
    stdout.writeln('No network calls were made. Review this output against the '
        'manifest, then run without --dry-run (see header comment).');
    return;
  }

  // 2. Real run: authenticate as the owner.
  final email = Platform.environment['CLAIM_EMAIL'];
  final password = Platform.environment['CLAIM_PASSWORD'];
  if (email == null || email.isEmpty || password == null || password.isEmpty) {
    stderr.writeln('ABORT: CLAIM_EMAIL and CLAIM_PASSWORD must be set for a '
        'real run (owner email/password — the same account whose uid is '
        '<ownerUid>).');
    exitCode = 64;
    return;
  }
  final token = await _signIn(email, password, ownerUid);
  if (token == null) {
    exitCode = 1;
    return;
  }

  // 3. Preflight: the claimed org should already exist (created by the
  //    owner's app sign-in). Best-effort — report, don't block.
  await _preflight(ownerUid, orgId, token);

  // 4. Claim each backed-up recipient: GET before -> PATCH orgId -> GET after.
  stdout.writeln();
  stdout.writeln('Claiming ${recipients.length} careRecipients doc(s)...');
  var patched = 0, skipped = 0;
  for (final r in recipients) {
    final result = await _claimOne(r['id'] as String, orgId, token);
    if (result == 'patched') {
      patched++;
    } else if (result == 'skipped') {
      skipped++;
    }
  }

  stdout.writeln();
  stdout.writeln('=== SUMMARY ===');
  stdout.writeln('patched : $patched');
  stdout.writeln('skipped : $skipped (already claimed or doc gone)');
  stdout.writeln('symptom : ${check.message}');
  stdout.writeln('Next    : Phase 4 rules flip; verify the owner sees their '
      'recipients and the 1 symptom entry (§5.3 manual checklist).');
}

// ---------------------------------------------------------------------------
// Backup loading
// ---------------------------------------------------------------------------

Map<String, List<Map<String, dynamic>>>? _loadBackup(String dir) {
  Map<String, dynamic>? manifest;
  try {
    manifest = jsonDecode(File('$dir/manifest.json').readAsStringSync())
        as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
  final collections = manifest['collections'] as Map<String, dynamic>;
  // The claim targets ONLY collections the backup could read ('ok' status).
  final ok = collections.entries
      .where((e) => (e.value as Map<String, dynamic>)['status'] == 'ok')
      .map((e) => e.key)
      .toList();
  final out = <String, List<Map<String, dynamic>>>{};
  for (final col in ok) {
    try {
      final docs = jsonDecode(File('$dir/$col.json').readAsStringSync())
          as List<dynamic>;
      out[col] = docs.map((d) {
        final doc = d as Map<String, dynamic>;
        final name = doc['name'] as String;
        return {
          'id': name.split('/').last,
          'name': name,
          'fields': (doc['fields'] as Map<String, dynamic>?) ?? const {},
        };
      }).toList();
    } catch (_) {
      stderr.writeln('WARNING: could not read backup file $dir/$col.json — '
          'treating as empty.');
      out[col] = [];
    }
  }
  return out;
}

/// Extracts the document path from a Firestore referenceValue string.
String? _refPath(dynamic referenceValue) {
  if (referenceValue is! String || referenceValue.isEmpty) {
    return null;
  }
  final idx = referenceValue.indexOf('/documents/');
  return idx < 0 ? null : referenceValue.substring(idx + '/documents/'.length);
}

String _lastSegment(String path) => path.split('/').last;

({bool ok, String message}) _checkSymptomLink(
  Map<String, dynamic>? symptomDoc,
  List<Map<String, dynamic>> recipients,
) {
  if (symptomDoc == null) {
    return (ok: true, message: 'none backed up — nothing to link-check');
  }
  final fields = symptomDoc['fields'] as Map<String, dynamic>;
  final refValue = fields['patientRef'] is Map<String, dynamic>
      ? (fields['patientRef'] as Map<String, dynamic>)['referenceValue']
      : null;
  final refPath = _refPath(refValue);
  if (refPath == null) {
    return (
      ok: false,
      message:
          'doc ${symptomDoc['id']} has NO patientRef — it would stay orphaned '
          'under the Phase-4 rules',
    );
  }
  final claimedIds = recipients.map((r) => r['id']).toSet();
  if (!claimedIds.contains(_lastSegment(refPath))) {
    return (
      ok: false,
      message:
          'doc ${symptomDoc['id']} points at $refPath — NOT one of the '
          'claimed recipients',
    );
  }
  return (
    ok: true,
    message: 'doc ${symptomDoc['id']} → patientRef $refPath is a claimed '
        'recipient: follows automatically once claimed, NO orgId write '
        '(design §5.1 — child docs stay recipient-scoped)',
  );
}

// ---------------------------------------------------------------------------
// REST helpers
// ---------------------------------------------------------------------------

Future<HttpClientResponse> _send(
  String method,
  String url, {
  Map<String, dynamic>? body,
  String? token,
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, Uri.parse(url));
    request.headers.contentType = ContentType.json;
    if (token != null && token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (body != null) {
      request.write(jsonEncode(body));
    }
    return await request.close();
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, dynamic>?> _getJson(String url, {String? token}) async {
  final response = await _send('GET', url, token: token);
  final text = await response.transform(utf8.decoder).join();
  if (response.statusCode >= 200 && response.statusCode < 300) {
    return text.isEmpty ? <String, dynamic>{} : jsonDecode(text) as Map<String, dynamic>;
  }
  stderr.writeln('GET $url -> HTTP ${response.statusCode}: $text');
  return null;
}

Future<Map<String, dynamic>?> _patchJson(
  String url,
  Map<String, dynamic> body, {
  required String token,
}) async {
  final response = await _send('PATCH', url, body: body, token: token);
  final text = await response.transform(utf8.decoder).join();
  if (response.statusCode >= 200 && response.statusCode < 300) {
    return jsonDecode(text) as Map<String, dynamic>;
  }
  stderr.writeln('PATCH $url -> HTTP ${response.statusCode}: $text');
  return null;
}

/// Signs in with email/password via the Firebase Auth REST API and verifies
/// the account is the intended owner (localId == ownerUid). Returns the ID
/// token, or null on failure (exitCode already set).
Future<String?> _signIn(String email, String password, String ownerUid) async {
  final url = '$kAuthUrl?key=$kApiKey';
  final response = await _send('POST', url, body: {
    'email': email,
    'password': password,
    'returnSecureToken': true,
  });
  final text = await response.transform(utf8.decoder).join();
  if (response.statusCode < 200 || response.statusCode >= 300) {
    stderr.writeln('Sign-in failed (HTTP ${response.statusCode}): $text');
    exitCode = 1;
    return null;
  }
  final data = jsonDecode(text) as Map<String, dynamic>;
  final localId = data['localId'] as String?;
  if (localId != ownerUid) {
    stderr.writeln('ABORT: signed in as "$localId" but ownerUid is '
        '"$ownerUid" — refusing to claim under the wrong account.');
    exitCode = 1;
    return null;
  }
  stdout.writeln('Authenticated as $localId (matches ownerUid).');
  return data['idToken'] as String?;
}

Future<void> _preflight(String ownerUid, String orgId, String token) async {
  // The org + membership are auto-created when the owner signs into the app
  // (org_service.ensureOrgMembership). Report, don't block: the PATCH result
  // below is the real signal.
  final usersDoc =
      await _getJson('$kDocBase/users/$ownerUid', token: token);
  final activeGroupId = usersDoc == null
      ? null
      : (usersDoc['fields'] as Map<String, dynamic>?)?['activeGroupId']
          ?['stringValue'];
  stdout.writeln('preflight users/$ownerUid: ${activeGroupId == null ? 'not readable' : 'activeGroupId=$activeGroupId'}');
  if (activeGroupId != null && activeGroupId != orgId) {
    stderr.writeln('WARNING: the owner profile\'s activeGroupId '
        '($activeGroupId) differs from $orgId — the app may be pointing at a '
        'different group. Confirm before continuing.');
  }
  final orgDoc =
      await _getJson('$kDocBase/organizations/$orgId', token: token);
  stdout.writeln('preflight organizations/$orgId: '
      '${orgDoc == null ? 'NOT FOUND or not readable' : 'exists'}');
  if (orgDoc == null) {
    stderr.writeln('WARNING: could not confirm the org exists. Sign into the '
        'app once with the owner account (this auto-creates the org), then '
        're-run the claim.');
  }
}

/// Claims a single recipient: GET before -> PATCH orgId + migrationStatus ->
/// GET after. Returns 'patched', or 'skipped' (already claimed, doc gone, or
/// owned by a DIFFERENT org — never overwritten).
Future<String> _claimOne(String id, String orgId, String token) async {
  final url = '$kDocBase/careRecipients/$id';
  final before = await _getJson(url, token: token);
  if (before == null) {
    stderr.writeln('  SKIP careRecipients/$id: live doc not readable (gone '
        'or denied) — left untouched.');
    return 'skipped';
  }
  final fields = (before['fields'] as Map<String, dynamic>?) ?? const {};
  final currentOrgId = fields['orgId'] is Map<String, dynamic>
      ? (fields['orgId'] as Map<String, dynamic>)['stringValue']
      : null;
  final currentStatus = fields['migrationStatus'] is Map<String, dynamic>
      ? (fields['migrationStatus'] as Map<String, dynamic>)['stringValue']
      : null;
  if (currentOrgId != null && currentOrgId.isNotEmpty) {
    if (currentOrgId != orgId) {
      stdout.writeln('  SKIP careRecipients/$id: already owned by '
          '"$currentOrgId" (not $orgId) — never overwrite.');
      return 'skipped';
    }
    if (currentStatus == kMigrationStatusClaimed) {
      stdout.writeln('  SKIP careRecipients/$id: already claimed '
          '(orgId=$currentOrgId, migrationStatus=claimed).');
      return 'skipped';
    }
  }

  stdout.writeln('  PATCH careRecipients/$id');
  stdout.writeln('    orgId: ${currentOrgId ?? '(absent)'} -> $orgId');
  stdout.writeln('    migrationStatus: ${currentStatus ?? '(absent)'} -> '
      '$kMigrationStatusClaimed');
  final patched = await _patchJson(
    '$url?updateMask.fieldPaths=orgId&updateMask.fieldPaths=migrationStatus',
    {
      'fields': {
        'orgId': {'stringValue': orgId},
        'migrationStatus': {'stringValue': kMigrationStatusClaimed},
      },
    },
    token: token,
  );
  if (patched == null) {
    stderr.writeln('    FAILED (see error above) — doc NOT claimed.');
    exitCode = 1;
    return 'skipped';
  }
  final afterFields = (patched['fields'] as Map<String, dynamic>?) ?? const {};
  final afterOrgId = afterFields['orgId'] is Map<String, dynamic>
      ? (afterFields['orgId'] as Map<String, dynamic>)['stringValue']
      : null;
  final afterStatus = afterFields['migrationStatus'] is Map<String, dynamic>
      ? (afterFields['migrationStatus'] as Map<String, dynamic>)['stringValue']
      : null;
  stdout.writeln('    after: orgId=${afterOrgId ?? '(missing)'}, '
      'migrationStatus=${afterStatus ?? '(missing)'} — '
      '${afterOrgId == orgId && afterStatus == kMigrationStatusClaimed
          ? 'OK'
          : 'UNEXPECTED VALUE, review!'}');
  return 'patched';
}

void _usage() {
  stdout.writeln('''
Usage:
  dart run scripts/claim_legacy_data.dart <ownerUid> [--dry-run]
                                           [--backup-dir <path>]

  <ownerUid>    the owner's Firebase uid (shown in the app after first
                sign-in); the claim writes orgId = 'org_<ownerUid>' +
                migrationStatus = 'claimed'.
  --dry-run     offline: print the exact PATCHes without sending anything.
  --backup-dir  path to the backup dump (default:
                legacy-backup-20260818-001046 relative to CWD).

Run order: backup exists → dry-run → owner approval → run.
Real run needs CLAIM_EMAIL and CLAIM_PASSWORD (the owner's own
email/password) — never hardcode them.''');
}
