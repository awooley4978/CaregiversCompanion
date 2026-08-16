import '/components/switch_component/switch_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'settings_group_child2_widget.dart' show SettingsGroupChild2Widget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class SettingsGroupChild2Model
    extends FlutterFlowModel<SettingsGroupChild2Widget> {
  ///  State fields for stateful widgets in this component.

  // Model for Switch.
  late SwitchComponentModel switchModel1;
  // Model for Switch.
  late SwitchComponentModel switchModel2;

  @override
  void initState(BuildContext context) {
    switchModel1 = createModel(context, () => SwitchComponentModel());
    switchModel2 = createModel(context, () => SwitchComponentModel());
  }

  @override
  void dispose() {
    switchModel1.dispose();
    switchModel2.dispose();
  }
}
