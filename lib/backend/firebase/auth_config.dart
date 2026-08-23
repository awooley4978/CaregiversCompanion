// Email sign-in return/continue-URL configuration.
//
// The app's primary email sign-in is Email/Password (`signInWithEmailAndPassword`,
// see auth_service.dart / login_widget.dart). That flow does NOT require a
// continue URL. However, Firebase's hosted email-action handler (the page at
// `<authDomain>/__/auth/handler`) IS used whenever Firebase sends an email that
// carries a return link — Email Link (passwordless) sign-in, email verification,
// or password reset — and it will refuse to complete with "Continue URL is
// required for email sign-in!" unless a valid continue URL is supplied.
//
// This file is the SINGLE source of truth for that return/continue URL so the
// value is switched in one place and never scattered or hardcoded around the
// codebase. main.dart reads it when handling an incoming email-action link on
// the web entry, and it is the value to paste into the Firebase Console email
// action / continue-URL setting and into any `ActionCodeSettings.url` used by a
// send flow.
import 'package:flutter/foundation.dart' show kIsWeb;

/// The canonical entry URL that an email-action link should return the user to
/// after Firebase completes the email sign-in / verification / reset.
///
/// TODAY'S VALUE: the temporary web tester build, served statically at the
/// site's `/app/` path (a testing/delivery path only — this is NOT a decision
/// that Caregivers Companion becomes a web product). The app boots to this
/// entry and its router then moves the user to `/app/login` (or, once signed
/// in, to `/app/`).
///
/// PRODUCTION REPLACEMENT (REQUIRED BEFORE GOING LIVE):
///   * Delete the temporary path below.
///   * Set this to the app's real production entry point — either the eventual
///     production web domain (e.g. `https://app.example.com/`) or, for native,
///     the app deep-link / universal-link (e.g.
///     `https://<prod-domain>/__/auth/action` or the custom-scheme callback).
///   * The switch is EXACTLY this one constant — no other code changes. You
///     must also add the corresponding domain to Firebase Auth → Sign-in method
///     → Authorized domains for the value to be accepted (console setting, not
///     code — see the deployment note in my report / the constant below).
///
/// Must be a full absolute HTTPS URL whose origin appears in the Firebase Auth
/// "Authorized domains" list, or Firebase rejects the email action outright.
const String authContinueUrl = 'https://294fee88cd6ebd52ee50baa9cebb83d9-dev.ctonew.app/app/index.html';

/// The Firebase authDomain this app signs in against (from firebase_config.dart).
/// The `<authDomain>/__/auth/handler` page is what renders the "Continue URL is
/// required for email sign-in!" error when an email action is attempted without
/// a valid [authContinueUrl]. Kept here solely for diagnostics/console docs.
const String authDomain = 'carerecipients.firebaseapp.com';

/// True on the web entry (the only platform the temporary tester / email-action
/// link handling applies to today).
bool get isWeb => kIsWeb;
