// App-wide classification of Firestore permission-denied failures.
//
// Security phase 5 hardening (design §1.1, §6.3 items 3-4). Firestore's
// security rules surface a SINGLE error code for every denial —
// `permission-denied` — regardless of which rule predicate rejected the
// request (stale group context, a revoked grant, or a D7 assignment expiry).
// The error object therefore cannot tell us WHY access was denied; only the
// CALLER knows which kind of access it was attempting. So the shared handler
// asks the call site to declare its [AccessSurface] and treats a denial on
// that surface as a [PermissionDeniedKind] that the central router
// (lib/backend/permissions/permission_router.dart) turns into an actionable
// destination.
//
// Every Firestore read/write error path in the app should classify through
// [asPermissionDenied] (or [isPermissionDenied]) so a lock-rules denial
// never shows up as a raw, unexplained stream error.
//
// This module is pure Dart (no BuildContext / no Flutter widget tree), so all
// of it is unit-testable in isolation.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart' show PlatformException;

/// Which product / access surface an operation was touching. This is the ONLY
/// input that lets the handler infer the user's correct routing on denial.
enum AccessSurface {
  /// Care Circle (family org): org-scoped group data (recipients, notes,
  /// symptoms, meals, checklist). A denial almost always means the active
  /// group context is stale — the user was removed from the org, the org was
  /// deleted, or `users/{uid}.activeGroupId` points at a group the user no
  /// longer belongs to (§1.1, §6.3 item 4). Routes to the group switcher /
  /// Household page.
  careCircleGroup,

  /// Professional (kind 'organization'): assignment-scoped recipient data. A
  /// denial means the staff member's assignment was revoked or a temporary
  /// shift's `validUntil` (D7 hard cutoff) has passed (§3.2, §6.3 item 10).
  /// Routes to the "assignment ended" state.
  professionalAssignment,

  /// Cross-org shared recipient (recipientShares grant). A denial means the
  /// grant doc was deleted / revoked by the owner org (§3.3). Routes
  /// gracefully back to the recipient list with a clear message.
  sharedGrant,
}

/// The routing decision produced for a denied [AccessSurface].
enum PermissionDeniedKind { staleGroup, assignmentEnded, grantRevoked }

/// Thrown (or returned) when a Firestore error is a security-rules denial of
/// a known [AccessSurface]. Non-permission errors are deliberately NOT wrapped
/// — they keep surfacing normally so ordinary failures are never mistaken for
/// a session/access problem.
class PermissionDeniedException implements Exception {
  PermissionDeniedException(this.kind, [this.surface]);

  final PermissionDeniedKind kind;
  final AccessSurface? surface;

  @override
  String toString() => 'PermissionDeniedException($kind)';
}

/// True when [error] is a Firestore security-rules permission denial.
///
/// Handles both the modern `FirebaseException` (cloud_firestore) and the
/// underlying `PlatformException` a plugin may surface. The message is not
/// inspected — the code is the stable contract.
bool isPermissionDenied(Object error) {
  if (error is FirebaseException) {
    return error.code == 'permission-denied';
  }
  if (error is PlatformException) {
    return error.code == 'permission-denied';
  }
  return false;
}

/// The [PermissionDeniedKind] to route to for an [AccessSurface] denial.
PermissionDeniedKind kindForSurface(AccessSurface surface) => switch (surface) {
      AccessSurface.careCircleGroup => PermissionDeniedKind.staleGroup,
      AccessSurface.professionalAssignment => PermissionDeniedKind.assignmentEnded,
      AccessSurface.sharedGrant => PermissionDeniedKind.grantRevoked,
    };

/// Returns a [PermissionDeniedException] when [error] is a permission denial
/// for [surface]; null otherwise (so callers rethrow non-permission errors
/// unchanged and preserve existing error handling for them).
PermissionDeniedException? asPermissionDenied(
  Object error, {
  required AccessSurface surface,
}) {
  if (!isPermissionDenied(error)) {
    return null;
  }
  return PermissionDeniedException(kindForSurface(surface), surface);
}
