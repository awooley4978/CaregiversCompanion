import '/backend/schema/symptom_entries_record.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dashboard_symptom_card_model.dart';
export 'dashboard_symptom_card_model.dart';

/// One row of the Daily Dashboard's Symptoms section.
///
/// The row renders the values of the `symptomEntries` document it is given and
/// its only control updates THAT document (`isResolved: true`). It never
/// creates anything: the exported row's 'Add Entry' button used to `set()` a
/// copy of the row on every tap (a duplicate entry that also cleared the
/// resolved flag) — a new symptom now comes only from the section header's
/// explicit 'Log New Symptom' action.
class DashboardSymptomCardWidget extends StatefulWidget {
  const DashboardSymptomCardWidget({
    super.key,
    required this.record,
  });

  /// The symptom entry this row stands for.
  final SymptomEntriesRecord record;

  @override
  State<DashboardSymptomCardWidget> createState() =>
      _DashboardSymptomCardWidgetState();
}

class _DashboardSymptomCardWidgetState extends State<DashboardSymptomCardWidget> {
  late DashboardSymptomCardModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DashboardSymptomCardModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  /// Marks THIS entry resolved (an in-place update, never a new record). A
  /// rejected write is reported to the caregiver, never silent.
  Future<void> _markResolved(BuildContext context) async {
    try {
      await widget.record.reference.update({'isResolved': true});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Symptom marked as resolved.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update this symptom. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    final record = widget.record;

    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(36.0),
        shape: BoxShape.rectangle,
        border: Border.all(
          color: FlutterFlowTheme.of(context).tertiary,
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48.0,
                height: 48.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).tertiary,
                  borderRadius: BorderRadius.circular(28.0),
                  shape: BoxShape.rectangle,
                ),
                alignment: AlignmentDirectional(0.0, 0.0),
                child: Icon(
                  Icons.admin_panel_settings,
                  color: FlutterFlowTheme.of(context).primaryText,
                  size: 24.0,
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.symptomName,
                      style: FlutterFlowTheme.of(context).bodyLarge.override(
                            font: GoogleFonts.nunito(
                              fontWeight: FontWeight.w600,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyLarge
                                  .fontStyle,
                            ),
                            color: FlutterFlowTheme.of(context).primaryText,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w600,
                            fontStyle:
                                FlutterFlowTheme.of(context).bodyLarge.fontStyle,
                            lineHeight: 1.6,
                          ),
                    ),
                    Text(
                      record.note,
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
                            fontWeight:
                                FlutterFlowTheme.of(context).bodySmall.fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodySmall
                                .fontStyle,
                            lineHeight: 1.5,
                          ),
                    ),
                    Text(
                      valueOrDefault<String>(
                        record.timeLogged?.toString(),
                        'Time Logged',
                      ),
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.nunito(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                            letterSpacing: 0.0,
                            fontWeight: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                          ),
                    ),
                  ].divide(SizedBox(height: 2.0)),
                ),
              ),
              if (record.isResolved)
                Text(
                  'Resolved',
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        font: GoogleFonts.nunito(
                          fontWeight:
                              FlutterFlowTheme.of(context).bodySmall.fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodySmall.fontStyle,
                        ),
                        color: FlutterFlowTheme.of(context).secondaryText,
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).bodySmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodySmall.fontStyle,
                      ),
                )
              else
                ButtonWidget(
                  iconPresent: false,
                  iconEndPresent: false,
                  content: 'Mark Resolved',
                  variant: 'secondary',
                  size: 'small',
                  fullWidth: false,
                  loading: false,
                  disabled: false,
                  onPressed: () async {
                    await _markResolved(context);
                  },
                ),
            ].divide(SizedBox(width: 16.0)),
          ),
        ),
      ),
    );
  }
}
