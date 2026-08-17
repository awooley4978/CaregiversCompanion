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
/// Works on web once the owner enables the Google provider in the Firebase
/// console. If the provider is disabled / the domain is not authorized the
/// platform raises a [FirebaseAuthException] which the caller surfaces via
/// [authErrorMessage]; on non-web platforms `signInWithPopup` is
/// unimplemented, which is surfaced as a clean message rather than a crash.
/// Provider-agnostic account model (Q1): the resulting uid is all the app
/// layer stores; nothing Google-specific is written to the user record.
Future<User?> signInWithGoogle() async {
  final credential =
      await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
  return credential.user;
}

/// Human-readable message for auth-form inline errors.
String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
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
  if (error is UnimplementedError) {
    return 'Google sign-in is not available on this device yet — use email and password.';
  }
  return 'Something went wrong. Please try again.';
}
