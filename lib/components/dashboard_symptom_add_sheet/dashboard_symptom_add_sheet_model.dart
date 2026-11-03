import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'dashboard_symptom_add_sheet_widget.dart'
    show DashboardSymptomAddSheetWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class DashboardSymptomAddSheetModel
    extends FlutterFlowModel<DashboardSymptomAddSheetWidget> {
  ///  Local state fields for this component.

  TextEditingController? symptomNameController;
  FocusNode? symptomNameFocusNode;

  TextEditingController? symptomNoteController;
  FocusNode? symptomNoteFocusNode;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    symptomNameController?.dispose();
    symptomNameFocusNode?.dispose();

    symptomNoteController?.dispose();
    symptomNoteFocusNode?.dispose();
  }
}
