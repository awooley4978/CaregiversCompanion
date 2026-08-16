import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'settings_item_model.dart';
export 'settings_item_model.dart';

class SettingsItemWidget extends StatefulWidget {
  const SettingsItemWidget({
    super.key,
    bool? hasSubtitle,
    this.icon,
    Color? iconBg,
    Color? iconColor,
    String? label,
    bool? showArrow,
    String? subtitle,
    String? onTap,
  })  : this.hasSubtitle = hasSubtitle ?? true,
        this.iconBg = iconBg ?? const Color(0x00000000),
        this.iconColor = iconColor ?? const Color(0x00000000),
        this.label = label ?? 'Manage Caregivers',
        this.showArrow = showArrow ?? true,
        this.subtitle = subtitle ?? '3 people have access',
        this.onTap = onTap ?? 'navigate:ClientProfiles';

  final bool hasSubtitle;
  final Widget? icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final bool showArrow;
  final String subtitle;
  final String onTap;

  @override
  State<SettingsItemWidget> createState() => _SettingsItemWidgetState();
}

class _SettingsItemWidgetState extends State<SettingsItemWidget> {
  late SettingsItemModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SettingsItemModel());

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
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(24.0, 16.0, 24.0, 16.0),
        child: Container(
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36.0,
                height: 36.0,
                decoration: BoxDecoration(
                  color: valueOrDefault<Color>(
                    widget!.iconBg,
                    FlutterFlowTheme.of(context).secondary15,
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
                        widget!.label,
                        'Manage Caregivers',
                      ),
                      maxLines: 1,
                      style: FlutterFlowTheme.of(context).bodyLarge.override(
                            font: GoogleFonts.nunito(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodyLarge
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyLarge
                                  .fontStyle,
                            ),
                            color: FlutterFlowTheme.of(context).primaryText,
                            letterSpacing: 0.0,
                            fontWeight: FlutterFlowTheme.of(context)
                                .bodyLarge
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyLarge
                                .fontStyle,
                            lineHeight: 1.6,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (valueOrDefault<bool>(
                      widget!.hasSubtitle,
                      true,
                    ))
                      Text(
                        valueOrDefault<String>(
                          widget!.subtitle,
                          '3 people have access',
                        ),
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              font: GoogleFonts.nunito(
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .fontStyle,
                              ),
                              color: FlutterFlowTheme.of(context).secondaryText,
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
                  ].divide(SizedBox(height: 2.0)),
                ),
              ),
              if (valueOrDefault<bool>(
                widget!.showArrow,
                true,
              ))
                Icon(
                  Icons.chevron_right_rounded,
                  color: FlutterFlowTheme.of(context).accent3,
                  size: 20.0,
                ),
            ].divide(SizedBox(width: 16.0)),
          ),
        ),
      ),
    );
  }
}
