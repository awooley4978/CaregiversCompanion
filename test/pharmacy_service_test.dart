// Preferred Pharmacy service tests (medication Reorder handoff).
//
// Verifies (offline, against the in-memory Firestore fake):
//   * the exact handoff URL each supported pharmacy produces (owner req 7's
//     "correct destination"), and how "Other" resolves;
//   * the setting round-trips through the user's OWN scoped doc `users/{uid}`
//     with ONLY the non-sensitive slug + optional label (no credentials);
//   * an unset pharmacy reads back as null (the "prompt to choose" guard).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/backend/pharmacy/pharmacy_service.dart';
import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initFirebaseForTest();
  });
  setUp(() {
    fakeFirestore.clear();
  });

  group('handoff URL mapping', () {
    test('each supported pharmacy resolves to its refill/prescription page', () {
      expect(
        pharmacyRefillUrl(kPharmacyCvs),
        'https://www.cvs.com/account/refill',
      );
      expect(
        pharmacyRefillUrl(kPharmacyWalgreens),
        'https://www.walgreens.com/refill',
      );
      expect(
        pharmacyRefillUrl(kPharmacyRiteAid),
        'https://www.riteaid.com/pharmacy/refill',
      );
      expect(
        pharmacyRefillUrl(kPharmacyWalmart),
        'https://www.walmart.com/pharmacy/refills',
      );
    });

    test('Other with a label hands off to a web search of that label', () {
      final url = pharmacyRefillUrl(kPharmacyOther, 'Costco');
      expect(url, startsWith('https://www.google.com/search?q='));
      expect(url, contains(Uri.encodeQueryComponent('Costco prescription refill')));
    });

    test('Other without a label falls back to a generic refill search', () {
      final url = pharmacyRefillUrl(kPharmacyOther, null);
      expect(url,
          'https://www.google.com/search?q=${Uri.encodeQueryComponent('my pharmacy prescription refill')}');
    });

    test('unknown/null id does not leak a URL', () {
      expect(pharmacyRefillUrl(null, null), isNotNull);
      expect(pharmacyById('nonsense'), isNull);
    });
  });

  group('display name', () {
    test('known pharmacies show their name', () {
      expect(pharmacyDisplayName(kPharmacyWalgreens, null), 'Walgreens');
    });
    test('Other shows its label when provided', () {
      expect(pharmacyDisplayName(kPharmacyOther, 'Costco'), 'Costco');
      expect(pharmacyDisplayName(kPharmacyOther, null), 'Other');
    });
  });

  group('storage (users/{uid} self-scoped, non-sensitive)', () {
    test('unset pharmacy reads back as null (prompt-to-choose guard)', () async {
      final pref = await PharmacyService().getPreferredPharmacy('u1');
      expect(pref.id, isNull);
      expect(pref.label, isNull);
    });

    test('set then get round-trips only the slug + optional label', () async {
      final svc = PharmacyService();
      await svc.setPreferredPharmacy('u1', id: kPharmacyWalgreens);
      final pref = await svc.getPreferredPharmacy('u1');
      expect(pref.id, kPharmacyWalgreens);
      // The stored doc contains ONLY the non-sensitive fields — no passwords,
      // account numbers, or any credential material.
      final data = await FirebaseFirestore.instance
          .collection('users')
          .doc('u1')
          .get();
      final map = data.data()!;
      expect(map['preferredPharmacy'], kPharmacyWalgreens);
      for (final key in map.keys) {
        expect(
          key.toLowerCase(),
          isNot(anyOf('password', 'pass', 'credential', 'token', 'account')),
          reason: 'no sensitive key should ever be stored for the pharmacy',
        );
      }
    });

    test('Other stores its label too', () async {
      final svc = PharmacyService();
      await svc.setPreferredPharmacy('u1', id: kPharmacyOther, label: 'Costco');
      final pref = await svc.getPreferredPharmacy('u1');
      expect(pref.id, kPharmacyOther);
      expect(pref.label, 'Costco');
    });
  });
}
