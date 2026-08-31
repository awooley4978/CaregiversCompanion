import '/backend/backend.dart';
import '/components/button2_widget.dart';
import '/components/text_field2_widget.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'add_medication_model.dart';
export 'add_medication_model.dart';

/// Add Medication create form (Audit-fix Part1 Unit3).
///
/// Follows the repo's existing AddMealWidget modal pattern: a small bottom-sheet
/// form captured below the tracker's previously-inert "Add Medication" button.
/// On save it writes a `medications` doc scoped to the CURRENTLY-SELECTED care
/// recipient (careRecipientRef = selected recipient's DocumentReference — the
/// exact field the Phase-4 rules and the tracker's live stream gate on), so the
/// new med shows up in the tracker stream with no extra wiring.
///
/// Field -> MedicationsRecord mapping (matches lib/backend/schema/
/// medications_record.dart + how the tracker/med_card render):
///   * medicationName  <- "Medication Name" input
///   * dose            <- "Dose" input
///   * directions      <- "Directions" input
///   * timeOfDay       <- "Time of Day" dropdown (Morning/Afternoon)
///   * scheduledTime   <- today at 08:00 (Morning) / 14:00 (Afternoon); drives
///                        the tracker's Morning/Afternoon grouping and the
///                        'hh:mm a' label on the med card (see
///                        d_medication_tracker_widget.dart _isMorning + timeLabel).
///   * status='PENDING', taken=false, active=true, refillNeeded=false,
///     createdAt=server timestamp. (A brand-new med is never pre-marked Taken.)
class AddMedicationWidget extends StatefulWidget {
  const AddMedicationWidget({super.key});

  @override
  State<AddMedicationWidget> createState() => _AddMedicationWidgetState();
}

class _AddMedicationWidgetState extends State<AddMedicationWidget> {
  late AddMedicationModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AddMedicationModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  /// Reads a TextField2Widget controller as entered text, treating the
  /// FlutterFlow slot placeholder that the template seeds an empty field with
  /// (`SlotValue($meal_name)`) as empty. TextField2Widget's controller is
  /// initialized with `valueOrDefault(widget.value, 'SlotValue($meal_name)')`,
  /// and valueOrDefault falls back to that sentinel whenever the passed `value`
  /// is empty — so a genuinely-blank field yields the literal placeholder, not
  /// ''. Treating it as empty keeps a blank form from ever persisting the
  /// placeholder as a medication name/dose/directions.
  String _enteredText(TextEditingController? controller) {
    final text = (controller?.text ?? '').trim();
    if (text == 'SlotValue(\$meal_name)') {
      return '';
    }
    return text;
  }

  /// Saves the new medication to the `medications` collection for the selected
  /// care recipient. Mirrors AddMealWidget's save: gate on a valid selection
  /// (the Phase-4 create rule requires careRecipientRef to be a real, writable
  /// recipient), then write through the record's create-helper. A medication
  /// name is required — an unnamed med would render only as "Untitled".
  Future<void> _save(BuildContext context) async {
    final recipient = FFAppState().selectedCareRecipient;
    if (recipient == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Select a care recipient to add this medication.'),
          ),
        );
      }
      return;
    }

    final name = _enteredText(_model.textFieldModel1.inputTextController);
    if (name.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a medication name.'),
          ),
        );
      }
      return;
    }
    final dose = _enteredText(_model.textFieldModel2.inputTextController);
    final directions =
        _enteredText(_model.textFieldModel3.inputTextController);
    final timeOfDay = _model.dropdownValue ?? 'Morning';
    final now = DateTime.now();
    // Representative clock time for the chosen section so the tracker's
    // Morning/Afternoon grouping and the card's 'hh:mm a' label stay coherent.
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      timeOfDay == 'Afternoon' ? 14 : 8,
    );

    try {
      await MedicationsRecord.collection.doc().set({
        ...createMedicationsRecordData(
          careRecipientRef: recipient,
          medicationName: name,
          dose: dose.isEmpty ? null : dose,
          directions: directions.isEmpty ? null : directions,
          timeOfDay: timeOfDay,
          scheduledTime: scheduledTime,
          status: 'PENDING',
          active: true,
          refillNeeded: false,
          taken: false,
        ),
        ...mapToFirestore(
          {
            'createdAt': FieldValue.serverTimestamp(),
          },
        ),
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Could not add this medication. Please try again.'),
          ),
        );
      }
      return;
    }

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Medication added.')),
    );
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(28.0),
        shape: BoxShape.rectangle,
      ),
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Container(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Medication',
                style: FlutterFlowTheme.of(context).titleLarge.override(
                      font: GoogleFonts.dmSans(
                        fontWeight:
                            FlutterFlowTheme.of(context).titleLarge.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).titleLarge.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).primaryText,
                      letterSpacing: 0.0,
                      fontWeight:
                          FlutterFlowTheme.of(context).titleLarge.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleLarge.fontStyle,
                      lineHeight: 1.4,
                    ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  wrapWithModel(
                    model: _model.textFieldModel1,
                    updateCallback: () => safeSetState(() {}),
                    child: TextField2Widget(
                      label: 'Medication Name',
                      labelPresent: true,
                      helper: '',
                      helperPresent: false,
                      leadingIconPresent: false,
                      trailingIconPresent: false,
                      hint: 'e.g. Lisinopril',
                      value: '',
                      onChange: '',
                      onSubmit: '',
                      variant: 'outlined',
                      error: false,
                    ),
                  ),
                  wrapWithModel(
                    model: _model.textFieldModel2,
                    updateCallback: () => safeSetState(() {}),
                    child: TextField2Widget(
                      label: 'Dose',
                      labelPresent: true,
                      helper: '',
                      helperPresent: false,
                      leadingIconPresent: false,
                      trailingIconPresent: false,
                      hint: 'e.g. 10mg - 1 tablet',
                      value: '',
                      onChange: '',
                      onSubmit: '',
                      variant: 'outlined',
                      error: false,
                    ),
                  ),
                  wrapWithModel(
                    model: _model.textFieldModel3,
                    updateCallback: () => safeSetState(() {}),
                    child: TextField2Widget(
                      label: 'Directions',
                      labelPresent: true,
                      helper: '',
                      helperPresent: false,
                      leadingIconPresent: false,
                      trailingIconPresent: false,
                      hint: 'e.g. Take with food',
                      value: '',
                      onChange: '',
                      onSubmit: '',
                      variant: 'outlined',
                      error: false,
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional(0.0, 1.0),
                    child: Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          16.0, 0.0, 16.0, 0.0),
                      child: FlutterFlowDropDown<String>(
                        controller: _model.dropdownValueController ??=
                            FormFieldController<String>(
                          _model.dropdownValue ??= 'Morning',
                        ),
                        options: ['Morning', 'Afternoon'],
                        onChanged: (val) =>
                            safeSetState(() => _model.dropdownValue = val),
                        width: 200.0,
                        height: 40.0,
                        textStyle: FlutterFlowTheme.of(context)
                            .bodyMedium
                            .override(
                              font: GoogleFonts.nunito(
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                              color: FlutterFlowTheme.of(context).primaryText,
                              letterSpacing: 0.0,
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                              lineHeight: 1.4,
                            ),
                        hintText: 'Morning',
                        icon: Icon(
                          Icons.arrow_drop_down_rounded,
                          color: FlutterFlowTheme.of(context).secondaryText,
                          size: 24.0,
                        ),
                        fillColor:
                            FlutterFlowTheme.of(context).primaryBackground,
                        elevation: 2.0,
                        borderColor: FlutterFlowTheme.of(context).alternate,
                        borderWidth: 1.0,
                        borderRadius: 12.0,
                        margin: EdgeInsetsDirectional.fromSTEB(
                            16.0, 0.0, 16.0, 0.0),
                        hidesUnderline: true,
                        isOverButton: false,
                        isSearchable: false,
                        isMultiSelect: false,
                      ),
                    ),
                  ),
                ].divide(SizedBox(height: 16.0)),
              ),
              InkWell(
                splashColor: Colors.transparent,
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () async {
                  await _save(context);
                },
                child: wrapWithModel(
                  model: _model.buttonModel,
                  updateCallback: () => safeSetState(() {}),
                  child: Button2Widget(
                    icon: Icon(
                      Icons.medication_rounded,
                      color: FlutterFlowTheme.of(context).primaryText,
                      size: 24.0,
                    ),
                    iconPresent: true,
                    iconEndPresent: false,
                    content: 'Save Medication',
                    variant: 'primary',
                    size: 'large',
                    fullWidth: true,
                    loading: false,
                    disabled: false,
                  ),
                ),
              ),
            ].divide(SizedBox(height: 24.0)),
          ),
        ),
      ),
    );
  }
}
