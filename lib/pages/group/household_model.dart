import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'household_widget.dart' show HouseholdWidget;

/// Model for the Household (Care Circle group) page — security phase 2.
class HouseholdModel extends FlutterFlowModel<HouseholdWidget> {
  ///  State fields for stateful widgets in this page.

  /// Email input for the owner/admin invite form.
  late final TextEditingController inviteEmailController;
  final inviteEmailFocusNode = FocusNode();

  /// Role selected in the invite form (defaults to caregiver — the Care
  /// Circle role most members get; admin is model-level and not prominent).
  String inviteRole = 'caregiver';

  /// True while an invite submit is in flight (disables the button).
  bool inviting = false;

  @override
  void initState(BuildContext context) {
    inviteEmailController = TextEditingController();
  }

  @override
  void dispose() {
    inviteEmailController.dispose();
    inviteEmailFocusNode.dispose();
  }
}
