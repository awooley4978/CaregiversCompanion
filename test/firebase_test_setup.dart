// Test-only Firebase bootstrap for the CI widget-test harness.
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
//  * cloud_firestore: replaces `FirebaseFirestorePlatform.instance` with a
//    minimal fake whose queries resolve immediately to an EMPTY snapshot.
//    This is deterministic: no real channel traffic, no timers, and the
//    app's landing-route StreamBuilder receives an empty result set on the
//    first microtask, which `tester.pump()` flushes.
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';

/// Initializes Firebase for the test environment and installs the fake
/// Firestore backend. Call from `setUpAll` before pumping the app.
Future<void> initFirebaseForTest() async {
  // Official in-memory firebase_core mock (pigeon channel, no platform).
  setupFirebaseCoreMocks();

  // All Firestore queries resolve to an empty snapshot (see below).
  FirebaseFirestorePlatform.instance = _EmptyFirestorePlatform();

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

/// Firestore platform fake: every collection is empty.
class _EmptyFirestorePlatform extends FirebaseFirestorePlatform {
  _EmptyFirestorePlatform()
      : super(appInstance: null, databaseChoice: '(default)');

  @override
  FirebaseFirestorePlatform delegateFor({
    required FirebaseApp app,
    required String databaseId,
  }) =>
      this;

  @override
  CollectionReferencePlatform collection(String collectionPath) =>
      _EmptyCollectionReference(this, collectionPath);
}

/// Collection reference fake: snapshots/get resolve to an empty result.
class _EmptyCollectionReference extends CollectionReferencePlatform {
  _EmptyCollectionReference(FirebaseFirestorePlatform firestore, String path)
      : super(firestore, path);

  @override
  Stream<QuerySnapshotPlatform> snapshots({
    bool includeMetadataChanges = false,
    required ListenSource listenSource,
  }) {
    return Stream<QuerySnapshotPlatform>.value(_emptySnapshot());
  }

  @override
  Future<QuerySnapshotPlatform> get(
      [GetOptions options = const GetOptions()]) async {
    return _emptySnapshot();
  }
}

QuerySnapshotPlatform _emptySnapshot() => QuerySnapshotPlatform(
      <DocumentSnapshotPlatform>[],
      <DocumentChangePlatform>[],
      SnapshotMetadataPlatform(false, false),
    );
