import '/backend/backend.dart';
import '/backend/auth/auth_service.dart';
import '/backend/org/org_service.dart';
import '/components/client_card/client_card_widget.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'a_client_directory_model.dart';
export 'a_client_directory_model.dart';

class AClientDirectoryWidget extends StatefulWidget {
  const AClientDirectoryWidget({super.key});

  static String routeName = 'AClientDirectory';
  static String routePath = '/aClientDirectory';

  @override
  State<AClientDirectoryWidget> createState() => _AClientDirectoryWidgetState();
}

class _AClientDirectoryWidgetState extends State<AClientDirectoryWidget> {
  late AClientDirectoryModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AClientDirectoryModel());

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  /// The typed search term, normalized for matching. The model's default value
  /// is the literal junk string `'" "'`, so blank, whitespace-only and
  /// quote-only terms all mean "no search" (show every recipient).
  String _normalizedSearchTerm() {
    return _model.searchName
        .replaceAll('"', '')
        .trim()
        .toLowerCase();
  }

  /// True when [record] matches [query] (already normalized/lower-cased) by
  /// name or by initials, ignoring punctuation so "mj" finds "M.J.".
  bool _matchesSearch(CareRecipientsRecord record, String query) {
    if (record.name.toLowerCase().contains(query)) {
      return true;
    }
    final compactQuery = query.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (compactQuery.isEmpty) {
      return false;
    }
    final compactInitials =
        record.initials.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return compactInitials.contains(compactQuery);
  }

  // -------------------------------------------------------------------
  // Care-circle loading / error / retry (owner decision 2026-11-21).
  //
  // The directory is the landing route, so it can be built before the signed-in
  // user's care circle is known. It used to render that — and a failed
  // resolution — as an empty list, which reads as "my loved one's information
  // disappeared". The four display states are:
  //
  //   resolving      -> spinner + "Loading your care circle…"
  //   failed         -> "We could not load your care circle." + Retry
  //   ready, empty   -> the genuine empty line (only after a real resolution)
  //   ready, filled  -> the existing recipient list
  //
  // The status itself lives in FFAppState and is set by auth_service.dart.
  // -------------------------------------------------------------------

  /// True while the care circle has not resolved yet: provisioning is in
  /// flight, or it has not started and the group context is still unknown.
  bool _circleResolving() {
    final appState = FFAppState();
    return switch (appState.careCircleStatus) {
      CareCircleStatus.loading => true,
      // Provisioning has not started (the auth listener has not run). The
      // circle can only be read once the group context is known; until then
      // the page is still resolving.
      CareCircleStatus.idle => appState.activeGroupId == null,
      CareCircleStatus.ready || CareCircleStatus.failed => false,
    };
  }

  /// True when resolving the care circle failed (provisioning, or the
  /// recipients query — the latter is handled inside the stream builder).
  bool _circleFailed() =>
      FFAppState().careCircleStatus == CareCircleStatus.failed;

  /// Retry for BOTH failure kinds: re-runs the care-circle provisioning (which
  /// sets the status again) and rebuilds the page, which re-creates the
  /// recipients stream — so a failed query is retried too.
  Future<void> _retryCareCircle() async {
    FFAppState().setCareCircleLoading();
    await retryCareCircleProvisioning();
    if (mounted) {
      safeSetState(() {});
    }
  }

  /// The spinner shown while the care circle resolves. Never an empty list.
  Widget _careCircleLoading() {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 50.0,
            height: 50.0,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(0.0, 12.0, 0.0, 0.0),
            child: Text(
              'Loading your care circle…',
              textAlign: TextAlign.center,
              style: theme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// The failure state: what went wrong plus a Retry button. Never an empty
  /// list, never a silent blank.
  Widget _careCircleError(String? message) {
    final theme = FlutterFlowTheme.of(context);
    final detail = (message ?? '').trim();
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'We could not load your care circle.',
            textAlign: TextAlign.center,
            style: theme.titleSmall,
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(0.0, 4.0, 0.0, 0.0),
            child: Text(
              detail.isNotEmpty
                  ? detail
                  : 'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: theme.bodySmall,
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(0.0, 12.0, 0.0, 0.0),
            child: FFButtonWidget(
              onPressed: () async {
                await _retryCareCircle();
              },
              text: 'Retry',
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
          ),
        ],
      ),
    );
  }

  /// The genuine empty circle: reachable only after a successful resolution.
  Widget _careCircleEmpty() {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 16.0),
      child: Text(
        'No care recipients in your care circle yet.',
        textAlign: TextAlign.center,
        style: FlutterFlowTheme.of(context).bodyMedium,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The directory can be built before the signed-in user's group context has
    // resolved (cold start): `careRecipientsForActiveGroup()` then returns an
    // empty stream and nothing would ever replace it, so the list stayed empty
    // until an unrelated setState. Watching FFAppState makes the activeGroupId
    // notification rebuild this page, which re-creates the recipients stream
    // with the real group filter.
    context.watch<FFAppState>();
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: ListView(
          padding: EdgeInsets.zero,
          scrollDirection: Axis.vertical,
          children: [
            Align(
              alignment: AlignmentDirectional(0.0, 0.0),
              child: Container(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.sizeOf(context).height * 0.0,
                ),
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primaryBackground,
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional(0.0, 0.0),
              child: Container(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.sizeOf(context).height * 0.0,
                ),
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primaryBackground,
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional(0.0, -1.0),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 40.0, 0.0, 0.0),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Align(
                          alignment: AlignmentDirectional(-1.0, 0.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.only(),
                            child: Image.asset(
                              'assets/images/Screenshot_2026-06-07_at_10.59.53_PM.png',
                              width: 305.9,
                              height: 123.0,
                              fit: BoxFit.fitWidth,
                              alignment: Alignment(0.0, -1.0),
                            ),
                          ),
                        ),
                        Flexible(
                          child: Align(
                            alignment: AlignmentDirectional(1.0, -1.0),
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: FlutterFlowIconButton(
                                borderRadius: 28.0,
                                buttonSize: 40.0,
                                fillColor: Colors.transparent,
                                icon: Icon(
                                  Icons.menu,
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                  size: 24.0,
                                ),
                                onPressed: () async {
                                  await showModalBottomSheet(
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
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
                                          padding:
                                              MediaQuery.viewInsetsOf(context),
                                          child: NavMenuDirectoryWidget(),
                                        ),
                                      );
                                    },
                                  ).then((value) => safeSetState(() {}));
                                },
                              ),
                            ),
                          ),
                        ),
                      ].divide(SizedBox(width: 0.0)),
                    ),
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(25.0, 0.0, 25.0, 0.0),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                        ),
                        child: Container(
                          width: 150.0,
                          child: TextFormField(
                            controller: _model.textController,
                            focusNode: _model.textFieldFocusNode,
                            onChanged: (_) => EasyDebounce.debounce(
                              '_model.textController',
                              Duration(milliseconds: 300),
                              () async {
                                _model.searchName = _model.textController.text;
                                safeSetState(() {});
                              },
                            ),
                            autofocus: false,
                            enabled: true,
                            obscureText: false,
                            decoration: InputDecoration(
                              isDense: true,
                              labelStyle: FlutterFlowTheme.of(context)
                                  .labelMedium
                                  .override(
                                    font: GoogleFonts.nunito(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontStyle,
                                    ),
                                    fontSize: 14.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontStyle,
                                    lineHeight: 1.6,
                                  ),
                              hintText: 'Search by name...',
                              hintStyle: FlutterFlowTheme.of(context)
                                  .labelMedium
                                  .override(
                                    font: GoogleFonts.nunito(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontStyle,
                                    ),
                                    fontSize: 14.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontStyle,
                                  ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: FlutterFlowTheme.of(context).alternate,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(28.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(28.0),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: FlutterFlowTheme.of(context).error,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(28.0),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: FlutterFlowTheme.of(context).error,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(28.0),
                              ),
                              filled: true,
                              fillColor: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                              prefixIcon: Icon(
                                Icons.search,
                                color: FlutterFlowTheme.of(context).primaryText,
                                size: 20.0,
                              ),
                            ),
                            style: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  font: GoogleFonts.dmSans(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                                  fontSize: 14.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
                                  lineHeight: 1.6,
                                ),
                            cursorColor:
                                FlutterFlowTheme.of(context).primaryText,
                            enableInteractiveSelection: true,
                            validator: _model.textControllerValidator
                                .asValidator(context),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          24.0, 0.0, 24.0, 100.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).primaryBackground,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: AlignmentDirectional(0.0, 0.0),
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    16.0, 12.0, 16.0, 12.0),
                                child: Container(
                                  constraints: BoxConstraints(
                                    minHeight:
                                        MediaQuery.sizeOf(context).height * 0.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .primaryBackground,
                                  ),
                                ),
                              ),
                            ),
                            // Owner decision 2026-11-21: an empty directory may
                            // only ever mean "the care circle really is
                            // empty". While the circle resolves show the
                            // spinner, and on failure show the error + Retry —
                            // the stream alone cannot tell those apart from a
                            // genuinely empty circle.
                            if (_circleResolving())
                              _careCircleLoading()
                            else if (_circleFailed())
                              _careCircleError(FFAppState().careCircleError)
                            else
                            StreamBuilder<List<CareRecipientsRecord>>(
                              stream: careRecipientsForActiveGroup(),
                              builder: (context, snapshot) {
                                // Customize what your widget looks like when it's loading.
                                  if (snapshot.hasError) {
                                    // The recipients query itself failed (rules
                                    // denial, network): never an empty list.
                                    return _careCircleError(
                                        'Please check your connection and try '
                                        'again.');
                                  }
                                // A recipients stream that ENDS without ever
                                // producing data is a failed load, not "still
                                // loading": the generated query helper logs a
                                // stream error and closes, so the error itself
                                // never reaches snapshot.hasError and the page
                                // would otherwise spin forever.
                                if (snapshot.connectionState ==
                                        ConnectionState.done &&
                                    !snapshot.hasData) {
                                  return _careCircleError(
                                      'Please check your connection and try '
                                      'again.');
                                }
                                if (!snapshot.hasData) {
                                  return _careCircleLoading();
                                }
                                List<CareRecipientsRecord>
                                    listViewCareRecipientsRecordList =
                                    snapshot.data!;

                                // Client-side filter over the already-streamed
                                // circle: the search box narrows the list by
                                // name or initials. No query/rules change.
                                final searchTerm = _normalizedSearchTerm();
                                final filteredRecipients = searchTerm.isEmpty
                                    ? listViewCareRecipientsRecordList
                                    : listViewCareRecipientsRecordList
                                        .where((recipient) =>
                                            _matchesSearch(recipient, searchTerm))
                                        .toList();

                                if (filteredRecipients.isEmpty &&
                                    searchTerm.isNotEmpty) {
                                  return Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 8.0, 0.0, 16.0),
                                    child: Text(
                                      'No care recipients match your search.',
                                      textAlign: TextAlign.center,
                                      style:
                                          FlutterFlowTheme.of(context).bodyMedium,
                                    ),
                                  );
                                }

                                // A resolved care circle that genuinely has no
                                // recipients (no search term is narrowing it).
                                if (filteredRecipients.isEmpty) {
                                  return _careCircleEmpty();
                                }

                                return ListView.separated(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  scrollDirection: Axis.vertical,
                                  itemCount: filteredRecipients.length,
                                  separatorBuilder: (_, __) =>
                                      SizedBox(height: 4.0),
                                  itemBuilder: (context, listViewIndex) {
                                    final listViewCareRecipientsRecord =
                                        filteredRecipients[listViewIndex];
                                    return InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        FFAppState().selectedCareRecipient =
                                            listViewCareRecipientsRecord
                                                .reference;
                                        safeSetState(() {});
                                        // Open the selected recipient's Daily
                                        // Dashboard (same destination/pattern
                                        // as the nav menu's "Daily Care").
                                        context.pushNamed(
                                            CDailyDashboardWidget.routeName);
                                      },
                                      child: ClientCardWidget(
                                        key: Key(
                                            'Key5hp_${listViewIndex}_of_${filteredRecipients.length}'),
                                        condition: listViewCareRecipientsRecord
                                            .primaryCondition,
                                        conditionIcon: Icon(
                                          Icons.psychology_rounded,
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          size: 14.0,
                                        ),
                                        initials: listViewCareRecipientsRecord
                                            .initials,
                                        name: listViewCareRecipientsRecord.name,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                context
                                    .pushNamed(BCareProfileSetupWidget.routeName);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  borderRadius: BorderRadius.circular(36.0),
                                  shape: BoxShape.rectangle,
                                  border: Border.all(
                                    color:
                                        FlutterFlowTheme.of(context).alternate,
                                    width: 1.0,
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Container(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_circle_outline_rounded,
                                          color: FlutterFlowTheme.of(context)
                                              .onSurface,
                                          size: 24.0,
                                        ),
                                        Text(
                                          'Add New Care Recipient',
                                          style: FlutterFlowTheme.of(context)
                                              .titleMedium
                                              .override(
                                                font: GoogleFonts.dmSans(
                                                  fontWeight: FontWeight.w600,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .titleMedium
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .onSurface,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w600,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .titleMedium
                                                        .fontStyle,
                                                lineHeight: 1.45,
                                              ),
                                        ),
                                      ].divide(SizedBox(width: 16.0)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              height: 32.0,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 0.0, 0.0, 16.0),
                              child: Container(
                                child: Text(
                                  'Quick Actions',
                                  style: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .override(
                                        font: GoogleFonts.dmSans(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .fontStyle,
                                        lineHeight: 1.5,
                                      ),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      context.pushNamed(
                                          IEmergencyInformationWidget
                                              .routeName);
                                    },
                                    child: Container(
                                      height: 100.0,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryContainer,
                                        borderRadius:
                                            BorderRadius.circular(28.0),
                                        shape: BoxShape.rectangle,
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Container(
                                          child: Container(
                                            height: 68.0,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.emergency_rounded,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .onSecondaryContainer,
                                                  size: 28.0,
                                                ),
                                                Text(
                                                  'Emergency',
                                                  textAlign: TextAlign.center,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .labelLarge
                                                      .override(
                                                        font:
                                                            GoogleFonts.nunito(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelLarge
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelLarge
                                                                  .fontStyle,
                                                        ),
                                                        color: FlutterFlowTheme
                                                                .of(context)
                                                            .onSecondaryContainer,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelLarge
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelLarge
                                                                .fontStyle,
                                                        lineHeight: 1.4,
                                                      ),
                                                ),
                                              ].divide(SizedBox(height: 8.0)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      context.pushNamed(
                                          HWeeklySummaryReportWidget.routeName);
                                    },
                                    child: Container(
                                      height: 100.0,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .accentContainer,
                                        borderRadius:
                                            BorderRadius.circular(28.0),
                                        shape: BoxShape.rectangle,
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Container(
                                          decoration: BoxDecoration(),
                                          child: Container(
                                            height: 68.0,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.description_rounded,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .onAccentContainer,
                                                  size: 28.0,
                                                ),
                                                Text(
                                                  'Reports',
                                                  textAlign: TextAlign.center,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .labelLarge
                                                      .override(
                                                        font:
                                                            GoogleFonts.nunito(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelLarge
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelLarge
                                                                  .fontStyle,
                                                        ),
                                                        color: FlutterFlowTheme
                                                                .of(context)
                                                            .onAccentContainer,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelLarge
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelLarge
                                                                .fontStyle,
                                                        lineHeight: 1.4,
                                                      ),
                                                ),
                                              ].divide(SizedBox(height: 8.0)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ].divide(SizedBox(width: 16.0)),
                            ),
                          ].divide(SizedBox(height: 4.0)),
                        ),
                      ),
                    ),
                  ].addToStart(SizedBox(height: 0.0)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
