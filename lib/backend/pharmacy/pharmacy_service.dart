// Preferred Pharmacy setting (medication Reorder handoff).
//
// The user picks ONE preferred pharmacy in their account Settings
// (PREFERENCES). Medication "Order"/"Reorder" actions use that choice to hand
// the user OFF to the pharmacy's own refill/prescription webpage in a new tab —
// the app NEVER places, and never represents itself as placing, a prescription
// order for the user.
//
// STORAGE / SENSITIVITY GUARDRAILS:
//   * The setting lives on the signed-in user's OWN scoped doc
//     `users/{uid}` (fields `preferredPharmacy` + `preferredPharmacyLabel`).
//     It is USER-scoped, self-serviceable, and its write path (self-update)
//     is already permitted by the existing rules without any rules change —
//     writing a merge that does NOT touch activeGroupId.
//   * Only a NON-SENSITIVE pharmacy identifier is stored: a stable slug
//     ('cvs', 'walgreens', 'riteaid', 'walmart', 'other') and, for "Other",
//     an optional display label the user typed. NO credentials, pharmacy
//     passwords, account numbers, DOB, or any other sensitive data is ever
//     written, read, or placed in a URL.
//   * The handoff URL is a constant per pharmacy (a public refill/prescription
//     landing page). NO user data is injected into the URL.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Slug constants for the supported pharmacies.
const String kPharmacyCvs = 'cvs';
const String kPharmacyWalgreens = 'walgreens';
const String kPharmacyRiteAid = 'riteaid';
const String kPharmacyWalmart = 'walmart';
const String kPharmacyOther = 'other';

/// A supported pharmacy choice (id + friendly name + handoff URL builder).
class Pharmacy {
  const Pharmacy({
    required this.id,
    required this.name,
    required this.refillUrl,
  });

  final String id;
  final String name;

  /// The public refill/prescription webpage this pharmacy's Reorder action
  /// hands the user off to. Always a constant — no user data is injected.
  final String refillUrl;
}

/// The small initial list of supported pharmacies (owner req 5), plus
/// "Other" for any pharmacy not listed. "Other" hands off to a web search of
/// the user's own label + "refill" so the action still opens a useful
/// destination.
const List<Pharmacy> kPharmacies = [
  Pharmacy(
    id: kPharmacyCvs,
    name: 'CVS',
    refillUrl: 'https://www.cvs.com/account/refill',
  ),
  Pharmacy(
    id: kPharmacyWalgreens,
    name: 'Walgreens',
    refillUrl: 'https://www.walgreens.com/refill',
  ),
  Pharmacy(
    id: kPharmacyRiteAid,
    name: 'Rite Aid',
    refillUrl: 'https://www.riteaid.com/pharmacy/refill',
  ),
  Pharmacy(
    id: kPharmacyWalmart,
    name: 'Walmart',
    refillUrl: 'https://www.walmart.com/pharmacy/refills',
  ),
  Pharmacy(id: kPharmacyOther, name: 'Other', refillUrl: ''),
];

/// Look up a supported pharmacy by slug; null when unknown/not chosen.
Pharmacy? pharmacyById(String? id) {
  if (id == null) return null;
  for (final p in kPharmacies) {
    if (p.id == id) return p;
  }
  return null;
}

/// The friendly display name for a stored choice (uses the "Other" label when
/// the choice is "other" and a label was provided).
String pharmacyDisplayName(String? id, String? label) {
  final p = pharmacyById(id);
  if (p == null) return 'Not set';
  if (p.id == kPharmacyOther) {
    final t = (label ?? '').trim();
    return t.isEmpty ? 'Other' : t;
  }
  return p.name;
}

/// The URL the Reorder handoff opens for a stored choice.
///
/// For the four known pharmacies this is the constant refillUrl. For "Other"
/// (no reliable public page) it hands off to a neutral web search of the
/// pharmacy's own label so the action still opens a real, useful destination.
/// Nothing user-provided beyond the pharmacy label itself is used, and no
/// credentials are ever present.
String pharmacyRefillUrl(String? id, [String? label]) {
  final p = pharmacyById(id);
  if (p != null && p.id != kPharmacyOther) {
    return p.refillUrl;
  }
  final term = (label ?? '').trim().isNotEmpty
      ? (label ?? '').trim()
      : 'my pharmacy';
  final query = Uri.encodeQueryComponent('$term prescription refill');
  return 'https://www.google.com/search?q=$query';
}

/// Handles the Recommended/Preferred Pharmacy setting on the user's own
/// `users/{uid}` scoped document.
class PharmacyService {
  /// The signed-in user's uid, or null when signed out.
  static String? currentUid() => FirebaseAuth.instance.currentUser?.uid;

  /// The stored pharmacy slug for [uid] (null when unset).
  Future<String?> getPreferredPharmacyId(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return doc.data()?['preferredPharmacy'] as String?;
  }

  /// The stored "Other" label for [uid] (null when unset / not "Other").
  Future<String?> getPreferredPharmacyLabel(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return doc.data()?['preferredPharmacyLabel'] as String?;
  }

  /// Reads both pharmacy fields in one doc fetch.
  Future<({String? id, String? label})> getPreferredPharmacy(
    String uid,
  ) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!doc.exists) return (id: null, label: null);
    final data = doc.data()!;
    return (
      id: data['preferredPharmacy'] as String?,
      label: data['preferredPharmacyLabel'] as String?,
    );
  }

  /// Persists the choice to `users/{uid}` via a self-merge write. Only the
  /// two non-sensitive pharmacy fields are written; activeGroupId and every
  /// other field are untouched, so the existing self-update rule path
  /// (no rules change) governs this write.
  Future<void> setPreferredPharmacy(
    String uid, {
    required String id,
    String? label,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {
        'preferredPharmacy': id,
        if ((label ?? '').trim().isNotEmpty) 'preferredPharmacyLabel': label,
      },
      SetOptions(merge: true),
    );
  }
}
