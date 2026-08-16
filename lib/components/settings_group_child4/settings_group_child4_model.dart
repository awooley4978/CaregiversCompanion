import '/components/settings_item/settings_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'settings_group_child4_widget.dart' show SettingsGroupChild4Widget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class SettingsGroupChild4Model
    extends FlutterFlowModel<SettingsGroupChild4Widget> {
  ///  State fields for stateful widgets in this component.

  // Model for SettingsItem.
  late SettingsItemModel settingsItemModel1;
  // Model for SettingsItem.
  late SettingsItemModel settingsItemModel2;

  @override
  void initState(BuildContext context) {
    settingsItemModel1 = createModel(context, () => SettingsItemModel());
    settingsItemModel2 = createModel(context, () => SettingsItemModel());
  }

  @override
  void dispose() {
    settingsItemModel1.dispose();
    settingsItemModel2.dispose();
  }
}
