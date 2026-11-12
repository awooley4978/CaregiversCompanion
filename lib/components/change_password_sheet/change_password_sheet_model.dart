import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'change_password_sheet_widget.dart' show ChangePasswordSheetWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ChangePasswordSheetModel
    extends FlutterFlowModel<ChangePasswordSheetWidget> {
  ///  State fields for stateful widgets in this component.

  FocusNode? currentPasswordFocusNode;
  TextEditingController? currentPasswordController;
  FocusNode? newPasswordFocusNode;
  TextEditingController? newPasswordController;
  FocusNode? confirmPasswordFocusNode;
  TextEditingController? confirmPasswordController;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    currentPasswordFocusNode?.dispose();
    currentPasswordController?.dispose();
    newPasswordFocusNode?.dispose();
    newPasswordController?.dispose();
    confirmPasswordFocusNode?.dispose();
    confirmPasswordController?.dispose();
  }
}
