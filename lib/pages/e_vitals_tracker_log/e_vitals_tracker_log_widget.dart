// Vitals & Health — real recording for the selected care recipient.
//
// Owner decisions of 2026-11-13 (proposal §9) implemented here:
//  * the page resolves the real care recipient (route parameter first, else
//    `FFAppState().selectedCareRecipient`, the same rule the dashboard uses);
//    with no recipient it shows an honest empty state and cannot write;
//  * the invented person, diagnoses, readings, times, "Normal"/"Elevated"
//    classifications and the symptom chips are gone;
//  * all seven measurements the model carries are recordable (°F, lb, mg/dL,
//    bpm, %, pain 0–10 with 0 valid) plus optional observations;
//  * "Save Daily Logs" writes ONE `vitalLogs` document carrying `orgId` and
//    `loggedByUid` as the merged security rules require;
//  * the history icon opens the recipient's saved readings with dates, times,
//    real author names, and edit/delete for the author or an org owner/admin
//    (the rules enforce the same restriction regardless of what is shown);
//  * "Add Care Note" and the symptom chips are removed — those belong to their
//    own features.
//
// A response that arrives for a previously selected recipient is discarded
// (see `_loadToken`), so this screen can never show another recipient's data.
import '/backend/backend.dart';
import '/backend/org/org_service.dart';
import '/backend/vitals/vitals_entry.dart';
import '/components/button/button_widget.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'e_vitals_tracker_log_model.dart';
export 'e_vitals_tracker_log_model.dart';

class EVitalsTrackerLogWidget extends StatefulWidget {
  const EVitalsTrackerLogWidget({super.key, this.careRecipients});

  static String routeName = 'EVitalsTrackerLog';
  static String routePath = '/eVitalsTrackerLog';

  /// The care recipient to record for. When null, the app-wide selection
  /// (`FFAppState().selectedCareRecipient`) is used.
  final DocumentReference? careRecipients;

  @override
  State<EVitalsTrackerLogWidget> createState() =>
      _EVitalsTrackerLogWidgetState();
}

class _EVitalsTrackerLogWidgetState extends State<EVitalsTrackerLogWidget> {
  late EVitalsTrackerLogModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  DocumentReference? _recipientRef;
  CareRecipientsRecord? _recipient;
  List<VitalLogsRecord> _logs = const [];
  Map<String, String> _authorNames = const {};

  String? _loadError;
  String? _status;
  bool _statusIsError = false;
  bool _loading = false;
  bool _saving = false;
  bool _isOwnerOrAdmin = false;
  String? _uid;

  /// Bumped on every load; a response carrying an older token belongs to a
  /// previously selected recipient and is thrown away.
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EVitalsTrackerLogModel());

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
      widget.careRecipients ?? FFAppState().selectedCareRecipient;

  String get _recipientName => (_recipient?.name ?? '').trim();

  /// The recipient changed while this page is open (e.g. picked from the
  /// directory): reload everything for the new one and drop the old data.
  void _onAppStateChanged() {
    if (widget.careRecipients != null || !mounted) {
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
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (!mounted) {
      return;
    }
    setState(() {
      _recipientRef = ref;
      _recipient = null;
      _logs = const [];
      _authorNames = const {};
      _loadError = null;
      _status = null;
      _isOwnerOrAdmin = false;
      _uid = (uid == null || uid.isEmpty) ? null : uid;
      _loading = ref != null;
    });
    _clearInputs();

    if (ref == null) {
      return;
    }

    try {
      final recipient = await CareRecipientsRecord.getDocumentOnce(ref);
      final logs = await queryVitalLogsRecordOnce(
        queryBuilder: (query) => query
            .where('careRecipientRef', isEqualTo: ref)
            .orderBy('logDateTime', descending: true),
        limit: 50,
      );

      final orgId = recipient.orgId.trim();
      final authorNames = <String, String>{};
      var canManage = false;
      final currentUid = _uid;
      if (orgId.isNotEmpty && currentUid != null) {
        final membership = await getMembership(orgId, currentUid);
        canManage = membership != null &&
            (membership.role == kRoleOwner || membership.role == kRoleAdmin);
        for (final log in logs) {
          final authorUid = log.loggedByUid;
          if (authorUid.isEmpty) {
            continue;
          }
          final member = authorUid == currentUid
              ? membership
              : await getMembership(orgId, authorUid);
          final name = (member?.displayName ?? '').trim();
          authorNames[authorUid] =
              name.isNotEmpty ? name : (member?.email ?? '').trim();
        }
      }

      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _recipient = recipient;
        _logs = sortVitalsNewestFirst(logs);
        _authorNames = authorNames;
        _isOwnerOrAdmin = canManage;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = 'Could not load the vitals for this care recipient. '
            'Please check your connection and try again.';
      });
    }
  }

  void _clearInputs() {
    for (final controller in [
      _model.systolicModel.inputTextController,
      _model.diastolicModel.inputTextController,
      _model.heartRateModel.inputTextController,
      _model.bloodGlucoseModel.inputTextController,
      _model.oxygenSaturationModel.inputTextController,
      _model.temperatureModel.inputTextController,
      _model.weightModel.inputTextController,
      _model.painLevelModel.inputTextController,
      _model.notesModel.inputTextController,
    ]) {
      controller?.clear();
    }
  }

  VitalsValidation _validateForm() => validateVitalsInput(
        systolic: _model.systolicModel.inputTextController?.text,
        diastolic: _model.diastolicModel.inputTextController?.text,
        heartRate: _model.heartRateModel.inputTextController?.text,
        bloodGlucose: _model.bloodGlucoseModel.inputTextController?.text,
        oxygenSaturation:
            _model.oxygenSaturationModel.inputTextController?.text,
        temperature: _model.temperatureModel.inputTextController?.text,
        weight: _model.weightModel.inputTextController?.text,
        painLevel: _model.painLevelModel.inputTextController?.text,
        notes: _model.notesModel.inputTextController?.text,
      );

  void _setStatus(String message, {required bool isError}) {
    if (!mounted) {
      return;
    }
    setState(() {
      _status = message;
      _statusIsError = isError;
    });
  }

  /// Saves one `vitalLogs` document for the selected recipient.
  Future<void> _save() async {
    final recipient = _recipient;
    final recipientRef = _recipientRef;
    final uid = _uid;

    if (recipient == null || recipientRef == null) {
      _setStatus('Choose a care recipient before saving vitals.',
          isError: true);
      return;
    }
    if (uid == null) {
      _setStatus('You must be signed in to save vitals.', isError: true);
      return;
    }
    final orgId = recipient.orgId.trim();
    if (orgId.isEmpty) {
      _setStatus(
        'This care recipient is not linked to a household, so vitals cannot '
        'be saved.',
        isError: true,
      );
      return;
    }

    final validation = _validateForm();
    if (!validation.isValid) {
      _setStatus(validation.error!, isError: true);
      return;
    }
    final draft = validation.draft!;

    setState(() {
      _saving = true;
      _status = null;
    });

    try {
      final now = DateTime.now();
      await VitalLogsRecord.collection.doc().set(
            createVitalLogsRecordData(
              careRecipientRef: recipientRef,
              logDateTime: now,
              bloodPressureSystolic: draft.bloodPressureSystolic,
              bloodPressureDiastolic: draft.bloodPressureDiastolic,
              heartRate: draft.heartRate,
              bloodGlucose: draft.bloodGlucose,
              oxygenSaturation: draft.oxygenSaturation,
              temperature: draft.temperature,
              weight: draft.weight,
              painLevel: draft.painLevel,
              notes: draft.notes.isEmpty ? null : draft.notes,
              orgId: orgId,
              loggedByUid: uid,
              createdAt: now.toIso8601String(),
              updatedAt: now.toIso8601String(),
            ),
          );
      _clearInputs();
      if (mounted) {
        setState(() => _saving = false);
      }
      await _load();
      _setStatus(
        'Vitals saved for ${_recipientName.isEmpty ? 'this care recipient' : _recipientName}.',
        isError: false,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
      }
      _setStatus(
        'Could not save these vitals. Please check your connection and try '
        'again.',
        isError: true,
      );
    }
  }

  /// True when this user may edit/delete [log]: the original author, or an
  /// owner/admin of the recipient's org — the same rule the security rules
  /// enforce.
  bool _canModify(VitalLogsRecord log) {
    final uid = _uid;
    if (uid != null && log.loggedByUid == uid) {
      return true;
    }
    return _isOwnerOrAdmin;
  }

  /// The editable fields of one reading. `careRecipientRef`, `orgId` and
  /// `loggedByUid` are never touched; cleared measurements are removed.
  Map<String, dynamic> _updateFrom(VitalsDraft draft) {
    dynamic orDelete(dynamic value) => value ?? FieldValue.delete();
    return {
      'bloodPressureSystolic': orDelete(draft.bloodPressureSystolic),
      'bloodPressureDiastolic': orDelete(draft.bloodPressureDiastolic),
      'heartRate': orDelete(draft.heartRate),
      'bloodGlucose': orDelete(draft.bloodGlucose),
      'oxygenSaturation': orDelete(draft.oxygenSaturation),
      'temperature': orDelete(draft.temperature),
      'weight': orDelete(draft.weight),
      'painLevel': orDelete(draft.painLevel),
      'notes': draft.notes.isEmpty ? FieldValue.delete() : draft.notes,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _updateLog(VitalLogsRecord log, VitalsDraft draft) async {
    try {
      await log.reference.update(_updateFrom(draft));
      await _load();
      _setStatus('Reading updated.', isError: false);
    } catch (_) {
      _setStatus(
        'Could not update this reading. Please check your connection and try '
        'again.',
        isError: true,
      );
    }
  }

  Future<void> _deleteLog(VitalLogsRecord log) async {
    try {
      await log.reference.delete();
      await _load();
      _setStatus('Reading deleted.', isError: false);
    } catch (_) {
      _setStatus(
        'Could not delete this reading. Please check your connection and try '
        'again.',
        isError: true,
      );
    }
  }

  Future<void> _openHistory() async {
    if (!mounted) {
      return;
    }
    final entries =
        buildVitalsHistory(logs: _logs, authorNames: _authorNames);
    final action = await showModalBottomSheet<_HistoryAction>(
      isScrollControlled: true,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      context: context,
      builder: (sheetContext) => _VitalsHistorySheet(
        entries: entries,
        recipientName: _recipientName,
        canModify: _canModify,
      ),
    );
    if (action == null || !mounted) {
      return;
    }
    if (action.delete) {
      final confirmed = await _confirmDelete();
      if (confirmed == true && mounted) {
        await _deleteLog(action.entry.log);
      }
      return;
    }
    final draft = await _showEditDialog(action.entry);
    if (draft != null && mounted) {
      await _updateLog(action.entry.log, draft);
    }
  }

  Future<bool?> _confirmDelete() => showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete this reading?'),
          content: Text(
            'The saved reading for '
            '${_recipientName.isEmpty ? 'this care recipient' : _recipientName} '
            'will be removed. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

  /// Edits the measurements of an existing reading. Returns null when the user
  /// cancels.
  Future<VitalsDraft?> _showEditDialog(VitalsHistoryEntry entry) =>
      showDialog<VitalsDraft>(
        context: context,
        builder: (dialogContext) => _VitalsEditDialog(entry: entry),
      );

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return '';
    }
    final first = words.first.substring(0, 1);
    final last = words.length > 1 ? words.last.substring(0, 1) : '';
    return '$first$last'.toUpperCase();
  }

  Widget _wrapField(TextFieldModel model, String hint) => wrapWithModel(
        model: model,
        updateCallback: () => safeSetState(() {}),
        child: TextFieldWidget(
          label: '',
          labelPresent: false,
          helper: '',
          helperPresent: false,
          leadingIconPresent: false,
          trailingIconPresent: false,
          hint: hint,
          value: '',
          onChange: '',
          onSubmit: '',
          variant: 'filled',
          error: false,
        ),
      );

  Widget _card({
    required Widget icon,
    required Color iconBg,
    required String label,
    required String unit,
    required VitalMeasurement measurement,
    required String clock,
    required List<Widget> fields,
  }) =>
      _VitalsInputCard(
        icon: icon,
        iconBg: iconBg,
        label: label,
        unit: unit,
        clock: clock,
        lastReading: lastReadingText(_logs, measurement),
        fields: fields,
      );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final now = DateTime.now();
    final clock = formatVitalsClock(now);
    final name = _recipientName;
    final hasRecipient = _recipientRef != null;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: theme.primaryBackground,
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
                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 5.0, 0.0, 0.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.primaryBackground,
                      shape: BoxShape.rectangle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    10.0, 0.0, 0.0, 0.0),
                                child: Text(
                                  'Vitals & Health',
                                  style: theme.titleLarge.override(
                                    font: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.bold,
                                      fontStyle: theme.titleLarge.fontStyle,
                                    ),
                                    color: theme.primaryText,
                                    fontSize: 28.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: theme.titleLarge.fontStyle,
                                    lineHeight: 1.3,
                                  ),
                                ),
                              ),
                              Text(
                                formatVitalsToday(now),
                                style: theme.bodySmall.override(
                                  font: GoogleFonts.nunito(
                                    fontWeight: theme.bodySmall.fontWeight,
                                    fontStyle: theme.bodySmall.fontStyle,
                                  ),
                                  color: theme.secondaryText,
                                  letterSpacing: 0.0,
                                  fontWeight: theme.bodySmall.fontWeight,
                                  fontStyle: theme.bodySmall.fontStyle,
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
                                    35.0, 0.0, 30.0, 0.0),
                                child: FlutterFlowIconButton(
                                  key: const ValueKey('vitals_history_button'),
                                  borderRadius: 8.0,
                                  buttonSize: 40.0,
                                  fillColor: Colors.transparent,
                                  icon: Icon(
                                    Icons.history_rounded,
                                    color: theme.primaryText,
                                    size: 24.0,
                                  ),
                                  onPressed: _openHistory,
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: AlignmentDirectional(1.0, -1.0),
                            child: Padding(
                              padding: EdgeInsets.all(4.0),
                              child: FlutterFlowIconButton(
                                borderRadius: 28.0,
                                buttonSize: 40.0,
                                fillColor: theme.secondaryBackground,
                                icon: Icon(
                                  Icons.menu,
                                  color: theme.secondaryText,
                                  size: 24.0,
                                ),
                                onPressed: () async {
                                  await showModalBottomSheet(
                                    isScrollControlled: true,
                                    backgroundColor: theme.primaryBackground,
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
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.secondaryBackground,
                      borderRadius: BorderRadius.circular(28.0),
                      shape: BoxShape.rectangle,
                    ),
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 40.0,
                          height: 40.0,
                          decoration: BoxDecoration(
                            color: theme.primary,
                            shape: BoxShape.circle,
                          ),
                          alignment: AlignmentDirectional(0.0, 0.0),
                          child: Text(
                            _initials(name),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: theme.labelMedium.override(
                              font: GoogleFonts.nunito(
                                fontWeight: FontWeight.w600,
                                fontStyle: theme.labelMedium.fontStyle,
                              ),
                              color: theme.onPrimary,
                              fontSize: 15.2,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w600,
                              fontStyle: theme.labelMedium.fontStyle,
                              lineHeight: 1.4,
                            ),
                            overflow: TextOverflow.clip,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasRecipient
                                    ? 'Logging for '
                                        '${name.isEmpty ? 'this care recipient' : name}'
                                    : 'No care recipient selected',
                                style: theme.labelLarge.override(
                                  font: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w600,
                                    fontStyle: theme.labelLarge.fontStyle,
                                  ),
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: theme.labelLarge.fontStyle,
                                  lineHeight: 1.4,
                                ),
                              ),
                              if (!hasRecipient)
                                Text(
                                  'Choose a care recipient from the directory '
                                  'to record vitals.',
                                  style: theme.labelSmall.override(
                                    font: GoogleFonts.nunito(
                                      fontWeight: theme.labelSmall.fontWeight,
                                      fontStyle: theme.labelSmall.fontStyle,
                                    ),
                                    color: theme.secondaryText,
                                    letterSpacing: 0.0,
                                    fontWeight: theme.labelSmall.fontWeight,
                                    fontStyle: theme.labelSmall.fontStyle,
                                    lineHeight: 1.3,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ].divide(SizedBox(width: 16.0)),
                    ),
                  ),
                ),
                if (!hasRecipient)
                  _emptyState(theme)
                else if (_loading)
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                        24.0, 24.0, 24.0, 24.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_loadError != null)
                  _errorState(theme, _loadError!)
                else
                  _form(theme, clock),
                Container(
                  height: 40.0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(FlutterFlowTheme theme) => Padding(
        padding: EdgeInsetsDirectional.fromSTEB(24.0, 8.0, 24.0, 0.0),
        child: Container(
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: BorderRadius.circular(36.0),
            border: Border.all(color: theme.alternate, width: 1.0),
          ),
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No care recipient is selected, so there is nothing to log. Pick a '
            'care recipient from the directory first.',
            style: theme.bodyMedium.override(
              font: GoogleFonts.nunito(
                fontWeight: theme.bodyMedium.fontWeight,
                fontStyle: theme.bodyMedium.fontStyle,
              ),
              color: theme.secondaryText,
              letterSpacing: 0.0,
              fontWeight: theme.bodyMedium.fontWeight,
              fontStyle: theme.bodyMedium.fontStyle,
              lineHeight: 1.6,
            ),
          ),
        ),
      );

  Widget _errorState(FlutterFlowTheme theme, String message) => Padding(
        padding: EdgeInsetsDirectional.fromSTEB(24.0, 8.0, 24.0, 0.0),
        child: Container(
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: BorderRadius.circular(36.0),
            border: Border.all(color: theme.alternate, width: 1.0),
          ),
          padding: EdgeInsets.all(24.0),
          child: Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded,
                    color: theme.error, size: 20.0),
                SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    message,
                    style: theme.bodyMedium.override(
                      font: GoogleFonts.nunito(
                        fontWeight: theme.bodyMedium.fontWeight,
                        fontStyle: theme.bodyMedium.fontStyle,
                      ),
                      color: theme.primaryText,
                      letterSpacing: 0.0,
                      fontWeight: theme.bodyMedium.fontWeight,
                      fontStyle: theme.bodyMedium.fontStyle,
                      lineHeight: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _form(FlutterFlowTheme theme, String clock) => Padding(
        padding: EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
              child: Text(
                'Required Daily Logs',
                style: theme.labelLarge.override(
                  font: GoogleFonts.nunito(
                    fontWeight: theme.labelLarge.fontWeight,
                    fontStyle: theme.labelLarge.fontStyle,
                  ),
                  color: theme.secondaryText,
                  letterSpacing: 0.0,
                  fontWeight: theme.labelLarge.fontWeight,
                  fontStyle: theme.labelLarge.fontStyle,
                  lineHeight: 1.4,
                ),
              ),
            ),
            _card(
              icon: Icon(Icons.favorite_rounded, color: theme.error, size: 22.0),
              iconBg: Color(0xFFFCECEC),
              label: 'Blood Pressure',
              unit: 'mmHg',
              measurement: VitalMeasurement.bloodPressure,
              clock: clock,
              fields: [
                Expanded(
                  child: _wrapField(_model.systolicModel, 'Systolic'),
                ),
                SizedBox(width: 8.0),
                Expanded(
                  child: _wrapField(_model.diastolicModel, 'Diastolic'),
                ),
              ],
            ),
            _card(
              icon: Icon(Icons.monitor_heart_rounded,
                  color: theme.secondary, size: 22.0),
              iconBg: Color(0xFFE3F2FD),
              label: 'Heart Rate',
              unit: 'bpm',
              measurement: VitalMeasurement.heartRate,
              clock: clock,
              fields: [
                Expanded(
                  child: _wrapField(_model.heartRateModel, 'Heart rate'),
                ),
              ],
            ),
            _card(
              icon: Icon(Icons.water_drop_rounded,
                  color: theme.tertiary, size: 22.0),
              iconBg: Color(0xFFFFFDE7),
              label: 'Blood Glucose',
              unit: 'mg/dL',
              measurement: VitalMeasurement.bloodGlucose,
              clock: clock,
              fields: [
                Expanded(
                  child: _wrapField(_model.bloodGlucoseModel, 'Glucose'),
                ),
              ],
            ),
            _card(
              icon: Icon(Icons.air_rounded, color: theme.secondary, size: 22.0),
              iconBg: Color(0xFFE3F2FD),
              label: 'Oxygen Saturation',
              unit: '%',
              measurement: VitalMeasurement.oxygenSaturation,
              clock: clock,
              fields: [
                Expanded(
                  child: _wrapField(_model.oxygenSaturationModel, 'SpO₂'),
                ),
              ],
            ),
            _card(
              icon: Icon(Icons.thermostat_rounded, color: theme.error, size: 22.0),
              iconBg: Color(0xFFFCECEC),
              label: 'Temperature',
              unit: '°F',
              measurement: VitalMeasurement.temperature,
              clock: clock,
              fields: [
                Expanded(
                  child: _wrapField(_model.temperatureModel, 'Temperature'),
                ),
              ],
            ),
            _card(
              icon: Icon(Icons.monitor_weight_rounded,
                  color: theme.tertiary, size: 22.0),
              iconBg: Color(0xFFFFFDE7),
              label: 'Weight',
              unit: 'lb',
              measurement: VitalMeasurement.weight,
              clock: clock,
              fields: [
                Expanded(
                  child: _wrapField(_model.weightModel, 'Weight'),
                ),
              ],
            ),
            _card(
              icon: Icon(Icons.healing_rounded, color: theme.warning, size: 22.0),
              iconBg: Color(0xFFFFF3E0),
              label: 'Pain Level',
              unit: '0–10',
              measurement: VitalMeasurement.painLevel,
              clock: clock,
              fields: [
                Expanded(
                  child: _wrapField(_model.painLevelModel, '0–10'),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 24.0),
              child: Divider(
                height: 16.0,
                thickness: 1.0,
                indent: 0.0,
                endIndent: 0.0,
                color: theme.alternate,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: theme.secondaryBackground,
                borderRadius: BorderRadius.circular(36.0),
                shape: BoxShape.rectangle,
                border: Border.all(color: theme.alternate, width: 1.0),
              ),
              padding: EdgeInsets.all(24.0),
              child: _wrapField(_model.notesModel, 'e.g. slight tremor in left hand'),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 24.0, 0.0, 0.0),
              child: wrapWithModel(
                model: _model.buttonModel1,
                updateCallback: () => safeSetState(() {}),
                child: ButtonWidget(
                  icon: Icon(
                    Icons.check_rounded,
                    color: theme.primaryText,
                    size: 24.0,
                  ),
                  iconPresent: true,
                  iconEndPresent: false,
                  content: 'Save Daily Logs',
                  variant: 'primary',
                  size: 'large',
                  fullWidth: true,
                  loading: _saving,
                  disabled: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
            ),
            if (_status != null)
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                child: Semantics(
                  liveRegion: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _statusIsError
                            ? Icons.error_outline_rounded
                            : Icons.check_circle_outline_rounded,
                        color: _statusIsError ? theme.error : theme.success,
                        size: 20.0,
                      ),
                      SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          _status!,
                          style: theme.bodyMedium.override(
                            font: GoogleFonts.nunito(
                              fontWeight: theme.bodyMedium.fontWeight,
                              fontStyle: theme.bodyMedium.fontStyle,
                            ),
                            color: _statusIsError
                                ? theme.error
                                : theme.primaryText,
                            letterSpacing: 0.0,
                            fontWeight: theme.bodyMedium.fontWeight,
                            fontStyle: theme.bodyMedium.fontStyle,
                            lineHeight: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}

/// One measurement card: icon, label, unit, the input(s), the time this log
/// will carry, and the recipient's last recorded value for it.
class _VitalsInputCard extends StatelessWidget {
  const _VitalsInputCard({
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.unit,
    required this.clock,
    required this.lastReading,
    required this.fields,
  });

  final Widget icon;
  final Color iconBg;
  final String label;
  final String unit;
  final String clock;
  final String lastReading;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              borderRadius: BorderRadius.circular(36.0),
              shape: BoxShape.rectangle,
            ),
            padding: EdgeInsets.all(24.0),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 40.0,
                          height: 40.0,
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(28.0),
                            shape: BoxShape.rectangle,
                          ),
                          alignment: AlignmentDirectional(0.0, 0.0),
                          child: icon,
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
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
                            Text(
                              unit,
                              style: theme.labelSmall.override(
                                font: GoogleFonts.nunito(
                                  fontWeight: theme.labelSmall.fontWeight,
                                  fontStyle: theme.labelSmall.fontStyle,
                                ),
                                color: theme.secondaryText,
                                letterSpacing: 0.0,
                                fontWeight: theme.labelSmall.fontWeight,
                                fontStyle: theme.labelSmall.fontStyle,
                                lineHeight: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ].divide(SizedBox(width: 8.0)),
                    ),
                    Icon(
                      Icons.info_outlined,
                      color: theme.accent3,
                      size: 20.0,
                    ),
                  ],
                ),
                SizedBox(height: 16.0),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ...fields,
                    SizedBox(width: 16.0),
                    Container(
                      width: 80.0,
                      height: 56.0,
                      decoration: BoxDecoration(
                        color: theme.primaryBackground,
                        borderRadius: BorderRadius.circular(28.0),
                        shape: BoxShape.rectangle,
                        border: Border.all(
                          color: theme.alternate,
                          width: 1.0,
                        ),
                      ),
                      alignment: AlignmentDirectional(0.0, 0.0),
                      child: Text(
                        clock,
                        style: theme.bodyMedium.override(
                          font: GoogleFonts.nunito(
                            fontWeight: theme.bodyMedium.fontWeight,
                            fontStyle: theme.bodyMedium.fontStyle,
                          ),
                          color: theme.primaryText,
                          letterSpacing: 0.0,
                          fontWeight: theme.bodyMedium.fontWeight,
                          fontStyle: theme.bodyMedium.fontStyle,
                          lineHeight: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(4.0, 8.0, 4.0, 8.0),
            child: Text(
              lastReading,
              style: theme.labelSmall.override(
                font: GoogleFonts.nunito(
                  fontWeight: theme.labelSmall.fontWeight,
                  fontStyle: theme.labelSmall.fontStyle,
                ),
                color: theme.secondaryText,
                letterSpacing: 0.0,
                fontWeight: theme.labelSmall.fontWeight,
                fontStyle: theme.labelSmall.fontStyle,
                lineHeight: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the history sheet asks the page to do with one reading.
class _HistoryAction {
  const _HistoryAction({required this.entry, required this.delete});

  final VitalsHistoryEntry entry;
  final bool delete;
}

/// The edit-reading dialog. It owns its text controllers for exactly as long
/// as the dialog route exists: disposing them when `showDialog` returns would
/// tear them down while the route is still animating out.
class _VitalsEditDialog extends StatefulWidget {
  const _VitalsEditDialog({required this.entry});

  final VitalsHistoryEntry entry;

  @override
  State<_VitalsEditDialog> createState() => _VitalsEditDialogState();
}

class _VitalsEditDialogState extends State<_VitalsEditDialog> {
  late final TextEditingController _systolic;
  late final TextEditingController _diastolic;
  late final TextEditingController _heartRate;
  late final TextEditingController _bloodGlucose;
  late final TextEditingController _oxygenSaturation;
  late final TextEditingController _temperature;
  late final TextEditingController _weight;
  late final TextEditingController _painLevel;
  late final TextEditingController _notes;

  String? _error;

  @override
  void initState() {
    super.initState();
    final log = widget.entry.log;
    _systolic = TextEditingController(
        text: log.hasBloodPressureSystolic()
            ? log.bloodPressureSystolic.toString()
            : '');
    _diastolic = TextEditingController(
        text: log.hasBloodPressureDiastolic()
            ? log.bloodPressureDiastolic.toString()
            : '');
    _heartRate =
        TextEditingController(text: log.hasHeartRate() ? '${log.heartRate}' : '');
    _bloodGlucose = TextEditingController(
        text: log.hasBloodGlucose() ? '${log.bloodGlucose}' : '');
    _oxygenSaturation = TextEditingController(
        text: log.hasOxygenSaturation() ? '${log.oxygenSaturation}' : '');
    _temperature = TextEditingController(
        text: log.hasTemperature() ? '${log.temperature}' : '');
    _weight =
        TextEditingController(text: log.hasWeight() ? '${log.weight}' : '');
    _painLevel = TextEditingController(
        text: log.hasPainLevel() ? '${log.painLevel}' : '');
    _notes = TextEditingController(text: log.notes);
  }

  @override
  void dispose() {
    _systolic.dispose();
    _diastolic.dispose();
    _heartRate.dispose();
    _bloodGlucose.dispose();
    _oxygenSaturation.dispose();
    _temperature.dispose();
    _weight.dispose();
    _painLevel.dispose();
    _notes.dispose();
    super.dispose();
  }

  Widget _field(String label, TextEditingController controller) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 0.0),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label, isDense: true),
        ),
      );

  void _save() {
    final validation = validateVitalsInput(
      systolic: _systolic.text,
      diastolic: _diastolic.text,
      heartRate: _heartRate.text,
      bloodGlucose: _bloodGlucose.text,
      oxygenSaturation: _oxygenSaturation.text,
      temperature: _temperature.text,
      weight: _weight.text,
      painLevel: _painLevel.text,
      notes: _notes.text,
    );
    if (!validation.isValid) {
      setState(() => _error = validation.error);
      return;
    }
    Navigator.of(context).pop(validation.draft);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return AlertDialog(
      title: const Text('Edit reading'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.entry.dateTimeText,
              style: theme.bodySmall,
            ),
            const SizedBox(height: 12),
            _field('Blood pressure systolic (mmHg)', _systolic),
            _field('Blood pressure diastolic (mmHg)', _diastolic),
            _field('Heart rate (bpm)', _heartRate),
            _field('Blood glucose (mg/dL)', _bloodGlucose),
            _field('Oxygen saturation (%)', _oxygenSaturation),
            _field('Temperature (°F)', _temperature),
            _field('Weight (lb)', _weight),
            _field('Pain level (0–10)', _painLevel),
            _field('Additional observations', _notes),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: theme.bodySmall.override(color: theme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}


/// The recipient's saved readings, newest first, with the author and (where
/// permitted) edit/delete controls.
class _VitalsHistorySheet extends StatelessWidget {
  const _VitalsHistorySheet({
    required this.entries,
    required this.recipientName,
    required this.canModify,
  });

  final List<VitalsHistoryEntry> entries;
  final String recipientName;
  final bool Function(VitalLogsRecord log) canModify;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(24.0, 16.0, 24.0, 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: theme.alternate,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              SizedBox(height: 16.0),
              Text(
                'Saved readings',
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
              Text(
                recipientName.isEmpty
                    ? 'No care recipient selected'
                    : 'For $recipientName',
                style: theme.labelSmall.override(
                  font: GoogleFonts.nunito(
                    fontWeight: theme.labelSmall.fontWeight,
                    fontStyle: theme.labelSmall.fontStyle,
                  ),
                  color: theme.secondaryText,
                  letterSpacing: 0.0,
                  fontWeight: theme.labelSmall.fontWeight,
                  fontStyle: theme.labelSmall.fontStyle,
                  lineHeight: 1.3,
                ),
              ),
              SizedBox(height: 16.0),
              if (entries.isEmpty)
                Text(
                  'No readings have been saved for this care recipient yet.',
                  style: theme.bodyMedium.override(
                    font: GoogleFonts.nunito(
                      fontWeight: theme.bodyMedium.fontWeight,
                      fontStyle: theme.bodyMedium.fontStyle,
                    ),
                    color: theme.secondaryText,
                    letterSpacing: 0.0,
                    fontWeight: theme.bodyMedium.fontWeight,
                    fontStyle: theme.bodyMedium.fontStyle,
                    lineHeight: 1.6,
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12.0),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final editable = canModify(entry.log);
                      return Container(
                        decoration: BoxDecoration(
                          color: theme.secondaryBackground,
                          borderRadius: BorderRadius.circular(24.0),
                        ),
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.dateTimeText,
                                    style: theme.labelLarge.override(
                                      font: GoogleFonts.nunito(
                                        fontWeight: FontWeight.w600,
                                        fontStyle: theme.labelLarge.fontStyle,
                                      ),
                                      color: theme.primaryText,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: theme.labelLarge.fontStyle,
                                      lineHeight: 1.4,
                                    ),
                                  ),
                                ),
                                if (editable)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit reading',
                                        iconSize: 20.0,
                                        visualDensity: VisualDensity.compact,
                                        icon: Icon(
                                          Icons.edit_rounded,
                                          color: theme.primaryText,
                                        ),
                                        onPressed: () => Navigator.of(context)
                                            .pop(_HistoryAction(
                                          entry: entry,
                                          delete: false,
                                        )),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete reading',
                                        iconSize: 20.0,
                                        visualDensity: VisualDensity.compact,
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          color: theme.error,
                                        ),
                                        onPressed: () => Navigator.of(context)
                                            .pop(_HistoryAction(
                                          entry: entry,
                                          delete: true,
                                        )),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            ...entry.valueLines.map(
                              (line) => Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 4.0, 0.0, 0.0),
                                child: Text(
                                  line,
                                  style: theme.bodyMedium.override(
                                    font: GoogleFonts.nunito(
                                      fontWeight: theme.bodyMedium.fontWeight,
                                      fontStyle: theme.bodyMedium.fontStyle,
                                    ),
                                    color: theme.primaryText,
                                    letterSpacing: 0.0,
                                    fontWeight: theme.bodyMedium.fontWeight,
                                    fontStyle: theme.bodyMedium.fontStyle,
                                    lineHeight: 1.6,
                                  ),
                                ),
                              ),
                            ),
                            if (entry.hasNotes)
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 4.0, 0.0, 0.0),
                                child: Text(
                                  entry.notes,
                                  style: theme.bodySmall.override(
                                    font: GoogleFonts.nunito(
                                      fontWeight: theme.bodySmall.fontWeight,
                                      fontStyle: theme.bodySmall.fontStyle,
                                    ),
                                    color: theme.secondaryText,
                                    letterSpacing: 0.0,
                                    fontWeight: theme.bodySmall.fontWeight,
                                    fontStyle: theme.bodySmall.fontStyle,
                                    lineHeight: 1.5,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 8.0, 0.0, 0.0),
                              child: Text(
                                'Recorded by ${entry.authorName}',
                                style: theme.labelSmall.override(
                                  font: GoogleFonts.nunito(
                                    fontWeight: theme.labelSmall.fontWeight,
                                    fontStyle: theme.labelSmall.fontStyle,
                                  ),
                                  color: theme.secondaryText,
                                  letterSpacing: 0.0,
                                  fontWeight: theme.labelSmall.fontWeight,
                                  fontStyle: theme.labelSmall.fontStyle,
                                  lineHeight: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
