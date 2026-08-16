import '/backend/backend.dart';
import '/components/button/button_widget.dart';
import '/components/condition_chip/condition_chip_widget.dart';
import '/components/module_toggle/module_toggle_widget.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'b_care_profile_setup_widget.dart' show BCareProfileSetupWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class BCareProfileSetupModel extends FlutterFlowModel<BCareProfileSetupWidget> {
  ///  Local state fields for this page.

  List<String> selectedConditions = [
    'Diabetes',
    'Hypertension',
    'Heart Failure',
    'Dementia',
    'Limited Mobility',
    'Fall Risk',
    'Wound Care'
  ];
  void addToSelectedConditions(String item) => selectedConditions.add(item);
  void removeFromSelectedConditions(String item) =>
      selectedConditions.remove(item);
  void removeAtIndexFromSelectedConditions(int index) =>
      selectedConditions.removeAt(index);
  void insertAtIndexInSelectedConditions(int index, String item) =>
      selectedConditions.insert(index, item);
  void updateSelectedConditionsAtIndex(int index, Function(String) updateFn) =>
      selectedConditions[index] = updateFn(selectedConditions[index]);

  ///  State fields for stateful widgets in this page.

  // Model for TextField-Name.
  late TextFieldModel textFieldNameModel;
  // Model for TextField-Primary.
  late TextFieldModel textFieldPrimaryModel;
  // Model for ConditionChip.
  late ConditionChipModel conditionChipModel1;
  // Model for ConditionChip.
  late ConditionChipModel conditionChipModel2;
  // Model for ConditionChip.
  late ConditionChipModel conditionChipModel3;
  // Model for ConditionChip.
  late ConditionChipModel conditionChipModel4;
  // Model for ConditionChip.
  late ConditionChipModel conditionChipModel5;
  // Model for ConditionChip.
  late ConditionChipModel conditionChipModel6;
  // Model for ConditionChip.
  late ConditionChipModel conditionChipModel7;
  // Model for TextField-AddCondition.
  late TextFieldModel textFieldAddConditionModel;
  // Model for ModuleToggle.
  late ModuleToggleModel moduleToggleModel1;
  // Model for ModuleToggle.
  late ModuleToggleModel moduleToggleModel2;
  // Model for ModuleToggle.
  late ModuleToggleModel moduleToggleModel3;
  // Model for ModuleToggle.
  late ModuleToggleModel moduleToggleModel4;
  // Model for ModuleToggle.
  late ModuleToggleModel moduleToggleModel5;
  // Model for TextField-PrimaryContact.
  late TextFieldModel textFieldPrimaryContactModel;
  // Model for TextFieldPrimaryPhone.
  late TextFieldModel textFieldPrimaryPhoneModel;
  // Model for TextField-Emergency.
  late TextFieldModel textFieldEmergencyModel;
  // Model for TextField-EmergencyPhone.
  late TextFieldModel textFieldEmergencyPhoneModel;
  // Model for Button.
  late ButtonModel buttonModel;

  @override
  void initState(BuildContext context) {
    textFieldNameModel = createModel(context, () => TextFieldModel());
    textFieldPrimaryModel = createModel(context, () => TextFieldModel());
    conditionChipModel1 = createModel(context, () => ConditionChipModel());
    conditionChipModel2 = createModel(context, () => ConditionChipModel());
    conditionChipModel3 = createModel(context, () => ConditionChipModel());
    conditionChipModel4 = createModel(context, () => ConditionChipModel());
    conditionChipModel5 = createModel(context, () => ConditionChipModel());
    conditionChipModel6 = createModel(context, () => ConditionChipModel());
    conditionChipModel7 = createModel(context, () => ConditionChipModel());
    textFieldAddConditionModel = createModel(context, () => TextFieldModel());
    moduleToggleModel1 = createModel(context, () => ModuleToggleModel());
    moduleToggleModel2 = createModel(context, () => ModuleToggleModel());
    moduleToggleModel3 = createModel(context, () => ModuleToggleModel());
    moduleToggleModel4 = createModel(context, () => ModuleToggleModel());
    moduleToggleModel5 = createModel(context, () => ModuleToggleModel());
    textFieldPrimaryContactModel = createModel(context, () => TextFieldModel());
    textFieldPrimaryPhoneModel = createModel(context, () => TextFieldModel());
    textFieldEmergencyModel = createModel(context, () => TextFieldModel());
    textFieldEmergencyPhoneModel = createModel(context, () => TextFieldModel());
    buttonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    textFieldNameModel.dispose();
    textFieldPrimaryModel.dispose();
    conditionChipModel1.dispose();
    conditionChipModel2.dispose();
    conditionChipModel3.dispose();
    conditionChipModel4.dispose();
    conditionChipModel5.dispose();
    conditionChipModel6.dispose();
    conditionChipModel7.dispose();
    textFieldAddConditionModel.dispose();
    moduleToggleModel1.dispose();
    moduleToggleModel2.dispose();
    moduleToggleModel3.dispose();
    moduleToggleModel4.dispose();
    moduleToggleModel5.dispose();
    textFieldPrimaryContactModel.dispose();
    textFieldPrimaryPhoneModel.dispose();
    textFieldEmergencyModel.dispose();
    textFieldEmergencyPhoneModel.dispose();
    buttonModel.dispose();
  }
}
