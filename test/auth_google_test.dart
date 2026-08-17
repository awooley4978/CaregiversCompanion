// Google sign-in mobile-flow tests (auth_service.signInWithGoogle).
//
// The native GoogleSignIn flow is exercised through the google_sign_in
// platform interface (GoogleSignInPlatform.instance) — the same seam the
// plugin's own tests use. A fake platform implementation replaces the
// method-channel default, so no native code is involved.
//
// Covered here:
//  * mobile: dismissing the Google account sheet (canceled / interrupted)
//    returns null and the login screen stays silent,
//  * non-mobile platforms keep the clean UnimplementedError message,
//  * authErrorMessage maps Google + Firebase cancellation to "no error".
//
// The full happy path (GoogleSignIn success -> FirebaseAuth credential
// exchange) is not exercised: it would require extending the shared
// FirebaseAuth fake in firebase_test_setup.dart with a
// signInWithCredential implementation that reconstructs a
// UserCredentialPlatform — heavier mocking than warranted for this change;
// the wiring it exercises is two standard calls (GoogleAuthProvider.credential
// + signInWithCredential) already covered by the platform packages' own
// integration tests. The cancel and error paths above are the app-specific
// behavior this feature adds, so they are the ones tested here.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:new_project/backend/auth/auth_service.dart';

import 'firebase_test_setup.dart';

/// In-memory [GoogleSignInPlatform] that either returns a canned
/// [AuthenticationResults] or throws a canned [GoogleSignInException].
class FakeGoogleSignInPlatform extends GoogleSignInPlatform
    with MockPlatformInterfaceMixin {
  FakeGoogleSignInPlatform({this.result, this.error});

  final AuthenticationResults? result;
  final GoogleSignInException? error;
  bool authenticateCalled = false;

  @override
  Future<AuthenticationResults> authenticate(AuthenticateParameters params) async {
    authenticateCalled = true;
    if (error != null) {
      throw error!;
    }
    return result!;
  }

  @override
  Future<void> init(InitParameters params) async {}

  @override
  Future<AuthenticationResults?> attemptLightweightAuthentication(
          AttemptLightweightAuthenticationParameters params) async =>
      null;

  @override
  bool supportsAuthenticate() => true;

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
          ClientAuthorizationTokensForScopesParameters params) async =>
      null;

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
          ServerAuthorizationTokensForScopesParameters params) async =>
      null;

  @override
  Future<void> signOut(SignOutParams params) async {}

  @override
  Future<void> disconnect(DisconnectParams params) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initFirebaseForTest();
  });

  setUp(() {
    fakeFirestore.clear();
    // Force the mobile branch of signInWithGoogle regardless of the host OS.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('signInWithGoogle (mobile)', () {
    test('user dismissing the Google sheet returns null silently', () async {
      GoogleSignInPlatform.instance = FakeGoogleSignInPlatform(
          error: const GoogleSignInException(
              code: GoogleSignInExceptionCode.canceled));

      final user = await signInWithGoogle();

      expect(user, isNull);
    });

    test('interrupted flow (e.g. app backgrounded) also returns null', () async {
      GoogleSignInPlatform.instance = FakeGoogleSignInPlatform(
          error: const GoogleSignInException(
              code: GoogleSignInExceptionCode.interrupted));

      final user = await signInWithGoogle();

      expect(user, isNull);
    });

    test('real failures still propagate to authErrorMessage', () async {
      GoogleSignInPlatform.instance = FakeGoogleSignInPlatform(
          error: const GoogleSignInException(
              code: GoogleSignInExceptionCode.providerConfigurationError,
              description: 'no client id'));

      expect(signInWithGoogle(), throwsA(isA<GoogleSignInException>()));
      expect(
        authErrorMessage(const GoogleSignInException(
            code: GoogleSignInExceptionCode.providerConfigurationError)),
        'Google sign-in is not configured for this device yet — use email and password.',
      );
    });
  });

  group('signInWithGoogle (non-mobile)', () {
    test('keeps the clean unimplemented-message behavior', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      expect(signInWithGoogle(), throwsA(isA<UnimplementedError>()));
      expect(
        authErrorMessage(UnimplementedError()),
        'Google sign-in is not available on this device yet — use email and password.',
      );
    });
  });

  group('authErrorMessage Google mappings', () {
    test('FirebaseAuthException code "canceled" maps to no error', () {
      expect(
        authErrorMessage(FirebaseAuthException(code: 'canceled')),
        isNull,
      );
    });

    test('GoogleSignInException canceled maps to no error', () {
      expect(
        authErrorMessage(
            const GoogleSignInException(code: GoogleSignInExceptionCode.canceled)),
        isNull,
      );
    });

    test('unknown Google failures map to the generic message', () {
      expect(
        authErrorMessage(
            const GoogleSignInException(code: GoogleSignInExceptionCode.unknownError)),
        'Sign-in failed. Please try again.',
      );
    });
  });
}
