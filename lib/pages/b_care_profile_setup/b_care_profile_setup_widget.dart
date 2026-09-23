import '/backend/backend.dart';
import '/backend/org/org_service.dart';
import '/components/button/button_widget.dart';
import '/components/condition_chip/condition_chip_widget.dart';
import '/components/module_toggle/module_toggle_widget.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'b_care_profile_setup_model.dart';
export 'b_care_profile_setup_model.dart';

/// The built-in condition chips on this page, in the order they are laid out in
/// the condition Wrap below. The chips are fed from this list, so the names the
/// page saves can never drift from the labels the caregiver sees.
const kCareProfileConditionChipLabels = <String>[
  'Diabetes',
  'Hypertension',
  'Heart Failure',
  'Dementia',
  'Limited Mobility',
  'Fall Risk',
  'Wound Care',
];

/// Collects the conditions to save for a care profile: every selected built-in
/// chip, plus the free-text 'Other / Add Your Own' entry when the caregiver
/// typed one (owner-approved 2026-09-23 — the chips used to be static
/// decoration, and nothing the caregiver picked was written to the recipient's
/// Conditions field).
///
/// Each chip's selection is read off that chip's own widget model, the same
/// pattern the Tracking Modules use via `switchModel.switchValue`, so the page
/// keeps no second copy of the selection state. Top-level so its contract can
/// be pinned in a test without rendering the whole page.
List<String> careProfileConditionsToSave(
  List<ConditionChipModel> chipModels, {
  String? otherCondition,
}) {
  assert(
    chipModels.length == kCareProfileConditionChipLabels.length,
    'one ConditionChipModel per built-in condition chip',
  );

  final conditions = <String>[
    for (var i = 0; i < chipModels.length; i++)
      if (valueOrDefault<bool>(chipModels[i].selectedValue, false))
        kCareProfileConditionChipLabels[i],
  ];

  // 'Other / Add Your Own': a typed condition is saved too, once, without
  // dropping the built-in chip that already covers it.
  final other = otherCondition?.trim() ?? '';
  if (other.isNotEmpty && !conditions.contains(other)) {
    conditions.add(other);
  }

  return conditions;
}

class BCareProfileSetupWidget extends StatefulWidget {
  const BCareProfileSetupWidget({super.key});

  static String routeName = 'BCareProfileSetup';
  static String routePath = '/bCareProfileSetup';

  @override
  State<BCareProfileSetupWidget> createState() =>
      _BCareProfileSetupWidgetState();
}

class _BCareProfileSetupWidgetState extends State<BCareProfileSetupWidget> {
  late BCareProfileSetupModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => BCareProfileSetupModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
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
        body: Stack(
          children: [
            Align(
              alignment: AlignmentDirectional(0.0, 0.0),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 50.0, 0.0, 0.0),
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(10.0),
                            bottomRight: Radius.circular(10.0),
                          ),
                          shape: BoxShape.rectangle,
                        ),
                        alignment: AlignmentDirectional(0.0, 0.0),
                      ),
                      Container(
                        width: 100.0,
                        height: 117.43,
                        decoration: BoxDecoration(
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                FlutterFlowTheme.of(context).primaryBackground,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(10.0),
                              bottomRight: Radius.circular(10.0),
                            ),
                            shape: BoxShape.rectangle,
                          ),
                          alignment: AlignmentDirectional(-1.0, 0.0),
                          child: Stack(
                            children: [
                              Align(
                                alignment: AlignmentDirectional(1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          24.0, 32.0, 24.0, 32.0),
                                      child: Container(
                                        child: Align(
                                          alignment:
                                              AlignmentDirectional(-1.0, 0.0),
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
                                                  Align(
                                                    alignment:
                                                        AlignmentDirectional(
                                                            1.0, -1.0),
                                                    child: Padding(
                                                      padding:
                                                          EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  20.0,
                                                                  0.0,
                                                                  0.0,
                                                                  0.0),
                                                      child:
                                                          FlutterFlowIconButton(
                                                        borderRadius: 28.0,
                                                        buttonSize: 40.0,
                                                        fillColor: FlutterFlowTheme
                                                                .of(context)
                                                            .secondaryBackground,
                                                        icon: Icon(
                                                          Icons.menu,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          size: 24.0,
                                                        ),
                                                        onPressed: () async {
                                                          await showModalBottomSheet(
                                                            isScrollControlled:
                                                                true,
                                                            backgroundColor:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryBackground,
                                                            enableDrag: false,
                                                            context: context,
                                                            builder: (context) {
                                                              return GestureDetector(
                                                                onTap: () {
                                                                  FocusScope.of(
                                                                          context)
                                                                      .unfocus();
                                                                  FocusManager
                                                                      .instance
                                                                      .primaryFocus
                                                                      ?.unfocus();
                                                                },
                                                                child: Padding(
                                                                  padding: MediaQuery
                                                                      .viewInsetsOf(
                                                                          context),
                                                                  child:
                                                                      NavMenuDirectoryWidget(),
                                                                ),
                                                              );
                                                            },
                                                          ).then((value) =>
                                                              safeSetState(
                                                                  () {}));
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: <Widget>[].divide(
                                                    SizedBox(height: 4.0)),
                                              ),
                                            ].divide(SizedBox(height: 1.0)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Align(
                                alignment: AlignmentDirectional(-1.0, 0.0),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      30.0, 0.0, 7.0, 0.0),
                                  child: Text(
                                    'Care Profile Setup',
                                    textAlign: TextAlign.start,
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
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Client Information',
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
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                        lineHeight: 1.45,
                                      ),
                                ),
                                wrapWithModel(
                                  model: _model.textFieldNameModel,
                                  updateCallback: () => safeSetState(() {}),
                                  child: TextFieldWidget(
                                    label: 'Full Name',
                                    labelPresent: true,
                                    helper: '',
                                    helperPresent: false,
                                    leadingIcon: Icon(
                                      Icons.person_outline_rounded,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      size: 24.0,
                                    ),
                                    leadingIconPresent: true,
                                    trailingIconPresent: false,
                                    hint: 'e.g. Margaret Smith',
                                    value: '',
                                    onChange: '',
                                    onSubmit: '',
                                    variant: 'outlined',
                                    error: false,
                                  ),
                                ),
                                wrapWithModel(
                                  model: _model.textFieldPrimaryModel,
                                  updateCallback: () => safeSetState(() {}),
                                  child: TextFieldWidget(
                                    label: 'Primary Condition',
                                    labelPresent: true,
                                    helper: '',
                                    helperPresent: false,
                                    leadingIcon: Icon(
                                      Icons.medical_services_outlined,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      size: 24.0,
                                    ),
                                    leadingIconPresent: true,
                                    trailingIconPresent: false,
                                    hint: 'e.g. Stroke Recovery',
                                    value: '',
                                    onChange: '',
                                    onSubmit: '',
                                    variant: 'outlined',
                                    error: false,
                                  ),
                                ),
                              ].divide(SizedBox(height: 16.0)),
                            ),
                            Column(
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
                                      'Care Conditions',
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
                                            lineHeight: 1.45,
                                          ),
                                    ),
                                    Text(
                                      'Select All That Apply',
                                      style: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .override(
                                            font: GoogleFonts.nunito(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelSmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelSmall
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .onBackground,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelSmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelSmall
                                                    .fontStyle,
                                            lineHeight: 1.3,
                                          ),
                                    ),
                                  ],
                                ),
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 8.0,
                                  alignment: WrapAlignment.start,
                                  crossAxisAlignment: WrapCrossAlignment.start,
                                  direction: Axis.horizontal,
                                  runAlignment: WrapAlignment.start,
                                  verticalDirection: VerticalDirection.down,
                                  clipBehavior: Clip.none,
                                  children: [
                                    wrapWithModel(
                                      model: _model.conditionChipModel1,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ConditionChipWidget(
                                        label:
                                            kCareProfileConditionChipLabels[0],
                                        selected: true,
                                      ),
                                    ),
                                    wrapWithModel(
                                      model: _model.conditionChipModel2,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ConditionChipWidget(
                                        label:
                                            kCareProfileConditionChipLabels[1],
                                        selected: true,
                                      ),
                                    ),
                                    wrapWithModel(
                                      model: _model.conditionChipModel3,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ConditionChipWidget(
                                        label:
                                            kCareProfileConditionChipLabels[2],
                                        selected: false,
                                      ),
                                    ),
                                    wrapWithModel(
                                      model: _model.conditionChipModel4,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ConditionChipWidget(
                                        label:
                                            kCareProfileConditionChipLabels[3],
                                        selected: false,
                                      ),
                                    ),
                                    wrapWithModel(
                                      model: _model.conditionChipModel5,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ConditionChipWidget(
                                        label:
                                            kCareProfileConditionChipLabels[4],
                                        selected: true,
                                      ),
                                    ),
                                    wrapWithModel(
                                      model: _model.conditionChipModel6,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ConditionChipWidget(
                                        label:
                                            kCareProfileConditionChipLabels[5],
                                        selected: true,
                                      ),
                                    ),
                                    wrapWithModel(
                                      model: _model.conditionChipModel7,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ConditionChipWidget(
                                        label:
                                            kCareProfileConditionChipLabels[6],
                                        selected: false,
                                      ),
                                    ),
                                  ],
                                ),
                                wrapWithModel(
                                  model: _model.textFieldAddConditionModel,
                                  updateCallback: () => safeSetState(() {}),
                                  child: TextFieldWidget(
                                    label: 'Other / Add Your Own',
                                    labelPresent: true,
                                    helper: '',
                                    helperPresent: false,
                                    leadingIconPresent: false,
                                    trailingIconPresent: false,
                                    hint: 'Type a condition...',
                                    value: '',
                                    onChange: '',
                                    onSubmit: '',
                                    variant: 'ghost',
                                    error: false,
                                  ),
                                ),
                              ].divide(SizedBox(height: 16.0)),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Tracking Modules',
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
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                        lineHeight: 1.45,
                                      ),
                                ),
                                wrapWithModel(
                                  model: _model.moduleToggleModel1,
                                  updateCallback: () => safeSetState(() {}),
                                  child: ModuleToggleWidget(
                                    icon: Icon(
                                      Icons.favorite_border_rounded,
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      size: 20.0,
                                    ),
                                    subtitle:
                                        'Blood pressure, heart rate, weight',
                                    title: 'Vitals Tracker',
                                    active: true,
                                  ),
                                ),
                                wrapWithModel(
                                  model: _model.moduleToggleModel2,
                                  updateCallback: () => safeSetState(() {}),
                                  child: ModuleToggleWidget(
                                    icon: Icon(
                                      Icons.water_drop_rounded,
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      size: 20.0,
                                    ),
                                    subtitle: 'Blood sugar & insulin logs',
                                    title: 'Glucose Tracker',
                                    active: true,
                                  ),
                                ),
                                wrapWithModel(
                                  model: _model.moduleToggleModel3,
                                  updateCallback: () => safeSetState(() {}),
                                  child: ModuleToggleWidget(
                                    icon: Icon(
                                      Icons.medication_outlined,
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      size: 20.0,
                                    ),
                                    subtitle: 'Schedules & refill reminders',
                                    title: 'Medication Tracker',
                                    active: true,
                                  ),
                                ),
                                wrapWithModel(
                                  model: _model.moduleToggleModel4,
                                  updateCallback: () => safeSetState(() {}),
                                  child: ModuleToggleWidget(
                                    icon: Icon(
                                      Icons.psychology_rounded,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      size: 20.0,
                                    ),
                                    subtitle: 'Falls, mood, pain, appetite',
                                    title: 'Symptoms Log',
                                    active: false,
                                  ),
                                ),
                                wrapWithModel(
                                  model: _model.moduleToggleModel5,
                                  updateCallback: () => safeSetState(() {}),
                                  child: ModuleToggleWidget(
                                    icon: Icon(
                                      Icons.restaurant_rounded,
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      size: 20.0,
                                    ),
                                    subtitle: 'Nutrition and fluid intake',
                                    title: 'Meals & Hydration',
                                    active: true,
                                  ),
                                ),
                              ].divide(SizedBox(height: 16.0)),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Primary Physician',
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
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                        lineHeight: 1.45,
                                      ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    borderRadius: BorderRadius.circular(28.0),
                                    shape: BoxShape.rectangle,
                                    border: Border.all(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Container(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          wrapWithModel(
                                            model: _model
                                                .textFieldPrimaryContactModel,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: TextFieldWidget(
                                              label: 'Primary Physician',
                                              labelPresent: true,
                                              helper: '',
                                              helperPresent: false,
                                              leadingIcon: Icon(
                                                Icons.local_hospital_outlined,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                size: 24.0,
                                              ),
                                              leadingIconPresent: true,
                                              trailingIconPresent: false,
                                              hint: 'Dr. Smith',
                                              value: '',
                                              onChange: '',
                                              onSubmit: '',
                                              variant: 'outlined',
                                              error: false,
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model
                                                .textFieldPrimaryPhoneModel,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: TextFieldWidget(
                                              label: 'Primary Physician Phone',
                                              labelPresent: true,
                                              helper: '',
                                              helperPresent: false,
                                              leadingIcon: Icon(
                                                Icons.phone_outlined,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                size: 24.0,
                                              ),
                                              leadingIconPresent: true,
                                              trailingIconPresent: false,
                                              hint: '555-555-0123',
                                              value: '',
                                              onChange: '',
                                              onSubmit: '',
                                              variant: 'outlined',
                                              error: false,
                                            ),
                                          ),
                                        ].divide(SizedBox(height: 16.0)),
                                      ),
                                    ),
                                  ),
                                ),
                              ].divide(SizedBox(height: 16.0)),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Emergency Contacts',
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
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                        lineHeight: 1.45,
                                      ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    borderRadius: BorderRadius.circular(28.0),
                                    shape: BoxShape.rectangle,
                                    border: Border.all(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Container(
                                      decoration: BoxDecoration(),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          wrapWithModel(
                                            model:
                                                _model.textFieldEmergencyModel,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: TextFieldWidget(
                                              label: 'Emergency Contact',
                                              labelPresent: true,
                                              helper: '',
                                              helperPresent: false,
                                              leadingIcon: Icon(
                                                Icons.local_hospital_outlined,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                size: 24.0,
                                              ),
                                              leadingIconPresent: true,
                                              trailingIconPresent: false,
                                              hint: 'Dr. Smith',
                                              value: '',
                                              onChange: '',
                                              onSubmit: '',
                                              variant: 'outlined',
                                              error: false,
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model
                                                .textFieldEmergencyPhoneModel,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: TextFieldWidget(
                                              label: 'Emergency Contact Phone',
                                              labelPresent: true,
                                              helper: '',
                                              helperPresent: false,
                                              leadingIcon: Icon(
                                                Icons.phone_outlined,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                size: 24.0,
                                              ),
                                              leadingIconPresent: true,
                                              trailingIconPresent: false,
                                              hint: '555-555-0123',
                                              value: '',
                                              onChange: '',
                                              onSubmit: '',
                                              variant: 'outlined',
                                              error: false,
                                            ),
                                          ),
                                        ].divide(SizedBox(height: 16.0)),
                                      ),
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
                                final user =
                                    FirebaseAuth.instance.currentUser;
                                if (user == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Sign in to save a care recipient.'),
                                    ),
                                  );
                                  return;
                                }
                                try {
                                  final createdRef =
                                      await createCareRecipientForActiveGroup(
                                    user: user,
                                    data: createCareRecipientsRecordData(
                                      name: _model.textFieldNameModel
                                          .inputTextController.text,
                                      conditions: careProfileConditionsToSave(
                                        [
                                          _model.conditionChipModel1,
                                          _model.conditionChipModel2,
                                          _model.conditionChipModel3,
                                          _model.conditionChipModel4,
                                          _model.conditionChipModel5,
                                          _model.conditionChipModel6,
                                          _model.conditionChipModel7,
                                        ],
                                        otherCondition: _model
                                            .textFieldAddConditionModel
                                            .inputTextController
                                            ?.text,
                                      ),
                                      primaryCondition: _model
                                          .textFieldPrimaryModel
                                          .inputTextController
                                          .text,
                                      primaryCarePhysicianName: _model
                                          .textFieldPrimaryContactModel
                                          .inputTextController
                                          .text,
                                      primaryCarePhysicianPhone: _model
                                          .textFieldPrimaryPhoneModel
                                          .inputTextController
                                          .text,
                                      emergencyContactName: _model
                                          .textFieldEmergencyModel
                                          .inputTextController
                                          .text,
                                      emergencyContactPhone: _model
                                          .textFieldEmergencyPhoneModel
                                          .inputTextController
                                          .text,
                                      trackVitals: _model.moduleToggleModel1
                                          .switchModel.switchValue,
                                      trackGlucose: _model.moduleToggleModel2
                                          .switchModel.switchValue,
                                      trackMedication: _model
                                          .moduleToggleModel3
                                          .switchModel
                                          .switchValue,
                                      trackSymptoms: _model.moduleToggleModel4
                                          .switchModel.switchValue,
                                      tracksMealsHydration: _model
                                          .moduleToggleModel5
                                          .switchModel
                                          .switchValue,
                                    ),
                                  );
                                  // Make this the active care card so the rest
                                  // of the app (dashboard, notes, etc.) shows
                                  // the profile we just saved.
                                  FFAppState().selectedCareRecipient =
                                      createdRef;
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Care Profile saved successfully.'),
                                      ),
                                    );
                                    // Navigate to the newly created
                                    // recipient's Daily Dashboard (same
                                    // destination/pattern as the nav menu's
                                    // "Daily Care" and the Client Directory
                                    // card tap). selectedCareRecipient was set
                                    // above so the dashboard opens for the new
                                    // recipient, not a stale one.
                                    context.pushNamed(
                                        CDailyDashboardWidget.routeName);
                                  }
                                } on OrgAccessDeniedException catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.message)),
                                  );
                                } on SaveStepException catch (e) {
                                  // A SaveStepException carries the exact step
                                  // label + Firestore code + message, so the
                                  // owner can read WHICH operation was denied
                                  // straight from the snackbar, no devtools.
                                  print(
                                    'CareProfileSetup: save failed (step $e)',
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Could not save at step ${e.step}: $e'),
                                    ),
                                  );
                                } catch (e) {
                                  // A failed save must never destroy the
                                  // entered form data: the text fields retain
                                  // their controllers, and we only surface a
                                  // clear message instead of wiping the form.
                                  // But the failure must NOT be silent: log the
                                  // real exception (Firestore code + message)
                                  // so a non-membership failure (permission-
                                  // denied, unavailable, invalid-argument, ...)
                                  // is diagnosable instead of opaque.
                                  print(
                                    'CareProfileSetup: save failed '
                                    '(non-membership): '
                                    '${e is FirebaseException ? '${e.code}: ${e.message}' : e.toString()}',
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Could not save: '
                                          '${e is FirebaseException ? e.code : e.runtimeType} — '
                                          '${e.toString().length > 80 ? e.toString().substring(0, 80) : e.toString()}'),
                                    ),
                                  );
                                }
                              },
                              child: wrapWithModel(
                                model: _model.buttonModel,
                                updateCallback: () => safeSetState(() {}),
                                child: ButtonWidget(
                                  iconPresent: false,
                                  iconEndPresent: false,
                                  content: 'Save Profile',
                                  variant: 'primary',
                                  size: 'small',
                                  fullWidth: false,
                                  loading: false,
                                  disabled: false,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context).info10,
                                borderRadius: BorderRadius.circular(20.0),
                                shape: BoxShape.rectangle,
                                border: Border.all(
                                  color: FlutterFlowTheme.of(context).info20,
                                  width: 1.0,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Container(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        color: FlutterFlowTheme.of(context)
                                            .onSurface,
                                        size: 20.0,
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          'This profile is for organizational purposes only and does not constitute medical advice.',
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
                                                        .onSurface,
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
                                      ),
                                    ].divide(SizedBox(width: 16.0)),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              height: 48.0,
                            ),
                          ].divide(SizedBox(height: 24.0)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
