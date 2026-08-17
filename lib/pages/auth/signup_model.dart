import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'signup_widget.dart' show AuthSignupWidget;

class AuthSignupModel extends FlutterFlowModel<AuthSignupWidget> {
  ///  State fields for stateful widgets in this page.

  final formKey = GlobalKey<FormState>();

  ///  State fields for the name / email / password / confirm fields.
  late final TextEditingController nameTextController;
  final nameFocusNode = FocusNode();

  late final TextEditingController emailTextController;
  final emailFocusNode = FocusNode();

  late final TextEditingController passwordTextController;
  final passwordFocusNode = FocusNode();

  late final TextEditingController confirmPasswordTextController;
  final confirmPasswordFocusNode = FocusNode();

  /// While account creation is in flight the submit button is disabled.
  bool submitting = false;

  /// Inline auth error (email already in use, weak password, network, ...).
  String? errorText;

  @override
  void initState(BuildContext context) {
    nameTextController = TextEditingController();
    emailTextController = TextEditingController();
    passwordTextController = TextEditingController();
    confirmPasswordTextController = TextEditingController();
  }

  @override
  void dispose() {
    nameTextController.dispose();
    nameFocusNode.dispose();
    emailTextController.dispose();
    emailFocusNode.dispose();
    passwordTextController.dispose();
    passwordFocusNode.dispose();
    confirmPasswordTextController.dispose();
    confirmPasswordFocusNode.dispose();
  }
}
