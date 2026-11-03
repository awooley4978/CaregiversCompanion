import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dashboard_task_add_sheet_model.dart';
export 'dashboard_task_add_sheet_model.dart';

/// The explicit add action behind the dashboard Care Checklist 'Edit List'
/// button.
///
/// New checklist documents are created HERE and only here. The checklist rows
/// themselves toggle/delete the document they show — they never create one
/// (a tap used to append a fabricated 'Morning Mobility Exercise' task).
class DashboardTaskAddSheetWidget extends StatefulWidget {
  const DashboardTaskAddSheetWidget({
    super.key,
    this.careRecipientRef,
  });

  /// The care recipient whose `carechecklist` subcollection receives the task.
  final DocumentReference? careRecipientRef;

  @override
  State<DashboardTaskAddSheetWidget> createState() =>
      _DashboardTaskAddSheetWidgetState();
}

class _DashboardTaskAddSheetWidgetState
    extends State<DashboardTaskAddSheetWidget> {
  late DashboardTaskAddSheetModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DashboardTaskAddSheetModel());

    _model.taskTitleController ??= TextEditingController();
    _model.taskTitleFocusNode ??= FocusNode();
    _model.taskSubtitleController ??= TextEditingController();
    _model.taskSubtitleFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  /// Creates the task with the entered title/details. A rejected write is
  /// reported to the caregiver instead of failing silently.
  Future<void> _addTask(BuildContext context) async {
    final title = _model.taskTitleController?.text.trim() ?? '';
    final subtitle = _model.taskSubtitleController?.text.trim() ?? '';
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a task name.')),
      );
      return;
    }
    final parent = widget.careRecipientRef;
    if (parent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a care recipient to add this task.'),
        ),
      );
      return;
    }
    try {
      await CarechecklistRecord.createDoc(parent).set({
        ...createCarechecklistRecordData(
          title: title,
          subtitle: subtitle,
          iconeName: '',
          completed: false,
        ),
        ...mapToFirestore(
          {
            'created_time': FieldValue.serverTimestamp(),
          },
        ),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task added.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not add the task. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add a checklist task',
              style: FlutterFlowTheme.of(context).titleMedium.override(
                    font: GoogleFonts.dmSans(
                      fontWeight:
                          FlutterFlowTheme.of(context).titleMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleMedium.fontStyle,
                    ),
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).titleMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleMedium.fontStyle,
                  ),
            ),
            TextField(
              controller: _model.taskTitleController,
              focusNode: _model.taskTitleFocusNode,
              autofocus: false,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Task name',
                hintStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.nunito(),
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
                filled: true,
                fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 1.0,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide(
                    color: FlutterFlowTheme.of(context).primary,
                    width: 1.0,
                  ),
                ),
              ),
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.nunito(),
                    letterSpacing: 0.0,
                  ),
            ),
            TextField(
              controller: _model.taskSubtitleController,
              focusNode: _model.taskSubtitleFocusNode,
              autofocus: false,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Details (optional)',
                hintStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.nunito(),
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
                filled: true,
                fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 1.0,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide(
                    color: FlutterFlowTheme.of(context).primary,
                    width: 1.0,
                  ),
                ),
              ),
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.nunito(),
                    letterSpacing: 0.0,
                  ),
            ),
            FFButtonWidget(
              onPressed: () async {
                await _addTask(context);
              },
              text: 'Add Task',
              options: FFButtonOptions(
                height: 40.0,
                padding: EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
                iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                color: FlutterFlowTheme.of(context).primary,
                textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                      font: GoogleFonts.dmSans(
                        fontWeight:
                            FlutterFlowTheme.of(context).titleSmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).titleSmall.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).onPrimary,
                      letterSpacing: 0.0,
                      fontWeight:
                          FlutterFlowTheme.of(context).titleSmall.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleSmall.fontStyle,
                    ),
                elevation: 0.0,
                borderSide: BorderSide(
                  color: Colors.transparent,
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(24.0),
              ),
            ),
          ].divide(SizedBox(height: 12.0)),
        ),
      ),
    );
  }
}
