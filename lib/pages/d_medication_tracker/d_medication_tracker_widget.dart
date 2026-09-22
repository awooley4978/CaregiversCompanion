import '/backend/backend.dart';
import '/components/add_medication/add_medication_widget.dart';
import '/components/button/button_widget.dart';
import '/components/med_card/med_card_widget.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/components/refill_item/refill_item_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import 'd_medication_tracker_model.dart';
export 'd_medication_tracker_model.dart';

/// Builds the Firestore update payload for a Taken/un-taken toggle on a med.
///
/// Only marking a dose Taken stamps `takenAt` with a server timestamp (the day
/// the dose was actually taken). Untoggling back to Pending clears the field
/// with `FieldValue.delete()` so no stale or new timestamp lingers — the record
/// then reads `takenAt` as null (owner req: "clear/null rather than writing a
/// new timestamp").
Map<String, dynamic> medicationTakenUpdate({required bool taken}) => {
      'taken': taken,
      'status': taken ? 'TAKEN' : 'PENDING',
      'takenAt': taken ? FieldValue.serverTimestamp() : FieldValue.delete(),
    };

/// Effective "taken for today" state for a med: a dose counts as Taken only
/// when its `takenAt` timestamp falls on the current local calendar date.
///
/// A persisted `taken:true` from a previous day (or a missing timestamp)
/// renders as Pending for the new day and does not count toward today's
/// adherence ring — the stored `taken` boolean is left untouched (render-time,
/// day-rollover interpretation, not a persisted reset).
bool isTakenForDay(DateTime? takenAt, DateTime now) {
  if (takenAt == null) {
    return false;
  }
  final t = takenAt.toLocal();
  final n = now.toLocal();
  return t.year == n.year && t.month == n.month && t.day == n.day;
}

/// Groups a medication record into the Morning schedule section.
///
/// Legacy/demo meds carry a real clock time (`scheduledTime`): AM < 12 -> Morn.
/// V1 records captured by the Add Medication form store NO clock time
/// (scheduledTime unset) — there the Morning/Afternoon dropdown value IS the
/// schedule value, so group by `timeOfDay` (defaulting to Morning when neither
/// is present). A freshly-saved med therefore lands in the correct section and
/// is never silently dropped.
bool isMedicationMorning(MedicationsRecord med) {
  final t = med.scheduledTime;
  if (t != null) {
    return t.hour < 12;
  }
  return med.timeOfDay != 'Afternoon';
}

class DMedicationTrackerWidget extends StatefulWidget {
  const DMedicationTrackerWidget({super.key});

  static String routeName = 'DMedicationTracker';
  static String routePath = '/dMedicationTracker';

  @override
  State<DMedicationTrackerWidget> createState() =>
      _DMedicationTrackerWidgetState();
}

class _DMedicationTrackerWidgetState extends State<DMedicationTrackerWidget> {
  late DMedicationTrackerModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DMedicationTrackerModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  /// Persists a Taken/un-taken toggle back to the `medications` collection for
  /// the selected care recipient. The Phase-4 rules enforce the recipient-org
  /// gate via `careRecipientRef` (an owner/active member may update; a
  /// stranger/other-org member is denied). This is a real write driven by the
  /// med card's check-circle control — replacing the old `print` stub
  /// (audit-part3 §1a).
  Future<void> _onTakenChanged(
    BuildContext context,
    MedicationsRecord med,
    bool taken,
  ) async {
    try {
      await med.reference.update(medicationTakenUpdate(taken: taken));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update this medication. Please try again.'),
          ),
        );
      }
    }
  }

  /// Opens the Add Medication create form as a bottom sheet (the repo's
  /// AddMealWidget modal pattern). The form writes a `medications` doc scoped
  /// to the selected care recipient; the tracker's live stream (the same
  /// scoped query below) picks the new record up with no extra wiring.
  Future<void> _openAddMedication(BuildContext context) async {
    await showModalBottomSheet(
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
            child: AddMedicationWidget(),
          ),
        );
      },
    ).then((value) => safeSetState(() {}));
  }

  /// Builds one live medication card from a `medications` record, keeping the
  /// existing MedCard component and visual language. Background/status colors
  /// are driven by whether the dose has been taken (green "taken" vs the
  /// neutral "pending" look the demo already used for un-taken doses).
  Widget _buildMedCard(BuildContext context, MedicationsRecord med) {
    // Effective per-day taken state: a stale `taken:true` from a previous day
    // (or a missing `takenAt`) renders as Pending for the new day instead of
    // trusting the persisted boolean alone.
    final taken = isTakenForDay(med.takenAt, DateTime.now());
    final timeLabel = med.scheduledTime != null
        ? dateTimeFormat('hh:mm a', med.scheduledTime)
        : (med.timeOfDay.isNotEmpty ? med.timeOfDay : '');
    return MedCardWidget(
      bgTint: taken
          ? const Color(0xFFE8F5E9)
          : FlutterFlowTheme.of(context).primaryBackground,
      dosage: med.dose.isEmpty ? '—' : med.dose,
      icon: Icon(
        Icons.medication_rounded,
        color: FlutterFlowTheme.of(context).primary,
        size: 26.0,
      ),
      iconColor: FlutterFlowTheme.of(context).primary,
      name: med.medicationName.isEmpty ? 'Untitled' : med.medicationName,
      statusBg: taken
          ? const Color(0xFFE8F5E9)
          : FlutterFlowTheme.of(context).primaryBackground,
      statusColor: taken
          ? const Color(0xFF2E7D32)
          : FlutterFlowTheme.of(context).secondaryText,
      statusText: taken ? 'TAKEN' : 'PENDING',
      time: timeLabel,
      taken: taken,
      onTakenChanged: (next) => _onTakenChanged(context, med, next),
    );
  }

  /// One schedule section (Morning / Afternoon): a titled header with divider
  /// followed by its medication cards — the same two-section layout the page
  /// already had.
  Widget _buildMedCardSection(
    BuildContext context,
    String title,
    List<MedicationsRecord> meds,
  ) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 16.0),
            child: Container(
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: theme.titleMedium.override(
                      font: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600,
                        fontStyle: theme.titleMedium.fontStyle,
                      ),
                      color: theme.primaryText,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                      fontStyle: theme.titleMedium.fontStyle,
                      lineHeight: 1.45,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Divider(
                      height: 16.0,
                      thickness: 1.0,
                      indent: 0.0,
                      endIndent: 0.0,
                      color: theme.alternate,
                    ),
                  ),
                ].divide(SizedBox(width: 16.0)),
              ),
            ),
          ),
          if (meds.isEmpty)
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 24.0),
              child: Text(
                'No $title medications scheduled.',
                textAlign: TextAlign.center,
                style: theme.bodyMedium.override(
                  font: GoogleFonts.nunito(),
                  color: theme.secondaryText,
                ),
              ),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final med in meds) _buildMedCard(context, med),
              ],
            ),
        ],
      ),
    );
  }

  /// Refill Reminders section, driven by real `medications` records that have
  /// refillNeeded set (quantity left + refill-by date where present). If no
  /// med needs a refill, shows a graceful empty state — no fabricated items.
  Widget _buildRefillSection(BuildContext context, List<MedicationsRecord> meds) {
    final theme = FlutterFlowTheme.of(context);
    final refills = meds.where((m) => m.refillNeeded).toList();
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 40.0),
      child: Container(
        child: Container(
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: BorderRadius.circular(24.0),
            shape: BoxShape.rectangle,
            border: Border.all(
              color: theme.alternate,
              width: 1.0,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Container(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Refill Reminders',
                        style: theme.titleSmall.override(
                          font: GoogleFonts.dmSans(
                            fontWeight: FontWeight.bold,
                            fontStyle: theme.titleSmall.fontStyle,
                          ),
                          color: theme.primaryText,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.bold,
                          fontStyle: theme.titleSmall.fontStyle,
                          lineHeight: 1.5,
                        ),
                      ),
                      Text(
                        'See All',
                        style: theme.labelLarge.override(
                          font: GoogleFonts.nunito(
                            fontWeight: theme.labelLarge.fontWeight,
                            fontStyle: theme.labelLarge.fontStyle,
                          ),
                          color: theme.onSurface,
                          letterSpacing: 0.0,
                          fontWeight: theme.labelLarge.fontWeight,
                          fontStyle: theme.labelLarge.fontStyle,
                          lineHeight: 1.4,
                        ),
                      ),
                    ],
                  ),
                  if (refills.isEmpty)
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          0.0, 0.0, 0.0, 0.0),
                      child: Text(
                        'No refills needed right now.',
                        textAlign: TextAlign.center,
                        style: theme.bodyMedium.override(
                          font: GoogleFonts.nunito(),
                          color: theme.secondaryText,
                        ),
                      ),
                    )
                  else
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (final m in refills)
                          RefillItemWidget(
                            count: '${m.quatityLeft}',
                            date: m.refillByDate != null
                                ? dateTimeFormat('MMM d', m.refillByDate)
                                : '',
                            name: m.medicationName.isEmpty
                                ? 'Untitled'
                                : m.medicationName,
                          ),
                      ].divide(SizedBox(height: 8.0)),
                    ),
                ].divide(SizedBox(height: 16.0)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isMorning(MedicationsRecord med) => isMedicationMorning(med);

  @override
  Widget build(BuildContext context) {
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
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 100.0,
                  height: 122.3,
                  decoration: BoxDecoration(),
                  child: Container(
                    decoration: BoxDecoration(),
                    child: Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          24.0, 24.0, 24.0, 12.0),
                      child: Container(
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      10.0, 0.0, 0.0, 0.0),
                                  child: Text(
                                    'Medications',
                                    style: FlutterFlowTheme.of(context)
                                        .headlineMedium
                                        .override(
                                          font: GoogleFonts.dmSans(
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .headlineMedium
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .headlineMedium
                                                  .fontStyle,
                                          lineHeight: 1.3,
                                        ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      10.0, 0.0, 0.0, 0.0),
                                  child: Text(
                                    'Daily Schedule • ${dateTimeFormat('MMM d', DateTime.now())}',
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.nunito(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                          lineHeight: 1.6,
                                        ),
                                  ),
                                ),
                              ].divide(SizedBox(height: 4.0)),
                            ),
                            Flexible(
                              child: Align(
                                alignment: AlignmentDirectional(1.0, 0.0),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      45.0, 0.0, 0.0, 0.0),
                                  child: Container(
                                    width: 40.0,
                                    height: 48.0,
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                      borderRadius:
                                          BorderRadius.circular(9999.0),
                                      shape: BoxShape.rectangle,
                                    ),
                                    alignment: AlignmentDirectional(0.0, 0.0),
                                    child: Icon(
                                      Icons.calendar_month_rounded,
                                      color: FlutterFlowTheme.of(context)
                                          .onSurface,
                                      size: 24.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: AlignmentDirectional(1.0, -1.0),
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: FlutterFlowIconButton(
                                  borderRadius: 28.0,
                                  buttonSize: 40.0,
                                  fillColor: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  icon: Icon(
                                    Icons.menu,
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    size: 24.0,
                                  ),
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
                                            child: NavMenuDirectoryWidget(),
                                          ),
                                        );
                                      },
                                    ).then((value) => safeSetState(() {}));
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // ---------------------------------------------------------------------
                // The schedule + refill + adherence sections, streamed from the
                // `medications` collection for the selected care recipient. The
                // stream is empty until a recipient is selected (same pattern as
                // care notes): the Day header, Morning/Afternoon grouping, refill
                // reminders and the adherence ring are all driven by these records.
                // ---------------------------------------------------------------------
                StreamBuilder<List<MedicationsRecord>>(
                  // The live LIST query filters on orgId AS WELL AS the selected
                  // recipient — exactly like the careRecipients list query
                  // (`careRecipientsForActiveGroup`): the Phase-4 `medications`
                  // LIST rule gates on resource.data.orgId
                  // (canListRecipientsInOrg), and Firestore only exposes a field
                  // to a list rule when the QUERY itself constrains it — an
                  // unconstrained field reads as undefined there and the whole
                  // query is denied. orgId is the caller's active group
                  // (FFAppState().activeGroupId, the same source the medication
                  // create writes); with no group context the stream stays empty
                  // and is never an unscoped query.
                  stream: (FFAppState().selectedCareRecipient == null ||
                          (FFAppState().activeGroupId ?? '').isEmpty)
                      ? Stream<List<MedicationsRecord>>.value(const [])
                      : queryMedicationsRecord(
                          queryBuilder: (q) => q
                              .where(
                                'orgId',
                                isEqualTo: FFAppState().activeGroupId,
                              )
                              .where(
                                'careRecipientRef',
                                isEqualTo: FFAppState().selectedCareRecipient,
                              ),
                        ),
                  builder: (context, snapshot) {
                    final theme = FlutterFlowTheme.of(context);
                    if (snapshot.hasError) {
                      return Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            24.0, 24.0, 24.0, 24.0),
                        child: Text(
                          'Could not load medications. Please try again.',
                          textAlign: TextAlign.center,
                          style: theme.bodyMedium.override(
                            font: GoogleFonts.nunito(),
                            color: theme.secondaryText,
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return Center(
                        child: Padding(
                          padding:
                              EdgeInsetsDirectional.fromSTEB(
                                  0.0, 48.0, 0.0, 48.0),
                          child: SizedBox(
                            width: 40.0,
                            height: 40.0,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.primary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    final meds = [...snapshot.data!]
                      ..sort((a, b) {
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
                    final morning = meds.where(_isMorning).toList();
                    final afternoon =
                        meds.where((m) => !_isMorning(m)).toList();
                    final takenCount = meds
                        .where((m) =>
                            isTakenForDay(m.takenAt, DateTime.now()))
                        .length;
                    final total = meds.length;
                    // takenCount can never exceed total, so percent is in [0,1].
                    final percent = total == 0 ? 0.0 : takenCount / total;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              24.0, 0.0, 24.0, 24.0),
                          child: Container(
                            decoration: BoxDecoration(),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    FlutterFlowTheme.of(context).primary,
                                    Color(0xFFA3C4B1)
                                  ],
                                  stops: [0.0, 1.0],
                                  begin: AlignmentDirectional(1.0, 1.0),
                                  end: AlignmentDirectional(-1.0, -1.0),
                                ),
                                borderRadius: BorderRadius.circular(24.0),
                                shape: BoxShape.rectangle,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Container(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Stack(
                                        alignment: AlignmentDirectional(
                                            0.0, 0.0),
                                        children: [
                                          CircularPercentIndicator(
                                            percent: percent,
                                            radius: 32.0,
                                            lineWidth: 6.0,
                                            animation: true,
                                            animateFromLastPercent: true,
                                            progressColor: FlutterFlowTheme
                                                    .of(context)
                                                .secondaryBackground,
                                            backgroundColor:
                                                FlutterFlowTheme.of(context)
                                                    .onPrimary27,
                                          ),
                                          Text(
                                            '$takenCount/$total',
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  font: GoogleFonts.nunito(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .onBackground,
                                                  fontSize: 14.0,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.bold,
                                                  fontStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                                  lineHeight: 1.6,
                                                ),
                                          ),
                                        ],
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
                                            Text(
                                              'Daily Adherence',
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .titleSmall
                                                  .override(
                                                    font: GoogleFonts.dmSans(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontStyle: FlutterFlowTheme
                                                              .of(context)
                                                          .titleSmall
                                                          .fontStyle,
                                                    ),
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .onBackground,
                                                    letterSpacing: 0.0,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    fontStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .titleSmall
                                                        .fontStyle,
                                                    lineHeight: 1.5,
                                                  ),
                                            ),
                                            Opacity(
                                              opacity: 0.9,
                                              child: Text(
                                                "You've logged $takenCount of "
                                                '$total doses for today.',
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodySmall
                                                    .override(
                                                      font: GoogleFonts.nunito(
                                                        fontWeight: FlutterFlowTheme
                                                                .of(context)
                                                            .bodySmall
                                                            .fontWeight,
                                                        fontStyle: FlutterFlowTheme
                                                                .of(context)
                                                            .bodySmall
                                                            .fontStyle,
                                                      ),
                                                      color: FlutterFlowTheme
                                                              .of(context)
                                                          .onBackground,
                                                      letterSpacing: 0.0,
                                                      fontWeight: FlutterFlowTheme
                                                              .of(context)
                                                          .bodySmall
                                                          .fontWeight,
                                                      fontStyle: FlutterFlowTheme
                                                              .of(context)
                                                          .bodySmall
                                                          .fontStyle,
                                                      lineHeight: 1.5,
                                                    ),
                                              ),
                                            ),
                                          ].divide(SizedBox(height: 4.0)),
                                        ),
                                      ),
                                    ].divide(SizedBox(width: 24.0)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        _buildMedCardSection(context, 'Morning', morning),
                        Padding(
                          padding:
                              EdgeInsetsDirectional.fromSTEB(0.0, 24.0, 0.0, 24.0),
                          child: _buildMedCardSection(
                              context, 'Afternoon', afternoon),
                        ),
                        _buildRefillSection(context, meds),
                        Container(
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                24.0, 0.0, 24.0, 40.0),
                            child: Container(
                              child: wrapWithModel(
                                model: _model.buttonModel,
                                updateCallback: () => safeSetState(() {}),
                                child: ButtonWidget(
                                  icon: Icon(
                                    Icons.add_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    size: 24.0,
                                  ),
                                  iconPresent: true,
                                  iconEndPresent: false,
                                  content: 'Add Medication',
                                  variant: 'primary',
                                  size: 'small',
                                  fullWidth: true,
                                  loading: false,
                                  disabled: false,
                                  onPressed: () async {
                                    await _openAddMedication(context);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
