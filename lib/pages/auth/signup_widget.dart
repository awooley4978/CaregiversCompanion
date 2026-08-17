import 'package:firebase_auth/firebase_auth.dart';
import '/backend/auth/auth_service.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'signup_model.dart';
export 'signup_model.dart';

/// Account creation (security phase 1): collects the caregiver's display name
/// plus email/password. On success the global router redirect in nav.dart
/// moves the user to `/` (client directory).
class AuthSignupWidget extends StatefulWidget {
  const AuthSignupWidget({super.key});

  static String routeName = 'AuthSignup';
  static String routePath = '/signup';

  @override
  State<AuthSignupWidget> createState() => _AuthSignupWidgetState();
}

class _AuthSignupWidgetState extends State<AuthSignupWidget> {
  late AuthSignupModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AuthSignupModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!(_model.formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _model.submitting = true;
      _model.errorText = null;
    });
    try {
      final name = _model.nameTextController.text.trim();
      final email = _model.emailTextController.text.trim();
      final password = _model.passwordTextController.text;
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;
      if (user != null) {
        // Attach the caregiver's display name to the auth user, then make sure
        // users/{uid} is provisioned with it. The auth-state listener fires on
        // account creation (before the name exists on the auth user), so the
        // name is supplied explicitly here — provisioning is idempotent.
        await user.updateProfile(displayName: name);
        await ensureUserProfile(user, displayName: name);
      }
      // Success: redirect takes over.
    } catch (e) {
      setState(() {
        _model.errorText = authErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _model.submitting = false;
        });
      }
    }
  }

  InputDecoration _fieldDecoration(BuildContext context, String label,
      String hint, Widget leadingIcon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: FlutterFlowTheme.of(context).bodySmall.override(
            font: GoogleFonts.nunito(),
            color: FlutterFlowTheme.of(context).secondaryText,
          ),
      hintStyle: FlutterFlowTheme.of(context).bodySmall.override(
            font: GoogleFonts.nunito(),
            color: FlutterFlowTheme.of(context).alternate,
          ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(16.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: FlutterFlowTheme.of(context).primary,
          width: 2.0,
        ),
        borderRadius: BorderRadius.circular(16.0),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: FlutterFlowTheme.of(context).error,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(16.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: FlutterFlowTheme.of(context).error,
          width: 2.0,
        ),
        borderRadius: BorderRadius.circular(16.0),
      ),
      prefixIcon: leadingIcon,
      filled: true,
      fillColor: FlutterFlowTheme.of(context).secondaryBackground,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsetsDirectional.fromSTEB(24.0, 24.0, 24.0, 32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420.0),
                child: Form(
                  key: _model.formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          FlutterFlowIconButton(
                            borderRadius: 28.0,
                            buttonSize: 40.0,
                            fillColor: Colors.transparent,
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              color: FlutterFlowTheme.of(context).secondaryText,
                              size: 24.0,
                            ),
                            onPressed: () async {
                              context.go(AuthLoginWidget.routePath);
                            },
                          ),
                          Text(
                            'Create Account',
                            style: FlutterFlowTheme.of(context)
                                .titleLarge
                                .override(
                                  font: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  color: FlutterFlowTheme.of(context)
                                      .primaryText,
                                  fontSize: 24.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.bold,
                                  lineHeight: 1.3,
                                ),
                          ),
                          const SizedBox(width: 40.0),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            0.0, 8.0, 0.0, 24.0),
                        child: Text(
                          "Set up your caregiver profile — it takes less than a minute.",
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                font: GoogleFonts.nunito(),
                                color: FlutterFlowTheme.of(context)
                                    .secondaryText,
                                letterSpacing: 0.0,
                                lineHeight: 1.5,
                              ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            0.0, 0.0, 0.0, 16.0),
                        child: TextFormField(
                          controller: _model.nameTextController,
                          focusNode: _model.nameFocusNode,
                          autofocus: false,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Enter your name.';
                            }
                            return null;
                          },
                          decoration: _fieldDecoration(
                            context,
                            'Your name',
                            'e.g. Margaret Smith',
                            Icon(
                              Icons.person_outline_rounded,
                              color: FlutterFlowTheme.of(context).secondaryText,
                              size: 20.0,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            0.0, 0.0, 0.0, 16.0),
                        child: TextFormField(
                          controller: _model.emailTextController,
                          focusNode: _model.emailFocusNode,
                          autofocus: false,
                          autocorrect: false,
                          enableSuggestions: false,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            final email = (value ?? '').trim();
                            if (email.isEmpty) {
                              return 'Enter your email address.';
                            }
                            if (!RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(email)) {
                              return 'Enter a valid email address.';
                            }
                            return null;
                          },
                          decoration: _fieldDecoration(
                            context,
                            'Email',
                            'you@example.com',
                            Icon(
                              Icons.mail_outline_rounded,
                              color: FlutterFlowTheme.of(context).secondaryText,
                              size: 20.0,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            0.0, 0.0, 0.0, 16.0),
                        child: TextFormField(
                          controller: _model.passwordTextController,
                          focusNode: _model.passwordFocusNode,
                          autofocus: false,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if ((value ?? '').isEmpty) {
                              return 'Create a password.';
                            }
                            if ((value ?? '').length < 6) {
                              return 'Use at least 6 characters.';
                            }
                            return null;
                          },
                          decoration: _fieldDecoration(
                            context,
                            'Password',
                            'At least 6 characters',
                            Icon(
                              Icons.lock_outline_rounded,
                              color: FlutterFlowTheme.of(context).secondaryText,
                              size: 20.0,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            0.0, 0.0, 0.0, 8.0),
                        child: TextFormField(
                          controller: _model.confirmPasswordTextController,
                          focusNode: _model.confirmPasswordFocusNode,
                          autofocus: false,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          validator: (value) {
                            if ((value ?? '').isEmpty) {
                              return 'Confirm your password.';
                            }
                            if (value !=
                                _model.passwordTextController.text) {
                              return 'Passwords do not match.';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _createAccount(),
                          decoration: _fieldDecoration(
                            context,
                            'Confirm password',
                            'Re-enter your password',
                            Icon(
                              Icons.lock_outline_rounded,
                              color: FlutterFlowTheme.of(context).secondaryText,
                              size: 20.0,
                            ),
                          ),
                        ),
                      ),
                      if (_model.errorText != null)
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              0.0, 8.0, 0.0, 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: FlutterFlowTheme.of(context).error,
                                size: 18.0,
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: Text(
                                  _model.errorText!,
                                  style: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .override(
                                        font: GoogleFonts.nunito(),
                                        color:
                                            FlutterFlowTheme.of(context).error,
                                        lineHeight: 1.4,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            0.0, 16.0, 0.0, 16.0),
                        child: FFButtonWidget(
                          onPressed: _model.submitting
                              ? null
                              : () => _createAccount(),
                          text: 'Create Account',
                          showLoadingIndicator: false,
                          options: FFButtonOptions(
                            height: 52.0,
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                24.0, 0.0, 24.0, 0.0),
                            color: FlutterFlowTheme.of(context).primary,
                            textStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  font: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  color: FlutterFlowTheme.of(context).onPrimary,
                                  letterSpacing: 0.0,
                                ),
                            elevation: 0.0,
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            0.0, 0.0, 0.0, 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account?',
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    font: GoogleFonts.nunito(),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                  ),
                            ),
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  8.0, 0.0, 0.0, 0.0),
                              child: GestureDetector(
                                onTap: () =>
                                    context.go(AuthLoginWidget.routePath),
                                child: Text(
                                  'Sign in',
                                  style: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .override(
                                        font: GoogleFonts.nunito(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .primary,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
