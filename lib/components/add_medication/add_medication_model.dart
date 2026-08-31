import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'add_medication_widget.dart' show AddMedicationWidget;
import 'package:flutter/material.dart';
import '/components/button2_widget.dart';
import '/components/text_field2_widget.dart';

class AddMedicationModel extends FlutterFlowModel<AddMedicationWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for Time of Day dropdown.
  String? dropdownValue;
  FormFieldController<String>? dropdownValueController;
  // Model for TextField (medication name).
  late TextField2Model textFieldModel1;
  // Model for TextField (dose).
  late TextField2Model textFieldModel2;
  // Model for TextField (directions).
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
