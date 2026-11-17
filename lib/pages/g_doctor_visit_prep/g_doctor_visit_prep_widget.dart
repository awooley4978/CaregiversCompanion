import '/backend/appointments/appointment_display.dart';
import '/backend/appointments/appointment_form.dart';
import '/backend/backend.dart';
import '/backend/org/org_service.dart';
import '/backend/symptoms/symptom_history.dart';
import '/components/button/button_widget.dart';
import '/components/doctor_report_range_sheet/doctor_report_range_sheet_widget.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/components/question_card/question_card_widget.dart';
import '/components/symptom_history_sheet/symptom_history_sheet_widget.dart';
import '/components/symptom_log/symptom_log_widget.dart';
import '/pages/appointment_form/appointment_form_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/reports/care_report.dart';
import '/reports/care_report_pdf.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'g_doctor_visit_prep_model.dart';
export 'g_doctor_visit_prep_model.dart';

class GDoctorVisitPrepWidget extends StatefulWidget {
  const GDoctorVisitPrepWidget({super.key});

  static String routeName = 'GDoctorVisitPrep';
  static String routePath = '/gDoctorVisitPrep';

  @override
  State<GDoctorVisitPrepWidget> createState() => _GDoctorVisitPrepWidgetState();
}

class _GDoctorVisitPrepWidgetState extends State<GDoctorVisitPrepWidget> {
  late GDoctorVisitPrepModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  /// True while the report is being read from Firestore and rendered, so the
  /// Export button cannot be tapped twice and shows its loading state.
  bool _exporting = false;

  /// The recipient's next stored appointment — the SAME record (same query,
  /// same helper) the Calendar's "Upcoming" card shows, so the two screens can
  /// no longer disagree (appointments unit, part 3, proposal §6).
  AppointmentsRecord? _next;

  bool _loading = false;
  String? _loadError;

  /// The recipient's real symptom entries, newest first.
  List<SymptomEntriesRecord> _symptoms = const [];
  bool _symptomError = false;

  /// Bumped on every load; a response for a previously selected recipient is
  /// discarded.
  int _loadToken = 0;

  StreamSubscription<List<SymptomEntriesRecord>>? _symptomsSub;

  /// The recipient this page prepares for: the app-wide selection (route
  /// parameters take precedence there, the established dashboard/vitals rule).
  DocumentReference? get _recipientRef => FFAppState().selectedCareRecipient;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GDoctorVisitPrepModel());

    _load();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _symptomsSub?.cancel();
    _model.dispose();

    super.dispose();
  }

  /// Reads the recipient's appointments through the ONE recipient-scoped query
  /// (the merged rules deny a bare list and an org-only query, and the
  /// composite index serves exactly this one) and keeps the earliest future,
  /// not-completed one — the same helper the Calendar uses.
  Future<void> _load() async {
    final token = ++_loadToken;
    final ref = _recipientRef;

    if (!mounted) {
      return;
    }
    setState(() {
      _loading = ref != null;
      _loadError = null;
      _next = null;
      _symptoms = const [];
      _symptomError = false;
    });
    _subscribeSymptoms(ref);

    if (ref == null) {
      return;
    }

    try {
      final records = await queryAppointmentsRecordOnce(
        queryBuilder: (query) => query
            .where('careRecipientRef', isEqualTo: ref)
            .orderBy('appointmentDateTime'),
      );
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _next = nextUpcomingAppointment(records, DateTime.now());
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = 'Could not load the appointments for this care recipient. '
            'Please check your connection and try again.';
      });
    }
  }

  /// Follows the recipient's real `symptomEntries` (the collection the
  /// dashboard's symptom flow already writes) instead of the invented
  /// observations this page used to show.
  void _subscribeSymptoms(DocumentReference? ref) {
    _symptomsSub?.cancel();
    _symptomsSub = null;
    if (ref == null) {
      return;
    }
    _symptomsSub = symptomEntriesForRecipient(recipientRef: ref).listen(
      (records) {
        if (!mounted) {
          return;
        }
        setState(() {
          _symptoms = records;
          _symptomError = false;
        });
      },
      onError: (_) {
        if (mounted) {
          setState(() => _symptomError = true);
        }
      },
    );
  }

  /// "Details": the ONE appointment form in VIEW/EDIT mode, opened with the
  /// next appointment's own document — saving updates it, never duplicating it.
  Future<void> _openDetails() async {
    final next = _next;
    if (next == null) {
      return;
    }
    await context.pushNamed(
      AppointmentFormWidget.routeName,
      extra: {'appointments': next.reference},
    );
    if (mounted) {
      await _load();
    }
  }

  /// "Add Question": appends ONE line to the next appointment's existing
  /// `questionsToAsk` text (proposal §5 — one question per line, never split on
  /// a comma). Disabled when there is no upcoming appointment to prepare for.
  Future<void> _addQuestion() async {
    final next = _next;
    if (next == null) {
      return;
    }
    final controller = TextEditingController();
    final question = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
          title: Text(
            'Add a question',
            style: FlutterFlowTheme.of(context).titleMedium.override(
                  font: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.bold,
                ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: null,
            decoration: InputDecoration(
              hintText: 'e.g. Ask about the fluid limit this week',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text('Add'),
            ),
          ],
        );
      },
    );
    final text = (question ?? '').trim();
    controller.dispose();
    if (text.isEmpty || !mounted) {
      return;
    }
    try {
      await next.reference.update({
        'questionsToAsk': appendAppointmentQuestion(next.questionsToAsk, text),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        await _load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not add this question. Please check your connection and '
              'try again.',
            ),
          ),
        );
      }
    }
  }

  /// The history icon: the recipient's REAL symptom history.
  Future<void> _openHistory() async {
    await showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Padding(
            padding: MediaQuery.viewInsetsOf(context),
            child: SymptomHistorySheetWidget(recipientRef: _recipientRef),
          ),
        );
      },
    );
  }

  /// The 'Export' action: pick a range, then build a PDF from the recipient's
  /// stored care records over that range and hand it to the platform print /
  /// share sheet.
  ///
  /// Owner-approved spec (2026-11-03): the report covers a user-selected range
  /// with presets, contains only records that were actually saved, and never
  /// invents content. An empty period produces an honest no-records report; a
  /// failed read is reported to the caregiver instead of producing a blank PDF.
  Future<void> _exportReport(BuildContext context) async {
    final recipientRef = FFAppState().selectedCareRecipient;
    if (recipientRef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a care recipient before exporting a report.'),
        ),
      );
      return;
    }

    final range = await showModalBottomSheet<CareReportRange>(
      isScrollControlled: true,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Padding(
            padding: MediaQuery.viewInsetsOf(context),
            child: DoctorReportRangeSheetWidget(),
          ),
        );
      },
    );
    if (range == null || !mounted) {
      return;
    }

    safeSetState(() => _exporting = true);
    try {
      final report = await loadCareReportData(
        recipientRef: recipientRef,
        range: range,
      );
      final bytes = await buildCareReportPdf(report);
      await Printing.layoutPdf(
        name: careReportFileName(report),
        onLayout: (format) async => bytes,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not build the report. Please check your connection and '
              'try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        safeSetState(() => _exporting = false);
      }
    }
  }

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
                Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Container(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Doctor Visit Prep',
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
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .headlineMedium
                                            .fontStyle,
                                        lineHeight: 1.3,
                                      ),
                                ),
                                Text(
                                  'Preparation for upcoming appointments',
                                  style: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .override(
                                        font: GoogleFonts.nunito(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodySmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodySmall
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontStyle,
                                        lineHeight: 1.5,
                                      ),
                                ),
                              ].divide(SizedBox(height: 4.0)),
                            ),
                            Flexible(
                              child: Align(
                                alignment: AlignmentDirectional(1.0, 0.0),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 10.0, 0.0),
                                  child: FlutterFlowIconButton(
                                    borderRadius: 20.0,
                                    buttonSize: 40.0,
                                    fillColor: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    icon: Icon(
                                      Icons.event_note_rounded,
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      size: 24.0,
                                    ),
                                    onPressed: () async {
                                      context.pushNamed(
                                          CalendarPageWidget.routeName);
                                    },
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: AlignmentDirectional(1.0, -1.0),
                              child: Padding(
                                padding: EdgeInsets.all(6.0),
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
                        InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            context.pushNamed(CalendarPageWidget.routeName);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context).secondary15,
                              borderRadius: BorderRadius.circular(36.0),
                              shape: BoxShape.rectangle,
                              border: Border.all(
                                color: FlutterFlowTheme.of(context).secondary30,
                                width: 1.0,
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Container(
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 48.0,
                                      height: 48.0,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .secondary,
                                        borderRadius:
                                            BorderRadius.circular(9999.0),
                                        shape: BoxShape.rectangle,
                                      ),
                                      alignment: AlignmentDirectional(0.0, 0.0),
                                      child: Icon(
                                        Icons.medical_services_rounded,
                                        color: FlutterFlowTheme.of(context)
                                            .onSurface,
                                        size: 24.0,
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
                                          Text(
                                            'Next Appointment',
                                            style: FlutterFlowTheme.of(context)
                                                .labelSmall
                                                .override(
                                                  font: GoogleFonts.nunito(
                                                    fontWeight: FontWeight.bold,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelSmall
                                                            .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .onSurface,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.bold,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontStyle,
                                                  lineHeight: 1.3,
                                                ),
                                          ),
                                          Text(
                                            // The REAL next appointment (appointments unit, part 3):
                                            // the same record the Calendar's Upcoming card shows,
                                            // or an honest empty/error state — never a placeholder.
                                            _next != null &&
                                                    _next!.appointmentTitle
                                                        .trim()
                                                        .isNotEmpty
                                                ? _next!.appointmentTitle
                                                : _loadError != null
                                                    ? 'Appointments could not be loaded'
                                                    : 'No upcoming appointment scheduled',
                                            style: FlutterFlowTheme.of(context)
                                                .titleMedium
                                                .override(
                                                  font: GoogleFonts.dmSans(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .titleMedium
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .titleMedium
                                                            .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .titleMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .titleMedium
                                                          .fontStyle,
                                                  lineHeight: 1.45,
                                                ),
                                          ),
                                          Text(
                                            _next?.appointmentDateTime == null
                                                ? ''
                                                : appointmentWhenLabel(
                                                    _next!
                                                        .appointmentDateTime!),
                                            style: FlutterFlowTheme.of(context)
                                                .bodySmall
                                                .override(
                                                  font: GoogleFonts.nunito(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodySmall
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodySmall
                                                            .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .onSurface,
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodySmall
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodySmall
                                                          .fontStyle,
                                                  lineHeight: 1.5,
                                                ),
                                          ),
                                        ].divide(SizedBox(height: 4.0)),
                                      ),
                                    ),
                                    wrapWithModel(
                                      model: _model.buttonModel1,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ButtonWidget(
                                        iconPresent: false,
                                        iconEndPresent: false,
                                        content: 'Details',
                                        variant: 'outline',
                                        size: 'small',
                                        fullWidth: false,
                                        loading: false,
                                        disabled: _next == null,
                                        onPressed: _next == null
                                            ? null
                                            : () => _openDetails(),
                                      ),
                                    ),
                                  ].divide(SizedBox(width: 16.0)),
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
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Questions to Ask',
                                  style: FlutterFlowTheme.of(context)
                                      .titleLarge
                                      .override(
                                        font: GoogleFonts.dmSans(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .titleLarge
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleLarge
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleLarge
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleLarge
                                            .fontStyle,
                                        lineHeight: 1.4,
                                      ),
                                ),
                                wrapWithModel(
                                  model: _model.buttonModel2,
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
                                    content: 'Add Question',
                                    variant: 'ghost',
                                    size: 'small',
                                    fullWidth: false,
                                    loading: false,
                                    disabled: _next == null,
                                    onPressed: _next == null ? null : _addQuestion,
                                  ),
                                ),
                              ],
                            ),
                            if (_next == null)
                              Text(
                                'No upcoming appointment to prepare for.',
                                style: FlutterFlowTheme.of(context).bodySmall.override(
                                      font: GoogleFonts.nunito(),
                                      color: FlutterFlowTheme.of(context).secondaryText,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                            if (_next != null &&
                                appointmentQuestionLines(_next!.questionsToAsk).isEmpty)
                              Text(
                                'No questions added yet.',
                                style: FlutterFlowTheme.of(context).bodySmall.override(
                                      font: GoogleFonts.nunito(),
                                      color: FlutterFlowTheme.of(context).secondaryText,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                            ...appointmentQuestionLines(_next?.questionsToAsk ?? '')
                                .map((question) => QuestionCardWidget(question: question)),
                          ].divide(SizedBox(height: 16.0)),
                        ),
                        Column(
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
                                  'Recent Observations',
                                  style: FlutterFlowTheme.of(context)
                                      .titleLarge
                                      .override(
                                        font: GoogleFonts.dmSans(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .titleLarge
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleLarge
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleLarge
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleLarge
                                            .fontStyle,
                                        lineHeight: 1.4,
                                      ),
                                ),
                                FlutterFlowIconButton(
                                  borderRadius: 8.0,
                                  buttonSize: 40.0,
                                  fillColor: Colors.transparent,
                                  icon: Icon(
                                    Icons.history_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    size: 24.0,
                                  ),
                                  onPressed: _openHistory,
                                ),
                              ],
                            ),
                            if (_symptomError)
                              Text(
                                'Could not load the symptoms for this care recipient. Please check your connection and try again.',
                                style: FlutterFlowTheme.of(context).bodySmall.override(
                                      font: GoogleFonts.nunito(),
                                      color: FlutterFlowTheme.of(context).secondaryText,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                            if (!_symptomError && _symptoms.isEmpty)
                              Text(
                                'No symptoms logged for this care recipient yet.',
                                style: FlutterFlowTheme.of(context).bodySmall.override(
                                      font: GoogleFonts.nunito(),
                                      color: FlutterFlowTheme.of(context).secondaryText,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                            ...recentSymptoms(_symptoms).map(
                              (record) => SymptomLogWidget(
                                color: record.isResolved
                                    ? FlutterFlowTheme.of(context).success
                                    : FlutterFlowTheme.of(context).primary,
                                icon: Icon(
                                  record.isResolved
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.medical_information_rounded,
                                  color: record.isResolved
                                      ? FlutterFlowTheme.of(context).success
                                      : FlutterFlowTheme.of(context).primary,
                                  size: 20.0,
                                ),
                                label: symptomEntryHeadline(record),
                                note: symptomEntryNote(record),
                                time: symptomEntrySubtitle(record),
                              ),
                            ),
                          ].divide(SizedBox(height: 16.0)),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).primary,
                            borderRadius: BorderRadius.circular(28.0),
                            shape: BoxShape.rectangle,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Container(
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
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
                                          'Generate Report',
                                          style: FlutterFlowTheme.of(context)
                                              .titleMedium
                                              .override(
                                                font: GoogleFonts.dmSans(
                                                  fontWeight: FontWeight.bold,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .titleMedium
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .onSurface,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.bold,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .titleMedium
                                                        .fontStyle,
                                                lineHeight: 1.45,
                                              ),
                                        ),
                                        Text(
                                          'Create a PDF summary of these notes for the doctor.',
                                          style: FlutterFlowTheme.of(context)
                                              .bodySmall
                                              .override(
                                                font: GoogleFonts.nunito(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodySmall
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodySmall
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .onSurface80,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontStyle,
                                                lineHeight: 1.5,
                                              ),
                                        ),
                                      ].divide(SizedBox(height: 4.0)),
                                    ),
                                  ),
                                  wrapWithModel(
                                    model: _model.buttonModel3,
                                    updateCallback: () => safeSetState(() {}),
                                    child: ButtonWidget(
                                      icon: Icon(
                                        Icons.picture_as_pdf_rounded,
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        size: 24.0,
                                      ),
                                      iconPresent: true,
                                      iconEndPresent: false,
                                      content: 'Export',
                                      variant: 'secondary',
                                      size: 'medium',
                                      fullWidth: false,
                                      loading: _exporting,
                                      disabled: _exporting,
                                      onPressed: () => _exportReport(context),
                                    ),
                                  ),
                                ].divide(SizedBox(width: 16.0)),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          height: 24.0,
                        ),
                      ].divide(SizedBox(height: 24.0)),
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
