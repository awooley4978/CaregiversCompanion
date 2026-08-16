import '/backend/backend.dart';
import '/components/button2_widget.dart';
import '/components/text_field2_widget.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import 'add_meal_widget.dart' show AddMealWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AddMealModel extends FlutterFlowModel<AddMealWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for Dropdown widget.
  String? dropdownValue;
  FormFieldController<String>? dropdownValueController;
  // Model for TextField.
  late TextField2Model textFieldModel1;
  // Model for TextField.
  late TextField2Model textFieldModel2;
  // Model for TextField.
  late TextField2Model textFieldModel3;
  // Model for Button.
  late Button2Model buttonModel;

  @override
  void initState(BuildContext context) {
    textFieldModel1 = createModel(context, () => TextField2Model());
    textFieldModel2 = createModel(context, () => TextField2Model());
    textFieldModel3 = createModel(context, () => TextField2Model());
    buttonModel = createModel(context, () => Button2Model());
  }

  @override
  void dispose() {
    textFieldModel1.dispose();
    textFieldModel2.dispose();
    textFieldModel3.dispose();
    buttonModel.dispose();
  }
}
