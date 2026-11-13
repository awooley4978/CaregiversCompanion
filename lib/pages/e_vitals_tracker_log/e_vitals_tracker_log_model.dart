import '/components/button/button_widget.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'e_vitals_tracker_log_widget.dart' show EVitalsTrackerLogWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class EVitalsTrackerLogModel extends FlutterFlowModel<EVitalsTrackerLogWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for the systolic input.
  late TextFieldModel systolicModel;
  // State field(s) for the diastolic input.
  late TextFieldModel diastolicModel;
  // State field(s) for the heart rate input.
  late TextFieldModel heartRateModel;
  // State field(s) for the blood glucose input.
  late TextFieldModel bloodGlucoseModel;
  // State field(s) for the oxygen saturation input.
  late TextFieldModel oxygenSaturationModel;
  // State field(s) for the temperature input.
  late TextFieldModel temperatureModel;
  // State field(s) for the weight input.
  late TextFieldModel weightModel;
  // State field(s) for the pain level input.
  late TextFieldModel painLevelModel;
  // State field(s) for the additional observations input.
  late TextFieldModel notesModel;
  // Model for Button.
  late ButtonModel buttonModel1;

  @override
  void initState(BuildContext context) {
    systolicModel = createModel(context, () => TextFieldModel());
    diastolicModel = createModel(context, () => TextFieldModel());
    heartRateModel = createModel(context, () => TextFieldModel());
    bloodGlucoseModel = createModel(context, () => TextFieldModel());
    oxygenSaturationModel = createModel(context, () => TextFieldModel());
    temperatureModel = createModel(context, () => TextFieldModel());
    weightModel = createModel(context, () => TextFieldModel());
    painLevelModel = createModel(context, () => TextFieldModel());
    notesModel = createModel(context, () => TextFieldModel());
    buttonModel1 = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    systolicModel.dispose();
    diastolicModel.dispose();
    heartRateModel.dispose();
    bloodGlucoseModel.dispose();
    oxygenSaturationModel.dispose();
    temperatureModel.dispose();
    weightModel.dispose();
    painLevelModel.dispose();
    notesModel.dispose();
    buttonModel1.dispose();
  }
}
