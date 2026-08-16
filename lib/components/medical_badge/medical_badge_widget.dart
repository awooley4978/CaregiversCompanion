import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'medical_badge_model.dart';
export 'medical_badge_model.dart';

class MedicalBadgeWidget extends StatefulWidget {
  const MedicalBadgeWidget({
    super.key,
    Color? bg,
    Color? color,
    this.icon,
    String? label,
  })  : this.bg = bg ?? const Color(0xFFFEE2E2),
        this.color = color ?? const Color(0x00000000),
        this.label = label ?? 'Allergy: Penicillin';

  final Color bg;
  final Color color;
  final Widget? icon;
  final String label;

  @override
  State<MedicalBadgeWidget> createState() => _MedicalBadgeWidgetState();
}

class _MedicalBadgeWidgetState extends State<MedicalBadgeWidget> {
  late MedicalBadgeModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MedicalBadgeModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 8.0, 8.0),
      child: Container(
        child: Container(
          decoration: BoxDecoration(
            color: valueOrDefault<Color>(
              widget!.bg,
              Color(0xFFFEE2E2),
            ),
            borderRadius: BorderRadius.circular(20.0),
            shape: BoxShape.rectangle,
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(16.0, 8.0, 16.0, 8.0),
            child: Container(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  widget!.icon!,
                  Text(
                    valueOrDefault<String>(
                      widget!.label,
                      'Allergy: Penicillin',
                    ),
                    style: FlutterFlowTheme.of(context).labelMedium.override(
                          font: GoogleFonts.nunito(
                            fontWeight: FontWeight.w600,
                            fontStyle: FlutterFlowTheme.of(context)
                                .labelMedium
                                .fontStyle,
                          ),
                          color: valueOrDefault<Color>(
                            widget!.color,
                            FlutterFlowTheme.of(context).error,
                          ),
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w600,
                          fontStyle: FlutterFlowTheme.of(context)
                              .labelMedium
                              .fontStyle,
                          lineHeight: 1.4,
                        ),
                  ),
                ].divide(SizedBox(width: 4.0)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
