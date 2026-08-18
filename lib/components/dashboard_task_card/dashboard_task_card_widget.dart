import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dashboard_task_card_model.dart';
export 'dashboard_task_card_model.dart';

class DashboardTaskCardWidget extends StatefulWidget {
  const DashboardTaskCardWidget({
    super.key,
    this.icon,
    String? subtitle,
    String? title,
    bool? completed,
  })  : this.subtitle = subtitle ?? 'Assist with wheelchair transfer',
        this.title = title ?? 'Morning Mobility Exercise',
        this.completed = completed ?? true;

  final Widget? icon;
  final String subtitle;
  final String title;
  final bool completed;

  @override
  State<DashboardTaskCardWidget> createState() =>
      _DashboardTaskCardWidgetState();
}

class _DashboardTaskCardWidgetState extends State<DashboardTaskCardWidget> {
  late DashboardTaskCardModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DashboardTaskCardModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
      child: Container(
        child: Container(
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(36.0),
            shape: BoxShape.rectangle,
          ),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Container(
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 28.0,
                    height: 28.0,
                    decoration: BoxDecoration(
                      color: valueOrDefault<Color>(
                        valueOrDefault<bool>(
                          widget!.completed,
                          true,
                        )
                            ? FlutterFlowTheme.of(context).primary
                            : Colors.transparent,
                        FlutterFlowTheme.of(context).primary,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                      shape: BoxShape.rectangle,
                      border: Border.all(
                        color: valueOrDefault<Color>(
                          valueOrDefault<bool>(
                            widget!.completed,
                            true,
                          )
                              ? FlutterFlowTheme.of(context).primary
                              : FlutterFlowTheme.of(context).alternate,
                          FlutterFlowTheme.of(context).primary,
                        ),
                        width: valueOrDefault<double>(
                          valueOrDefault<bool>(
                            widget!.completed,
                            true,
                          )
                              ? 2.0
                              : 2.0,
                          2.0,
                        ),
                      ),
                    ),
                    alignment: AlignmentDirectional(0.0, 0.0),
                    child: Visibility(
                      visible: valueOrDefault<bool>(
                        widget!.completed,
                        true,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        color: FlutterFlowTheme.of(context).onPrimary,
                        size: 18.0,
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
                        // §5.2 item 4: only act when a valid recipient is
                        // selected — the carechecklist doc lives in the
                        // recipient's subcollection, so a null selection
                        // would crash (null assert) and is denied by the
                        // Phase-4 rules anyway (null parent fails the gate).
                        final selected =
                            FFAppState().selectedCareRecipient;
                        if (selected == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Select a care recipient to add this task.'),
                            ),
                          );
                          return;
                        }
                        await CarechecklistRecord.createDoc(selected).set({
                          ...createCarechecklistRecordData(
                            title: widget!.title,
                            subtitle: widget!.subtitle,
                            iconeName: '',
                            completed: false,
                          ),
                          ...mapToFirestore(
                            {
                              'created_time': FieldValue.serverTimestamp(),
                            },
                          ),
                        });
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            valueOrDefault<String>(
                              widget!.title,
                              'Morning Mobility Exercise',
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                  lineHeight: 1.6,
                                ),
                          ),
                          Text(
                            valueOrDefault<String>(
                              widget!.subtitle,
                              'Assist with wheelchair transfer',
                            ),
                            style:
                                FlutterFlowTheme.of(context).bodySmall.override(
                                      font: GoogleFonts.nunito(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
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
                  ),
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 20.0, 0.0),
                    child: widget!.icon!,
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
