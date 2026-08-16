import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'condition_chip_model.dart';
export 'condition_chip_model.dart';

class ConditionChipWidget extends StatefulWidget {
  const ConditionChipWidget({
    super.key,
    String? label,
    bool? selected,
  })  : this.label = label ?? 'Diabetes',
        this.selected = selected ?? true;

  final String label;
  final bool selected;

  @override
  State<ConditionChipWidget> createState() => _ConditionChipWidgetState();
}

class _ConditionChipWidgetState extends State<ConditionChipWidget> {
  late ConditionChipModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ConditionChipModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: valueOrDefault<Color>(
          valueOrDefault<bool>(
            widget!.selected,
            true,
          )
              ? FlutterFlowTheme.of(context).primary
              : FlutterFlowTheme.of(context).secondaryBackground,
          FlutterFlowTheme.of(context).primary,
        ),
        borderRadius: BorderRadius.circular(28.0),
        shape: BoxShape.rectangle,
        border: Border.all(
          color: valueOrDefault<Color>(
            valueOrDefault<bool>(
              widget!.selected,
              true,
            )
                ? FlutterFlowTheme.of(context).primary
                : FlutterFlowTheme.of(context).alternate,
            FlutterFlowTheme.of(context).primary,
          ),
          width: valueOrDefault<double>(
            valueOrDefault<bool>(
              widget!.selected,
              true,
            )
                ? 1.0
                : 1.0,
            1.0,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16.0, 8.0, 16.0, 8.0),
        child: Container(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                valueOrDefault<String>(
                  widget!.label,
                  'Diabetes',
                ),
                style: FlutterFlowTheme.of(context).labelLarge.override(
                      font: GoogleFonts.nunito(
                        fontWeight:
                            FlutterFlowTheme.of(context).labelLarge.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).labelLarge.fontStyle,
                      ),
                      color: valueOrDefault<Color>(
                        valueOrDefault<bool>(
                          widget!.selected,
                          true,
                        )
                            ? FlutterFlowTheme.of(context).onPrimary
                            : FlutterFlowTheme.of(context).primaryText,
                        FlutterFlowTheme.of(context).onPrimary,
                      ),
                      letterSpacing: 0.0,
                      fontWeight:
                          FlutterFlowTheme.of(context).labelLarge.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).labelLarge.fontStyle,
                      lineHeight: 1.4,
                    ),
              ),
              Container(
                width: 16.0,
                height: 16.0,
                child: Stack(
                  alignment: AlignmentDirectional(0.0, 0.0),
                  children: [
                    if (valueOrDefault<bool>(
                      valueOrDefault<bool>(
                        widget!.selected,
                        true,
                      )
                          ? true
                          : false,
                      true,
                    ))
                      Icon(
                        Icons.check_circle_rounded,
                        color: valueOrDefault<Color>(
                          valueOrDefault<bool>(
                            widget!.selected,
                            true,
                          )
                              ? FlutterFlowTheme.of(context).onPrimary
                              : FlutterFlowTheme.of(context).secondaryText,
                          FlutterFlowTheme.of(context).onPrimary,
                        ),
                        size: 16.0,
                      ),
                    if (valueOrDefault<bool>(
                      valueOrDefault<bool>(
                        widget!.selected,
                        true,
                      )
                          ? false
                          : true,
                      false,
                    ))
                      Icon(
                        Icons.add_circle_outline_rounded,
                        color: valueOrDefault<Color>(
                          valueOrDefault<bool>(
                            widget!.selected,
                            true,
                          )
                              ? FlutterFlowTheme.of(context).onPrimary
                              : FlutterFlowTheme.of(context).secondaryText,
                          FlutterFlowTheme.of(context).onPrimary,
                        ),
                        size: 16.0,
                      ),
                  ],
                ),
              ),
            ].divide(SizedBox(width: 4.0)),
          ),
        ),
      ),
    );
  }
}
