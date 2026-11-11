import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'doctor_report_range_sheet_widget.dart'
    show DoctorReportRangeSheetWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class DoctorReportRangeSheetModel
    extends FlutterFlowModel<DoctorReportRangeSheetWidget> {
  ///  State fields for stateful widgets in this component.

  // Model for Button.
  late ButtonModel buttonModel;

  @override
  void initState(BuildContext context) {
    buttonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    buttonModel.dispose();
  }
}
