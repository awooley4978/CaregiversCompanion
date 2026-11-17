// Calendar — the selected care recipient's REAL appointments.
//
// Appointments unit, part 2 (owner decisions 2026-11-16, proposal §7). This
// page used to be entirely fabricated: "March 2024", "You have 3 tasks today",
// "Thursday, March 14", three invented event rows and a "Quarterly Planning"
// upcoming card, with a week strip that rendered nothing at all.
//
// Now:
//  * ONE query reads the selected recipient's appointments
//    (`careRecipientRef == recipient`, ordered by `appointmentDateTime`), which
//    is what the merged rules and the composite index serve. Without the
//    deployed index the read fails and the page says so — it never falls back
//    to invented events;
//  * the month header, the count line, the selected-day heading, the agenda
//    rows, the week strip's day numbers and dots, and the "Upcoming" card are
//    all derived from those records (see
//    `lib/backend/appointments/appointment_display.dart`);
//  * tapping a day cell selects it; the Today pill jumps back to today and is
//    only shown as active when the selected day IS today;
//  * the search icon reveals a field that filters the LOADED appointments
//    client-side by title, provider and type — no search backend;
//  * the recipient changed app-wide (or there is none) is handled honestly, and
//    a response for a previously selected recipient is discarded (`_loadToken`).
//
// "New Event", the appointment form and Doctor Visit Prep are part 3 of the
// unit, so the FAB keeps its current inert state here.
import '/app_state.dart';
import '/backend/appointments/appointment_display.dart';
import '/backend/backend.dart';
import '/components/calendar_day_widget.dart';
import '/components/event_item_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/pages/appointment_form/appointment_form_widget.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'calendar_page_model.dart';
export 'calendar_page_model.dart';

/// Calendar with different colored dot over selected day
class CalendarPageWidget extends StatefulWidget {
  const CalendarPageWidget({super.key, this.now});

  /// The instant "today" is measured from. `null` (the app's own route) means
  /// the device clock; tests pass a fixed instant so the page can never depend
  /// on the wall clock or on the machine's time zone.
  final DateTime? now;

  static String routeName = 'CalendarPage';
  static String routePath = '/calendarPage';

  @override
  State<CalendarPageWidget> createState() => _CalendarPageWidgetState();
}

class _CalendarPageWidgetState extends State<CalendarPageWidget> {
  late CalendarPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  /// The recipient the loaded appointments belong to.
  DocumentReference? _recipientRef;
  List<AppointmentsRecord> _appointments = const [];

  String? _loadError;
  bool _loading = false;
  bool _searchVisible = false;

  /// The day the agenda is showing. Device-local, midnight.
  late DateTime _selectedDay;

  /// The current instant: the injected one when there is one, else the device
  /// clock. Every "today"/"upcoming" decision on this page goes through here.
  DateTime get _now => widget.now ?? DateTime.now();

  /// Bumped on every load; a response carrying an older token belongs to a
  /// previously selected recipient and is thrown away.
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CalendarPageModel());

    _selectedDay = appointmentToday(_now);

    FFAppState().addListener(_onAppStateChanged);
    _load();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    FFAppState().removeListener(_onAppStateChanged);
    _model.dispose();

    super.dispose();
  }

  DocumentReference? get _currentRecipientRef =>
      FFAppState().selectedCareRecipient;

  /// The recipient changed while this page is open: reload and drop the old
  /// recipient's appointments.
  void _onAppStateChanged() {
    if (!mounted) {
      return;
    }
    if (FFAppState().selectedCareRecipient?.path == _recipientRef?.path) {
      return;
    }
    _load();
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    final ref = _currentRecipientRef;

    if (!mounted) {
      return;
    }
    setState(() {
      _recipientRef = ref;
      _appointments = const [];
      _loadError = null;
      _loading = ref != null;
    });

    if (ref == null) {
      return;
    }

    try {
      // The one query of the page. The merged rules deny a bare list and an
      // org-only query, so the recipient filter is required, and the composite
      // index (careRecipientRef ASC, appointmentDateTime ASC) serves it.
      final records = await queryAppointmentsRecordOnce(
        queryBuilder: (query) => query
            .where('careRecipientRef', isEqualTo: ref)
            .orderBy('appointmentDateTime'),
      );

      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _appointments = sortAppointmentsByStart(records);
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = calendarLoadError;
      });
    }
  }

  void _selectDay(DateTime day) {
    safeSetState(() {
      _selectedDay = appointmentDay(day);
    });
  }

  String get _searchTerm => (_model.textController?.text ?? '').trim();

  /// The loaded appointments, narrowed by the search field (client-side only).
  List<AppointmentsRecord> get _visibleAppointments {
    final term = _searchTerm;
    if (term.isEmpty) {
      return _appointments;
    }
    return _appointments
        .where((record) => appointmentMatchesSearch(record, term))
        .toList();
  }

  Color _toneColor(BuildContext context, String tone) {
    final theme = FlutterFlowTheme.of(context);
    switch (tone) {
      case 'tertiary':
        return theme.tertiary;
      case 'warning':
        return theme.warning;
      case 'success':
        return theme.success;
      case 'neutral':
        return theme.secondaryText;
      default:
        return theme.primary;
    }
  }

  IconData _toneIcon(String tone) {
    switch (tone) {
      case 'tertiary':
        return Icons.healing_rounded;
      case 'warning':
        return Icons.science_rounded;
      case 'success':
        return Icons.medical_services_rounded;
      case 'neutral':
        return Icons.event_rounded;
      default:
        return Icons.local_hospital_rounded;
    }
  }

  /// An honest one-line state (no rows, no invented data).
  Widget _stateMessage(BuildContext context, String message, {Key? key}) {
    return Text(
      message,
      key: key,
      style: FlutterFlowTheme.of(context).bodyMedium.override(
            font: GoogleFonts.nunito(
              fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
            ),
            color: FlutterFlowTheme.of(context).secondaryText,
            letterSpacing: 0.0,
            fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
            lineHeight: 1.4,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();

    final today = appointmentToday(_now);
    final selectedDay = _selectedDay;
    final visible = _visibleAppointments;
    final dayAppointments = appointmentsOnDay(visible, selectedDay);
    final searchTerm = _searchTerm;
    final upcoming = nextUpcomingAppointment(visible, _now);
    final isTodaySelected = isSameAppointmentDay(selectedDay, today);
    final week = weekDaysFor(selectedDay);
    final dayModels = [
      _model.calendarDayModel1,
      _model.calendarDayModel2,
      _model.calendarDayModel3,
      _model.calendarDayModel4,
      _model.calendarDayModel5,
      _model.calendarDayModel6,
      _model.calendarDayModel7,
    ];

    final String headerSubtitle;
    if (_recipientRef == null) {
      headerSubtitle = 'No care recipient selected';
    } else if (_loadError != null) {
      headerSubtitle = 'Appointments could not be loaded';
    } else {
      headerSubtitle = calendarCountLine(
        dayAppointments.length,
        day: selectedDay,
        today: today,
      );
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            // "New Event" (appointments unit, part 3): the ONE appointment form
            // in CREATE mode, pre-filled with the selected day and the selected
            // care recipient. On return the page reloads, so the new event
            // appears in the strip, the agenda and the Upcoming card.
            final recipientRef = _currentRecipientRef;
            await context.pushNamed(
              AppointmentFormWidget.routeName,
              extra: {
                if (recipientRef != null) 'careRecipient': recipientRef,
                'initialDate': _selectedDay,
              },
            );
            if (mounted) {
              await _load();
            }
          },
          backgroundColor: FlutterFlowTheme.of(context).primary,
          icon: Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 24.0,
          ),
          elevation: 0.0,
          label: Text(
            'New Event',
            style: FlutterFlowTheme.of(context).labelLarge.override(
                  font: GoogleFonts.nunito(
                    fontWeight:
                        FlutterFlowTheme.of(context).labelLarge.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).labelLarge.fontStyle,
                  ),
                  color: Colors.white,
                  letterSpacing: 0.0,
                  fontWeight:
                      FlutterFlowTheme.of(context).labelLarge.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).labelLarge.fontStyle,
                  lineHeight: 1.4,
                ),
          ),
        ),
        body: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                shape: BoxShape.rectangle,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(16.0, 24.0, 16.0, 24.0),
                    child: Container(
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              FlutterFlowIconButton(
                                key: const ValueKey('calendarBackButton'),
                                borderRadius: 8.0,
                                buttonSize: 40.0,
                                fillColor: Colors.transparent,
                                icon: Icon(
                                  Icons.arrow_back_rounded,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  size: 24.0,
                                ),
                                onPressed: () => context.safePop(),
                              ),
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    12.0, 0.0, 0.0, 0.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      calendarMonthHeading(selectedDay),
                                      key: const ValueKey(
                                          'calendarMonthHeading'),
                                      style: FlutterFlowTheme.of(context)
                                          .headlineSmall
                                          .override(
                                            font: GoogleFonts.dmSans(
                                              fontWeight: FontWeight.bold,
                                              fontStyle: FlutterFlowTheme.of(context)
                                                  .headlineSmall
                                                  .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.bold,
                                            fontStyle: FlutterFlowTheme.of(context)
                                                .headlineSmall
                                                .fontStyle,
                                          ),
                                    ),
                                    Text(
                                      headerSubtitle,
                                      key: const ValueKey(
                                          'calendarCountLine'),
                                      style: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .override(
                                            font: GoogleFonts.nunito(
                                              fontWeight: FlutterFlowTheme.of(context)
                                                  .bodySmall
                                                  .fontWeight,
                                              fontStyle: FlutterFlowTheme.of(context)
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
                                            lineHeight: 1.4,
                                          ),
                                    ),
                                  ].divide(SizedBox(height: 4.0)),
                                ),
                              ),
                            ],
                          ),
                          FlutterFlowIconButton(
                            key: const ValueKey('calendarSearchButton'),
                            borderRadius: 8.0,
                            buttonSize: 40.0,
                            fillColor: Colors.transparent,
                            icon: Icon(
                              Icons.search_rounded,
                              color: FlutterFlowTheme.of(context).primaryText,
                              size: 24.0,
                            ),
                            onPressed: () {
                              safeSetState(() {
                                _searchVisible = !_searchVisible;
                                if (!_searchVisible) {
                                  _model.textController?.clear();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_searchVisible)
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 24.0),
                      child: TextFormField(
                        key: const ValueKey('calendarSearchField'),
                        controller: _model.textController,
                        focusNode: _model.textFieldFocusNode,
                        onChanged: (_) => safeSetState(() {}),
                        autofocus: false,
                        enabled: true,
                        obscureText: false,
                        decoration: InputDecoration(
                          isDense: true,
                          labelStyle: FlutterFlowTheme.of(context)
                              .labelMedium
                              .override(
                                font: GoogleFonts.nunito(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontStyle,
                                ),
                                fontSize: 14.0,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .labelMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .labelMedium
                                    .fontStyle,
                                lineHeight: 1.6,
                              ),
                          hintText: 'Search appointments...',
                          hintStyle: FlutterFlowTheme.of(context)
                              .labelMedium
                              .override(
                                font: GoogleFonts.nunito(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontStyle,
                                ),
                                fontSize: 14.0,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .labelMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .labelMedium
                                    .fontStyle,
                              ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).alternate,
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(28.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0x00000000),
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(28.0),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).error,
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(28.0),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).error,
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(28.0),
                          ),
                          filled: true,
                          fillColor:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          prefixIcon: Icon(
                            Icons.search,
                            color: FlutterFlowTheme.of(context).primaryText,
                            size: 20.0,
                          ),
                        ),
                        style: FlutterFlowTheme.of(context)
                            .titleSmall
                            .override(
                              font: GoogleFonts.dmSans(
                                fontWeight: FlutterFlowTheme.of(context)
                                    .titleSmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .titleSmall
                                    .fontStyle,
                              ),
                              fontSize: 14.0,
                              letterSpacing: 0.0,
                              fontWeight: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .fontStyle,
                              lineHeight: 1.6,
                            ),
                      ),
                    ),
                  Container(
                    height: 1.0,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).alternate,
                      shape: BoxShape.rectangle,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                shape: BoxShape.rectangle,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Container(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'M',
                                style: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .override(
                                      font: GoogleFonts.nunito(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .fontStyle,
                                      ),
                                      color:
                                          FlutterFlowTheme.of(context).accent3,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontStyle,
                                      lineHeight: 1.4,
                                    ),
                              ),
                              Text(
                                'T',
                                style: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .override(
                                      font: GoogleFonts.nunito(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .fontStyle,
                                      ),
                                      color:
                                          FlutterFlowTheme.of(context).accent3,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontStyle,
                                      lineHeight: 1.4,
                                    ),
                              ),
                              Text(
                                'W',
                                style: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .override(
                                      font: GoogleFonts.nunito(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .fontStyle,
                                      ),
                                      color:
                                          FlutterFlowTheme.of(context).accent3,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontStyle,
                                      lineHeight: 1.4,
                                    ),
                              ),
                              Text(
                                'T',
                                style: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .override(
                                      font: GoogleFonts.nunito(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .fontStyle,
                                      ),
                                      color:
                                          FlutterFlowTheme.of(context).accent3,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontStyle,
                                      lineHeight: 1.4,
                                    ),
                              ),
                              Text(
                                'F',
                                style: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .override(
                                      font: GoogleFonts.nunito(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .fontStyle,
                                      ),
                                      color:
                                          FlutterFlowTheme.of(context).accent3,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontStyle,
                                      lineHeight: 1.4,
                                    ),
                              ),
                              Text(
                                'S',
                                style: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .override(
                                      font: GoogleFonts.nunito(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .fontStyle,
                                      ),
                                      color:
                                          FlutterFlowTheme.of(context).accent3,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontStyle,
                                      lineHeight: 1.4,
                                    ),
                              ),
                              Text(
                                'S',
                                style: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .override(
                                      font: GoogleFonts.nunito(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .fontStyle,
                                      ),
                                      color:
                                          FlutterFlowTheme.of(context).accent3,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontStyle,
                                      lineHeight: 1.4,
                                    ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              for (var index = 0; index < week.length; index++)
                                wrapWithModel(
                                  model: dayModels[index],
                                  updateCallback: () => safeSetState(() {}),
                                  child: CalendarDayWidget(
                                    key: ValueKey(
                                        'calendarDay-${DateFormat('yyyy-MM-dd').format(week[index])}'),
                                    selected: isSameAppointmentDay(
                                        week[index], selectedDay),
                                    isToday:
                                        isSameAppointmentDay(week[index], today),
                                    day: '${week[index].day}',
                                    dotColor: dayDotTone(visible, week[index]),
                                    onTap: () => _selectDay(week[index]),
                                  ),
                                ),
                            ],
                          ),
                        ].divide(SizedBox(height: 16.0)),
                      ),
                    ),
                  ),
                  Container(
                    height: 1.0,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).alternate,
                      shape: BoxShape.rectangle,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
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
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    calendarDayHeading(selectedDay),
                                    key: const ValueKey(
                                        'calendarSelectedDayHeading'),
                                    style: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .override(
                                          font: GoogleFonts.dmSans(
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleMedium
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleMedium
                                                  .fontStyle,
                                          lineHeight: 1.4,
                                        ),
                                  ),
                                  GestureDetector(
                                    key: const ValueKey('calendarTodayPill'),
                                    onTap: () => _selectDay(today),
                                    child: Container(
                                      height: 34.0,
                                      decoration: BoxDecoration(
                                        color: isTodaySelected
                                            ? FlutterFlowTheme.of(context)
                                                .primary
                                            : FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                        borderRadius:
                                            BorderRadius.circular(9999.0),
                                        border: Border.all(
                                          color: FlutterFlowTheme.of(context)
                                              .alternate,
                                          width: 1.0,
                                        ),
                                      ),
                                      alignment:
                                          AlignmentDirectional(0.0, 0.0),
                                      child: Padding(
                                        padding:
                                            EdgeInsetsDirectional.fromSTEB(
                                                12.0, 0.0, 12.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.check_rounded,
                                              color: isTodaySelected
                                                  ? Colors.white
                                                  : FlutterFlowTheme.of(context)
                                                      .primaryText,
                                              size: 16.0,
                                            ),
                                            Text(
                                              'Today',
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .labelMedium
                                                  .override(
                                                    font: GoogleFonts.nunito(
                                                      fontWeight:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .labelMedium
                                                              .fontWeight,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .labelMedium
                                                              .fontStyle,
                                                    ),
                                                    color: isTodaySelected
                                                        ? Colors.white
                                                        : FlutterFlowTheme.of(
                                                                context)
                                                            .primaryText,
                                                    fontSize: 14.0,
                                                    letterSpacing: 0.0,
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelMedium
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelMedium
                                                            .fontStyle,
                                                    lineHeight: 1.4,
                                                  ),
                                            ),
                                          ].divide(SizedBox(width: 6.0)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_loadError != null)
                                    _stateMessage(
                                      context,
                                      _loadError!,
                                      key: const ValueKey(
                                          'calendarLoadError'),
                                    )
                                  else if (_recipientRef == null)
                                    _stateMessage(
                                      context,
                                      calendarNoRecipient,
                                      key: const ValueKey(
                                          'calendarNoRecipient'),
                                    )
                                  else if (_loading)
                                    SizedBox.shrink()
                                  else if (dayAppointments.isEmpty)
                                    _stateMessage(
                                      context,
                                      searchTerm.isNotEmpty
                                          ? calendarNoAppointmentsMatchSearch
                                          : _appointments.isEmpty
                                              ? calendarNoAppointmentsAtAll
                                              : calendarNoAppointmentsForDay,
                                      key: const ValueKey(
                                          'calendarDayEmpty'),
                                    )
                                  else
                                    for (final record in dayAppointments)
                                      EventItemWidget(
                                        categoryColor: _toneColor(
                                          context,
                                          appointmentTone(
                                              record.appointmentType),
                                        ),
                                        title: record.appointmentTitle
                                                .trim()
                                                .isEmpty
                                            ? 'Appointment'
                                            : record.appointmentTitle,
                                        time: appointmentTimeLabel(record)
                                                .trim()
                                                .isEmpty
                                            ? 'Time not set'
                                            : appointmentTimeLabel(record),
                                        iconName: Icon(
                                          _toneIcon(appointmentTone(
                                              record.appointmentType)),
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          size: 20.0,
                                        ),
                                      ),
                                ].divide(SizedBox(height: 16.0)),
                              ),
                              Text(
                                'Upcoming',
                                style: FlutterFlowTheme.of(context)
                                    .labelLarge
                                    .override(
                                      font: GoogleFonts.nunito(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .labelLarge
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelLarge
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelLarge
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelLarge
                                          .fontStyle,
                                      lineHeight: 1.4,
                                    ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28.0),
                                  shape: BoxShape.rectangle,
                                  border: Border.all(
                                    color:
                                        FlutterFlowTheme.of(context).alternate,
                                    width: 1.0,
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Container(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.event_available_rounded,
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                          size: 24.0,
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Text(
                                                upcoming == null
                                                    ? calendarNoUpcomingAppointment
                                                    : (upcoming.appointmentTitle
                                                            .trim()
                                                            .isEmpty
                                                        ? 'Appointment'
                                                        : upcoming
                                                            .appointmentTitle),
                                                key: const ValueKey(
                                                    'calendarUpcomingTitle'),
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodyMedium
                                                    .override(
                                                      font: GoogleFonts.nunito(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontStyle,
                                                      lineHeight: 1.4,
                                                    ),
                                              ),
                                              if (upcoming?.appointmentDateTime !=
                                                  null)
                                                Text(
                                                  appointmentWhenLabel(
                                                      upcoming!
                                                          .appointmentDateTime!,
                                                      now: _now),
                                                  key: const ValueKey(
                                                      'calendarUpcomingWhen'),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .labelSmall
                                                      .override(
                                                        font:
                                                            GoogleFonts.nunito(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmall
                                                                  .fontWeight,
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
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontStyle,
                                                        lineHeight: 1.4,
                                                      ),
                                                ),
                                            ].divide(SizedBox(height: 4.0)),
                                          ),
                                        ),
                                      ].divide(SizedBox(width: 16.0)),
                                    ),
                                  ),
                                ),
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
            Align(
              alignment: AlignmentDirectional(0.0, 1.0),
              child: Container(
                child: Container(
                  width: 0.0,
                  height: 0.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
