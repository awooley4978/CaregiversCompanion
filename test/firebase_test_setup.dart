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
//
//  * firebase_auth: replaces `FirebaseAuthPlatform.instance` with an
//    in-memory fake (same platform-interface pattern). Tests drive auth state
//    through [fakeAuthPlatform] — `emitSignedOut()` / `emitSignedIn()` feed
//    `authStateChanges()`, which `attachAuthStateListener()` (the same wiring
//    main() uses) mirrors onto AppStateNotifier to exercise the router's
//    global auth redirect.
import 'dart:async';

import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';

/// The installed auth fake; tests emit auth state through it.
late FakeFirebaseAuthPlatform fakeAuthPlatform;

/// Initializes Firebase for the test environment and installs the fake
/// Firestore and Firebase Auth backends. Call from `setUpAll` before pumping
/// the app.
Future<void> initFirebaseForTest() async {
  // Official in-memory firebase_core mock (pigeon channel, no platform).
  setupFirebaseCoreMocks();

  // All Firestore queries resolve to an empty snapshot (see below).
  FirebaseFirestorePlatform.instance = _EmptyFirestorePlatform();

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
// Firestore fake: every collection is empty.
// ---------------------------------------------------------------------------

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
