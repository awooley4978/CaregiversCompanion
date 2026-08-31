import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'med_card_model.dart';
export 'med_card_model.dart';

class MedCardWidget extends StatefulWidget {
  const MedCardWidget({
    super.key,
    Color? bgTint,
    String? dosage,
    this.icon,
    Color? iconColor,
    String? name,
    Color? statusBg,
    Color? statusColor,
    String? statusText,
    String? time,
    bool? taken,
    this.onTakenChanged,
  })  : this.bgTint = bgTint ?? const Color(0xFFE8F5E9),
        this.dosage = dosage ?? '10mg - 1 tablet',
        this.iconColor = iconColor ?? const Color(0x00000000),
        this.name = name ?? 'Lisinopril',
        this.statusBg = statusBg ?? const Color(0xFFE8F5E9),
        this.statusColor = statusColor ?? const Color(0xFF2E7D32),
        this.statusText = statusText ?? 'TAKEN',
        this.time = time ?? '08:00 AM',
        this.taken = taken ?? true;

  final Color bgTint;
  final String dosage;
  final Widget? icon;
  final Color iconColor;
  final String name;
  final Color statusBg;
  final Color statusColor;
  final String statusText;
  final String time;
  final bool taken;

  /// Called when the trailing "Taken" check-circle is tapped, with the new
  /// toggled value. When provided the card is interactive: its check icon and
  /// status chip are driven by the live toggle state and the new value is
  /// reported here so the parent can persist it to `medications`. When null
  /// the card stays purely presentational (previous static behavior).
  final void Function(bool taken)? onTakenChanged;

  @override
  State<MedCardWidget> createState() => _MedCardWidgetState();
}

class _MedCardWidgetState extends State<MedCardWidget> {
  late MedCardModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MedCardModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  /// Re-sync local taken state when the parent rebuilds with a new value
  /// (e.g. the `medications` stream delivers an update from this device, a
  /// teammate, or after Firestore's local cache round-trips our own write).
  @override
  void didUpdateWidget(covariant MedCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taken != widget.taken) {
      _model.taken = widget.taken;
    }
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Live toggle state. When the card is interactive (an onTakenChanged
    // callback is wired), the check icon and status chip reflect the current
    // taken state so tapping gives immediate visual feedback; when no callback
    // is provided the card keeps its previous static-presentation behavior.
    final interactive = widget.onTakenChanged != null;
    final isTaken = _model.taken;
    final statusText = interactive
        ? (isTaken ? 'TAKEN' : 'PENDING')
        : widget.statusText;
    final statusBgColor = interactive
        ? (isTaken
            ? const Color(0xFFE8F5E9)
            : FlutterFlowTheme.of(context).primaryBackground)
        : widget.statusBg;
    final statusFgColor = interactive
        ? (isTaken
            ? const Color(0xFF2E7D32)
            : FlutterFlowTheme.of(context).secondaryText)
        : widget.statusColor;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 16.0),
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
                    width: 52.0,
                    height: 52.0,
                    decoration: BoxDecoration(
                      color: valueOrDefault<Color>(
                        widget!.bgTint,
                        Color(0xFFE8F5E9),
                      ),
                      borderRadius: BorderRadius.circular(20.0),
                      shape: BoxShape.rectangle,
                    ),
                    alignment: AlignmentDirectional(0.0, 0.0),
                    child: widget!.icon!,
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          valueOrDefault<String>(
                            widget!.name,
                            'Lisinopril',
                          ),
                          style: FlutterFlowTheme.of(context)
                              .titleMedium
                              .override(
                                font: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).primaryText,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w600,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .fontStyle,
                                lineHeight: 1.45,
                              ),
                        ),
                        Text(
                          valueOrDefault<String>(
                            widget!.dosage,
                            '10mg - 1 tablet',
                          ),
                          style: FlutterFlowTheme.of(context)
                              .bodySmall
                              .override(
                                font: GoogleFonts.nunito(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .fontStyle,
                                ),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .fontStyle,
                                lineHeight: 1.5,
                              ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              color: FlutterFlowTheme.of(context).accent3,
                              size: 14.0,
                            ),
                            Text(
                              valueOrDefault<String>(
                                widget!.time,
                                '08:00 AM',
                              ),
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
                                    color: FlutterFlowTheme.of(context).accent3,
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
                          ].divide(SizedBox(width: 4.0)),
                        ),
                      ].divide(SizedBox(height: 4.0)),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(9999.0),
                          shape: BoxShape.rectangle,
                        ),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              12.0, 6.0, 12.0, 6.0),
                          child: Container(
                            child: Text(
                              statusText,
                              style: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .override(
                                    font: GoogleFonts.nunito(
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontStyle,
                                    ),
                                    color: statusFgColor,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .fontStyle,
                                    lineHeight: 1.3,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      FlutterFlowIconButton(
                        borderRadius: 8.0,
                        buttonSize: 48.0,
                        fillColor: Colors.transparent,
                        icon: Icon(
                          Icons.check_circle_rounded,
                          color: isTaken
                              ? FlutterFlowTheme.of(context).success
                              : FlutterFlowTheme.of(context).alternate,
                          size: 32.0,
                        ),
                        onPressed: () {
                          if (widget.onTakenChanged != null) {
                            final next = !_model.taken;
                            _model.taken = next;
                            setState(() {});
                            widget.onTakenChanged!.call(next);
                          }
                        },
                      ),
                    ].divide(SizedBox(height: 8.0)),
                  ),
                ].divide(SizedBox(width: 16.0)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
