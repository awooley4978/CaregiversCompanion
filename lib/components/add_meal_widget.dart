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
import 'add_meal_model.dart';
export 'add_meal_model.dart';

/// Im creating an add meal form.
///
/// I need a clean look. A dropdown that lists breakfast lunch dinner snack. A
/// text box to fill in meal name, a text box for amount eaten, a text box for
/// caregiver notes and a save button
class AddMealWidget extends StatefulWidget {
  const AddMealWidget({
    super.key,
    String? mealType,
    String? mealName,
    String? amount,
    String? notes,
  })  : this.mealType = mealType ?? '',
        this.mealName = mealName ?? '',
        this.amount = amount ?? '',
        this.notes = notes ?? '';

  final String mealType;
  final String mealName;
  final String amount;
  final String notes;

  @override
  State<AddMealWidget> createState() => _AddMealWidgetState();
}

class _AddMealWidgetState extends State<AddMealWidget> {
  late AddMealModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AddMealModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
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
                'Add Meal',
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
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Meal Type',
                        style: FlutterFlowTheme.of(context)
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
                              color: FlutterFlowTheme.of(context).secondaryText,
                              letterSpacing: 0.0,
                              fontWeight: FlutterFlowTheme.of(context)
                                  .labelMedium
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .labelMedium
                                  .fontStyle,
                              lineHeight: 1.4,
                            ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            8.0, 16.0, 8.0, 16.0),
                        child: FlutterFlowDropDown<String>(
                          controller: _model.dropdownValueController ??=
                              FormFieldController<String>(
                            _model.dropdownValue ??= widget!.mealType,
                          ),
                          options: ['Breakfast', 'Lunch', 'Dinner', 'Snack'],
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
                          hintText: 'Breakfast',
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
                    ].divide(SizedBox(height: 4.0)),
                  ),
                  wrapWithModel(
                    model: _model.textFieldModel1,
                    updateCallback: () => safeSetState(() {}),
                    child: TextField2Widget(
                      label: 'Meal Name',
                      labelPresent: true,
                      helper: '',
                      helperPresent: false,
                      leadingIconPresent: false,
                      trailingIconPresent: false,
                      hint: 'e.g. Scrambled Eggs',
                      value: widget!.mealName,
                      onChange: '',
                      onSubmit: '',
                      variant: 'outlined',
                      error: false,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 1,
                        child: wrapWithModel(
                          model: _model.textFieldModel2,
                          updateCallback: () => safeSetState(() {}),
                          child: TextField2Widget(
                            label: 'Amount Eaten',
                            labelPresent: true,
                            helper: '',
                            helperPresent: false,
                            leadingIconPresent: false,
                            trailingIconPresent: false,
                            hint: 'e.g. 1/2 cup',
                            value: widget!.amount,
                            onChange: '',
                            onSubmit: '',
                            variant: 'outlined',
                            error: false,
                          ),
                        ),
                      ),
                      Container(
                        width: 48.0,
                        height: 48.0,
                        decoration: BoxDecoration(
                          color: Color(0x1A8DA9C4),
                          borderRadius: BorderRadius.circular(12.0),
                          shape: BoxShape.rectangle,
                        ),
                        alignment: AlignmentDirectional(0.0, 0.0),
                        child: Icon(
                          Icons.restaurant_rounded,
                          color: FlutterFlowTheme.of(context).secondary,
                          size: 20.0,
                        ),
                      ),
                    ].divide(SizedBox(width: 16.0)),
                  ),
                  wrapWithModel(
                    model: _model.textFieldModel3,
                    updateCallback: () => safeSetState(() {}),
                    child: TextField2Widget(
                      label: 'Caregiver Notes',
                      labelPresent: true,
                      helper: '',
                      helperPresent: false,
                      leadingIconPresent: false,
                      trailingIconPresent: false,
                      hint: 'Any specific observations...',
                      value: widget!.notes,
                      onChange: '',
                      onSubmit: '',
                      variant: 'outlined',
                      error: false,
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
                  // §5.2 item 5: never write a null patientRef — gate on a
                  // valid selection (the Phase-4 create rule requires the ref
                  // to be a real, accessible recipient).
                  final selected = FFAppState().selectedCareRecipient;
                  if (selected == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Select a care recipient to save this meal.'),
                      ),
                    );
                    return;
                  }
                  await MealEntriesRecord.collection.doc().set({
                    ...createMealEntriesRecordData(
                      patientRef: selected,
                      mealType: widget!.mealType,
                      mealName: widget!.mealName,
                      amountEaten: widget!.amount,
                      caregiveNote: widget!.notes,
                    ),
                    ...mapToFirestore(
                      {
                        'createdAt': FieldValue.serverTimestamp(),
                      },
                    ),
                  });
                },
                child: wrapWithModel(
                  model: _model.buttonModel,
                  updateCallback: () => safeSetState(() {}),
                  child: Button2Widget(
                    icon: Icon(
                      Icons.check_rounded,
                      color: FlutterFlowTheme.of(context).primaryText,
                      size: 24.0,
                    ),
                    iconPresent: true,
                    iconEndPresent: false,
                    content: 'Save Meal',
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
