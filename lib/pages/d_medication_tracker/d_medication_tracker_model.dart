import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'd_medication_tracker_widget.dart' show DMedicationTrackerWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';

class DMedicationTrackerModel
    extends FlutterFlowModel<DMedicationTrackerWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for Button (the "Add Medication" control). Med cards and refill
  // items are rendered directly from the streamed `medications` records and
  // manage their own per-card state, so they no longer need page-level models.
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
