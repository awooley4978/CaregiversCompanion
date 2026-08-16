import '/components/button/button_widget.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/components/question_card/question_card_widget.dart';
import '/components/symptom_log/symptom_log_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'g_doctor_visit_prep_widget.dart' show GDoctorVisitPrepWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class GDoctorVisitPrepModel extends FlutterFlowModel<GDoctorVisitPrepWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for Button.
  late ButtonModel buttonModel1;
  // Model for Button.
  late ButtonModel buttonModel2;
  // Model for QuestionCard.
  late QuestionCardModel questionCardModel1;
  // Model for QuestionCard.
  late QuestionCardModel questionCardModel2;
  // Model for QuestionCard.
  late QuestionCardModel questionCardModel3;
  // Model for SymptomLog.
  late SymptomLogModel symptomLogModel1;
  // Model for SymptomLog.
  late SymptomLogModel symptomLogModel2;
  // Model for SymptomLog.
  late SymptomLogModel symptomLogModel3;
  // Model for Button.
  late ButtonModel buttonModel3;

  @override
  void initState(BuildContext context) {
    buttonModel1 = createModel(context, () => ButtonModel());
    buttonModel2 = createModel(context, () => ButtonModel());
    questionCardModel1 = createModel(context, () => QuestionCardModel());
    questionCardModel2 = createModel(context, () => QuestionCardModel());
    questionCardModel3 = createModel(context, () => QuestionCardModel());
    symptomLogModel1 = createModel(context, () => SymptomLogModel());
    symptomLogModel2 = createModel(context, () => SymptomLogModel());
    symptomLogModel3 = createModel(context, () => SymptomLogModel());
    buttonModel3 = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    buttonModel1.dispose();
    buttonModel2.dispose();
    questionCardModel1.dispose();
    questionCardModel2.dispose();
    questionCardModel3.dispose();
    symptomLogModel1.dispose();
    symptomLogModel2.dispose();
    symptomLogModel3.dispose();
    buttonModel3.dispose();
  }
}
