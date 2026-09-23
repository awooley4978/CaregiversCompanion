import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'condition_chip_widget.dart' show ConditionChipWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ConditionChipModel extends FlutterFlowModel<ConditionChipWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for the chip's selection. Seeded from the widget's `selected`
  // parameter in the widget's initState and toggled on tap, exactly like
  // SwitchComponentModel.switchValue — so the Add Care Profile page can read the
  // selection back when it saves the care profile.
  bool? selectedValue;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
