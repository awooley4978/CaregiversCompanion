// Test-only Firebase bootstrap for the CI test harness.
//
// The real app calls initFirebase() in main() before runApp(). flutter_test
// has no native Firebase backend, so this helper replaces both Firebase
// backends with fully in-memory fakes BEFORE the app is pumped:
//
//  * firebase_core: uses the official `setupFirebaseCoreMocks()` helper that
//    ships inside `firebase_core_platform_interface` (already a transitive
//    dependency of firebase_core — no new packages). It registers a mock
//    handler for the FirebaseCoreHostApi pigeon channel, so
//    `Firebase.initializeApp(...)` completes in pure Dart with no platform
//    calls and no network.
//
//  * cloud_firestore: replaces `FirebaseFirestorePlatform.instance` with an
//    in-memory document store. Unlike the phase-1 harness (every collection
//    empty), this fake supports the reads/writes the security phases need:
//    doc get/set/delete (with SetOptions merge), subcollection + collection
//    group queries with `where` equality filters and `limit`, and write
//    batches. `FieldValue.serverTimestamp()` sentinels resolve to a concrete
//    DateTime at write time (real Firestore stores a server Timestamp), so
//    record parsing works unchanged.
//
//  * firebase_auth: replaces `FirebaseAuthPlatform.instance` with an
//    in-memory fake (same platform-interface pattern). Tests drive auth state
//    through [fakeAuthPlatform] — `emitSignedOut()` / `emitSignedIn()` feed
//    `authStateChanges()`, which `attachAuthStateListener()` (the same wiring
//    main() uses) mirrors onto AppStateNotifier to exercise the router's
//    global auth redirect.
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';

/// The installed auth fake; tests emit auth state through it.
late FakeFirebaseAuthPlatform fakeAuthPlatform;

/// The installed Firestore fake; tests seed/assert data through it.
late MemoryFirestorePlatform fakeFirestore;

/// Initializes Firebase for the test environment and installs the fake
/// Firestore and Firebase Auth backends. Call from `setUpAll` before pumping
/// the app (or running service tests).
Future<void> initFirebaseForTest() async {
  // Official in-memory firebase_core mock (pigeon channel, no platform).
  setupFirebaseCoreMocks();

  // In-memory Firestore document store (see below).
  fakeFirestore = MemoryFirestorePlatform();
  FirebaseFirestorePlatform.instance = fakeFirestore;

  // Auth state is driven explicitly by the test through fakeAuthPlatform.
  fakeAuthPlatform = FakeFirebaseAuthPlatform();
  FirebaseAuthPlatform.instance = fakeAuthPlatform;

  // Mirrors the app's initFirebase(); the 'demo-' projectId bypasses
  // firebase_core's options-comparison guard against the mock's default app.
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'demo-api-key',
      appId: 'demo-app-id',
      messagingSenderId: 'demo-sender-id',
      projectId: 'demo-test-project',
    ),
  );
}

// ---------------------------------------------------------------------------
// Firebase Auth fake (platform-interface pattern)
// ---------------------------------------------------------------------------

class FakeFirebaseAuthPlatform extends FirebaseAuthPlatform {
  FakeFirebaseAuthPlatform() : super(appInstance: null);

  final StreamController<UserPlatform?> _authStateController =
      StreamController<UserPlatform?>.broadcast();

  UserPlatform? _currentUser;

  @override
  UserPlatform? get currentUser => _currentUser;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  Stream<UserPlatform?> authStateChanges() => _authStateController.stream;

  /// Test helper: resolve the session-restore window to "no signed-in user".
  void emitSignedOut() {
    _currentUser = null;
    _authStateController.add(null);
  }

  /// Test helper: sign a user in (with [uid], [email], [displayName]).
  void emitSignedIn({
    String uid = 'test-user-1',
    String? email,
    String? displayName,
  }) {
    _currentUser = _makeUser(uid, email: email, displayName: displayName);
    _authStateController.add(_currentUser);
  }

  UserPlatform _makeUser(String uid, {String? email, String? displayName}) {
    final details = PigeonUserDetails(
      userInfo: PigeonUserInfo(
        uid: uid,
        email: email,
        displayName: displayName,
        isAnonymous: false,
        isEmailVerified: false,
      ),
      providerData: const [],
    );
    return FakeUserPlatform(this, FakeMultiFactorPlatform(this), details);
  }
}

class FakeUserPlatform extends UserPlatform {
  FakeUserPlatform(super.auth, super.multiFactor, super.user);
}

class FakeMultiFactorPlatform extends MultiFactorPlatform {
  FakeMultiFactorPlatform(super.auth);
}

// ---------------------------------------------------------------------------
// Firestore fake: in-memory document store with doc writes and filtered
// queries (collection, subcollection, and collection-group).
// ---------------------------------------------------------------------------

/// Firestore platform fake backed by an in-memory map of document paths.
class MemoryFirestorePlatform extends FirebaseFirestorePlatform {
  MemoryFirestorePlatform()
      : super(appInstance: null, databaseChoice: '(default)');

  /// document path -> data. Test-only accessors below.
  final Map<String, Map<String, dynamic>> docs = {};

  /// Test helper: wipe every document (fresh database per test).
  void clear() => docs.clear();

  /// Test helper: read raw data for [path] (null when absent).
  Map<String, dynamic>? dataAt(String path) => docs[path];

  @override
  FirebaseFirestorePlatform delegateFor({
    required FirebaseApp app,
    required String databaseId,
  }) =>
      this;

  @override
  CollectionReferencePlatform collection(String collectionPath) =>
      _MemoryCollectionReference(this, collectionPath);

  @override
  DocumentReferencePlatform doc(String documentPath) =>
      _MemoryDocumentReference(this, documentPath);

  @override
  QueryPlatform collectionGroup(String collectionId) =>
      _MemoryQuery(this, <String, dynamic>{}, collectionGroupId: collectionId);

  @override
  WriteBatchPlatform batch() => _MemoryWriteBatch(this);

  /// All docs whose path is a direct child of [collectionPath].
  Iterable<MapEntry<String, Map<String, dynamic>>> _docsInCollection(
          String collectionPath) =>
      docs.entries.where((e) =>
          e.key.startsWith('$collectionPath/') &&
          !e.key.substring(collectionPath.length + 1).contains('/'));

  /// All docs whose immediate parent collection is [collectionId] (collection
  /// groups match by the doc's collection name, at any depth).
  Iterable<MapEntry<String, Map<String, dynamic>>> _docsInGroup(
          String collectionId) =>
      docs.entries.where((e) {
        final segments = e.key.split('/');
        return segments.length.isEven &&
            segments.length >= 2 &&
            segments[segments.length - 2] == collectionId;
      });

  void writeDoc(String path, Map<String, dynamic> data,
      {SetOptions? options}) {
    final resolved = _resolveSentinels(data);
    final existing = docs[path];
    if (existing != null &&
        (options?.merge == true || options?.mergeFields != null)) {
      final merged = Map<String, dynamic>.from(existing);
      if (options?.mergeFields != null) {
        for (final field in options!.mergeFields!) {
          final value = _dig(merged, field);
          // The app only merges top-level fields in this phase.
          merged[field.components.first] =
              _dig(resolved, field) ?? value;
        }
      } else {
        merged.addAll(resolved);
      }
      docs[path] = merged;
    } else {
      docs[path] = Map<String, dynamic>.from(resolved);
    }
  }

  void deleteDoc(String path) => docs.remove(path);

  DocumentSnapshotPlatform snapshotAt(String path) =>
      DocumentSnapshotPlatform(
        this,
        path,
        docs[path],
        PigeonSnapshotMetadata(hasPendingWrites: false, isFromCache: false),
      );
}

/// Resolves `FieldValue` sentinels to concrete values the store can read back
/// (the app-facing set() encodes them to platform delegates before we see
/// them; real Firestore would store a server Timestamp).
dynamic _resolveSentinel(dynamic value) {
  if (value is FieldValuePlatform) {
    value = FieldValuePlatform.getDelegate(value);
  }
  if (value != null &&
      value.runtimeType.toString().contains('FieldValue')) {
    final type = (value as dynamic).type?.toString();
    if (type == 'FieldValueType.serverTimestamp') {
      return DateTime.now();
    }
    throw UnsupportedError(
        'FieldValue sentinel "$type" is not supported by the memory fake.');
  }
  return value;
}

Map<String, dynamic> _resolveSentinels(Map<String, dynamic> data) =>
    data.map((key, value) => MapEntry(key, _resolveSentinel(value)));

dynamic _dig(Map<String, dynamic> map, FieldPath path) {
  dynamic value = map;
  for (final component in path.components) {
    if (value is! Map || !value.containsKey(component)) {
      return null;
    }
    value = value[component];
  }
  return value;
}

/// Ensure the standard query parameter keys exist, mirroring
/// QueryPlatform._initialParameters (which only applies when params is null).
void _seedDefaults(Map<String, dynamic>? params) {
  params?['where'] ??= <List<List<dynamic>>>[];
}

class _MemoryDocumentReference extends DocumentReferencePlatform {
  _MemoryDocumentReference(super.firestore, super.path);

  MemoryFirestorePlatform get _store => firestore as MemoryFirestorePlatform;

  @override
  Future<DocumentSnapshotPlatform> get(
      [GetOptions options = const GetOptions()]) async {
    return _store.snapshotAt(path);
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    _store.writeDoc(path, data, options: options);
  }

  @override
  Future<void> delete() async {
    _store.deleteDoc(path);
  }

  @override
  Stream<DocumentSnapshotPlatform> snapshots({
    bool includeMetadataChanges = false,
    required ListenSource listenSource,
  }) {
    return Stream<DocumentSnapshotPlatform>.value(
        _store.snapshotAt(path));
  }
}

class _MemoryCollectionReference extends CollectionReferencePlatform {
  _MemoryCollectionReference(super.firestore, super.path) {
    // CollectionReferencePlatform hardcodes an empty params map; the real
    // platform passes null so the QueryPlatform defaults (incl. 'where': [])
    // apply. The app-side Query.where reads parameters['where'] before
    // calling our where(), so the list must exist from construction.
    _seedDefaults(parameters);
  }

  @override
  DocumentReferencePlatform doc([String? path]) {
    final id = path ??
        'fake_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(0xFFFFFF)}';
    return _MemoryDocumentReference(firestore, '${this.path}/$id');
  }

  @override
  QueryPlatform where(List<List<dynamic>> conditions) =>
      _MemoryQuery.from(this, extraConditions: conditions);

  @override
  QueryPlatform limit(int limit) =>
      _MemoryQuery.from(this, limit: limit);

  @override
  Future<QuerySnapshotPlatform> get(
      [GetOptions options = const GetOptions()]) async {
    return _MemoryQuery.from(this)._run();
  }

  @override
  Stream<QuerySnapshotPlatform> snapshots({
    bool includeMetadataChanges = false,
    required ListenSource listenSource,
  }) {
    return Stream<QuerySnapshotPlatform>.value(
        _MemoryQuery.from(this)._runSync());
  }
}

/// Query fake supporting `where` equality filters and `limit` over the memory
/// store. `parameters` mirrors the real QueryPlatform parameter map (the
/// app-facing Query builds 'where' condition triples and 'limit' from it).
class _MemoryQuery extends QueryPlatform {
  _MemoryQuery(
    super.firestore,
    super.params, {
    this.basePath,
    this.collectionGroupId,
  }) {
    _seedDefaults(parameters);
  }

  /// Path of the collection being queried (collection queries only).
  final String? basePath;

  /// Collection id for collection-group queries.
  final String? collectionGroupId;

  factory _MemoryQuery.from(QueryPlatform other,
      {List<List<dynamic>> extraConditions = const [], int? limit}) {
    final params = Map<String, dynamic>.from(other.parameters);
    if (extraConditions.isNotEmpty) {
      final conditions =
          List<List<dynamic>>.from(params['where'] as List? ?? const [])
            ..addAll(extraConditions);
      params['where'] = conditions;
    }
    if (limit != null) {
      params['limit'] = limit;
    }
    if (other is _MemoryCollectionReference) {
      return _MemoryQuery(other.firestore, params,
          basePath: other.path);
    }
    final memory = other as _MemoryQuery;
    return _MemoryQuery(other.firestore, params,
        basePath: memory.basePath, collectionGroupId: memory.collectionGroupId);
  }

  MemoryFirestorePlatform get _store => firestore as MemoryFirestorePlatform;

  @override
  QueryPlatform where(List<List<dynamic>> conditions) =>
      _MemoryQuery.from(this, extraConditions: conditions);

  @override
  QueryPlatform limit(int limit) => _MemoryQuery.from(this, limit: limit);

  @override
  Future<QuerySnapshotPlatform> get(
      [GetOptions options = const GetOptions()]) async {
    return _run();
  }

  @override
  Stream<QuerySnapshotPlatform> snapshots({
    bool includeMetadataChanges = false,
    required ListenSource listenSource,
  }) {
    return Stream<QuerySnapshotPlatform>.value(_runSync());
  }

  /// Documents matching the query, as (path, data) entries.
  List<MapEntry<String, Map<String, dynamic>>> _matches() {
    Iterable<MapEntry<String, Map<String, dynamic>>> candidates;
    if (collectionGroupId != null) {
      candidates = _store._docsInGroup(collectionGroupId!);
    } else {
      candidates = _store._docsInCollection(basePath!);
    }
    final conditions = (parameters['where'] as List?) ?? const [];
    var result = candidates.where((entry) =>
        conditions.every((c) => _matchesCondition(entry, c)));
    final limit = parameters['limit'] as int?;
    if (limit != null && limit >= 0) {
      result = result.take(limit);
    }
    return result.toList();
  }

  bool _matchesCondition(MapEntry<String, Map<String, dynamic>> entry,
      List<dynamic> condition) {
    final field = condition[0];
    final op = condition[1] as String;
    final value = condition[2];
    if (field is FieldPath && field.components.first == '__name__') {
      throw UnsupportedError('documentId filters are not supported by the '
          'memory fake.');
    }
    final fieldPath = field is FieldPath ? field : FieldPath.fromString(field as String);
    final actual = _dig(entry.value, fieldPath);
    switch (op) {
      case '==':
        return _equals(actual, value);
      case '!=':
        return !_equals(actual, value);
      case 'in':
        return value is List && value.any((v) => _equals(actual, v));
      default:
        throw UnsupportedError('where operator "$op" is not supported by the '
            'memory fake.');
    }
  }

  bool _equals(dynamic a, dynamic b) {
    if (a == null || b == null) {
      return a == b;
    }
    return a == b;
  }

  QuerySnapshotPlatform _runSync() {
    final docs = _matches()
        .map((entry) => DocumentSnapshotPlatform(
              firestore,
              entry.key,
              entry.value,
              PigeonSnapshotMetadata(
                  hasPendingWrites: false, isFromCache: false),
            ))
        .toList();
    return QuerySnapshotPlatform(
      docs,
      <DocumentChangePlatform>[],
      SnapshotMetadataPlatform(false, false),
    );
  }

  QuerySnapshotPlatform _run() => _runSync();
}

class _MemoryWriteBatch extends WriteBatchPlatform {
  _MemoryWriteBatch(this._store);

  final MemoryFirestorePlatform _store;
  final List<void Function()> _ops = [];

  @override
  void set(String documentPath, Map<String, dynamic> data,
      [SetOptions? options]) {
    _ops.add(() => _store.writeDoc(documentPath, data, options: options));
  }

  @override
  void delete(String documentPath) {
    _ops.add(() => _store.deleteDoc(documentPath));
  }

  @override
  Future<void> commit() async {
    // Apply atomically from the batch's perspective (no interleaving with
    // other writes is possible in a single-threaded test).
    for (final op in _ops) {
      op();
    }
    _ops.clear();
  }
}
