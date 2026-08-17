import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'login_widget.dart' show AuthLoginWidget;

class AuthLoginModel extends FlutterFlowModel<AuthLoginWidget> {
  ///  State fields for stateful widgets in this page.

  final formKey = GlobalKey<FormState>();

  ///  State fields for the email / password fields.
  late final TextEditingController emailTextController;
  final emailFocusNode = FocusNode();

  late final TextEditingController passwordTextController;
  final passwordFocusNode = FocusNode();

  /// While a sign-in attempt is in flight the submit buttons are disabled.
  bool submitting = false;

  /// Inline auth error shown above the buttons (wrong password, unknown
  /// email, network failure, Google provider disabled, ...).
  String? errorText;

  @override
  void initState(BuildContext context) {
    emailTextController = TextEditingController();
    passwordTextController = TextEditingController();
  }

  @override
  void dispose() {
    emailTextController.dispose();
    emailFocusNode.dispose();
    passwordTextController.dispose();
    passwordFocusNode.dispose();
  }
}
