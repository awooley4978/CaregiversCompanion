import 'dart:async';

import 'package:flutter/material.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_flow/flutter_flow_util.dart';

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
