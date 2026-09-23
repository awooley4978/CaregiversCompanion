import '/backend/backend.dart';
import '/backend/org/org_service.dart';
import '/components/add_meal_widget.dart';
import '/components/button/button_widget.dart';
import '/components/dashboard_notes_form/dashboard_notes_form_widget.dart';
import '/components/dashboard_task_card/dashboard_task_card_widget.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/components/patent_picker_sheet_widget.dart';
import '/components/section_header/section_header_widget.dart';
import '/components/vital_chip/vital_chip_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/pages/d_medication_tracker/d_medication_tracker_widget.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'c_daily_dashboard_model.dart';
export 'c_daily_dashboard_model.dart';

/// Defensive deref for the Daily Dashboard's Morning Vitals document.
///
/// The dashboard is also reachable from the nav menu ('Daily Care') with no
/// `careRecipients` param, and `FFAppState().selectedCareRecipient` is
/// in-memory/per-user — it is null until a care-recipient card is tapped (a
/// fresh session, or any session where nothing was selected yet). Building the
/// stream with `selectedCareRecipient!` threw 'Null check operator used on a
/// null value' while the page built (red screen); stream nothing instead and
/// let the builder below render the section's empty state.
@visibleForTesting
Stream<CareRecipientsRecord>? selectedRecipientVitalsStream() {
  final selected = FFAppState().selectedCareRecipient;
  if (selected == null) {
    return null;
  }
  return CareRecipientsRecord.getDocument(selected);
}

/// The care recipient every Dashboard read and write is scoped to.
///
/// The page has two entry points: pushed WITH the route param (a client
/// directory card tap / post-Save-Profile navigation — PR #23) and from the nav
/// menu's 'Daily Care' entry, which pushes it with NO param. On the second path
/// the working recipient is whatever the signed-in caregiver has selected
/// (`FFAppState().selectedCareRecipient`, per-user and persisted). When neither
/// exists there is no recipient to address, and the callers keep the PR #29
/// behaviour: an empty state, never a crash and never a forever spinner.
@visibleForTesting
DocumentReference? dashboardRecipientRef(CareRecipientsRecord? passed) =>
    passed?.reference ?? FFAppState().selectedCareRecipient;

/// Newest-first ordering for the Care Checklist, applied in Dart.
///
/// The recipient-scoped query must NOT `orderBy('created_time')`: Firestore
/// silently DROPS every document missing the ordered field, so a checklist
/// written by any path that did not stamp `created_time` reads to the caregiver
/// as "the checklist is empty". Ordering the records the query did return keeps
/// the newest-first design AND every record.
int carechecklistNewestFirst(CarechecklistRecord a, CarechecklistRecord b) {
  final ta = a.createdTime;
  final tb = b.createdTime;
  if (ta == null && tb == null) {
    return 0;
  }
  if (ta == null) {
    return 1;
  }
  if (tb == null) {
    return -1;
  }
  return tb.compareTo(ta);
}

/// Parent-safe `carechecklist` stream for the dashboard's Care Checklist.
///
/// The checklist lives in a `carechecklist` SUBCOLLECTION of the care
/// recipient, so the query needs that parent reference. On the nav-menu path
/// ('Daily Care') the page is built without a `careRecipients` param, and
/// `CarechecklistRecord.collection(null)` falls back to a
/// `collectionGroup('carechecklist')` query — which the Firestore rules do not
/// permit (no `{path=**}/carechecklist` rule), so the query is denied. With no
/// parent reference there is nothing to read: stream an empty list (the
/// section's empty state) instead of issuing a query that cannot succeed. With
/// one (the resolved recipient), read that recipient's real checklist.
@visibleForTesting
Stream<List<CarechecklistRecord>> carechecklistForParent(
    DocumentReference? parent) {
  if (parent == null) {
    return Stream<List<CarechecklistRecord>>.value(const []);
  }
  return queryCarechecklistRecord(parent: parent).map(
    (records) => [...records]..sort(carechecklistNewestFirst),
  );
}

/// Newest-first ordering for the symptom list, applied in Dart.
///
/// Same reason as [carechecklistNewestFirst]: `orderBy('timeLogged')` drops
/// every entry that has no logged time (legacy/imported rows), which is one way
/// the section can query "successfully" and still never show anything.
int symptomEntriesNewestFirst(SymptomEntriesRecord a, SymptomEntriesRecord b) {
  final ta = a.timeLogged;
  final tb = b.timeLogged;
  if (ta == null && tb == null) {
    return 0;
  }
  if (ta == null) {
    return 1;
  }
  if (tb == null) {
    return -1;
  }
  return tb.compareTo(ta);
}

/// The dose the Dashboard's 'Taken' button marks next: the earliest scheduled
/// medication that is not already taken TODAY.
///
/// "Taken today" is [isTakenForDay] — the exact day-rollover rule the
/// Medication Tracker renders with (PR #22), so both pages agree on what
/// "taken" means. Returns null when every dose is already taken for today (the
/// caller then leaves the records alone instead of re-stamping a timestamp).
@visibleForTesting
MedicationsRecord? nextPendingDose(List<MedicationsRecord> meds, DateTime now) {
  final sorted = [...meds]..sort((a, b) {
      final ta = a.scheduledTime;
      final tb = b.scheduledTime;
      if (ta == null && tb == null) {
        return 0;
      }
      if (ta == null) {
        return 1;
      }
      if (tb == null) {
        return -1;
      }
      return ta.compareTo(tb);
    });
  for (final med in sorted) {
    if (!isTakenForDay(med.takenAt, now)) {
      return med;
    }
  }
  return null;
}

/// Newest-first ordering for the Meals list, applied in Dart.
///
/// Same reason as [symptomEntriesNewestFirst]: `orderBy('createdAt')` silently
/// drops every entry written without a timestamp, which is how the card can
/// query "successfully" and still never show a meal.
int mealEntriesNewestFirst(MealEntriesRecord a, MealEntriesRecord b) {
  final ta = a.createdAt;
  final tb = b.createdAt;
  if (ta == null && tb == null) {
    return 0;
  }
  if (ta == null) {
    return 1;
  }
  if (tb == null) {
    return -1;
  }
  return tb.compareTo(ta);
}

/// The resolved recipient's meals, newest first - the live read behind the
/// 'Meals and Hydration' card (owner round-5, symptom 1: a saved meal was
/// invisible everywhere in the app because nothing read this collection).
///
/// The query is scoped EXACTLY like the medications list (orgId == the caller's
/// active group AND patientRef == the recipient) for the same Phase-4 rules
/// reason: a Firestore LIST rule cannot `get()` a candidate document, so the
/// mealEntries LIST rule gates on the STORED orgId (canListRecipientsInOrg) and
/// only a query that filters on that field can read it. Without the orgId filter
/// the list is denied live even after a confirmed save.
@visibleForTesting
Stream<List<MealEntriesRecord>> mealEntriesForRecipient({
  required DocumentReference? recipientRef,
}) {
  final orgId = FFAppState().activeGroupId;
  if (recipientRef == null || orgId == null || orgId.isEmpty) {
    return Stream.value(const []);
  }
  return queryMealEntriesRecord(
    queryBuilder: (q) => q
        .where('orgId', isEqualTo: orgId)
        .where('patientRef', isEqualTo: recipientRef),
  ).map((records) => [...records]..sort(mealEntriesNewestFirst));
}

/// The resolved recipient's medications - the live stream behind the 'Taken'
/// dose card, built with the SAME scoped lookup [_markTaken] runs
/// (orgId + careRecipientRef: the field set the Phase-4 medications LIST rule
/// gates on). The card used to render hardcoded demo content ('Donepezil
/// 10mg') that no record backed, while the Taken button acted on real data -
/// the contradiction the owner reported as "it's on a dose card".
@visibleForTesting
Stream<List<MedicationsRecord>> medicationsForRecipient({
  required DocumentReference? recipientRef,
}) {
  final orgId = FFAppState().activeGroupId;
  if (recipientRef == null || orgId == null || orgId.isEmpty) {
    return Stream.value(const []);
  }
  return queryMedicationsRecord(
    queryBuilder: (q) => q
        .where('orgId', isEqualTo: orgId)
        .where('careRecipientRef', isEqualTo: recipientRef),
  );
}

/// How many meals the dashboard card lists before summarising the rest: the card
/// is a daily summary, not the full history, and the live read is newest-first.
const dashboardMealsShown = 3;

/// The dose card's headline: the next pending dose ("Donepezil 10mg"), the
/// honest empty state, or the all-taken state. Built on the same
/// [nextPendingDose] the Taken button acts on, so the card can no longer
/// describe a dose the action cannot find.
@visibleForTesting
String medicationCardHeadline(List<MedicationsRecord> meds, DateTime now) {
  if (meds.isEmpty) {
    return 'No medications added yet.';
  }
  final dose = nextPendingDose(meds, now);
  if (dose == null) {
    return 'All of today\'s doses are taken.';
  }
  final name = dose.medicationName.trim();
  final amount = dose.dose.trim();
  final labelled = name.isEmpty ? 'Medication' : name;
  return amount.isEmpty ? labelled : '$labelled $amount';
}

/// The dose card's second line ("Take with breakfast • 8:00 AM"), built
/// from the next pending dose's real schedule fields. Empty when there is
/// nothing truthful to show (no medications at all, or every dose already taken
/// today).
@visibleForTesting
String medicationCardSubtitle(List<MedicationsRecord> meds, DateTime now) {
  final dose = nextPendingDose(meds, now);
  if (dose == null) {
    return '';
  }
  final directions = dose.directions.trim();
  final timeOfDay = dose.timeOfDay.trim();
  final schedule = directions.isNotEmpty ? directions : timeOfDay;
  final parts = <String>[
    if (schedule.isNotEmpty) schedule,
    if (dose.scheduledTime != null)
      dateTimeFormat('hh:mm a', dose.scheduledTime),
  ];
  return parts.join(' • ');
}

/// A meal row's headline: the meal's own name (or its type when the caregiver
/// saved a nameless meal - the Add Meal form still allows that).
@visibleForTesting
String mealEntryHeadline(MealEntriesRecord meal) {
  final name = meal.mealName.trim();
  if (name.isNotEmpty) {
    return name;
  }
  final type = meal.mealType.trim();
  return type.isEmpty ? 'Meal' : type;
}

/// A meal row's second line - the fields the Add Meal sheet captured
/// ("Lunch • 1/2 cup • 11:30 AM"), in the card's existing subtitle style.
@visibleForTesting
String mealEntrySubtitle(MealEntriesRecord meal) {
  final parts = <String>[
    if (meal.mealType.trim().isNotEmpty) meal.mealType.trim(),
    if (meal.amountEaten.trim().isNotEmpty) meal.amountEaten.trim(),
    if (meal.createdAt != null) dateTimeFormat('hh:mm a', meal.createdAt),
  ];
  return parts.join(' • ');
}

/// Opens the Add Meal sheet for [recipientRef] — the ONE code path every
/// 'Add Meal' affordance on the Daily Dashboard uses: the meal card's tap, the
/// section's 'Add Meal' button, and now the 'Meals and Hydration' section
/// header's action (owner round-5 finding #3: the header's button had no
/// handler at all). Extracted rather than copied so the three cannot drift.
@visibleForTesting
Future<void> openAddMealSheet(
  BuildContext context,
  DocumentReference? recipientRef,
) {
  return showModalBottomSheet(
    isScrollControlled: true,
    backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
    enableDrag: false,
    context: context,
    builder: (context) {
      return GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Padding(
          padding: MediaQuery.viewInsetsOf(context),
          child: AddMealWidget(patientRef: recipientRef),
        ),
      );
    },
  );
}
class CDailyDashboardWidget extends StatefulWidget {
  const CDailyDashboardWidget({
    super.key,
    required this.careRecipients,
  });

  final CareRecipientsRecord? careRecipients;

  static String routeName = 'CDailyDashboard';
  static String routePath = '/cDailyDashboard';

  @override
  State<CDailyDashboardWidget> createState() => _CDailyDashboardWidgetState();
}

class _CDailyDashboardWidgetState extends State<CDailyDashboardWidget> {
  late CDailyDashboardModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CDailyDashboardModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      // Normalise the working recipient: when the page was pushed WITH the
      // route param, make the app-wide selection match it, so the child sheets
      // and cards below (Add Meal, the checklist card, the notes form) target
      // the same recipient this dashboard is showing.
      final passedRef = widget.careRecipients?.reference;
      if (passedRef != null &&
          FFAppState().selectedCareRecipient != passedRef) {
        FFAppState().selectedCareRecipient = passedRef;
      }
      _model.selectedDate = getCurrentTimestamp;
      safeSetState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  /// The working care recipient for this dashboard: the route param when the
  /// page was pushed with one, else the app-wide selection.
  DocumentReference? get _recipientRef =>
      dashboardRecipientRef(widget.careRecipients);

  /// Marks the resolved recipient's next pending dose as taken — the same
  /// `medications` write the Medication Tracker's check-circle performs (PR #22
  /// `medicationTakenUpdate`), so the Dashboard's 'Taken' button and the
  /// tracker agree on the record shape (taken / status / takenAt).
  ///
  /// The lookup reuses the tracker's list query verbatim: `orgId` == the
  /// caller's active group AND `careRecipientRef` == the resolved recipient —
  /// the field set the Phase-4 `medications` LIST rule gates on, so this is a
  /// scoped read, never an unscoped one.
  Future<void> _markTaken(BuildContext context) async {
    final recipientRef = _recipientRef;
    final orgId = FFAppState().activeGroupId ?? '';
    if (recipientRef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a care recipient to update medications.'),
        ),
      );
      return;
    }
    if (orgId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active care circle for this account yet.'),
        ),
      );
      return;
    }
    try {
      final meds = await queryMedicationsRecordOnce(
        queryBuilder: (q) => q
            .where('orgId', isEqualTo: orgId)
            .where('careRecipientRef', isEqualTo: recipientRef),
      );
      final dose = nextPendingDose(meds, DateTime.now());
      if (dose == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No pending dose to mark as taken.'),
            ),
          );
        }
        return;
      }
      await dose.reference.update(medicationTakenUpdate(taken: true));
      if (context.mounted) {
        final name = dose.medicationName.trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${name.isEmpty ? 'Dose' : name} marked as taken.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Could not update this medication. Please try again.'),
          ),
        );
      }
    }
  }

  /// The Dashboard's 'Add Meal' entry point: the sheet in [openAddMealSheet],
  /// then a rebuild so the live meals card picks the new entry up (the sheet
  /// itself pops on a successful save).
  Future<void> _openAddMealSheet(BuildContext context) async {
    await openAddMealSheet(context, _recipientRef);
    safeSetState(() {});
  }
  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(0.0, 50.0, 0.0, 0.0),
          child: SingleChildScrollView(
            primary: false,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional(0.0, 0.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            35.0, 35.0, 0.0, 0.0),
                        child: Text(
                          'Daily Dashboard',
                          style: FlutterFlowTheme.of(context)
                              .headlineMedium
                              .override(
                                font: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .headlineMedium
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).primaryText,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.bold,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .headlineMedium
                                    .fontStyle,
                                lineHeight: 1.3,
                              ),
                        ),
                      ),
                      Flexible(
                        child: Align(
                          alignment: AlignmentDirectional(1.0, -1.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                50.0, 35.0, 30.0, 0.0),
                            child: FlutterFlowIconButton(
                              borderRadius: 28.0,
                              buttonSize: 40.0,
                              fillColor: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                              icon: Icon(
                                Icons.menu,
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                size: 24.0,
                              ),
                              onPressed: () async {
                                await showModalBottomSheet(
                                  isScrollControlled: true,
                                  backgroundColor: FlutterFlowTheme.of(context)
                                      .primaryBackground,
                                  enableDrag: false,
                                  context: context,
                                  builder: (context) {
                                    return GestureDetector(
                                      onTap: () {
                                        FocusScope.of(context).unfocus();
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                      },
                                      child: Padding(
                                        padding:
                                            MediaQuery.viewInsetsOf(context),
                                        child: NavMenuDirectoryWidget(),
                                      ),
                                    );
                                  },
                                ).then((value) => safeSetState(() {}));
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Container(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Align(
                          alignment: AlignmentDirectional(0.0, 0.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              StreamBuilder<List<CareRecipientsRecord>>(
                                stream: careRecipientsForActiveGroup(),
                                builder: (context, snapshot) {
                                  // Customize what your widget looks like when it's loading.
                                  if (snapshot.hasError) {
                                    return Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: Text(
                                        'Error loading care recipients: '
                                        '${snapshot.error}',
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium,
                                      ),
                                    );
                                  }
                                  if (!snapshot.hasData) {
                                    return Center(
                                      child: SizedBox(
                                        width: 50.0,
                                        height: 50.0,
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            FlutterFlowTheme.of(context)
                                                .primary,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  List<CareRecipientsRecord>
                                      containerCareRecipientsRecordList =
                                      snapshot.data!;

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                      borderRadius:
                                          BorderRadius.circular(9999.0),
                                      shape: BoxShape.rectangle,
                                      border: Border.all(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          4.0, 4.0, 12.0, 4.0),
                                      child: Container(
                                        child: InkWell(
                                          splashColor: Colors.transparent,
                                          focusColor: Colors.transparent,
                                          hoverColor: Colors.transparent,
                                          highlightColor: Colors.transparent,
                                          onTap: () async {
                                            await showModalBottomSheet(
                                              isScrollControlled: true,
                                              backgroundColor:
                                                  Colors.transparent,
                                              enableDrag: false,
                                              context: context,
                                              builder: (context) {
                                                return GestureDetector(
                                                  onTap: () {
                                                    FocusScope.of(context)
                                                        .unfocus();
                                                    FocusManager
                                                        .instance.primaryFocus
                                                        ?.unfocus();
                                                  },
                                                  child: Padding(
                                                    padding:
                                                        MediaQuery.viewInsetsOf(
                                                            context),
                                                    child:
                                                        PatentPickerSheetWidget(),
                                                  ),
                                                );
                                              },
                                            ).then(
                                                (value) => safeSetState(() {}));
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 32.0,
                                                height: 32.0,
                                                decoration: BoxDecoration(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .tertiary,
                                                  shape: BoxShape.circle,
                                                ),
                                                alignment: AlignmentDirectional(
                                                    0.0, 0.0),
                                                child: Text(
                                                  'M',
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .labelMedium
                                                      .override(
                                                        font:
                                                            GoogleFonts.nunito(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        fontSize: 12.16,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                        lineHeight: 0.4,
                                                      ),
                                                  overflow: TextOverflow.clip,
                                                ),
                                              ),
                                              Text(
                                                'Mom',
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .labelLarge
                                                    .override(
                                                      font: GoogleFonts.nunito(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelLarge
                                                                .fontStyle,
                                                      ),
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .labelLarge
                                                              .fontStyle,
                                                      lineHeight: 1.4,
                                                    ),
                                              ),
                                              Icon(
                                                Icons
                                                    .keyboard_arrow_down_rounded,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                size: 20.0,
                                              ),
                                            ].divide(SizedBox(width: 8.0)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Opacity(
                          opacity: 0.9,
                          child: Container(
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context).warning,
                              borderRadius: BorderRadius.circular(28.0),
                              shape: BoxShape.rectangle,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Container(
                                child: Align(
                                  alignment: AlignmentDirectional(0.0, 0.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            dateTimeFormat("MMMMEEEEd",
                                                _model.selectedDate),
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  font: GoogleFonts.nunito(
                                                    fontWeight: FontWeight.w600,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.w600,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontStyle,
                                                  lineHeight: 1.6,
                                                ),
                                          ),
                                        ].divide(SizedBox(height: 2.0)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            wrapWithModel(
                              model: _model.sectionHeaderModel1,
                              updateCallback: () => safeSetState(() {}),
                              // No action: this section has no create flow
                              // yet, so the header renders no button rather
                              // than a dead 'Log New'.
                              child: SectionHeaderWidget(
                                title: 'Morning Vitals',
                              ),
                            ),
                            if (widget!.careRecipients?.trackVitals ?? true)
                              StreamBuilder<CareRecipientsRecord>(
                                stream: selectedRecipientVitalsStream(),
                                builder: (context, snapshot) {
                                  // No care recipient selected (first run, or
                                  // the dashboard opened from the nav menu):
                                  // there is no vitals document to stream, so
                                  // render the section's empty state rather
                                  // than a spinner that would never resolve.
                                  if (FFAppState().selectedCareRecipient ==
                                      null) {
                                    return const SizedBox.shrink();
                                  }
                                  // Customize what your widget looks like when it's loading.
                                  if (!snapshot.hasData) {
                                    return Center(
                                      child: SizedBox(
                                        width: 50.0,
                                        height: 50.0,
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            FlutterFlowTheme.of(context)
                                                .primary,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final containerCareRecipientsRecord =
                                      snapshot.data!;

                                  return Container(
                                    decoration: BoxDecoration(),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          if (widget!.careRecipients
                                                  ?.trackVitals ??
                                              true)
                                            Flexible(
                                              child: Align(
                                                alignment: AlignmentDirectional(
                                                    0.0, 0.0),
                                                child: wrapWithModel(
                                                  model: _model.vitalChipModel1,
                                                  updateCallback: () =>
                                                      safeSetState(() {}),
                                                  child: VitalChipWidget(
                                                    icon: Icon(
                                                      Icons.favorite_rounded,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      size: 16.0,
                                                    ),
                                                    label: 'Heart Rate',
                                                    value: '72 bpm',
                                                  ),
                                                ),
                                              ),
                                            ),
                                          if (widget!.careRecipients
                                                  ?.trackVitals ??
                                              true)
                                            wrapWithModel(
                                              model: _model.vitalChipModel2,
                                              updateCallback: () =>
                                                  safeSetState(() {}),
                                              child: VitalChipWidget(
                                                icon: Icon(
                                                  Icons.speed_rounded,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primary,
                                                  size: 16.0,
                                                ),
                                                label: 'Blood Pressure',
                                                value: '118/76',
                                              ),
                                            ),
                                          if (widget!.careRecipients
                                                  ?.trackGlucose ??
                                              true)
                                            wrapWithModel(
                                              model: _model.vitalChipModel3,
                                              updateCallback: () =>
                                                  safeSetState(() {}),
                                              child: VitalChipWidget(
                                                icon: Icon(
                                                  Icons.thermostat_rounded,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primary,
                                                  size: 16.0,
                                                ),
                                                label: 'Glucose',
                                                value: '94 mg/dL',
                                              ),
                                            ),
                                          if (widget!.careRecipients
                                                  ?.trackVitals ??
                                              true)
                                            wrapWithModel(
                                              model: _model.vitalChipModel4,
                                              updateCallback: () =>
                                                  safeSetState(() {}),
                                              child: VitalChipWidget(
                                                icon: Icon(
                                                  Icons.monitor_weight_rounded,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primary,
                                                  size: 16.0,
                                                ),
                                                label: 'Weight',
                                                value: '142 lbs',
                                              ),
                                            ),
                                        ].divide(SizedBox(width: 5.0)),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            wrapWithModel(
                              model: _model.sectionHeaderModel2,
                              updateCallback: () => safeSetState(() {}),
                              child: SectionHeaderWidget(
                                action: 'View Schedule',
                                title: 'Medications',
                                // Same destination as the nav menu's
                                // 'Medication Tracker' entry.
                                onAction: () => context.pushNamed(
                                    DMedicationTrackerWidget.routeName),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 0.0, 0.0, 16.0),
                              child: Container(
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    if (widget!
                                            .careRecipients?.trackMedication ??
                                        true)
                                      Container(
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                          borderRadius:
                                              BorderRadius.circular(36.0),
                                          shape: BoxShape.rectangle,
                                          border: Border.all(
                                            color: FlutterFlowTheme.of(context)
                                                .tertiary,
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: Container(
                                            decoration: BoxDecoration(),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Container(
                                                  width: 48.0,
                                                  height: 48.0,
                                                  decoration: BoxDecoration(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .tertiary,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            28.0),
                                                    shape: BoxShape.rectangle,
                                                  ),
                                                  alignment:
                                                      AlignmentDirectional(
                                                          0.0, 0.0),
                                                  child: Icon(
                                                    Icons.medication_rounded,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primaryText,
                                                    size: 24.0,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 1,
                                                  child: StreamBuilder<List<MedicationsRecord>>(
                                                    // Live replacement for the hardcoded "Donepezil 10mg" demo
                                                    // card: the exact scoped query the Taken button below runs, so
                                                    // the card describes the real record(s) - or says honestly
                                                    // that there are none.
                                                    stream: medicationsForRecipient(recipientRef: _recipientRef),
                                                    builder: (context, snapshot) {
                                                      final meds = snapshot.data ??
                                                        const <MedicationsRecord>[];
                                                      final now = DateTime.now();
                                                      final doseHeadline = snapshot.hasError
                                                        ? 'Could not load medications.'
                                                        : (snapshot.hasData
                                                          ? medicationCardHeadline(meds, now)
                                                          : 'Loading medications…');
                                                      final doseSubtitle =
                                                        (!snapshot.hasData || snapshot.hasError)
                                                        ? ''
                                                        : medicationCardSubtitle(meds, now);
                                                      return Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        doseHeadline,
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .override(
                                                                  font: GoogleFonts
                                                                      .nunito(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyLarge
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontStyle,
                                                                  lineHeight:
                                                                      1.6,
                                                                ),
                                                      ),
                                                      if (doseSubtitle.isNotEmpty) Text(
                                                        doseSubtitle,
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodySmall
                                                                .override(
                                                                  font: GoogleFonts
                                                                      .nunito(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodySmall
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodySmall
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .fontStyle,
                                                                  lineHeight:
                                                                      1.5,
                                                                ),
                                                      ),
                                                    ].divide(
                                                        SizedBox(height: 2.0)),
                                                  );
                                                    },
                                                  ),
                                                ),
                                                InkWell(
                                                  splashColor:
                                                      Colors.transparent,
                                                  focusColor:
                                                      Colors.transparent,
                                                  hoverColor:
                                                      Colors.transparent,
                                                  highlightColor:
                                                      Colors.transparent,
                                                  onTap: () async {
                                                    await _markTaken(context);
                                                  },
                                                  child: wrapWithModel(
                                                    model: _model.buttonModel1,
                                                    updateCallback: () =>
                                                        safeSetState(() {}),
                                                    child: ButtonWidget(
                                                      iconPresent: false,
                                                      iconEndPresent: false,
                                                      content: 'Taken',
                                                      variant: 'primary',
                                                      size: 'small',
                                                      fullWidth: false,
                                                      loading: false,
                                                      disabled: false,
                                                    ),
                                                  ),
                                                ),
                                              ].divide(SizedBox(width: 16.0)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 30.0, 0.0, 0.0),
                                      child: wrapWithModel(
                                        model: _model.sectionHeaderModel3,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        // No action: logging a symptom
                                        // entry is an owner-decision item, so
                                        // the header shows no button (the ''
                                        // label used to render as a dead
                                        // 'Log New').
                                        child: SectionHeaderWidget(
                                          title: 'Symptoms',
                                        ),
                                      ),
                                    ),
                                    StreamBuilder<List<SymptomEntriesRecord>>(
                                      // Scoped to the RESOLVED recipient: the
                                      // route param when this page was pushed
                                      // with one, else the app-wide selection.
                                      // Reading the selection directly is how
                                      // the section stayed empty on the
                                      // nav-menu 'Daily Care' path.
                                      stream: symptomEntriesForRecipient(
                                          recipientRef: _recipientRef),
                                      builder: (context, snapshot) {
                                        // A denied query must not leave the
                                        // section spinning forever.
                                        if (snapshot.hasError) {
                                          return const SizedBox.shrink();
                                        }
                                        // Customize what your widget looks like when it's loading.
                                        if (!snapshot.hasData) {
                                          return Center(
                                            child: SizedBox(
                                              width: 50.0,
                                              height: 50.0,
                                              child: CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        // Newest-first in Dart, not via
                                        // orderBy: that would drop every entry
                                        // with no logged time.
                                        final listViewSymptomEntriesRecordList =
                                            <SymptomEntriesRecord>[
                                              ...snapshot.data!
                                            ]..sort(
                                                symptomEntriesNewestFirst);

                                        return ListView.builder(
                                          padding: EdgeInsets.zero,
                                          shrinkWrap: true,
                                          scrollDirection: Axis.vertical,
                                          itemCount:
                                              listViewSymptomEntriesRecordList
                                                  .length,
                                          itemBuilder:
                                              (context, listViewIndex) {
                                            final listViewSymptomEntriesRecord =
                                                listViewSymptomEntriesRecordList[
                                                    listViewIndex];
                                            return Container(
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryBackground,
                                                borderRadius:
                                                    BorderRadius.circular(36.0),
                                                shape: BoxShape.rectangle,
                                                border: Border.all(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .tertiary,
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: Padding(
                                                padding: EdgeInsets.all(16.0),
                                                child: Container(
                                                  decoration: BoxDecoration(),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Container(
                                                        width: 48.0,
                                                        height: 48.0,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .tertiary,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      28.0),
                                                          shape: BoxShape
                                                              .rectangle,
                                                        ),
                                                        alignment:
                                                            AlignmentDirectional(
                                                                0.0, 0.0),
                                                        child: Icon(
                                                          Icons
                                                              .admin_panel_settings,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          size: 24.0,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 1,
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .start,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              listViewSymptomEntriesRecord
                                                                  .symptomName,
                                                              style: FlutterFlowTheme
                                                                      .of(context)
                                                                  .bodyLarge
                                                                  .override(
                                                                    font: GoogleFonts
                                                                        .nunito(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      fontStyle: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyLarge
                                                                          .fontStyle,
                                                                    ),
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                                    letterSpacing:
                                                                        0.0,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyLarge
                                                                        .fontStyle,
                                                                    lineHeight:
                                                                        1.6,
                                                                  ),
                                                            ),
                                                            Text(
                                                              listViewSymptomEntriesRecord
                                                                  .note,
                                                              style: FlutterFlowTheme
                                                                      .of(context)
                                                                  .bodySmall
                                                                  .override(
                                                                    font: GoogleFonts
                                                                        .nunito(
                                                                      fontWeight: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodySmall
                                                                          .fontWeight,
                                                                      fontStyle: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodySmall
                                                                          .fontStyle,
                                                                    ),
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
                                                                        .secondaryText,
                                                                    letterSpacing:
                                                                        0.0,
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodySmall
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodySmall
                                                                        .fontStyle,
                                                                    lineHeight:
                                                                        1.5,
                                                                  ),
                                                            ),
                                                            Text(
                                                              valueOrDefault<
                                                                  String>(
                                                                listViewSymptomEntriesRecord
                                                                    .timeLogged
                                                                    ?.toString(),
                                                                'Time Logged',
                                                              ),
                                                              style: FlutterFlowTheme
                                                                      .of(context)
                                                                  .bodyMedium
                                                                  .override(
                                                                    font: GoogleFonts
                                                                        .nunito(
                                                                      fontWeight: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .fontWeight,
                                                                      fontStyle: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .fontStyle,
                                                                    ),
                                                                    letterSpacing:
                                                                        0.0,
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .fontStyle,
                                                                  ),
                                                            ),
                                                          ].divide(SizedBox(
                                                              height: 2.0)),
                                                        ),
                                                      ),
                                                      InkWell(
                                                        splashColor:
                                                            Colors.transparent,
                                                        focusColor:
                                                            Colors.transparent,
                                                        hoverColor:
                                                            Colors.transparent,
                                                        highlightColor:
                                                            Colors.transparent,
                                                        onTap: () async {
                                                          await SymptomEntriesRecord
                                                              .collection
                                                              .doc()
                                                              .set(
                                                                  createSymptomEntriesRecordData(
                                                                symptomName:
                                                                    listViewSymptomEntriesRecord
                                                                        .symptomName,
                                                                note:
                                                                    listViewSymptomEntriesRecord
                                                                        .note,
                                                                timeLogged:
                                                                    listViewSymptomEntriesRecord
                                                                        .timeLogged,
                                                                patientRef:
                                                                    listViewSymptomEntriesRecord
                                                                        .patientRef,
                                                                isResolved:
                                                                    false,
                                                              ));
                                                        },
                                                        child: ButtonWidget(
                                                          key: Key(
                                                              'Key7v7_${listViewIndex}_of_${listViewSymptomEntriesRecordList.length}'),
                                                          iconPresent: false,
                                                          iconEndPresent: false,
                                                          content: 'Add Entry',
                                                          variant: 'primary',
                                                          size: 'small',
                                                          fullWidth: false,
                                                          loading: false,
                                                          disabled: false,
                                                        ),
                                                      ),
                                                    ].divide(
                                                        SizedBox(width: 16.0)),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 30.0, 0.0, 0.0),
                                      child: wrapWithModel(
                                        model: _model.sectionHeaderModel4,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: SectionHeaderWidget(
                                          action: 'Add Meal',
                                          title: 'Meals and Hydration',
                                          // Same sheet as the meal card tap
                                          // and the section's 'Add Meal'
                                          // button.
                                          onAction: () =>
                                              _openAddMealSheet(context),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        borderRadius:
                                            BorderRadius.circular(36.0),
                                        shape: BoxShape.rectangle,
                                        border: Border.all(
                                          color: FlutterFlowTheme.of(context)
                                              .tertiary,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Container(
                                          decoration: BoxDecoration(),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 48.0,
                                                height: 48.0,
                                                decoration: BoxDecoration(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .tertiary,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          28.0),
                                                  shape: BoxShape.rectangle,
                                                ),
                                                alignment: AlignmentDirectional(
                                                    0.0, 0.0),
                                                child: Icon(
                                                  Icons.fastfood_rounded,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  size: 24.0,
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.start,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () => _openAddMealSheet(context),
                                                        child: StreamBuilder<List<MealEntriesRecord>>(
                                                          // This card used to show hardcoded demo copy (a saved meal
                                                          // was invisible everywhere in the app). It now reads the
                                                          // recipient's real meals, newest first.
                                                          stream: mealEntriesForRecipient(recipientRef: _recipientRef),
                                                          builder: (context, snapshot) {
                                                            final mutedStyle = FlutterFlowTheme.of(context)
                                                              .bodySmall
                                                              .override(
                                                                font: GoogleFonts.nunito(
                                                                  fontWeight:
                                                                    FlutterFlowTheme.of(context).bodySmall.fontWeight,
                                                                  fontStyle:
                                                                    FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                ),
                                                                color: FlutterFlowTheme.of(context).secondaryText,
                                                                letterSpacing: 0.0,
                                                                fontWeight:
                                                                  FlutterFlowTheme.of(context).bodySmall.fontWeight,
                                                                fontStyle:
                                                                  FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                lineHeight: 1.5,
                                                              );
                                                            // A denied or still-loading query must not leave the card
                                                            // spinning, and an empty collection must not keep showing
                                                            // demo food.
                                                            if (snapshot.hasError) {
                                                              return Text(
                                                                'Could not load meals.',
                                                                style: mutedStyle,
                                                              );
                                                            }
                                                            if (!snapshot.hasData) {
                                                              return Text(
                                                                'Loading meals…',
                                                                style: mutedStyle,
                                                              );
                                                            }
                                                            final meals = snapshot.data!;
                                                            if (meals.isEmpty) {
                                                              return Text(
                                                                'No meals logged yet',
                                                                style: mutedStyle,
                                                              );
                                                            }
                                                            final shown = meals.take(dashboardMealsShown).toList();
                                                            final extra = meals.length - shown.length;
                                                            return Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              mainAxisAlignment: MainAxisAlignment.start,
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                for (final meal in shown) _DashboardMealRow(meal),
                                                                if (extra > 0)
                                                                  Padding(
                                                                    padding: EdgeInsetsDirectional.fromSTEB(
                                                                      0.0, 4.0, 0.0, 0.0),
                                                                    child: Text(
                                                                      '+$extra earlier meal${extra == 1 ? '' : 's'}',
                                                                      style: mutedStyle,
                                                                    ),
                                                                  ),
                                                              ].divide(SizedBox(height: 8.0)),
                                                            );
                                                          },
                                                        ),
                                                    ),
                                                  ].divide(
                                                      SizedBox(height: 2.0)),
                                                ),
                                              ),
                                              InkWell(
                                                splashColor: Colors.transparent,
                                                focusColor: Colors.transparent,
                                                hoverColor: Colors.transparent,
                                                highlightColor:
                                                    Colors.transparent,
                                                onTap: () => _openAddMealSheet(context),
                                                child: wrapWithModel(
                                                  model: _model.buttonModel3,
                                                  updateCallback: () =>
                                                      safeSetState(() {}),
                                                  child: ButtonWidget(
                                                    iconPresent: false,
                                                    iconEndPresent: false,
                                                    content: 'Add Meal',
                                                    variant: 'primary',
                                                    size: 'small',
                                                    fullWidth: false,
                                                    loading: false,
                                                    disabled: false,
                                                  ),
                                                ),
                                              ),
                                            ].divide(SizedBox(width: 16.0)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (widget!.careRecipients?.trackMedication ?? true)
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 6.0),
                            child: Container(
                              height: 130.0,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                                borderRadius: BorderRadius.circular(36.0),
                                shape: BoxShape.rectangle,
                                border: Border.all(
                                  color: FlutterFlowTheme.of(context).tertiary,
                                  width: 1.0,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 58.2,
                                        height: 96.8,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(40.0),
                                          ),
                                        ),
                                        child: Align(
                                          alignment:
                                              AlignmentDirectional(0.0, 1.0),
                                          child: Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    15.0, 0.0, 0.0, 9.0),
                                            child: Container(
                                              width: 48.0,
                                              height: 48.0,
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .tertiary,
                                                borderRadius:
                                                    BorderRadius.circular(28.0),
                                                shape: BoxShape.rectangle,
                                              ),
                                              alignment: AlignmentDirectional(
                                                  0.0, 0.0),
                                              child: Icon(
                                                Icons.water_drop,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                size: 24.0,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Container(
                                          decoration: BoxDecoration(),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: 1,
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.start,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Align(
                                                      alignment:
                                                          AlignmentDirectional(
                                                              -1.0, -1.0),
                                                      child: Padding(
                                                        padding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    0.0,
                                                                    6.0,
                                                                    0.0,
                                                                    0.0),
                                                        child: Text(
                                                          'Daily Water Intake',
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyLarge
                                                              .override(
                                                                font:
                                                                    GoogleFonts
                                                                        .nunito(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontStyle,
                                                                ),
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryText,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyLarge
                                                                    .fontStyle,
                                                                lineHeight: 1.6,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                    Align(
                                                      alignment:
                                                          AlignmentDirectional(
                                                              -1.0, -1.0),
                                                      child: Text(
                                                        'Click to add water',
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .bodyLarge
                                                            .override(
                                                              font: GoogleFonts
                                                                  .nunito(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyLarge
                                                                    .fontStyle,
                                                              ),
                                                              color: FlutterFlowTheme
                                                                      .of(context)
                                                                  .primaryText,
                                                              fontSize: 10.0,
                                                              letterSpacing:
                                                                  0.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontStyle,
                                                              lineHeight: 1.6,
                                                            ),
                                                      ),
                                                    ),
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .start,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Align(
                                                          alignment:
                                                              AlignmentDirectional(
                                                                  0.0, 0.0),
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        0.0,
                                                                        3.0,
                                                                        0.0,
                                                                        0.0),
                                                            child: Container(
                                                              width: 241.2,
                                                              height: 42.49,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryBackground,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            28.0),
                                                                shape: BoxShape
                                                                    .rectangle,
                                                              ),
                                                              alignment:
                                                                  AlignmentDirectional(
                                                                      0.0, 0.0),
                                                              child: Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .spaceEvenly,
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  Stack(
                                                                    children: [
                                                                      Align(
                                                                        alignment: AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .water_drop_outlined,
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          size:
                                                                              30.0,
                                                                        ),
                                                                      ),
                                                                      Align(
                                                                        alignment: AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .water_drop,
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          size:
                                                                              30.0,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  Stack(
                                                                    children: [
                                                                      Align(
                                                                        alignment: AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .water_drop_outlined,
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          size:
                                                                              30.0,
                                                                        ),
                                                                      ),
                                                                      Align(
                                                                        alignment: AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .water_drop,
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          size:
                                                                              30.0,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  Stack(
                                                                    children: [
                                                                      Align(
                                                                        alignment: AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .water_drop_outlined,
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          size:
                                                                              30.0,
                                                                        ),
                                                                      ),
                                                                      Align(
                                                                        alignment: AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .water_drop,
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          size:
                                                                              30.0,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  Stack(
                                                                    children: [
                                                                      Align(
                                                                        alignment: AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .water_drop_outlined,
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          size:
                                                                              30.0,
                                                                        ),
                                                                      ),
                                                                      Align(
                                                                        alignment: AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .water_drop,
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          size:
                                                                              30.0,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  Stack(
                                                                    children: [
                                                                      Align(
                                                                        alignment: AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .water_drop_outlined,
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          size:
                                                                              30.0,
                                                                        ),
                                                                      ),
                                                                      Align(
                                                                        alignment: AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .water_drop,
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          size:
                                                                              30.0,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  Stack(
                                                                    children: [
                                                                      Align(
                                                                        alignment: AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .water_drop_outlined,
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          size:
                                                                              30.0,
                                                                        ),
                                                                      ),
                                                                      Align(
                                                                        alignment: AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .water_drop,
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          size:
                                                                              30.0,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  Stack(
                                                                    children: [
                                                                      Align(
                                                                        alignment: AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .water_drop_outlined,
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          size:
                                                                              30.0,
                                                                        ),
                                                                      ),
                                                                      Align(
                                                                        alignment: AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .water_drop,
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          size:
                                                                              30.0,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  Stack(
                                                                    children: [
                                                                      Align(
                                                                        alignment: AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .water_drop_outlined,
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          size:
                                                                              30.0,
                                                                        ),
                                                                      ),
                                                                      Align(
                                                                        alignment: AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .water_drop,
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          size:
                                                                              30.0,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  Stack(
                                                                    children: [
                                                                      Align(
                                                                        alignment: AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .water_drop_outlined,
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          size:
                                                                              30.0,
                                                                        ),
                                                                      ),
                                                                      Align(
                                                                        alignment: AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .water_drop,
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          size:
                                                                              30.0,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ].divide(
                                                          SizedBox(width: 0.0)),
                                                    ),
                                                  ].divide(
                                                      SizedBox(height: 2.0)),
                                                ),
                                              ),
                                            ].divide(SizedBox(width: 16.0)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Text(
                              'Care Checklist',
                              style: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .override(
                                    font: GoogleFonts.dmSans(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                            ),
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional(1.0, 0.0),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 8.0, 0.0),
                                  child: FFButtonWidget(
                                    onPressed: () async {
                                      await showModalBottomSheet(
                                        isScrollControlled: true,
                                        backgroundColor:
                                            FlutterFlowTheme.of(context)
                                                .primaryBackground,
                                        enableDrag: false,
                                        context: context,
                                        builder: (context) {
                                          return GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              // The card dereferences its
                                              // icon (`widget!.icon!`), so the
                                              // modal must pass one — the same
                                              // icon the checklist rows use.
                                              child: DashboardTaskCardWidget(
                                                icon: Icon(
                                                  Icons
                                                      .accessibility_new_rounded,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                  size: 20.0,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ).then((value) => safeSetState(() {}));
                                    },
                                    text: 'Edit List',
                                    options: FFButtonOptions(
                                      height: 30.0,
                                      padding: EdgeInsets.all(12.0),
                                      iconPadding:
                                          EdgeInsetsDirectional.fromSTEB(
                                              0.0, 0.0, 0.0, 0.0),
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      textStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .override(
                                            font: GoogleFonts.dmSans(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .titleSmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleSmall
                                                      .fontStyle,
                                            ),
                                            color: Colors.white,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontStyle,
                                          ),
                                      elevation: 0.0,
                                      borderRadius: BorderRadius.circular(24.0),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        StreamBuilder<List<CarechecklistRecord>>(
                          // Resolved recipient (route param or app-wide
                          // selection) — on the nav-menu path the param is
                          // null, which is why this section rendered nothing.
                          stream: carechecklistForParent(_recipientRef),
                          builder: (context, snapshot) {
                            // A denied or failed query must not leave the
                            // section spinning forever: fall through to the
                            // same empty rendering a recipient with no
                            // checklist entries shows.
                            if (snapshot.hasError) {
                              return const SizedBox.shrink();
                            }
                            // Customize what your widget looks like when it's loading.
                            if (!snapshot.hasData) {
                              return Center(
                                child: SizedBox(
                                  width: 50.0,
                                  height: 50.0,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      FlutterFlowTheme.of(context).primary,
                                    ),
                                  ),
                                ),
                              );
                            }
                            List<CarechecklistRecord>
                                listViewCarechecklistRecordList =
                                snapshot.data!;

                            return ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              scrollDirection: Axis.vertical,
                              itemCount: listViewCarechecklistRecordList.length,
                              itemBuilder: (context, listViewIndex) {
                                final listViewCarechecklistRecord =
                                    listViewCarechecklistRecordList[
                                        listViewIndex];
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    DashboardTaskCardWidget(
                                      key: Key(
                                          'Key258_${listViewIndex}_of_${listViewCarechecklistRecordList.length}'),
                                      icon: Icon(
                                        Icons.accessibility_new_rounded,
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                        size: 20.0,
                                      ),
                                      subtitle:
                                          'Assist with wheelchair transfer',
                                      title: 'Morning Mobility Exercise',
                                      completed: true,
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Text(
                              'Caregiver Notes',
                              style: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .override(
                                    font: GoogleFonts.dmSans(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                            ),
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional(1.0, 0.0),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 8.0, 0.0),
                                  child: FFButtonWidget(
                                    onPressed: () async {
                                      await showModalBottomSheet(
                                        isScrollControlled: true,
                                        backgroundColor:
                                            FlutterFlowTheme.of(context)
                                                .primaryBackground,
                                        barrierColor:
                                            FlutterFlowTheme.of(context)
                                                .alternate,
                                        enableDrag: false,
                                        context: context,
                                        builder: (context) {
                                          return GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              // The compose sheet writes
                                              // into `careNotes` ref-linked
                                              // to the resolved recipient.
                                              child: DashboardNotesFormWidget(
                                                authorBg: Color(0x00000000),
                                                careRecipientRef: _recipientRef,
                                                isPrivate: false,
                                              ),
                                            ),
                                          );
                                        },
                                      ).then((value) => safeSetState(() {}));
                                    },
                                    text: 'Add Note',
                                    options: FFButtonOptions(
                                      height: 30.0,
                                      padding: EdgeInsets.all(12.0),
                                      iconPadding:
                                          EdgeInsetsDirectional.fromSTEB(
                                              0.0, 0.0, 0.0, 0.0),
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      textStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .override(
                                            font: GoogleFonts.dmSans(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .titleSmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleSmall
                                                      .fontStyle,
                                            ),
                                            color: Colors.white,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontStyle,
                                          ),
                                      elevation: 0.0,
                                      borderRadius: BorderRadius.circular(24.0),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            borderRadius: BorderRadius.circular(36.0),
                            shape: BoxShape.rectangle,
                            border: Border.all(
                              color: FlutterFlowTheme.of(context).alternate,
                              width: 1.0,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Container(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 32.0,
                                        height: 32.0,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .secondary,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment:
                                            AlignmentDirectional(0.0, 0.0),
                                        child: Text(
                                          'AR',
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          style: FlutterFlowTheme.of(context)
                                              .labelMedium
                                              .override(
                                                font: GoogleFonts.nunito(
                                                  fontWeight: FontWeight.w600,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .onSurface,
                                                fontSize: 12.16,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w600,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontStyle,
                                                lineHeight: 1.4,
                                              ),
                                          overflow: TextOverflow.clip,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Sarah • 2h ago',
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .labelSmall
                                                      .override(
                                                        font:
                                                            GoogleFonts.nunito(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmall
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontStyle,
                                                        lineHeight: 1.3,
                                                      ),
                                                ),
                                                Icon(
                                                  Icons.lock_rounded,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .onSurface,
                                                  size: 12.0,
                                                ),
                                              ],
                                            ),
                                            Text(
                                              'Mom had a brief dizzy spell after lunch. Resting in the recliner. BP is stable.',
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .bodyMedium
                                                  .override(
                                                    font: GoogleFonts.nunito(
                                                      fontWeight:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontWeight,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontStyle,
                                                    ),
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primaryText,
                                                    letterSpacing: 0.0,
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontStyle,
                                                    lineHeight: 1.6,
                                                  ),
                                            ),
                                          ].divide(SizedBox(height: 4.0)),
                                        ),
                                      ),
                                    ].divide(SizedBox(width: 16.0)),
                                  ),
                                ].divide(SizedBox(height: 16.0)),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          height: 80.0,
                        ),
                      ].divide(SizedBox(height: 15.0)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One meal line on the dashboard's 'Meals and Hydration' card: the card's
/// existing row visual language (meal name + "type • amount • time"), bound
/// to a real `mealEntries` record instead of the demo copy the card used to show.
class _DashboardMealRow extends StatelessWidget {
  const _DashboardMealRow(this.meal);

  final MealEntriesRecord meal;

  @override
  Widget build(BuildContext context) {
    final subtitle = mealEntrySubtitle(meal);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          mealEntryHeadline(meal),
          style: FlutterFlowTheme.of(context).bodyLarge.override(
                font: GoogleFonts.nunito(
                  fontWeight: FontWeight.w600,
                  fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
                ),
                color: FlutterFlowTheme.of(context).primaryText,
                letterSpacing: 0.0,
                fontWeight: FontWeight.w600,
                fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
                lineHeight: 1.6,
              ),
        ),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  font: GoogleFonts.nunito(
                    fontWeight:
                        FlutterFlowTheme.of(context).bodySmall.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodySmall.fontStyle,
                  ),
                  color: FlutterFlowTheme.of(context).secondaryText,
                  letterSpacing: 0.0,
                  fontWeight:
                      FlutterFlowTheme.of(context).bodySmall.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                  lineHeight: 1.5,
                ),
          ),
      ].divide(SizedBox(height: 2.0)),
    );
  }
}
