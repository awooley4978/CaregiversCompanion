import '/components/button/button_widget.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/components/settings_group/settings_group_widget.dart';
import '/components/settings_group_child/settings_group_child_widget.dart';
import '/components/settings_group_child2/settings_group_child2_widget.dart';
import '/components/settings_group_child3/settings_group_child3_widget.dart';
import '/components/settings_group_child4/settings_group_child4_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'settings_account_widget.dart' show SettingsAccountWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class SettingsAccountModel extends FlutterFlowModel<SettingsAccountWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for SettingsGroup.
  late SettingsGroupModel settingsGroupModel1;
  // Model for SettingsGroup.
  late SettingsGroupModel settingsGroupModel2;
  // Model for SettingsGroup.
  late SettingsGroupModel settingsGroupModel3;
  // Model for SettingsGroup.
  late SettingsGroupModel settingsGroupModel4;
  // Model for Button.
  late ButtonModel buttonModel;

  @override
  void initState(BuildContext context) {
    settingsGroupModel1 = createModel(context, () => SettingsGroupModel());
    settingsGroupModel2 = createModel(context, () => SettingsGroupModel());
    settingsGroupModel3 = createModel(context, () => SettingsGroupModel());
    settingsGroupModel4 = createModel(context, () => SettingsGroupModel());
    buttonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    settingsGroupModel1.dispose();
    settingsGroupModel2.dispose();
    settingsGroupModel3.dispose();
    settingsGroupModel4.dispose();
    buttonModel.dispose();
  }
}
