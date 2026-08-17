import 'package:firebase_auth/firebase_auth.dart';
import '/backend/auth/auth_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_model.dart';
export 'login_model.dart';

/// Email/password (and Google) sign-in — the landing screen for
/// unauthenticated users (security phase 1). On success the global router
/// redirect in nav.dart moves the user to `/` (client directory).
class AuthLoginWidget extends StatefulWidget {
  const AuthLoginWidget({super.key});

  static String routeName = 'AuthLogin';
  static String routePath = '/login';

  @override
  State<AuthLoginWidget> createState() => _AuthLoginWidgetState();
}

class _AuthLoginWidgetState extends State<AuthLoginWidget> {
  late AuthLoginModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AuthLoginModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  Future<void> _signInWithEmailAndPassword() async {
    // Client-side validation before hitting the network.
    if (!(_model.formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _model.submitting = true;
      _model.errorText = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _model.emailTextController.text.trim(),
        password: _model.passwordTextController.text,
      );
      // Success: the auth-state listener flips AppStateNotifier.isLoggedIn and
      // the router redirect takes the user to '/'. Nothing to do here.
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

  Future<void> _continueWithGoogle() async {
    setState(() {
      _model.submitting = true;
      _model.errorText = null;
    });
    try {
      await signInWithGoogle();
      // Success: redirect takes over, profile is auto-provisioned by the
      // auth-state listener (uid-centric, provider-agnostic).
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
              padding: const EdgeInsetsDirectional.fromSTEB(24.0, 32.0, 24.0, 32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420.0),
                child: Form(
                  key: _model.formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 72.0,
                        height: 72.0,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: const AlignmentDirectional(0.0, 0.0),
                        child: Icon(
                          Icons.favorite_rounded,
                          color: FlutterFlowTheme.of(context).onPrimary,
                          size: 32.0,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            0.0, 20.0, 0.0, 4.0),
                        child: Text(
                          'Caregivers Companion',
                          textAlign: TextAlign.center,
                          style: FlutterFlowTheme.of(context)
                              .titleLarge
                              .override(
                                font: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.bold,
                                ),
                                color: FlutterFlowTheme.of(context).primaryText,
                                fontSize: 28.0,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.bold,
                                lineHeight: 1.3,
                              ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            0.0, 0.0, 0.0, 32.0),
                        child: Text(
                          'Sign in to coordinate care with the people who matter',
                          textAlign: TextAlign.center,
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
                            0.0, 0.0, 0.0, 8.0),
                        child: TextFormField(
                          controller: _model.passwordTextController,
                          focusNode: _model.passwordFocusNode,
                          autofocus: false,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          validator: (value) {
                            if ((value ?? '').isEmpty) {
                              return 'Enter your password.';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) =>
                              _signInWithEmailAndPassword(),
                          decoration: _fieldDecoration(
                            context,
                            'Password',
                            '••••••••',
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
                            0.0, 16.0, 0.0, 12.0),
                        child: FFButtonWidget(
                          onPressed: _model.submitting
                              ? null
                              : () => _signInWithEmailAndPassword(),
                          text: 'Sign In',
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
                            0.0, 0.0, 0.0, 24.0),
                        child: FFButtonWidget(
                          onPressed: _model.submitting
                              ? null
                              : () => _continueWithGoogle(),
                          text: 'Continue with Google',
                          showLoadingIndicator: false,
                          options: FFButtonOptions(
                            height: 52.0,
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                24.0, 0.0, 24.0, 0.0),
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            textStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  font: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  color: FlutterFlowTheme.of(context)
                                      .primaryText,
                                  letterSpacing: 0.0,
                                ),
                            elevation: 0.0,
                            borderRadius: BorderRadius.circular(16.0),
                            borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).alternate,
                              width: 1.0,
                            ),
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
                              "Don't have an account?",
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
                                onTap: () => context.go(
                                    AuthSignupWidget.routePath),
                                child: Text(
                                  'Sign up',
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
