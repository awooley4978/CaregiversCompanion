import '/components/button/button_widget.dart';
import '/components/emergency_contact_card/emergency_contact_card_widget.dart';
import '/components/medical_badge/medical_badge_widget.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/reports/emergency_info.dart';
import '/reports/emergency_info_pdf.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'i_emergency_information_model.dart';
export 'i_emergency_information_model.dart';

class IEmergencyInformationWidget extends StatefulWidget {
  const IEmergencyInformationWidget({super.key});

  static String routeName = 'IEmergencyInformation';
  static String routePath = '/iEmergencyInformation';

  @override
  State<IEmergencyInformationWidget> createState() =>
      _IEmergencyInformationWidgetState();
}

class _IEmergencyInformationWidgetState
    extends State<IEmergencyInformationWidget> {
  late IEmergencyInformationModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  /// The ONE load that feeds this screen and the EMS PDF. Both render this same
  /// object, so the page and the printout cannot disagree.
  EmergencyInfoData? _info;
  Future<EmergencyInfoData?>? _loadFuture;
  String? _loadError;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => IEmergencyInformationModel());

    _loadFuture = _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  /// Reads the selected care recipient's profile once, for this page.
  Future<EmergencyInfoData?> _load() async {
    final recipientRef = FFAppState().selectedCareRecipient;
    if (recipientRef == null) {
      if (mounted) {
        safeSetState(() => _loadError =
            'No care recipient is selected, so there is no emergency info to '
            'show.');
      }
      return null;
    }
    try {
      final info = await EmergencyInfoData.load(recipientRef: recipientRef);
      if (mounted) {
        safeSetState(() {
          _info = info;
          _loadError = null;
        });
      }
      return info;
    } catch (_) {
      if (mounted) {
        safeSetState(() => _loadError =
            'Could not load emergency info. Please check your connection and '
            'try again.');
      }
      return null;
    }
  }

  /// Exports the data the screen is already showing: the PDF is built from the
  /// loaded [EmergencyInfoData], never from a second read.
  Future<void> _exportPdf() async {
    final info = _info ?? await _loadFuture;
    if (info == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _loadError ?? 'Emergency info is not available to export yet.',
            ),
          ),
        );
      }
      return;
    }

    safeSetState(() => _exporting = true);
    try {
      final bytes = await buildEmergencyInfoPdf(info);
      await Printing.layoutPdf(
        name: emergencyInfoFileName(info),
        onLayout: (format) async => bytes,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not build the EMS PDF. Please check your connection and '
              'try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        safeSetState(() => _exporting = false);
      }
    }
  }

  @override
  void dispose() {
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await launchUrl(Uri(
              scheme: 'tel',
              path: '911',
            ));
          },
          backgroundColor: FlutterFlowTheme.of(context).error,
          icon: Icon(
            Icons.phone_forwarded_rounded,
            color: FlutterFlowTheme.of(context).onSurface,
            size: 24.0,
          ),
          elevation: 0.0,
          label: Text(
            'Call Emergency',
            style: FlutterFlowTheme.of(context).labelLarge.override(
                  font: GoogleFonts.nunito(
                    fontWeight:
                        FlutterFlowTheme.of(context).labelLarge.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).labelLarge.fontStyle,
                  ),
                  color: FlutterFlowTheme.of(context).onSurface,
                  letterSpacing: 0.0,
                  fontWeight:
                      FlutterFlowTheme.of(context).labelLarge.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).labelLarge.fontStyle,
                  lineHeight: 1.4,
                ),
          ),
        ),
        body: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(0.0, 40.0, 0.0, 0.0),
          child: SingleChildScrollView(
            primary: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Container(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Emergency Info',
                                  style: FlutterFlowTheme.of(context)
                                      .headlineMedium
                                      .override(
                                        font: GoogleFonts.dmSans(
                                          fontWeight: FontWeight.w800,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .headlineMedium
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.w800,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .headlineMedium
                                            .fontStyle,
                                        lineHeight: 1.3,
                                      ),
                                ),
                                if (_info != null) ...[
                                  Text(
                                    _info!.recipientNameOrNotProvided,
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.nunito(
                                            fontWeight: FontWeight.w600,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                          fontStyle: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .fontStyle,
                                          lineHeight: 1.6,
                                        ),
                                  ),
                                  Text(
                                    'DOB: ${_info!.dateOfBirthOrNotProvided}',
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
                                          color: FlutterFlowTheme.of(context)
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
                                ] else
                                  Text(
                                    _loadError ?? 'Loading...',
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
                                          color: FlutterFlowTheme.of(context)
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
                              ].divide(SizedBox(height: 4.0)),
                            ),
                            Align(
                              alignment: AlignmentDirectional(1.0, -1.0),
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
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
                        Container(
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            borderRadius: BorderRadius.circular(24.0),
                            shape: BoxShape.rectangle,
                            border: Border.all(
                              color: FlutterFlowTheme.of(context).tertiary,
                              width: 2.0,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Container(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Medical Quick-View',
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
                                          color: FlutterFlowTheme.of(context)
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
                                  Wrap(
                                    spacing: 8.0,
                                    runSpacing: 8.0,
                                    alignment: WrapAlignment.start,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.start,
                                    direction: Axis.horizontal,
                                    runAlignment: WrapAlignment.start,
                                    verticalDirection: VerticalDirection.down,
                                    clipBehavior: Clip.none,
                                    children: _medicalBadges(context),
                                  ),
                                ].divide(SizedBox(height: 16.0)),
                              ),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Primary Contacts',
                              style: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .override(
                                    font: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                    lineHeight: 1.45,
                                  ),
                            ),
                            ..._contactCards(context),
                          ].divide(SizedBox(height: 16.0)),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                                borderRadius: BorderRadius.circular(36.0),
                                shape: BoxShape.rectangle,
                                border: Border.all(
                                  color: FlutterFlowTheme.of(context).alternate,
                                  width: 1.0,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Container(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.medication_rounded,
                                            color: FlutterFlowTheme.of(context)
                                                .onSurface,
                                            size: 20.0,
                                          ),
                                          Text(
                                            'Current Medications',
                                            style: FlutterFlowTheme.of(context)
                                                .titleSmall
                                                .override(
                                                  font: GoogleFonts.dmSans(
                                                    fontWeight: FontWeight.bold,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .titleSmall
                                                            .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.bold,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .titleSmall
                                                          .fontStyle,
                                                  lineHeight: 1.5,
                                                ),
                                          ),
                                        ].divide(SizedBox(width: 8.0)),
                                      ),
                                      Divider(
                                        height: 16.0,
                                        thickness: 1.0,
                                        indent: 0.0,
                                        endIndent: 0.0,
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          for (final line in (_info
                                                  ?.medicationLines ??
                                              const ['Loading...']))
                                            Text(
                                              '• $line',
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  font: GoogleFonts.nunito(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontStyle,
                                                  lineHeight: 1.6,
                                                ),
                                          ),
                                        ].divide(SizedBox(height: 4.0)),
                                      ),
                                    ].divide(SizedBox(height: 8.0)),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                                borderRadius: BorderRadius.circular(36.0),
                                shape: BoxShape.rectangle,
                                border: Border.all(
                                  color: FlutterFlowTheme.of(context).alternate,
                                  width: 1.0,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Container(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.description_rounded,
                                            color: FlutterFlowTheme.of(context)
                                                .onSurface,
                                            size: 20.0,
                                          ),
                                          Text(
                                            'Advance Directives',
                                            style: FlutterFlowTheme.of(context)
                                                .titleSmall
                                                .override(
                                                  font: GoogleFonts.dmSans(
                                                    fontWeight: FontWeight.bold,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .titleSmall
                                                            .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.bold,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .titleSmall
                                                          .fontStyle,
                                                  lineHeight: 1.5,
                                                ),
                                          ),
                                        ].divide(SizedBox(width: 8.0)),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .primaryBackground,
                                          borderRadius:
                                              BorderRadius.circular(28.0),
                                          shape: BoxShape.rectangle,
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: Container(
                                            child: Text(
                                              _info == null
                                                  ? 'Loading...'
                                                  : _info!
                                                      .advanceDirectivesOrNotProvided,
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .bodySmall
                                                  .override(
                                                    font: GoogleFonts.nunito(
                                                      fontWeight:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodySmall
                                                              .fontWeight,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodySmall
                                                              .fontStyle,
                                                    ),
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primaryText,
                                                    letterSpacing: 0.0,
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodySmall
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodySmall
                                                            .fontStyle,
                                                    lineHeight: 1.5,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ].divide(SizedBox(height: 8.0)),
                                  ),
                                ),
                              ),
                            ),
                          ].divide(SizedBox(height: 16.0)),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 0.0, 32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              wrapWithModel(
                                model: _model.buttonModel1,
                                updateCallback: () => safeSetState(() {}),
                                child: ButtonWidget(
                                  icon: Icon(
                                    Icons.share_rounded,
                                    color:
                                        FlutterFlowTheme.of(context).primaryText,
                                    size: 24.0,
                                  ),
                                  iconPresent: true,
                                  iconEndPresent: false,
                                  content: 'Export PDF for EMS',
                                  variant: 'primary',
                                  size: 'large',
                                  fullWidth: true,
                                  loading: _exporting,
                                  disabled: false,
                                  onPressed: _exporting ? null : _exportPdf,
                                ),
                              ),
                              wrapWithModel(
                                model: _model.buttonModel2,
                                updateCallback: () => safeSetState(() {}),
                                child: ButtonWidget(
                                  iconPresent: false,
                                  iconEndPresent: false,
                                  content: 'Update Emergency Info',
                                  variant: 'outline',
                                  size: 'large',
                                  fullWidth: true,
                                  loading: false,
                                  disabled: false,
                                ),
                              ),
                            ].divide(SizedBox(height: 16.0)),
                          ),
                        ),
                      ].divide(SizedBox(height: 24.0)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Real allergies and conditions from the loaded profile. A profile that
  /// holds none says "Not provided" instead of showing an invented condition.
  List<Widget> _medicalBadges(BuildContext context) {
    final info = _info;
    if (info == null) {
      return [
        MedicalBadgeWidget(
          bg: FlutterFlowTheme.of(context).secondaryBackground,
          color: FlutterFlowTheme.of(context).secondaryText,
          icon: Icon(
            Icons.hourglass_empty_rounded,
            color: FlutterFlowTheme.of(context).secondaryText,
            size: 14.0,
          ),
          label: 'Loading...',
        ),
      ];
    }

    final badges = <Widget>[];
    if (info.allergies.isEmpty) {
      badges.add(MedicalBadgeWidget(
        bg: FlutterFlowTheme.of(context).secondaryBackground,
        color: FlutterFlowTheme.of(context).secondaryText,
        icon: Icon(
          Icons.warning_rounded,
          color: FlutterFlowTheme.of(context).secondaryText,
          size: 14.0,
        ),
        label: 'Allergies: $emergencyInfoNotProvided',
      ));
    } else {
      for (final allergy in info.allergies) {
        badges.add(MedicalBadgeWidget(
          bg: Color(0xFFFEE2E2),
          color: FlutterFlowTheme.of(context).error,
          icon: Icon(
            Icons.warning_rounded,
            color: FlutterFlowTheme.of(context).error,
            size: 14.0,
          ),
          label: 'Allergy: $allergy',
        ));
      }
    }

    if (info.conditions.isEmpty) {
      badges.add(MedicalBadgeWidget(
        bg: FlutterFlowTheme.of(context).secondaryBackground,
        color: FlutterFlowTheme.of(context).secondaryText,
        icon: Icon(
          Icons.favorite_rounded,
          color: FlutterFlowTheme.of(context).secondaryText,
          size: 14.0,
        ),
        label: 'Conditions: $emergencyInfoNotProvided',
      ));
    } else {
      for (final condition in info.conditions) {
        badges.add(MedicalBadgeWidget(
          bg: Color(0xFFE0F2F1),
          color: FlutterFlowTheme.of(context).primary,
          icon: Icon(
            Icons.favorite_rounded,
            color: FlutterFlowTheme.of(context).error,
            size: 14.0,
          ),
          label: condition,
        ));
      }
    }
    return badges;
  }

  /// The recipient's real emergency contact and primary care physician. The
  /// Pharmacy card is gone: the care profile holds no pharmacy, so it could only
  /// ever be invented (pharmacy stays a future care-profile feature).
  List<Widget> _contactCards(BuildContext context) {
    final info = _info;
    if (info == null) {
      return [
        EmergencyContactCardWidget(
          initials: '',
          name: 'Loading...',
          phone: '',
          relation: 'Emergency Contact',
        ),
      ];
    }
    return [
      EmergencyContactCardWidget(
        initials: EmergencyInfoData.initialsFor(info.emergencyContactName),
        name: info.emergencyContactNameOrNotProvided,
        phone: info.emergencyContactPhoneOrNotProvided,
        relation: 'Emergency Contact',
      ),
      EmergencyContactCardWidget(
        initials: EmergencyInfoData.initialsFor(info.primaryCarePhysicianName),
        name: info.primaryCarePhysicianNameOrNotProvided,
        phone: info.primaryCarePhysicianPhoneOrNotProvided,
        relation: 'Primary Care Physician',
      ),
    ];
  }
}
