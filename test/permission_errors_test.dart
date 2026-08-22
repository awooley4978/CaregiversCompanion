// Unit tests for the permission-denied classification (phase 5 hardening).
//
// These cover the PURE classification surface in permission_errors.dart —
// what counts as a permission-denied error, and how a denied AccessSurface
// maps to a routing kind. Routing to actual screens is covered by
// test/permission_router_test.dart.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/backend/permissions/permission_errors.dart';

void main() {
  group('isPermissionDenied', () {
    test('recognizes a FirebaseException with code permission-denied', () {
      expect(
        isPermissionDenied(FirebaseException(
          code: 'permission-denied',
          plugin: 'cloud_firestore',
        )),
        isTrue,
      );
    });

    test('recognizes a PlatformException with code permission-denied', () {
      expect(
        isPermissionDenied(PlatformException(code: 'permission-denied')),
        isTrue,
      );
    });

    test('rejects non-permission codes and non-exception errors', () {
      expect(
        isPermissionDenied(
            FirebaseException(code: 'not-found', plugin: 'cloud_firestore')),
        isFalse,
      );
      expect(
        isPermissionDenied(
            FirebaseException(code: 'unavailable', plugin: 'cloud_firestore')),
        isFalse,
      );
      expect(isPermissionDenied(Exception('boom')), isFalse);
      expect(isPermissionDenied('permission-denied'), isFalse);
    });
  });

  group('kindForSurface', () {
    test('maps each access surface to its routing kind', () {
      expect(kindForSurface(AccessSurface.careCircleGroup),
          PermissionDeniedKind.staleGroup);
      expect(kindForSurface(AccessSurface.professionalAssignment),
          PermissionDeniedKind.assignmentEnded);
      expect(kindForSurface(AccessSurface.sharedGrant),
          PermissionDeniedKind.grantRevoked);
    });
  });

  group('asPermissionDenied', () {
    test('returns a classified exception for a denied surface', () {
      final denied = asPermissionDenied(
        FirebaseException(code: 'permission-denied', plugin: 'cloud_firestore'),
        surface: AccessSurface.careCircleGroup,
      );
      expect(denied, isNotNull);
      expect(denied!.kind, PermissionDeniedKind.staleGroup);
      expect(denied.surface, AccessSurface.careCircleGroup);
    });

    test('returns null (do not wrap) for a non-permission error', () {
      final denied = asPermissionDenied(
        FirebaseException(code: 'aborted', plugin: 'cloud_firestore'),
        surface: AccessSurface.careCircleGroup,
      );
      expect(denied, isNull);
    });

    test('classifies assignment denial as assignmentEnded', () {
      final denied = asPermissionDenied(
        PlatformException(code: 'permission-denied'),
        surface: AccessSurface.professionalAssignment,
      );
      expect(denied, isNotNull);
      expect(denied!.kind, PermissionDeniedKind.assignmentEnded);
    });

    test('classifies a revoked-grant denial as grantRevoked', () {
      final denied = asPermissionDenied(
        FirebaseException(code: 'permission-denied', plugin: 'cloud_firestore'),
        surface: AccessSurface.sharedGrant,
      );
      expect(denied!.kind, PermissionDeniedKind.grantRevoked);
    });
  });
}
