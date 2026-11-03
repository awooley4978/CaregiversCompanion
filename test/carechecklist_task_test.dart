// Care Checklist task widget tests (cleanup audit O1 / N2).
//
// The dashboard's Care Checklist used to render hardcoded demo content for
// every streamed `carechecklist` record ('Morning Mobility Exercise' /
// 'Assist with wheelchair transfer' / completed: true) and created a NEW fake
// task on every row tap. These tests pin the corrected behaviour:
//   * a row renders the record's own title/subtitle/completed state,
//   * tapping a row toggles `completed` on that record and creates nothing,
//   * a row can be deleted,
//   * new tasks are created only by the explicit 'Edit List' add sheet,
//   * a rejected write (rules denial) is surfaced, never silent.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_project/app_state.dart';
import 'package:new_project/backend/backend.dart';
import 'package:new_project/components/dashboard_task_add_sheet/dashboard_task_add_sheet_widget.dart';
import 'package:new_project/components/dashboard_task_card/dashboard_task_card_widget.dart';
import 'package:provider/provider.dart';

import 'firebase_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DocumentReference recipient;

  setUpAll(() async {
    await initFirebaseForTest();
  });
  setUp(() {
    FFAppState.reset();
    fakeFirestore.clear();
    fakeFirestore.clearWriteError();
    recipient = FirebaseFirestore.instance.collection('careRecipients').doc('r1');
  });

  /// Seeds one checklist document through the app-facing API and returns the
  /// parsed record (the way the dashboard's stream hands rows to the card).
  Future<CarechecklistRecord> seedTask({
    String title = 'Give morning meds',
    String subtitle = 'With breakfast',
    bool completed = false,
  }) async {
    final ref = CarechecklistRecord.createDoc(recipient);
    await ref.set({
      ...createCarechecklistRecordData(
        title: title,
        subtitle: subtitle,
        iconeName: '',
        completed: completed,
      ),
      ...mapToFirestore({'created_time': FieldValue.serverTimestamp()}),
    });
    return CarechecklistRecord.getDocumentOnce(ref);
  }

  Future<void> pumpCard(
    WidgetTester tester,
    CarechecklistRecord record, {
    CarechecklistToggle? toggleCompleted,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<FFAppState>.value(
        value: FFAppState(),
        child: MaterialApp(
          home: Scaffold(
            body: DashboardTaskCardWidget(
              record: record,
              icon: const Icon(Icons.accessibility_new_rounded),
              toggleCompleted: toggleCompleted,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a row renders its own record, not the hardcoded demo task',
      (tester) async {
    final record = await seedTask(completed: false);
    await pumpCard(tester, record);

    expect(find.text('Give morning meds'), findsOneWidget);
    expect(find.text('With breakfast'), findsOneWidget);
    expect(find.text('Morning Mobility Exercise'), findsNothing);
    expect(find.text('Assist with wheelchair transfer'), findsNothing);

    // N2: the tick reflects what is STORED (completed: false -> no tick).
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('a stored completed task renders ticked', (tester) async {
    final record = await seedTask(completed: true);
    await pumpCard(tester, record);

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('tapping a row toggles completed and creates no new task',
      (tester) async {
    final record = await seedTask(completed: false);
    await pumpCard(tester, record);

    await tester.tap(find.text('Give morning meds'));
    await tester.pumpAndSettle();

    final saved = await CarechecklistRecord.getDocumentOnce(record.reference);
    expect(saved.completed, isTrue);

    // The old behaviour appended a fabricated 'Morning Mobility Exercise'.
    final all = await queryCarechecklistRecordOnce(parent: recipient);
    expect(all.length, 1);
  });

  testWidgets('a denied toggle shows a snackbar and leaves the task unchanged',
      (tester) async {
    final record = await seedTask(completed: false);
    await pumpCard(tester, record);

    fakeFirestore.writeError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing or insufficient permissions.',
    );
    await tester.tap(find.text('Give morning meds'));
    await tester.pumpAndSettle();

    expect(find.text('Could not update the task. Please try again.'),
        findsOneWidget);
    final saved = await CarechecklistRecord.getDocumentOnce(record.reference);
    expect(saved.completed, isFalse);
  });

  testWidgets('a rapid double tap issues exactly one write', (tester) async {
    final record = await seedTask(completed: false);
    // Hold the toggle write open so the second tap lands while it is in
    // flight — the race the guard exists for.
    final release = Completer<void>();
    var writes = 0;
    await pumpCard(tester, record, toggleCompleted: (ref, completed) async {
      writes++;
      await release.future;
      return setCarechecklistCompleted(ref, completed);
    });

    await tester.tap(find.text('Give morning meds'));
    await tester.pump();

    // While the write is on the wire the row is visibly non-interactive.
    expect(
      tester
          .widget<Opacity>(find
              .ancestor(
                of: find.text('Give morning meds'),
                matching: find.byType(Opacity),
              )
              .first)
          .opacity,
      lessThan(1.0),
    );

    // Second tap of the double tap: ignored, not a second overlapping write.
    await tester.tap(find.text('Give morning meds'));
    await tester.pump();
    expect(writes, 1);

    release.complete();
    await tester.pump();
    await tester.pumpAndSettle();

    // One write, and it is the one the caregiver's tap asked for (unticked ->
    // ticked), not a second write flipping it back.
    expect(writes, 1);
    final saved = await CarechecklistRecord.getDocumentOnce(record.reference);
    expect(saved.completed, isTrue);

    // The row is interactive again once the write has landed.
    expect(
      tester
          .widget<Opacity>(find
              .ancestor(
                of: find.text('Give morning meds'),
                matching: find.byType(Opacity),
              )
              .first)
          .opacity,
      1.0,
    );
  });

  testWidgets('the delete control asks first, then removes the task',
      (tester) async {
    final record = await seedTask();
    await pumpCard(tester, record);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    // Deleting is permanent, so it asks before touching the record.
    expect(find.text('Delete Task?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    final all = await queryCarechecklistRecordOnce(parent: recipient);
    expect(all, isEmpty);
  });

  testWidgets('cancelling the delete confirmation keeps the task',
      (tester) async {
    final record = await seedTask();
    await pumpCard(tester, record);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Delete Task?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Task?'), findsNothing);
    final all = await queryCarechecklistRecordOnce(parent: recipient);
    expect(all.length, 1);
    expect(all.first.title, 'Give morning meds');
  });

  testWidgets('a denied delete shows a snackbar and keeps the task',
      (tester) async {
    final record = await seedTask();
    await pumpCard(tester, record);

    fakeFirestore.writeError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing or insufficient permissions.',
    );
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Could not delete the task. Please try again.'),
        findsOneWidget);
    final all = await queryCarechecklistRecordOnce(parent: recipient);
    expect(all.length, 1);
  });

  Future<void> openAddSheet(
    WidgetTester tester, {
    List<CarechecklistRecord>? existing,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<FFAppState>.value(
        value: FFAppState(),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => DashboardTaskAddSheetWidget(
                    careRecipientRef: recipient,
                    existingTasksStream: existing == null
                        ? null
                        : Stream<List<CarechecklistRecord>>.value(existing),
                  ),
                ),
                child: const Text('Edit List'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit List'));
    await tester.pumpAndSettle();
  }

  testWidgets('the Edit List add action creates the task that was typed',
      (tester) async {
    await openAddSheet(tester);

    await tester.enterText(find.byType(TextField).at(0), 'Afternoon walk');
    await tester.enterText(find.byType(TextField).at(1), 'Around the garden');
    await tester.tap(find.text('Add Task'));
    await tester.pumpAndSettle();

    final all = await queryCarechecklistRecordOnce(parent: recipient);
    expect(all.length, 1);
    expect(all.first.title, 'Afternoon walk');
    expect(all.first.subtitle, 'Around the garden');
    expect(all.first.completed, isFalse);
  });

  testWidgets('Edit List lets an existing task be edited in place',
      (tester) async {
    final record = await seedTask();
    await openAddSheet(tester, existing: [record]);

    // The list action shows the caregiver's real tasks, each with an edit
    // control (this used to be add-only).
    expect(find.text('Give morning meds'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Edit checklist task'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
      'Give morning meds',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      'With breakfast',
    );

    await tester.enterText(find.byType(TextField).at(0), 'Give evening meds');
    await tester.enterText(find.byType(TextField).at(1), 'With dinner');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    // It UPDATES that record — it does not append a second task.
    final all = await queryCarechecklistRecordOnce(parent: recipient);
    expect(all.length, 1);
    final saved = await CarechecklistRecord.getDocumentOnce(record.reference);
    expect(saved.title, 'Give evening meds');
    expect(saved.subtitle, 'With dinner');
    expect(saved.completed, isFalse);
  });

  testWidgets('a denied edit shows a snackbar and leaves the task unchanged',
      (tester) async {
    final record = await seedTask();
    await openAddSheet(tester, existing: [record]);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Give evening meds');

    fakeFirestore.writeError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing or insufficient permissions.',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Could not save the task. Please try again.'),
        findsOneWidget);
    final saved = await CarechecklistRecord.getDocumentOnce(record.reference);
    expect(saved.title, 'Give morning meds');
  });

  testWidgets('a denied add shows a snackbar and creates nothing',
      (tester) async {
    await openAddSheet(tester);

    fakeFirestore.writeError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing or insufficient permissions.',
    );
    await tester.enterText(find.byType(TextField).at(0), 'Afternoon walk');
    await tester.tap(find.text('Add Task'));
    await tester.pumpAndSettle();

    expect(find.text('Could not add the task. Please try again.'),
        findsOneWidget);
    final all = await queryCarechecklistRecordOnce(parent: recipient);
    expect(all, isEmpty);
  });
}
