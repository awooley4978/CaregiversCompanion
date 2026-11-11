import '/backend/auth/auth_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'change_password_sheet_model.dart';
export 'change_password_sheet_model.dart';

/// Opens the Change Password sheet and reports the outcome on the page it was
/// opened from.
///
/// The sheet pops `true` only when Firebase actually changed the password, so
/// the "Password updated." confirmation can never appear after a failure.
Future<void> showChangePasswordSheet(BuildContext context) async {
  final changed = await showModalBottomSheet<bool>(
    isScrollControlled: true,
    backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
    context: context,
    builder: (context) {
      return GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Padding(
          padding: MediaQuery.viewInsetsOf(context),
          child: const ChangePasswordSheetWidget(),
        ),
      );
    },
  );
  if (changed == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password updated.')),
    );
  }
}

/// The Settings "Change Password" form.
///
/// This is a real password change with the existing Firebase Email/Password
/// authentication ([changePassword]): the caregiver enters their current
/// password, then the new one twice. Failures (wrong current password, weak
/// password, network) are shown inline and the sheet stays open; nothing is
/// reported as done unless Firebase accepted the new password.
class ChangePasswordSheetWidget extends StatefulWidget {
  const ChangePasswordSheetWidget({super.key});

  @override
  State<ChangePasswordSheetWidget> createState() =>
      _ChangePasswordSheetWidgetState();
}

class _ChangePasswordSheetWidgetState extends State<ChangePasswordSheetWidget> {
  late ChangePasswordSheetModel _model;

  /// The message shown under the fields; null while there is nothing to say.
  String? _error;

  /// True while Firebase is working, so the button cannot be pressed twice.
  bool _busy = false;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ChangePasswordSheetModel());

    _model.currentPasswordController ??= TextEditingController();
    _model.currentPasswordFocusNode ??= FocusNode();
    _model.newPasswordController ??= TextEditingController();
    _model.newPasswordFocusNode ??= FocusNode();
    _model.confirmPasswordController ??= TextEditingController();
    _model.confirmPasswordFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  /// Validates the form, then asks Firebase to change the password.
  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    final current = _model.currentPasswordController?.text ?? '';
    final next = _model.newPasswordController?.text ?? '';
    final confirm = _model.confirmPasswordController?.text ?? '';

    final validation = validateNewPassword(
      currentPassword: current,
      newPassword: next,
      confirmPassword: confirm,
    );
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final error = await changePassword(
      currentPassword: current,
      newPassword: next,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null) {
      Navigator.of(context).pop(true);
    }
  }

  Widget _passwordField(
    BuildContext context, {
    required String hint,
    required TextEditingController? controller,
    required FocusNode? focusNode,
    required void Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      autofocus: false,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: FlutterFlowTheme.of(context).bodyMedium.override(
              font: GoogleFonts.nunito(),
              color: FlutterFlowTheme.of(context).secondaryText,
            ),
        filled: true,
        fillColor: FlutterFlowTheme.of(context).secondaryBackground,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 12.0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24.0),
          borderSide: BorderSide(
            color: FlutterFlowTheme.of(context).alternate,
            width: 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24.0),
          borderSide: BorderSide(
            color: FlutterFlowTheme.of(context).alternate,
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24.0),
          borderSide: BorderSide(
            color: FlutterFlowTheme.of(context).primary,
            width: 1.0,
          ),
        ),
      ),
      style: FlutterFlowTheme.of(context).bodyMedium.override(
            font: GoogleFonts.nunito(),
            letterSpacing: 0.0,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.primaryBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 32.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Change password',
                style: theme.titleMedium.override(
                  font: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Enter your current password, then choose a new one. You stay '
                'signed in.',
                style: theme.bodySmall.override(
                  font: GoogleFonts.nunito(),
                  color: theme.secondaryText,
                  letterSpacing: 0.0,
                ),
              ),
              _passwordField(
                context,
                hint: 'Current password',
                controller: _model.currentPasswordController,
                focusNode: _model.currentPasswordFocusNode,
                onChanged: (_) => setState(() => _error = null),
              ),
              _passwordField(
                context,
                hint: 'New password (at least $minNewPasswordLength characters)',
                controller: _model.newPasswordController,
                focusNode: _model.newPasswordFocusNode,
                onChanged: (_) => setState(() => _error = null),
              ),
              _passwordField(
                context,
                hint: 'Confirm new password',
                controller: _model.confirmPasswordController,
                focusNode: _model.confirmPasswordFocusNode,
                onChanged: (_) => setState(() => _error = null),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: theme.bodySmall.override(
                    font: GoogleFonts.nunito(),
                    color: theme.error,
                    letterSpacing: 0.0,
                  ),
                ),
              FFButtonWidget(
                onPressed: () async {
                  await _submit();
                },
                text: _busy ? 'Updating...' : 'Update Password',
                options: FFButtonOptions(
                  height: 40.0,
                  padding: EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
                  iconPadding:
                      EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                  color: theme.primary,
                  textStyle: theme.titleSmall.override(
                    font: GoogleFonts.dmSans(
                      fontWeight: theme.titleSmall.fontWeight,
                      fontStyle: theme.titleSmall.fontStyle,
                    ),
                    color: theme.onPrimary,
                    letterSpacing: 0.0,
                    fontWeight: theme.titleSmall.fontWeight,
                    fontStyle: theme.titleSmall.fontStyle,
                  ),
                  elevation: 0.0,
                  borderSide: BorderSide(
                    color: Colors.transparent,
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(24.0),
                ),
              ),
            ].divide(SizedBox(height: 12.0)),
          ),
        ),
      ),
    );
  }
}
