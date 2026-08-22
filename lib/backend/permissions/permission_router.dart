// The single, app-wide router for Firestore permission-denied failures.
//
// Security phase 5 hardening (design §1.1, §6.4 "Error UX"). Once the Phase-4
// rules are locked, a rules denial surfaces to the app as a stream / future
// error. This router is where EVERY such failure ends up: pages intercept
// permission errors (via the shared classification in permission_errors.dart),
// then call [routePermissionDenied] to move the user somewhere actionable
// instead of showing a raw error — a stale group goes to the Household picker,
// an assignment expiry goes to the Professional "assignment ended" state, and
// a revoked share returns to the recipient list with a clear message.
//
// Successful paths are untouched; non-permission errors are the caller's to
// handle as before.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/app_state.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/pages/a_client_directory/a_client_directory_widget.dart';
import '/pages/assignment_ended/assignment_ended_widget.dart';
import '/pages/group/household_widget.dart';

import 'permission_errors.dart';

/// Human-readable message for each denial kind (also used by the assignment-
/// ended page when that route is chosen).
String permissionDeniedMessage(PermissionDeniedKind kind) => switch (kind) {
      PermissionDeniedKind.staleGroup =>
        'Your access to this care circle changed. Pick the care circle you '
            'want to view.',
      PermissionDeniedKind.assignmentEnded =>
        'This care assignment has ended. Contact your care organization to '
            'get a new assignment.',
      PermissionDeniedKind.grantRevoked =>
        'Access to this shared care recipient was revoked by its owner.',
    };

/// Shows a transient console-style message (SnackBar) for a denial, reusing
/// the app's existing error styling. Safe to call before navigating so the
/// message survives to the destination screen.
void showPermissionMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: FlutterFlowTheme.of(context).error,
      ),
    );
}

/// Routes [context] to the destination for a [PermissionDeniedKind].
///
/// This is the single place that owns the "where should a denied user go"
/// mapping, so the behavior stays consistent no matter which screen hit the
/// denial:
///  * [PermissionDeniedKind.staleGroup]     -> Household / group picker
///  * [PermissionDeniedKind.assignmentEnded]-> Professional "assignment
///    ended" state (model-ready; no Professional UI workflow yet)
///  * [PermissionDeniedKind.grantRevoked]   -> recipient list with a message
Future<void> routePermissionDenied(
  BuildContext context,
  PermissionDeniedKind kind,
) async {
  if (!context.mounted) {
    return;
  }
  switch (kind) {
    case PermissionDeniedKind.staleGroup:
      showPermissionMessage(
          context, permissionDeniedMessage(kind));
      context.go(HouseholdWidget.routePath);
    case PermissionDeniedKind.assignmentEnded:
      // The Professional workflow does not exist yet; ship the minimal route
      // and state now so staff never see a raw error when D7 fires.
      context.go(AssignmentEndedWidget.routePath);
    case PermissionDeniedKind.grantRevoked:
      // Return to the recipient list; do not hold a stale selection.
      FFAppState().selectedCareRecipient = null;
      showPermissionMessage(
          context, permissionDeniedMessage(kind));
      context.go(AClientDirectoryWidget.routePath);
  }
}

/// Runs a Firestore WRITE/READ future through the shared permission handler.
///
/// Wraps [run] so that:
///  * successful results pass through unchanged (caller returns them);
///  * a permission denial for [surface] is routed via [routePermissionDenied]
///    and a [PermissionDeniedException] is rethrown for the page's local
///    catch-block to finish (e.g. clear a busy spinner);
///  * any NON-permission error is rethrown untouched (existing behavior).
Future<T> guardPermission<T>(
  BuildContext context,
  Future<T> Function() run, {
  required AccessSurface surface,
}) async {
  try {
    return await run();
  } catch (e) {
    final denied = asPermissionDenied(e, surface: surface);
    if (denied == null) {
      rethrow;
    }
    await routePermissionDenied(context, denied.kind);
    throw denied;
  }
}

/// Wraps a Firestore STREAM through the shared permission handler.
///
/// Catches a permission denial on the stream and routes via
/// [routePermissionDenied]; non-permission errors and the successful data
/// stream are forwarded unchanged. Callers that use StreamBuilder should
/// instead handle the error in the builder via [classifyStreamError] so they
/// can also render a local state; this helper is for code that pipes a stream
/// through the handler without a builder.
Stream<T> guardPermissionStream<T>(
  Stream<T> source,
  BuildContext context, {
  required AccessSurface surface,
}) {
  return source.handleError((Object e, StackTrace st) {
    final denied = asPermissionDenied(e, surface: surface);
    if (denied == null) {
      // NOT a permission denial: preserve existing behavior and let the
      // error surface to the stream's listener / StreamBuilder normally.
      throw e;
    }
    // Permission denial: route the user; the stream has already been
    // navigated away from, so the error need not surface further.
    routePermissionDenied(context, denied.kind);
  });
}

/// Classifies a StreamBuilder / async `snapshot.error` permission failure.
///
/// Returns the routed [PermissionDeniedKind] when [error] is a denial for
/// [surface] (and routes it), or null for any other error so the page keeps
/// its existing non-permission error rendering. Call from a StreamBuilder
/// error branch.
PermissionDeniedKind? classifyStreamError(
  BuildContext context,
  Object? error, {
  required AccessSurface surface,
}) {
  if (error == null) {
    return null;
  }
  final denied = asPermissionDenied(error, surface: surface);
  if (denied == null) {
    return null;
  }
  routePermissionDenied(context, denied.kind);
  return denied.kind;
}
