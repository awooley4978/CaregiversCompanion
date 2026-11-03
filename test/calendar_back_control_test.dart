// Calendar back control (U4 navigation repair).
//
// The Calendar page (/calendarPage) has no AppBar, so before this change the
// only way out was the system back gesture — a dead end on the web build. This
// test pushes CalendarPageWidget onto a minimal in-test GoRouter stack (the way
// Doctor Visit Prep reaches it, via pushNamed) and verifies the new header back
// control pops back to the previous screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/calendar_page/calendar_page_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FFAppState.reset();
  });

  testWidgets('Calendar header back control pops back to the previous screen',
      (tester) async {
    tester.view.physicalSize = const Size(1080.0, 2400.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('openCalendar'),
                onPressed: () => context.push(CalendarPageWidget.routePath),
                child: const Text('ROUTE_HOME'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: CalendarPageWidget.routePath,
          builder: (context, state) => const CalendarPageWidget(),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('ROUTE_HOME'), findsOneWidget);

    await tester.tap(find.byKey(const Key('openCalendar')));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarPageWidget), findsOneWidget);
    expect(find.text('ROUTE_HOME'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('calendarBackButton')));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarPageWidget), findsNothing);
    expect(find.text('ROUTE_HOME'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
