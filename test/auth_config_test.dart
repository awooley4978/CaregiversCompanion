// Guard test for the email sign-in continue/return-URL configuration
// (lib/backend/firebase/auth_config.dart).
//
// The app's primary email sign-in is Email/Password, which needs no continue
// URL. But Firebase's hosted email-action handler (`<authDomain>/__/auth/
// handler`) refuses to complete email-action/email-link flows with "Continue
// URL is required for email sign-in!" unless a valid continue URL is supplied.
// authContinueUrl is the single configurable value that flows into that
// handler (and any send-side ActionCodeSettings). This test keeps it a valid,
// https, absolute, app-entry URL so the value can never silently regress.
//
// Deterministic & offline: pure value assertions, no Firebase/network/DOM.
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/backend/firebase/auth_config.dart';

void main() {
  group('authContinueUrl (email sign-in continue/return URL)', () {
    test('is a single, non-empty configured value', () {
      expect(authContinueUrl, isNotEmpty);
    });

    test('parses as an absolute https URL', () {
      final uri = Uri.parse(authContinueUrl);
      expect(uri.isAbsolute, isTrue, reason: '$authContinueUrl must be absolute');
      expect(uri.scheme, 'https');
      expect(uri.host, isNotEmpty);
    });

    test('points at the app entry path (/app/index.html) today', () {
      final uri = Uri.parse(authContinueUrl);
      // Temporary web-tester canonical entry (testing/delivery path only).
      expect(uri.path, endsWith('/app/index.html'));
      expect(uri.host, '294fee88cd6ebd52ee50baa9cebb83d9-dev.ctonew.app');
    });

    test('authDomain matches the configured Firebase Auth domain', () {
      expect(authDomain, 'carerecipients.firebaseapp.com');
    });
  });
}
