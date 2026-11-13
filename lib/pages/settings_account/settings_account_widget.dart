import 'package:firebase_auth/firebase_auth.dart';
import '/backend/auth/auth_service.dart'
    show UserProfile, loadUserProfile, saveOwnName;
import '/backend/org/org_service.dart'
    show
        getActiveGroupId,
        getMembership,
        kRoleAdmin,
        kRoleCaregiver,
        kRoleOwner,
        kRoleViewer;
import '/components/app_version_label/app_version_label_widget.dart';
import '/components/button/button_widget.dart';
import '/components/identity_edit_sheet/identity_edit_sheet.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/components/settings_group/settings_group_widget.dart';
import '/components/settings_group_child/settings_group_child_widget.dart';
import '/components/settings_group_child2/settings_group_child2_widget.dart';
import '/components/settings_group_child3/settings_group_child3_widget.dart';
import '/components/settings_group_child4/settings_group_child4_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'settings_account_model.dart';
export 'settings_account_model.dart';

class SettingsAccountWidget extends StatefulWidget {
  const SettingsAccountWidget({super.key, this.versionLoader});

  /// Injectable source of the app package version for the footer (tests supply
  /// a fixed value or a failing lookup). Null uses the real package info.
  final Future<String?> Function()? versionLoader;

  static String routeName = 'SettingsAccount';
  static String routePath = '/settingsAccount';

  @override
  State<SettingsAccountWidget> createState() => _SettingsAccountWidgetState();
}

class _SettingsAccountWidgetState extends State<SettingsAccountWidget> {
  late SettingsAccountModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  // The real signed-in caregiver's identity (U2): read from their own
  // users/{uid} profile record. Empty until it loads (or when there is no
  // profile to read) — the card then simply renders no name/email rather than
  // inventing one.
  String _profileName = '';
  String _profileEmail = '';

  // The signed-in caregiver's role in their ACTIVE organization, read from
  // `organizations/{activeGroupId}/members/{uid}.role` (the same membership
  // doc the Household page reads). Null whenever it cannot be reliably
  // determined — no signed-in user, no active org, no active membership, an
  // absent/unrecognised role value, or a failed lookup. The card then shows
  // NO badge rather than a wrong one.
  String? _memberRole;

  // The org context the current [_memberRole] was read for, so an app-state
  // notification that is not an org switch does not trigger a re-read.
  String? _roleOrgId;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SettingsAccountModel());

    _loadProfile();
    _loadRole();

    // Keep the badge accurate across org switches: `setActiveGroupId()`
    // updates FFAppState().activeGroupId and notifies, which re-reads the
    // role for the new active org.
    FFAppState().addListener(_onAppStateChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  void _onAppStateChanged() {
    final orgId = FFAppState().activeGroupId;
    if (orgId == _roleOrgId) {
      return;
    }
    _loadRole();
  }

  /// Reads the caregiver's role in the active org through the established
  /// membership read path: `users/{uid}.activeGroupId` (cached in
  /// FFAppState) → `getMembership(orgId, uid)` → `MembersRecord.role`.
  /// `getMembership` returns null unless the member doc is `active`, so a
  /// pending invite or a missing doc yields no badge.
  Future<void> _loadRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final orgId = FFAppState().activeGroupId;
    _roleOrgId = orgId;
    String? role;
    if (uid.isNotEmpty) {
      try {
        final activeOrgId = orgId ?? await getActiveGroupId(uid);
        if (activeOrgId != null && activeOrgId.isNotEmpty) {
          final membership = await getMembership(activeOrgId, uid);
          // `MembersRecord.role` defaults to 'viewer' when the field is
          // missing; only an explicitly stored role counts here.
          if (membership != null && membership.hasRole()) {
            role = membership.role;
          }
        }
      } catch (_) {
        role = null;
      }
    }
    if (!mounted) {
      return;
    }
    safeSetState(() => _memberRole = role);
  }

  /// The badge text for a stored role value, using the same labels as the
  /// Household page's role chip. Anything unrecognised maps to null (no
  /// badge) — the badge never guesses a role.
  String? get _roleLabel => switch (_memberRole) {
        kRoleOwner => 'Owner',
        kRoleAdmin => 'Admin',
        kRoleCaregiver => 'Caregiver',
        kRoleViewer => 'Viewer',
        _ => null,
      };

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    UserProfile? profile;
    try {
      profile = await loadUserProfile(uid);
    } catch (_) {
      profile = null;
    }
    if (!mounted) {
      return;
    }
    safeSetState(() {
      _profileName = profile?.name ?? '';
      _profileEmail = profile?.email ?? '';
    });
  }

  /// Edits the signed-in caregiver's own name (the pencil on the identity
  /// card): collects it in the standard modal sheet, writes it to their own
  /// `users/{uid}` profile, then shows the new name and initials on the card.
  /// A blank name never reaches the write (the sheet rejects it); a failed
  /// write is reported as a real error and leaves the card as it was.
  Future<void> _editName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      showSnackbar(context, 'Sign in again to edit your name.');
      return;
    }
    final name = await showIdentityEditSheet(context, currentName: _profileName);
    if (name == null || !mounted) {
      return;
    }
    try {
      await saveOwnName(uid, name);
    } catch (_) {
      if (mounted) {
        showSnackbar(
          context,
          "Couldn't save your name. Please check your connection and try "
          'again.',
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    safeSetState(() => _profileName = name);
    showSnackbar(context, 'Name updated.');
  }

  /// Avatar initials from the real identity: the name's first two words, or
  /// the email's local part when no name is on record. Empty when neither is
  /// known (the circle then just stays empty — no placeholder letters).
  String get _profileInitials {
    final source = _profileName.isNotEmpty
        ? _profileName
        : (_profileEmail.contains('@')
            ? _profileEmail.split('@').first
            : _profileEmail);
    final parts = source
        .split(RegExp(r'[\s._\-]+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '';
    }
    String firstLetter(String value) => value.substring(0, 1).toUpperCase();
    if (parts.length == 1) {
      return firstLetter(parts.first);
    }
    return '${firstLetter(parts.first)}${firstLetter(parts[1])}';
  }

  @override
  void dispose() {
    FFAppState().removeListener(_onAppStateChanged);
    _model.dispose();

    super.dispose();
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
        body: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(0.0, 20.0, 0.0, 0.0),
          child: SingleChildScrollView(
            primary: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 16.0),
                  child: Container(
                    child: Container(
                      decoration: BoxDecoration(),
                    ),
                  ),
                ),
                Container(
                  width: 100.0,
                  height: 100.0,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0xFFF7F4EE),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Container(
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Settings & Account',
                              style: FlutterFlowTheme.of(context)
                                  .titleLarge
                                  .override(
                                    font: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleLarge
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    fontSize: 28.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleLarge
                                        .fontStyle,
                                    lineHeight: 1.3,
                                  ),
                            ),
                            Container(
                              width: 40.0,
                            ),
                            Align(
                              alignment: AlignmentDirectional(1.0, -1.0),
                              child: Padding(
                                padding: EdgeInsets.all(2.0),
                                child: FlutterFlowIconButton(
                                  borderRadius: 28.0,
                                  buttonSize: 40.0,
                                  fillColor: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  icon: Icon(
                                    Icons.menu,
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    size: 24.0,
                                  ),
                                  onPressed: () async {
                                    await showModalBottomSheet(
                                      isScrollControlled: true,
                                      backgroundColor:
                                          FlutterFlowTheme.of(context)
                                              .primaryBackground,
                                      enableDrag: false,
                                      context: context,
                                      builder: (context) {
                                        return GestureDetector(
                                          onTap: () {
                                            FocusScope.of(context).unfocus();
                                            FocusManager.instance.primaryFocus
                                                ?.unfocus();
                                          },
                                          child: Padding(
                                            padding: MediaQuery.viewInsetsOf(
                                                context),
                                            child: NavMenuDirectoryWidget(),
                                          ),
                                        );
                                      },
                                    ).then((value) => safeSetState(() {}));
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 24.0),
                  child: Container(
                    child: Container(
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                        borderRadius: BorderRadius.circular(36.0),
                        shape: BoxShape.rectangle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Container(
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 64.0,
                                height: 64.0,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context).primary,
                                  shape: BoxShape.circle,
                                ),
                                alignment: AlignmentDirectional(0.0, 0.0),
                                child: Text(
                                  _profileInitials,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  style: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .override(
                                        font: GoogleFonts.nunito(
                                          fontWeight: FontWeight.w600,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelMedium
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .onPrimary,
                                        fontSize: 24.32,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontStyle,
                                        lineHeight: 1.4,
                                      ),
                                  overflow: TextOverflow.clip,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_profileName.isNotEmpty)
                                      Text(
                                        _profileName,
                                        style: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .override(
                                              font: GoogleFonts.dmSans(
                                                fontWeight: FontWeight.bold,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .titleMedium
                                                        .fontStyle,
                                              ),
                                              color: FlutterFlowTheme.of(
                                                      context)
                                                  .primaryText,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleMedium
                                                      .fontStyle,
                                              lineHeight: 1.45,
                                            ),
                                      ),
                                    if (_profileEmail.isNotEmpty)
                                      Text(
                                        _profileEmail,
                                        style: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .override(
                                              font: GoogleFonts.nunito(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontStyle,
                                              lineHeight: 1.5,
                                            ),
                                      ),
                                    if (_roleLabel != null)
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            0.0, 4.0, 0.0, 0.0),
                                        child: Container(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: FlutterFlowTheme.of(context)
                                                  .primaryBackground,
                                              borderRadius:
                                                  BorderRadius.circular(20.0),
                                              shape: BoxShape.rectangle,
                                            ),
                                            child: Padding(
                                              padding:
                                                  EdgeInsetsDirectional.fromSTEB(
                                                      8.0, 4.0, 8.0, 4.0),
                                              child: Container(
                                                child: Text(
                                                  _roleLabel!,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .labelSmall
                                                      .override(
                                                        font: GoogleFonts.nunito(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmall
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmall
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .onSurface,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontStyle,
                                                        lineHeight: 1.3,
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ].divide(SizedBox(height: 4.0)),
                                ),
                              ),
                              FlutterFlowIconButton(
                                borderRadius: 8.0,
                                buttonSize: 40.0,
                                fillColor: Colors.transparent,
                                icon: Icon(
                                  Icons.edit_rounded,
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                  size: 20.0,
                                ),
                                onPressed: () async {
                                  await _editName();
                                },
                              ),
                            ].divide(SizedBox(width: 24.0)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      wrapWithModel(
                        model: _model.settingsGroupModel1,
                        updateCallback: () => safeSetState(() {}),
                        child: SettingsGroupWidget(
                          title: 'SHARED CARE',
                          child: () => SettingsGroupChildWidget(),
                        ),
                      ),
                      wrapWithModel(
                        model: _model.settingsGroupModel2,
                        updateCallback: () => safeSetState(() {}),
                        child: SettingsGroupWidget(
                          title: 'PREFERENCES',
                          child: () => SettingsGroupChild2Widget(),
                        ),
                      ),
                      wrapWithModel(
                        model: _model.settingsGroupModel3,
                        updateCallback: () => safeSetState(() {}),
                        child: SettingsGroupWidget(
                          title: 'SECURITY',
                          child: () => SettingsGroupChild3Widget(),
                        ),
                      ),
                      wrapWithModel(
                        model: _model.settingsGroupModel4,
                        updateCallback: () => safeSetState(() {}),
                        child: SettingsGroupWidget(
                          title: 'SUPPORT',
                          child: () => SettingsGroupChild4Widget(),
                        ),
                      ),
                      Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 32.0),
                        child: Container(
                          child: Container(
                            child: GestureDetector(
                              onTap: () async {
                                // Security phase 1: working sign-out. Clears
                                // user-scoped app state, then the auth-state
                                // listener flips AppStateNotifier.isLoggedIn and
                                // the global router redirect lands on /login.
                                FFAppState().selectedCareRecipient = null;
                                await FirebaseAuth.instance.signOut();
                              },
                              child: wrapWithModel(
                                model: _model.buttonModel,
                                updateCallback: () => safeSetState(() {}),
                                child: ButtonWidget(
                                  icon: Icon(
                                    Icons.logout_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    size: 24.0,
                                  ),
                                  iconPresent: true,
                                  iconEndPresent: false,
                                  content: 'Sign Out',
                                  variant: 'outline',
                                  size: 'medium',
                                  fullWidth: true,
                                  loading: false,
                                  disabled: false,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AppVersionLabel(
                            versionLoader: widget.versionLoader,
                            style: FlutterFlowTheme.of(context)
                                .labelSmall
                                .override(
                                  font: GoogleFonts.nunito(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .fontStyle,
                                  ),
                                  color: FlutterFlowTheme.of(context).onSurface,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontStyle,
                                  lineHeight: 1.3,
                                ),
                          ),
                          Text(
                            'Made with ❤️ for caregivers',
                            style: FlutterFlowTheme.of(context)
                                .labelSmall
                                .override(
                                  font: GoogleFonts.nunito(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .fontStyle,
                                  ),
                                  color: FlutterFlowTheme.of(context).onSurface,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontStyle,
                                  lineHeight: 1.3,
                                ),
                          ),
                        ].divide(SizedBox(height: 4.0)),
                      ),
                      Container(
                        height: 24.0,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
