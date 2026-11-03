import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dashboard_task_add_sheet_widget.dart'
    show DashboardTaskAddSheetWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class DashboardTaskAddSheetModel
    extends FlutterFlowModel<DashboardTaskAddSheetWidget> {
  ///  State fields for stateful widgets in this component.

  FocusNode? taskTitleFocusNode;
  TextEditingController? taskTitleController;
  FocusNode? taskSubtitleFocusNode;
  TextEditingController? taskSubtitleController;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    taskTitleFocusNode?.dispose();
    taskTitleController?.dispose();
    taskSubtitleFocusNode?.dispose();
    taskSubtitleController?.dispose();
  }
}
