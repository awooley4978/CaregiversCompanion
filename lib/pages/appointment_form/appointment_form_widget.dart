// The ONE appointment form: "New Event" creates, Doctor Visit Prep's "Details"
// edits (appointments unit, part 3 — owner decision 2026-11-16, proposal §7).
//
// It is deliberately the same editor in two modes, the create-or-edit pattern
// the owner already approved for Care Profile Setup:
//
//   opened WITHOUT an appointment  -> create a new `appointments` document for
//                                     the selected care recipient (or the one
//                                     the caller passed), pre-filled with the
//                                     Calendar's selected day;
//   opened WITH an appointment     -> load it, edit it, and save back to the
//                                     SAME document. It can never create a
//                                     second copy: the reference it was opened
//                                     with is the only document it writes.
//
// Writes follow the merged rules exactly (see
// `lib/backend/appointments/appointment_form.dart`): create carries the
// recipient's own orgId and the caller's uid with server-stamped timestamps;
// update sends only the fields this form owns, so `careRecipientRef`, `orgId`,
// `createdByUid` and Doctor Prep's `questionsToAsk` are never touched.
import '/app_state.dart';
import '/backend/appointments/appointment_display.dart';
import '/backend/appointments/appointment_form.dart';
import '/backend/backend.dart';
import '/components/button/button_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AppointmentFormWidget extends StatefulWidget {
  const AppointmentFormWidget({
    super.key,
    this.appointments,
    this.careRecipient,
    this.initialDate,
    this.now,
  });

  /// The appointment being edited. Null means the form creates a new one.
  final DocumentReference? appointments;

  /// The care recipient a NEW appointment belongs to. Ignored in edit mode
  /// (the loaded record already knows its recipient).
  final DocumentReference? careRecipient;

  /// The day a NEW appointment starts on — the Calendar passes the day the
  /// caregiver had selected.
  final DateTime? initialDate;

  /// Injectable "today", so the form's date defaults are deterministic in
  /// tests. Null means the device clock.
  final DateTime? now;

  static String routeName = 'AppointmentForm';
  static String routePath = '/appointmentForm';

  @override
  State<AppointmentFormWidget> createState() => _AppointmentFormWidgetState();
}

class AppointmentFormModel extends FlutterFlowModel<AppointmentFormWidget> {
  late TextFieldModel textFieldTitleModel;
  late TextFieldModel textFieldTypeModel;
  late TextFieldModel textFieldProviderModel;
  late TextFieldModel textFieldLocationModel;
  late TextFieldModel textFieldReasonModel;
  late TextFieldModel textFieldNotesModel;
  late ButtonModel buttonSaveModel;

  @override
  void initState(BuildContext context) {
    textFieldTitleModel = createModel(context, () => TextFieldModel());
    textFieldTypeModel = createModel(context, () => TextFieldModel());
    textFieldProviderModel = createModel(context, () => TextFieldModel());
    textFieldLocationModel = createModel(context, () => TextFieldModel());
    textFieldReasonModel = createModel(context, () => TextFieldModel());
    textFieldNotesModel = createModel(context, () => TextFieldModel());
    buttonSaveModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    textFieldTitleModel.dispose();
    textFieldTypeModel.dispose();
    textFieldProviderModel.dispose();
    textFieldLocationModel.dispose();
    textFieldReasonModel.dispose();
    textFieldNotesModel.dispose();
    buttonSaveModel.dispose();
  }
}

class _AppointmentFormWidgetState extends State<AppointmentFormWidget> {
  late AppointmentFormModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  /// True while the appointment being edited is loading, and why it could not
  /// be loaded. While either is in play Save stays disabled: an unloaded form
  /// must never be saved, or it would blank a real appointment.
  bool _loadingExisting = false;
  String? _loadError;

  /// The validation message, shown under the fields and blocking the save.
  String? _formError;

  bool _saving = false;

  /// The loaded appointment (edit mode only).
  AppointmentsRecord? _loaded;

  /// The form's own date and times.
  DateTime? _day;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _followUpNeeded = false;

  bool get _isEditing => widget.appointments != null;
  bool get _saveBlocked =>
      _saving || (_isEditing && (_loadingExisting || _loadError != null));

  DateTime get _now => widget.now ?? DateTime.now();

  /// The recipient this form writes for: the loaded appointment's own recipient
  /// in edit mode, otherwise the caller's (or the app-wide selection).
  DocumentReference? get _recipientRef => _isEditing
      ? _loaded?.careRecipientRef
      : (widget.careRecipient ?? FFAppState().selectedCareRecipient);

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AppointmentFormModel());

    // A new appointment starts on the day the caller is looking at (the
    // Calendar's selected day); the times stay empty until they are chosen.
    _day = appointmentDay(widget.initialDate ?? _now);

    if (_isEditing) {
      _loadExisting();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  /// Loads the appointment being edited and pre-fills the form with its stored
  /// values. The text controllers are set directly because TextFieldWidget
  /// seeds its controller only once, in its own initState.
  Future<void> _loadExisting() async {
    final ref = widget.appointments;
    if (ref == null) {
      return;
    }
    safeSetState(() {
      _loadingExisting = true;
      _loadError = null;
    });
    try {
      final record = await AppointmentsRecord.getDocumentOnce(ref);
      if (!mounted) {
        return;
      }
      final values = AppointmentFormValues.fromRecord(record);
      safeSetState(() {
        _loadingExisting = false;
        _loadError = null;
        _loaded = record;
        _day = values.day;
        _startTime = values.startHour == null || values.startMinute == null
            ? null
            : TimeOfDay(hour: values.startHour!, minute: values.startMinute!);
        _endTime = values.endHour == null || values.endMinute == null
            ? null
            : TimeOfDay(hour: values.endHour!, minute: values.endMinute!);
        _followUpNeeded = values.followUpNeeded;

        _setText(_model.textFieldTitleModel, values.title);
        _setText(_model.textFieldTypeModel, values.type);
        _setText(_model.textFieldProviderModel, values.providerName);
        _setText(_model.textFieldLocationModel, values.location);
        _setText(_model.textFieldReasonModel, values.reason);
        _setText(_model.textFieldNotesModel, values.notes);
      });
    } catch (_) {
      if (mounted) {
        safeSetState(() {
          _loadingExisting = false;
          _loadError = 'Could not load this appointment. Please check your '
              'connection and try again.';
        });
      }
    }
  }

  void _setText(TextFieldModel field, String text) {
    final controller = field.inputTextController ??= TextEditingController();
    controller.text = text;
    controller.selection =
        TextSelection.collapsed(offset: controller.text.length);
  }

  AppointmentFormValues get _values => AppointmentFormValues(
        title: _model.textFieldTitleModel.inputTextController?.text ?? '',
        type: _model.textFieldTypeModel.inputTextController?.text ?? '',
        providerName:
            _model.textFieldProviderModel.inputTextController?.text ?? '',
        location: _model.textFieldLocationModel.inputTextController?.text ?? '',
        reason: _model.textFieldReasonModel.inputTextController?.text ?? '',
        notes: _model.textFieldNotesModel.inputTextController?.text ?? '',
        day: _day,
        startHour: _startTime?.hour,
        startMinute: _startTime?.minute,
        endHour: _endTime?.hour,
        endMinute: _endTime?.minute,
        followUpNeeded: _followUpNeeded,
      );

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day ?? appointmentToday(_now),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Appointment date',
    );
    if (picked == null) {
      return;
    }
    safeSetState(() => _day = appointmentDay(picked));
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ??
          const TimeOfDay(hour: 9, minute: 0),
      helpText: isStart ? 'Start time' : 'End time',
    );
    if (picked == null) {
      return;
    }
    safeSetState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  /// Creates or updates — never both, and never a duplicate.
  Future<void> _save() async {
    if (_saveBlocked) {
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack(appointmentNotSignedIn);
      return;
    }

    final values = _values;
    final error = appointmentFormError(values);
    safeSetState(() => _formError = error);
    if (error != null) {
      _snack(error);
      return;
    }

    safeSetState(() => _saving = true);
    try {
      if (_isEditing) {
        // The SAME document — an edit can never create a second appointment.
        await widget.appointments!.update(updateAppointmentDataFor(values));
      } else {
        final recipientRef = _recipientRef;
        if (recipientRef == null) {
          _snack(appointmentNoRecipient);
          return;
        }
        // The recipient's own org, read fresh: the rules require
        // `orgId == recipientOrgId(recipient)` on create.
        final recipient = await CareRecipientsRecord.getDocumentOnce(
          recipientRef,
        );
        final orgId = recipient.orgId.trim();
        if (orgId.isEmpty) {
          _snack(appointmentNoHousehold);
          return;
        }
        await AppointmentsRecord.collection.doc().set(
          createAppointmentDataFor(
            careRecipientRef: recipientRef,
            orgId: orgId,
            createdByUid: user.uid,
            values: values,
          ),
        );
      }
      if (!mounted) {
        return;
      }
      _snack('Appointment saved.');
      context.pop();
    } catch (_) {
      if (mounted) {
        safeSetState(() => _saving = false);
        _snack(appointmentSaveFailed);
      }
    }
  }

  void _snack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final title = _isEditing ? 'Appointment Details' : 'New Event';
    final subtitle = _isEditing
        ? 'Update this appointment. The care recipient cannot be changed here.'
        : 'Add an appointment for the selected care recipient.';

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: theme.primaryBackground,
        body: SafeArea(
          child: SingleChildScrollView(
            primary: false,
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(24.0, 24.0, 24.0, 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FlutterFlowIconButton(
                        borderRadius: 20.0,
                        buttonSize: 40.0,
                        fillColor: theme.secondaryBackground,
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: theme.primaryText,
                          size: 24.0,
                        ),
                        onPressed: () => context.pop(),
                      ),
                      SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.headlineMedium.override(
                                font: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.bold),
                                color: theme.primaryText,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.bold,
                                lineHeight: 1.3,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: theme.bodySmall.override(
                                font: GoogleFonts.nunito(),
                                color: theme.secondaryText,
                                letterSpacing: 0.0,
                                lineHeight: 1.5,
                              ),
                            ),
                          ].divide(SizedBox(height: 4.0)),
                        ),
                      ),
                    ],
                  ),
                  if (_loadingExisting)
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                      child: Text(
                        'Loading this appointment…',
                        style: theme.bodySmall.override(
                          font: GoogleFonts.nunito(),
                          color: theme.secondaryText,
                          letterSpacing: 0.0,
                        ),
                      ),
                    ),
                  if (_loadError != null)
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                      child: Text(
                        _loadError!,
                        style: theme.bodySmall.override(
                          font: GoogleFonts.nunito(),
                          color: theme.error,
                          letterSpacing: 0.0,
                        ),
                      ),
                    ),
                  SizedBox(height: 16.0),
                  wrapWithModel(
                    model: _model.textFieldTitleModel,
                    updateCallback: () => safeSetState(() {}),
                    child: TextFieldWidget(
                      label: 'Title',
                      labelPresent: true,
                      helper: 'e.g. Cardiology Follow-up',
                      helperPresent: false,
                      leadingIcon: Icon(
                        Icons.event_note_rounded,
                        color: theme.primaryText,
                        size: 24.0,
                      ),
                      leadingIconPresent: true,
                      trailingIconPresent: false,
                      hint: 'e.g. Cardiology Follow-up',
                      value: '',
                      onChange: '',
                      onSubmit: '',
                      variant: 'outlined',
                      error: _formError == appointmentTitleRequired,
                    ),
                  ),
                  SizedBox(height: 12.0),
                  wrapWithModel(
                    model: _model.textFieldTypeModel,
                    updateCallback: () => safeSetState(() {}),
                    child: TextFieldWidget(
                      label: 'Type',
                      labelPresent: true,
                      helper: 'e.g. Cardiology, Lab work, Therapy',
                      helperPresent: false,
                      leadingIcon: Icon(
                        Icons.local_hospital_rounded,
                        color: theme.primaryText,
                        size: 24.0,
                      ),
                      leadingIconPresent: true,
                      trailingIconPresent: false,
                      hint: 'e.g. Cardiology',
                      value: '',
                      onChange: '',
                      onSubmit: '',
                      variant: 'outlined',
                      error: false,
                    ),
                  ),
                  SizedBox(height: 12.0),
                  _pickerRow(
                    context,
                    label: 'Date',
                    value: _day == null
                        ? 'Choose a date'
                        : DateFormat('EEEE, MMMM d, yyyy').format(_day!),
                    icon: Icons.calendar_month_rounded,
                    onTap: _pickDay,
                  ),
                  SizedBox(height: 12.0),
                  _pickerRow(
                    context,
                    label: 'Start time',
                    value: _startTime == null
                        ? 'Choose a start time'
                        : _startTime!.format(context),
                    icon: Icons.schedule_rounded,
                    onTap: () => _pickTime(isStart: true),
                  ),
                  SizedBox(height: 12.0),
                  _pickerRow(
                    context,
                    label: 'End time (optional)',
                    value: _endTime == null
                        ? 'No end time'
                        : _endTime!.format(context),
                    icon: Icons.schedule_rounded,
                    onTap: () => _pickTime(isStart: false),
                    onClear: _endTime == null
                        ? null
                        : () => safeSetState(() => _endTime = null),
                  ),
                  SizedBox(height: 12.0),
                  wrapWithModel(
                    model: _model.textFieldProviderModel,
                    updateCallback: () => safeSetState(() {}),
                    child: TextFieldWidget(
                      label: 'Provider',
                      labelPresent: true,
                      helper: '',
                      helperPresent: false,
                      leadingIcon: Icon(
                        Icons.person_outline_rounded,
                        color: theme.primaryText,
                        size: 24.0,
                      ),
                      leadingIconPresent: true,
                      trailingIconPresent: false,
                      hint: 'e.g. Dr. Chen',
                      value: '',
                      onChange: '',
                      onSubmit: '',
                      variant: 'outlined',
                      error: false,
                    ),
                  ),
                  SizedBox(height: 12.0),
                  wrapWithModel(
                    model: _model.textFieldLocationModel,
                    updateCallback: () => safeSetState(() {}),
                    child: TextFieldWidget(
                      label: 'Location',
                      labelPresent: true,
                      helper: '',
                      helperPresent: false,
                      leadingIcon: Icon(
                        Icons.place_outlined,
                        color: theme.primaryText,
                        size: 24.0,
                      ),
                      leadingIconPresent: true,
                      trailingIconPresent: false,
                      hint: 'e.g. Riverside Clinic',
                      value: '',
                      onChange: '',
                      onSubmit: '',
                      variant: 'outlined',
                      error: false,
                    ),
                  ),
                  SizedBox(height: 12.0),
                  wrapWithModel(
                    model: _model.textFieldReasonModel,
                    updateCallback: () => safeSetState(() {}),
                    child: TextFieldWidget(
                      label: 'Reason',
                      labelPresent: true,
                      helper: '',
                      helperPresent: false,
                      leadingIcon: Icon(
                        Icons.info_outline_rounded,
                        color: theme.primaryText,
                        size: 24.0,
                      ),
                      leadingIconPresent: true,
                      trailingIconPresent: false,
                      hint: 'e.g. Routine follow-up',
                      value: '',
                      onChange: '',
                      onSubmit: '',
                      variant: 'outlined',
                      error: false,
                    ),
                  ),
                  SizedBox(height: 12.0),
                  wrapWithModel(
                    model: _model.textFieldNotesModel,
                    updateCallback: () => safeSetState(() {}),
                    child: TextFieldWidget(
                      label: 'Notes',
                      labelPresent: true,
                      helper: '',
                      helperPresent: false,
                      leadingIcon: Icon(
                        Icons.notes_rounded,
                        color: theme.primaryText,
                        size: 24.0,
                      ),
                      leadingIconPresent: true,
                      trailingIconPresent: false,
                      hint: 'Anything to remember for this visit',
                      value: '',
                      onChange: '',
                      onSubmit: '',
                      variant: 'outlined',
                      error: false,
                    ),
                  ),
                  SizedBox(height: 12.0),
                  InkWell(
                    splashColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: () => safeSetState(
                        () => _followUpNeeded = !_followUpNeeded),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _followUpNeeded
                            ? theme.secondary15
                            : theme.secondaryBackground,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: _followUpNeeded
                              ? theme.secondary30
                              : theme.alternate,
                          width: 1.0,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            12.0, 12.0, 12.0, 12.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Follow-up needed',
                              style: theme.bodyMedium.override(
                                font: GoogleFonts.nunito(),
                                color: theme.primaryText,
                                letterSpacing: 0.0,
                              ),
                            ),
                            Icon(
                              _followUpNeeded
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              color: _followUpNeeded
                                  ? theme.primary
                                  : theme.secondaryText,
                              size: 24.0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_formError != null)
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0.0, 12.0, 0.0, 0.0),
                      child: Text(
                        _formError!,
                        style: theme.bodySmall.override(
                          font: GoogleFonts.nunito(),
                          color: theme.error,
                          letterSpacing: 0.0,
                        ),
                      ),
                    ),
                  SizedBox(height: 20.0),
                  wrapWithModel(
                    model: _model.buttonSaveModel,
                    updateCallback: () => safeSetState(() {}),
                    child: ButtonWidget(
                      iconPresent: false,
                      iconEndPresent: false,
                      content: _isEditing ? 'Save Changes' : 'Create Appointment',
                      variant: 'primary',
                      size: 'medium',
                      fullWidth: true,
                      loading: _saving,
                      disabled: _saveBlocked,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One tappable date/time row (the design has no picker component; this is
  /// the same row shape the report's custom-range sheet uses).
  Widget _pickerRow(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: theme.alternate, width: 1.0),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(12.0, 12.0, 12.0, 12.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: theme.primaryText, size: 24.0),
              SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.labelSmall.override(
                        font: GoogleFonts.nunito(),
                        color: theme.secondaryText,
                        letterSpacing: 0.0,
                      ),
                    ),
                    Text(
                      value,
                      style: theme.bodyMedium.override(
                        font: GoogleFonts.nunito(),
                        color: theme.primaryText,
                        letterSpacing: 0.0,
                      ),
                    ),
                  ].divide(SizedBox(height: 2.0)),
                ),
              ),
              if (onClear != null)
                InkWell(
                  onTap: onClear,
                  child: Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.close_rounded,
                      color: theme.secondaryText,
                      size: 20.0,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
