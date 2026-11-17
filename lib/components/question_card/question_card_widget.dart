import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'question_card_model.dart';
export 'question_card_model.dart';

class QuestionCardWidget extends StatefulWidget {
  const QuestionCardWidget({
    super.key,
    this.category,
    String? question,
    this.answered,
    String? priority,
  })  : this.question =
            question ?? 'Should we adjust the morning dosage of Lisinopril?',
        this.priority = priority ?? 'high';

  /// The category chip's label, or null to render NO chip.
  ///
  /// `questionsToAsk` stores question text only — there is no category, no
  /// "answered" flag and no priority behind a real appointment question
  /// (appointments unit, proposal §5), so Doctor Visit Prep passes null and the
  /// card shows the question and nothing else. The chip, the status line and
  /// the inert 'Edit' button exist only when a caller supplies their values.
  final String? category;
  final String question;
  final bool? answered;
  final String priority;

  @override
  State<QuestionCardWidget> createState() => _QuestionCardWidgetState();
}

class _QuestionCardWidgetState extends State<QuestionCardWidget> {
  late QuestionCardModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => QuestionCardModel());

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
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 16.0),
      child: Container(
        child: Container(
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(28.0),
            shape: BoxShape.rectangle,
            border: Border.all(
              color: FlutterFlowTheme.of(context).alternate,
              width: 1.0,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Container(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The category chip and the priority pin exist only when a
                  // caller supplies a category: a real appointment question has
                  // neither, so nothing is invented for it.
                  if (widget!.category != null)
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                      Container(
                        decoration: BoxDecoration(
                          color: valueOrDefault<Color>(
                            valueOrDefault<String>(
                                      widget!.priority,
                                      'high',
                                    ) ==
                                    'high'
                                ? Color(0x00000000)
                                : Color(0x00000000),
                            Color(0x00000000),
                          ),
                          borderRadius: BorderRadius.circular(20.0),
                          shape: BoxShape.rectangle,
                        ),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              8.0, 4.0, 8.0, 4.0),
                          child: Container(
                            child: Text(
                              valueOrDefault<String>(
                                widget!.category,
                                'Medication',
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
                                    color: valueOrDefault<Color>(
                                      valueOrDefault<String>(
                                                widget!.priority,
                                                'high',
                                              ) ==
                                              'high'
                                          ? Color(0x00000000)
                                          : Color(0x00000000),
                                      Color(0x00000000),
                                    ),
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
                          ),
                        ),
                      ),
                      Icon(
                        Icons.push_pin_rounded,
                        color: valueOrDefault<Color>(
                          valueOrDefault<String>(
                                    widget!.priority,
                                    'high',
                                  ) ==
                                  'high'
                              ? FlutterFlowTheme.of(context).error
                              : FlutterFlowTheme.of(context).secondaryText,
                          FlutterFlowTheme.of(context).error,
                        ),
                        size: 18.0,
                      ),
                    ],
                  ),
                  Text(
                    valueOrDefault<String>(
                      widget!.question,
                      'Should we adjust the morning dosage of Lisinopril?',
                    ),
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.nunito(
                            fontWeight: FontWeight.w500,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                          ),
                          color: FlutterFlowTheme.of(context).primaryText,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w500,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                          lineHeight: 1.6,
                        ),
                  ),
                  // The status line and the (inert) Edit button exist only when
                  // a caller supplies `answered` — there is no such flag behind
                  // a stored question, so the card shows the question alone.
                  if (widget!.answered != null)
                    Divider(
                      height: 16.0,
                      thickness: 1.0,
                    indent: 0.0,
                    endIndent: 0.0,
                    color: FlutterFlowTheme.of(context).alternate,
                  ),
                  if (widget!.answered != null)
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            color: valueOrDefault<Color>(
                              valueOrDefault<bool>(
                                widget!.answered,
                                true,
                              )
                                  ? FlutterFlowTheme.of(context).success
                                  : FlutterFlowTheme.of(context).secondaryText,
                              FlutterFlowTheme.of(context).success,
                            ),
                            size: 16.0,
                          ),
                          Text(
                            valueOrDefault<String>(
                              valueOrDefault<bool>(
                                widget!.answered,
                                true,
                              )
                                  ? 'Addressed'
                                  : 'Awaiting discussion',
                              'Addressed',
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
                                  color: valueOrDefault<Color>(
                                    valueOrDefault<bool>(
                                      widget!.answered,
                                      true,
                                    )
                                        ? FlutterFlowTheme.of(context).success
                                        : FlutterFlowTheme.of(context)
                                            .secondaryText,
                                    FlutterFlowTheme.of(context).success,
                                  ),
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
                ].divide(SizedBox(height: 8.0)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
