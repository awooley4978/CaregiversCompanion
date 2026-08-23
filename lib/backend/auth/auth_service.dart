// Auth foundation service (security phase 1 + 2 hooks).
//
// Wires Firebase Auth into the app's router seam and owns the auth-adjacent
// behaviors this milestone ships:
//
//  1. Auth state -> AppStateNotifier (isLoggedIn / authInitializing), which
//     drives the global router redirect in lib/flutter_flow/nav/nav.dart.
//  2. users/{uid} auto-provisioning on first successful sign-in
//     (uid / name / email / createdAt, doc id == uid). Provider-agnostic and
//     uid-centric: nothing provider-specific is stored on the profile (Q1).
//  3. Security phase 2: on every sign-in, org membership is ensured
//     (ensureOrgMembership — auto-provisions the family org on first
//     sign-in, D5), pending invites addressed to the user's email are
//     accepted, and the per-user persisted app state (selected recipient,
//     activeGroupId context) is loaded into FFAppState. On sign-out the
//     in-memory user-scoped state is cleared.
//
// Firestore rules and the data schema are intentionally untouched this phase.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart'
    show GoogleSignInExceptionCode;

import '/app_state.dart';
import '/backend/org/org_service.dart';
import '/flutter_flow/nav/nav.dart';

/// Starts listening to `FirebaseAuth.instance.authStateChanges()` and mirrors
/// the result onto [appStateNotifier], which GoRouter uses to re-evaluate its
/// global redirect.
///
/// Call once from `main()` after `await initFirebase()` and before
/// `runApp()`. The first emitted event resolves the persisted-session restore
/// window (`authInitializing` -> false); every later event flips
/// `isLoggedIn`. Returns the subscription so callers (e.g. tests) can cancel
/// it.
StreamSubscription<User?> attachAuthStateListener(
  AppStateNotifier appStateNotifier,
) {
  return FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      // Fire-and-forget: provisioning must never block or fail the session.
      unawaited(_onSignedIn(user));
    } else {
      // Security phase 2: drop in-memory user-scoped state (selected
      // recipient, active group context). Device-persisted per-user values
      // are kept for the user's next sign-in (design §6.4).
      FFAppState().clearUserScopedState();
    }
    appStateNotifier.updateAuthState(user != null);
  });
}

/// Runs the sequential post-sign-in setup: profile provisioning (phase 1),
/// family-org membership (phase 2, D5), email-match invite acceptance
/// (phase 2), and per-user persisted-state load. Each step is idempotent;
/// any failure is contained so the session itself never breaks.
Future<void> _onSignedIn(User user) async {
  try {
    await ensureUserProfile(user);
    final orgId = await ensureOrgMembership(user);
    FFAppState().activeGroupId = orgId;
    await acceptInvitesForUser(user);
    await FFAppState().initializePersistedStateForUser(user.uid);
  } catch (_) {
    // Never fail the session because of a provisioning/state error; all
    // steps are retried on the next sign-in.
  }
}

/// Auto-provisions the `users/{uid}` profile document on first successful
/// sign-in (client-side, no Cloud Functions).
///
/// Idempotent: on re-sign-in (or session restore) an existing profile is
/// never clobbered. Any error (transient network failure, a concurrent write
/// race with another device) is swallowed — provisioning must never fail the
/// auth session; the profile is retried on the next sign-in.
///
/// [displayName] is passed by the sign-up flow, which sets the profile name
/// through Firebase Auth *after* the account exists; the auth-state listener
/// fires before that profile update lands, so the sign-up screen supplies the
/// final name explicitly. An empty name is never written.
Future<void> ensureUserProfile(User user, {String? displayName}) async {
  if (user.uid.isEmpty) {
    return;
  }
  try {
    final docRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await docRef.get();

    final explicitName = (displayName ?? '').trim();
    final name = explicitName.isNotEmpty
        ? explicitName
        : (user.displayName ?? '').trim();

    if (snapshot.exists) {
      // Re-sign-in / restore: keep the existing profile. The only allowed
      // touch-up is the sign-up flow backfilling the display name it just set
      // on the auth user (the listener may have created the doc first without
      // a name).
      if (explicitName.isEmpty) {
        return;
      }
      await docRef.set({
        'uid': user.uid,
        'name': name,
        'email': user.email ?? '',
      }, SetOptions(merge: true));
      return;
    }

    await docRef.set({
      'uid': user.uid,
      if (name.isNotEmpty) 'name': name,
      'email': user.email ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  } catch (_) {
    // Never fail the session because of a profile-write race or a transient
    // backend error; the profile is re-attempted on the next sign-in.
  }
}

/// Signs in with Google (the approved provider set: email/password + Google).
///
/// Platform-aware:
///  * Web: `FirebaseAuth.signInWithPopup` with a `GoogleAuthProvider` — the
///    Firebase-hosted Google dialog (unchanged).
///  * iOS/Android: the native Google Sign-In SDK
///    (`GoogleSignIn.instance.authenticate()`), exchanging the returned ID
///    token for a Firebase credential via `signInWithCredential`. The native
///    account sheet is the user-facing UI; dismissing it returns null and the
///    login screen shows no error (silent abort).
///  * Any other platform: throws [UnimplementedError], which
///    [authErrorMessage] surfaces as a clean "not available" message rather
///    than a crash (same behavior as the previous web-only flow).
///
/// Provider-agnostic account model (Q1): the resulting uid is all the app
/// layer stores; nothing Google-specific is written to the user record. The
/// uid flows through [_onSignedIn] (profile provisioning, org membership,
/// invite acceptance, persisted state) exactly like the email/password flow.
Future<User?> signInWithGoogle() async {
  if (kIsWeb) {
    final credential =
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    return credential.user;
  }
  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android) {
    try {
      final googleAccount = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleAccount.authentication;
      final credential =
          GoogleAuthProvider.credential(idToken: googleAuth.idToken);
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      return userCredential.user;
    } on GoogleSignInException catch (e) {
      // The user dismissed the account sheet, or the flow was interrupted
      // (e.g. the app was backgrounded) — a normal abort, not an error.
      // Swallow it so the login screen stays silent.
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      // Real failures (configuration / network / unknown) propagate so
      // [authErrorMessage] can surface a clear message.
      rethrow;
    }
  }
  // Desktop / other platforms: clean "not available" message, never a crash.
  throw UnimplementedError('Google sign-in is not available on this device yet.');
}

/// Handles an incoming Firebase email-action / email-link return on the web
/// entry (the temporary web tester and the eventual production web/deep-link
/// path). This is the RECEIVER seam for the continue URL configured in
/// [authConfig.authContinueUrl]: Firebase's hosted email-action handler
/// (`<authDomain>/__/auth/handler`) only completes a "Continue URL is required
/// for email sign-in!" flow when the app can redeem the link it was returned
/// at.
///
/// Why this seams exists and is safe to call on every launch:
///  * The app's primary email sign-in is Email/Password (unchanged); this
///    helper only reacts when the app is opened AT an email-link return URL
///    (i.e. the owner tapped a passwordless/verification/reset link on their
///    phone), so normal login and session restore are unaffected.
///  * Email Link (passwordless) redemption needs the recipient email, which
///    Firebase deliberately does NOT embed in the link — the flow that issued
///    the link stores it per-browser at send time. We recover it when present;
///    when absent (this app never sends passwordless links) we fall through to
///    the ordinary login. [email] can be supplied by a sender flow.
///  * On success the existing [attachAuthStateListener] provisions the
///    profile/org and routes the user to '/' — nothing downstream changes.
///
/// Guardrail: this does NOT change the authentication model, Firestore rules,
/// org scoping, or any account data. Email/Password remains the primary login.
Future<void> completeEmailActionLinkIfNeeded({
  String? email,
  Uri? initialUri,
}) async {
  if (!kIsWeb) {
    return; // Email-action links are a web/deep-link concern only.
  }
  final uri = initialUri ?? Uri.base;
  final link = uri.toString();
  if (!FirebaseAuth.instance.isSignInWithEmailLink(link)) {
    return; // Not an email-link return — nothing to do.
  }
  final redeemingEmail = (email ?? '').trim();
  if (redeemingEmail.isEmpty) {
    // No recipient email available for this origin → cannot redeem here. The
    // app falls through to the normal login screen.
    return;
  }
  try {
    await FirebaseAuth.instance.signInWithEmailLink(
      email: redeemingEmail,
      emailLink: link,
    );
    // Success: the auth-state listener flips AppStateNotifier and the router
    // redirect takes over. Nothing to do here.
  } catch (_) {
    // Stale/expired link or email mismatch → leave the user on login.
  }
}

/// Human-readable message for auth-form inline errors.
///
/// Returns null when the error is a user abort (e.g. dismissing the Google
/// account sheet) — the login screen then shows no error at all.
String? authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'canceled':
        // User closed the Google sign-in flow — no error to show.
        return null;
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found for this email. Check the address or create an account.';
      case 'wrong-password':
        return 'Incorrect password. Try again.';
      case 'invalid-credential':
        return 'The email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists for this email. Sign in instead.';
      case 'weak-password':
        return 'Password is too weak — use at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Try again in a moment.';
      case 'operation-not-allowed':
        return 'Sign-in with this method is not enabled yet. Use email and password.';
      case 'unauthorized-domain':
        return 'Sign-in with this method is not authorized for this domain yet.';
      case 'account-exists-with-different-credential':
        return 'An account already exists for this email using a different sign-in method.';
      default:
        return 'Sign-in failed. Please try again.';
    }
  }
  if (error is GoogleSignInException) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
      case GoogleSignInExceptionCode.interrupted:
        // User aborted the native Google sheet — silent.
        return null;
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google sign-in is not configured for this device yet — use email and password.';
      default:
        // unknownError, uiUnavailable, userMismatch, future codes.
        return 'Sign-in failed. Please try again.';
    }
  }
  if (error is UnimplementedError) {
    return 'Google sign-in is not available on this device yet — use email and password.';
  }
  return 'Something went wrong. Please try again.';
}
