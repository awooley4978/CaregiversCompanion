// Calendar page reads real data (appointments unit, part 2 — proposal §7).
//
// What is covered here:
//  * the display helpers — Monday-first week, month/day headings, the count
//    line, time and "Today/Tomorrow" labels, the day agenda order, the next
//    upcoming appointment (completed and past ones skipped), the client-side
//    search filter and the day-dot tone;
//  * the page renders the selected recipient's REAL appointments: the real
//    month heading, the real count line, the real selected-day heading, the
//    real rows — and none of the fabricated "March 2024" / "You have 3 tasks
//    today" / "Product Strategy Sync" / "Quarterly Planning" content;
//  * the week strip shows real day numbers and a dot only on days that have an
//    appointment, and tapping a day selects it;
//  * the Today pill returns to today and is active only when today is selected;
//  * the search icon filters the LOADED appointments client-side;
//  * honest empty states (no recipient, no appointments, no match, no upcoming)
//    and an honest error state — never invented events;
//  * switching recipients never shows another recipient's appointments.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/backend/appointments/appointment_display.dart';
import 'package:new_project/backend/backend.dart';
import 'package:new_project/calendar_page/calendar_page_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initFirebaseForTest();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FFAppState.reset();
    fakeFirestore.clear();
    fakeFirestore.clearWriteError();
    fakeFirestore.clearQueryError();
    FFAppState().selectedCareRecipient = null;
    FFAppState().activeGroupId = null;
    fakeAuthPlatform.emitSignedIn(uid: 'uid-1', email: 'cg@example.com');
  });

  DocumentReference recipientRef([String id = 'r1']) =>
      FirebaseFirestore.instance.doc('careRecipients/$id');

  Future<void> seedRecipient({String id = 'r1'}) async {
    await recipientRef(id).set({'Name': 'Margaret Alvarez', 'orgId': 'org_test'});
  }

  Future<void> seedAppointment({
    String recipientId = 'r1',
    required String title,
    required DateTime start,
    DateTime? end,
    String type = '',
    String provider = '',
    bool completed = false,
  }) async {
    await AppointmentsRecord.collection.doc().set(
      createAppointmentsRecordData(
        careRecipientRef: recipientRef(recipientId),
        appointmentTitle: title,
        appointmentType: type.isEmpty ? null : type,
        appointmentDateTime: start,
        endDateTime: end,
        providerName: provider.isEmpty ? null : provider,
        completed: completed,
        orgId: 'org_test',
        createdByUid: 'uid-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<List<AppointmentsRecord>> loaded([String recipientId = 'r1']) =>
      queryAppointmentsRecordOnce(
        queryBuilder: (q) => q
            .where('careRecipientRef', isEqualTo: recipientRef(recipientId))
            .orderBy('appointmentDateTime'),
      );

  // A FIXED local instant — Friday, 20 November 2026, 4:00 PM. Every date below
  // is derived from it and the page is handed the same instant, so this file
  // never depends on the wall clock or on the machine's time zone. (Before this
  // the suite ran on `DateTime.now()`, so at 05:30 the 09:30 appointment was
  // still in the future: it appeared on the Upcoming card as well as in the
  // agenda, and "tomorrow's" visit was no longer the next upcoming one.)
  //
  // 4:00 PM is deliberately after both of today's seeded times, so today's
  // appointments are in the past and tomorrow's is the next upcoming one.
  final now = DateTime(2026, 11, 20, 16, 0);
  final todayAt0930 = DateTime(now.year, now.month, now.day, 9, 30);
  final todayAt1400 = DateTime(now.year, now.month, now.day, 14, 0);
  final tomorrowAt1000 = DateTime(now.year, now.month, now.day, 10, 0)
      .add(const Duration(days: 1));

  Future<void> pumpCalendar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080.0, 2400.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: CalendarPageWidget(now: now)));
    await tester.pumpAndSettle();
  }

  group('display helpers', () {
    test('the week starts on Monday and has seven real days', () {
      // 2026-11-20 is a Friday.
      final week = weekDaysFor(DateTime(2026, 11, 20));
      expect(week.length, 7);
      expect(week.first, DateTime(2026, 11, 16));
      expect(week.first.weekday, DateTime.monday);
      expect(week.last, DateTime(2026, 11, 22));
    });

    test('headings and the count line come from the real date', () {
      final day = DateTime(2026, 11, 20);
      expect(calendarMonthHeading(day), 'November 2026');
      expect(calendarDayHeading(day), 'Friday, November 20');
      expect(
        calendarCountLine(2, day: day, today: DateTime(2026, 11, 20)),
        'You have 2 appointments today',
      );
      expect(
        calendarCountLine(1, day: day, today: DateTime(2026, 11, 19)),
        'You have 1 appointment on Fri, Nov 20',
      );
      expect(
        calendarCountLine(0, day: day, today: DateTime(2026, 11, 20)),
        'You have 0 appointments today',
      );
    });

    test('time labels use the stored start and end', () async {
      await seedRecipient();
      await seedAppointment(
        title: 'Cardiology Follow-up',
        start: todayAt0930,
        end: todayAt0930.add(const Duration(hours: 1)),
      );
      await seedAppointment(title: 'Lab work', start: todayAt1400);

      final records = await loaded();
      expect(appointmentTimeLabel(records[0]), '9:30 AM - 10:30 AM');
      expect(appointmentTimeLabel(records[1]), '2:00 PM');
    });

    test('"Today"/"Tomorrow" are produced by comparing dates', () {
      final base = DateTime(2026, 11, 20, 9, 30);
      expect(appointmentWhenLabel(base, now: DateTime(2026, 11, 20, 8)),
          'Today at 9:30 AM');
      expect(appointmentWhenLabel(base, now: DateTime(2026, 11, 19, 8)),
          'Tomorrow at 9:30 AM');
      expect(appointmentWhenLabel(base, now: DateTime(2026, 11, 10, 8)),
          'Nov 20 at 9:30 AM');
    });

    test('the day agenda is the day\'s records, earliest first', () async {
      await seedRecipient();
      await seedAppointment(title: 'Afternoon visit', start: todayAt1400);
      await seedAppointment(title: 'Morning visit', start: todayAt0930);

      final records = await loaded();
      final day = appointmentsOnDay(records, now);
      expect(day.map((r) => r.appointmentTitle).toList(),
          ['Morning visit', 'Afternoon visit']);
      expect(
        appointmentsOnDay(records, tomorrowAt1000),
        isEmpty,
      );
    });

    test('the next upcoming appointment skips past and completed records',
        () async {
      await seedRecipient();
      await seedAppointment(
        title: 'Already done',
        start: tomorrowAt1000,
        completed: true,
      );
      await seedAppointment(
        title: 'Past visit',
        start: now.subtract(const Duration(days: 2)),
      );
      await seedAppointment(title: 'Next visit', start: tomorrowAt1000);

      final records = await loaded();
      expect(
        nextUpcomingAppointment(records, now)?.appointmentTitle,
        'Next visit',
      );
    });

    test('search matches title, provider and type only', () async {
      await seedRecipient();
      await seedAppointment(
        title: 'Cardiology Follow-up',
        start: todayAt0930,
        type: 'medical',
        provider: 'Dr Okafor',
      );

      final record = (await loaded()).single;
      expect(appointmentMatchesSearch(record, 'cardio'), isTrue);
      expect(appointmentMatchesSearch(record, 'okafor'), isTrue);
      expect(appointmentMatchesSearch(record, 'medical'), isTrue);
      expect(appointmentMatchesSearch(record, '  '), isTrue);
      expect(appointmentMatchesSearch(record, 'dentist'), isFalse);
    });

    test('a day with no appointments gets no dot', () async {
      await seedRecipient();
      await seedAppointment(
        title: 'Cardiology Follow-up',
        start: todayAt0930,
        type: 'therapy',
      );

      final records = await loaded();
      expect(dayDotTone(records, now), 'tertiary');
      expect(dayDotTone(records, tomorrowAt1000), 'transparent');
    });
  });

  group('Calendar page', () {
    testWidgets('shows the real month, count, heading and appointments',
        (tester) async {
      await seedRecipient();
      FFAppState().selectedCareRecipient = recipientRef();
      await seedAppointment(
        title: 'Cardiology Follow-up',
        start: todayAt0930,
        end: todayAt0930.add(const Duration(hours: 1)),
        type: 'medical',
      );
      await seedAppointment(title: 'Physio session', start: todayAt1400);
      await seedAppointment(title: 'Hospice nurse visit', start: tomorrowAt1000);

      await pumpCalendar(tester);

      expect(find.text(calendarMonthHeading(now)), findsOneWidget);
      expect(find.text('You have 2 appointments today'), findsOneWidget);
      expect(find.text(calendarDayHeading(now)), findsOneWidget);
      // The agenda rows (a title can also appear on the Upcoming card, so
      // these are matched as "at least once").
      expect(find.text('Cardiology Follow-up'), findsWidgets);
      expect(find.text('Physio session'), findsWidgets);
      expect(find.text('9:30 AM - 10:30 AM'), findsOneWidget);

      // The fabricated content is gone.
      expect(find.text('March 2024'), findsNothing);
      expect(find.text('You have 3 tasks today'), findsNothing);
      expect(find.text('Thursday, March 14'), findsNothing);
      expect(find.text('Product Strategy Sync'), findsNothing);
      expect(find.text('Design Review: Calendar UI'), findsNothing);
      expect(find.text('Lunch with Sarah'), findsNothing);
      expect(find.text('Quarterly Planning'), findsNothing);

      // The Upcoming card is the same real record, never a placeholder.
      expect(find.text('Hospice nurse visit'), findsOneWidget);
      expect(find.text(appointmentWhenLabel(tomorrowAt1000, now: now)),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the week strip renders real days and dots, and a tap selects',
        (tester) async {
      await seedRecipient();
      FFAppState().selectedCareRecipient = recipientRef();
      await seedAppointment(title: 'Hospice nurse visit', start: tomorrowAt1000);

      await pumpCalendar(tester);

      for (final day in weekDaysFor(now)) {
        expect(
          find.byKey(ValueKey('calendarDay-${DateFormat('yyyy-MM-dd').format(day)}')),
          findsOneWidget,
        );
      }
      // Real day numbers for the week, not the export's 11–17.
      expect(find.text('${weekDaysFor(now).first.day}'), findsWidgets);

      await tester.tap(find.byKey(
          ValueKey('calendarDay-${DateFormat('yyyy-MM-dd').format(tomorrowAt1000)}')));
      await tester.pumpAndSettle();

      expect(find.text(calendarDayHeading(tomorrowAt1000)), findsOneWidget);
      expect(find.text('Hospice nurse visit'), findsWidgets);
      expect(
        find.text(calendarCountLine(1, day: tomorrowAt1000, today: now)),
        findsOneWidget,
      );

      // The Today pill brings the agenda back to today.
      await tester.tap(find.byKey(const ValueKey('calendarTodayPill')));
      await tester.pumpAndSettle();
      expect(find.text(calendarDayHeading(now)), findsOneWidget);
      expect(find.byKey(const ValueKey('calendarDayEmpty')), findsOneWidget);
    });

    testWidgets('the search icon filters the loaded appointments',
        (tester) async {
      await seedRecipient();
      FFAppState().selectedCareRecipient = recipientRef();
      await seedAppointment(title: 'Cardiology Follow-up', start: todayAt0930);
      await seedAppointment(title: 'Physio session', start: todayAt1400);

      await pumpCalendar(tester);
      // Once: 9:30 AM has already passed at the fixed 4:00 PM, so it is the
      // agenda row only and not also the next upcoming appointment.
      expect(find.text('Cardiology Follow-up'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('calendarSearchButton')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('calendarSearchField')), 'physio');
      await tester.pumpAndSettle();

      expect(find.text('Physio session'), findsWidgets);
      expect(find.text('Cardiology Follow-up'), findsNothing);
      expect(find.text('You have 1 appointment today'), findsOneWidget);

      await tester.enterText(
          find.byKey(const ValueKey('calendarSearchField')), 'dentist');
      await tester.pumpAndSettle();
      expect(find.text(calendarNoAppointmentsMatchSearch), findsOneWidget);
    });

    testWidgets('an appointment later today is in the agenda and Upcoming both',
        (tester) async {
      // This overlap is BY DESIGN, not a duplicate-render bug: the agenda lists
      // the selected day, the Upcoming card shows the next appointment that has
      // not started yet. The two surfaces show the same record whenever that
      // record is later today. The old wall-clock tests ran at whatever time CI
      // happened to build and mistook this for a regression.
      await seedRecipient();
      FFAppState().selectedCareRecipient = recipientRef();
      await seedAppointment(
        title: 'Evening check-in',
        start: DateTime(now.year, now.month, now.day, 18, 0),
      );

      await pumpCalendar(tester);

      expect(find.text('You have 1 appointment today'), findsOneWidget);
      // Once in the day agenda, once on the Upcoming card.
      expect(find.text('Evening check-in'), findsNWidgets(2));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('calendarUpcomingTitle')))
            .data,
        'Evening check-in',
      );
      expect(find.text('Today at 6:00 PM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty day and an empty schedule both say so honestly',
        (tester) async {
      await seedRecipient();
      FFAppState().selectedCareRecipient = recipientRef();
      await seedAppointment(title: 'Hospice nurse visit', start: tomorrowAt1000);

      await pumpCalendar(tester);

      expect(find.byKey(const ValueKey('calendarDayEmpty')), findsOneWidget);
      expect(find.text(calendarNoAppointmentsForDay), findsOneWidget);
      expect(find.text('You have 0 appointments today'), findsOneWidget);

      // Tomorrow's row is real, so the schedule is not empty overall.
      await tester.tap(find.byKey(
          ValueKey('calendarDay-${DateFormat('yyyy-MM-dd').format(tomorrowAt1000)}')));
      await tester.pumpAndSettle();
      expect(find.text(calendarNoAppointmentsForDay), findsNothing);
    });

    testWidgets('a recipient with no appointments has honest empty states',
        (tester) async {
      await seedRecipient();
      FFAppState().selectedCareRecipient = recipientRef();

      await pumpCalendar(tester);

      expect(find.text(calendarNoAppointmentsAtAll), findsOneWidget);
      expect(find.text(calendarNoUpcomingAppointment), findsOneWidget);
      expect(find.text('You have 0 appointments today'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with no recipient the page says so and invents nothing',
        (tester) async {
      await pumpCalendar(tester);

      expect(find.text(calendarNoRecipient), findsOneWidget);
      expect(find.text('No care recipient selected'), findsOneWidget);
      expect(find.text(calendarNoUpcomingAppointment), findsOneWidget);
      expect(find.text('Product Strategy Sync'), findsNothing);
    });

    testWidgets('a failed read shows the honest error state, never events',
        (tester) async {
      await seedRecipient();
      FFAppState().selectedCareRecipient = recipientRef();
      await seedAppointment(title: 'Cardiology Follow-up', start: todayAt0930);

      fakeFirestore.queryError = Exception('failed-precondition: index');
      await pumpCalendar(tester);

      expect(find.byKey(const ValueKey('calendarLoadError')), findsOneWidget);
      expect(find.text(calendarLoadError), findsOneWidget);
      expect(find.text('Cardiology Follow-up'), findsNothing);
      expect(find.text('Product Strategy Sync'), findsNothing);
      expect(find.byKey(const ValueKey('calendarUpcomingWhen')), findsNothing);
    });

    testWidgets('switching recipients never shows the previous one\'s data',
        (tester) async {
      await seedRecipient();
      await seedRecipient(id: 'r2');
      FFAppState().selectedCareRecipient = recipientRef();
      await seedAppointment(title: 'Cardiology Follow-up', start: todayAt0930);
      await seedAppointment(
        recipientId: 'r2',
        title: 'Dental cleaning',
        start: todayAt1400,
      );

      await pumpCalendar(tester);
      expect(find.text('Cardiology Follow-up'), findsWidgets);
      expect(find.text('Dental cleaning'), findsNothing);

      FFAppState().selectedCareRecipient = recipientRef('r2');
      await tester.pumpAndSettle();

      expect(find.text('Dental cleaning'), findsWidgets);
      expect(find.text('Cardiology Follow-up'), findsNothing);
    });
  });
}
