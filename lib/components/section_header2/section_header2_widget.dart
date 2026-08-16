import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'section_header2_model.dart';
export 'section_header2_model.dart';

class SectionHeader2Widget extends StatefulWidget {
  const SectionHeader2Widget({
    super.key,
    this.icon,
    String? title,
  }) : this.title = title ?? 'Vitals Overview';

  final Widget? icon;
  final String title;

  @override
  State<SectionHeader2Widget> createState() => _SectionHeader2WidgetState();
}

class _SectionHeader2WidgetState extends State<SectionHeader2Widget> {
  late SectionHeader2Model _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SectionHeader2Model());

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
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              widget!.icon!,
              Text(
                valueOrDefault<String>(
                  widget!.title,
                  'Vitals Overview',
                ),
                style: FlutterFlowTheme.of(context).titleMedium.override(
                      font: GoogleFonts.dmSans(
                        fontWeight: FontWeight.bold,
                        fontStyle:
                            FlutterFlowTheme.of(context).titleMedium.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).primaryText,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.bold,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleMedium.fontStyle,
                      lineHeight: 1.45,
                    ),
              ),
            ].divide(SizedBox(width: 8.0)),
          ),
          wrapWithModel(
            model: _model.buttonModel,
            updateCallback: () => safeSetState(() {}),
            child: ButtonWidget(
              iconPresent: false,
              iconEndPresent: false,
              content: 'Edit',
              variant: 'ghost',
              size: 'small',
              fullWidth: false,
              loading: false,
              disabled: false,
            ),
          ),
        ],
      ),
    );
  }
}
