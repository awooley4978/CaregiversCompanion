import 'dart:async';

import 'package:flutter/material.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_flow/flutter_flow_util.dart';

/// How far the signed-in user's care circle has been resolved.
///
/// Owner decision 2026-11-21: the Client Directory must never show an empty
/// list while the care circle is still resolving, nor after a failed
/// resolution — an empty directory may only mean "the circle really is empty".
enum CareCircleStatus {
  /// Provisioning has not started (signed out, or before the auth listener has
  /// run). Not one of the four display states; see [FFAppState.careCircleStatus].
  idle,

  /// The care circle is being resolved (`activeGroupId` not known yet).
  loading,

  /// The care circle resolved; the recipients list is authoritative.
  ready,

  /// Resolving failed; [FFAppState.careCircleError] carries the message.
  failed,
}

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {}

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // User-scoped state (security phases 1-2).
  //
  // selectedCareRecipient and activeGroupId are per-USER, never global: the
  // shared_preferences key for the selected recipient is scoped by uid, and
  // the active group context is read from the user's profile doc
  // (users/{uid}.activeGroupId, D1) and cached here in memory. Both are
  // cleared from memory on sign-out; the device-persisted recipient
  // selection survives so the same user gets it back on their next sign-in
  // (design §6.4).
  // ---------------------------------------------------------------------

  /// The uid the persisted state was last initialized for. Null while signed
  /// out or before the first auth-state resolution.
  String? _currentUid;
  String? get currentUid => _currentUid;

  /// Per-user persisted-state load. Called from the auth-state callback
  /// (lib/backend/auth/auth_service.dart) AFTER profile + org provisioning,
  /// so `users/{uid}` (and its activeGroupId) already exists.
  Future<void> initializePersistedStateForUser(String uid) async {
    _currentUid = uid;
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('selected_recipient_$uid');
    if (path == null || path.isEmpty) {
      _selectedCareRecipient = null;
    } else {
      // Restore by document path; the doc may or may not exist — the caller
      // stream handles that.
      _selectedCareRecipient = FirebaseFirestore.instance.doc(path);
    }
    notifyListeners();
  }

  /// Sign-out: drop all in-memory user-scoped state. The device-persisted
  /// recipient selection is intentionally KEPT (it is keyed by uid and
  /// belongs to the user, not the session).
  void clearUserScopedState() {
    _currentUid = null;
    _selectedCareRecipient = null;
    _activeGroupId = null;
    _careCircleStatus = CareCircleStatus.idle;
    _careCircleError = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Care-circle resolution status (owner decision 2026-11-21).
  //
  // The Client Directory is the landing screen, so it can be built before the
  // signed-in user's care circle is known — and it used to render that as an
  // empty list, indistinguishable from a genuine empty circle or from a
  // technical failure. auth_service.dart sets these while provisioning:
  // loading before the provisioning calls, ready once `activeGroupId` is
  // assigned, failed (with a message) when provisioning throws.
  // ---------------------------------------------------------------------

  CareCircleStatus _careCircleStatus = CareCircleStatus.idle;
  CareCircleStatus get careCircleStatus => _careCircleStatus;

  String? _careCircleError;
  String? get careCircleError => _careCircleError;

  /// The care circle is being resolved (also used by the Retry button, so the
  /// page shows the spinner again while provisioning re-runs).
  void setCareCircleLoading() {
    _careCircleStatus = CareCircleStatus.loading;
    _careCircleError = null;
    notifyListeners();
  }

  /// The care circle resolved: the recipients list is now authoritative.
  void setCareCircleReady() {
    _careCircleStatus = CareCircleStatus.ready;
    _careCircleError = null;
    notifyListeners();
  }

  /// Resolving failed. [message] is shown on the Client Directory next to the
  /// Retry button; null falls back to a generic line on the page.
  void setCareCircleFailed(String? message) {
    _careCircleStatus = CareCircleStatus.failed;
    _careCircleError = message;
    notifyListeners();
  }

  DocumentReference? _selectedCareRecipient;
  DocumentReference? get selectedCareRecipient => _selectedCareRecipient;
  set selectedCareRecipient(DocumentReference? value) {
    _selectedCareRecipient = value;
    _persistSelectedCareRecipient(value);
    notifyListeners();
  }

  void _persistSelectedCareRecipient(DocumentReference? value) {
    final uid = _currentUid;
    if (uid == null) {
      // Signed out / never initialized: nothing to persist to.
      return;
    }
    unawaited(() async {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove('selected_recipient_$uid');
      } else {
        await prefs.setString('selected_recipient_$uid', value.path);
      }
    }());
  }

  /// Cached `users/{uid}.activeGroupId` (D1 — CONTEXT SELECTOR ONLY, never
  /// authorization by itself; every org-scoped access re-verifies active
  /// membership in the referenced org at the app layer and, in Phase 4, in
  /// the rules).
  String? _activeGroupId;
  String? get activeGroupId => _activeGroupId;
  set activeGroupId(String? value) {
    _activeGroupId = value;
    notifyListeners();
  }
}
