// Widget tests for the permission-denied router (phase 5 hardening).
//
// Verifies that each PermissionDeniedKind routes the user to the correct
// destination via the single centralized handler (permission_router.dart):
// staleGroup -> Household picker, assignmentEnded -> the Professional
// "assignment ended" state, grantRevoked -> recipient list. Also verifies the
// AssignmentEndedWidget itself renders without crashing. No Firebase backend
// is needed — these are pure navigation tests against a minimal in-test
// GoRouter.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/backend/permissions/permission_errors.dart';
import 'package:new_project/backend/permissions/permission_router.dart';
import 'package:new_project/pages/a_client_directory/a_client_directory_widget.dart';
import 'package:new_project/pages/assignment_ended/assignment_ended_widget.dart';
import 'package:new_project/pages/group/household_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FFAppState.reset();
  });

  Future<void> pumpRouter(
      WidgetTester tester, PermissionDeniedKind initial) async {
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (context, state) => _Trigger(kind: initial),
        ),
        GoRoute(
          path: HouseholdWidget.routePath,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('ROUTE_HOUSEHOLD'))),
        ),
        GoRoute(
          path: AssignmentEndedWidget.routePath,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('ROUTE_ASSIGNMENT_ENDED'))),
        ),
        GoRoute(
          path: AClientDirectoryWidget.routePath,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('ROUTE_CLIENT_DIRECTORY'))),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byKey(const Key('trigger')));
    await tester.pumpAndSettle();
  }

  testWidgets('stale group routes to the Household picker', (tester) async {
    await pumpRouter(tester, PermissionDeniedKind.staleGroup);
    expect(find.text('ROUTE_HOUSEHOLD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assignment-ended routes to the Professional ended state',
      (tester) async {
    await pumpRouter(tester, PermissionDeniedKind.assignmentEnded);
    expect(find.text('ROUTE_ASSIGNMENT_ENDED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('revoked grant routes back to the recipient list',
      (tester) async {
    await pumpRouter(tester, PermissionDeniedKind.grantRevoked);
    expect(find.text('ROUTE_CLIENT_DIRECTORY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AssignmentEndedWidget renders within the app design language',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AssignmentEndedWidget()));
    await tester.pumpAndSettle();
    expect(find.text('This care assignment has ended'), findsOneWidget);
    expect(find.text('Back to care'), findsOneWidget);
    expect(find.textContaining('Professional care assignment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Trigger extends StatelessWidget {
  const _Trigger({required this.kind});

  final PermissionDeniedKind kind;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const Key('trigger'),
          onPressed: () => routePermissionDenied(context, kind),
          child: const Text('Trigger'),
        ),
      ),
    );
  }
}
