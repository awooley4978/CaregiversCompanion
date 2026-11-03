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

/// Updates the title/details of an existing checklist document.
///
/// Returns false when the write is rejected (rules denial, offline, ...) so the
/// caller can tell the caregiver instead of failing silently.
@visibleForTesting
Future<bool> updateCarechecklistTask(
  DocumentReference reference, {
  required String title,
  required String subtitle,
}) async {
  try {
    await reference.update({
      'title': title,
      'subtitle': subtitle,
    });
    return true;
  } catch (_) {
    return false;
  }
}

/// The explicit 'Edit List' action behind the dashboard Care Checklist.
///
/// This is the list action for the checklist: it lists the caregiver's existing
/// tasks (each editable — title + details are written back to that record) and
/// adds a new one. Checklist documents are created HERE and only here; the
/// checklist rows themselves toggle/delete the document they show (a row tap
/// used to append a fabricated 'Morning Mobility Exercise' task).
class DashboardTaskAddSheetWidget extends StatefulWidget {
  const DashboardTaskAddSheetWidget({
    super.key,
    this.careRecipientRef,
    this.existingTasksStream,
  });

  /// The care recipient whose `carechecklist` subcollection receives the task.
  final DocumentReference? careRecipientRef;

  /// The tasks this sheet can edit. The dashboard passes its own `carechecklist`
  /// stream so editing a task updates the record the row renders.
  final Stream<List<CarechecklistRecord>>? existingTasksStream;

  @override
  State<DashboardTaskAddSheetWidget> createState() =>
      _DashboardTaskAddSheetWidgetState();
}

class _DashboardTaskAddSheetWidgetState
    extends State<DashboardTaskAddSheetWidget> {
  late DashboardTaskAddSheetModel _model;

  /// The existing task being edited, or null when adding a new one.
  CarechecklistRecord? _editing;

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

  /// Loads an existing task into the fields so the caregiver can change it.
  void _startEdit(CarechecklistRecord task) {
    setState(() {
      _editing = task;
      _model.taskTitleController?.text = task.title;
      _model.taskSubtitleController?.text = task.subtitle;
    });
  }

  /// Leaves edit mode and clears the fields for a fresh add.
  void _cancelEdit() {
    setState(() {
      _editing = null;
      _model.taskTitleController?.text = '';
      _model.taskSubtitleController?.text = '';
    });
  }

  /// Saves the entered title/details — onto the task being edited, or onto a new
  /// task. A rejected write is reported to the caregiver, never silent.
  Future<void> _saveTask(BuildContext context) async {
    final title = _model.taskTitleController?.text.trim() ?? '';
    final subtitle = _model.taskSubtitleController?.text.trim() ?? '';
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a task name.')),
      );
      return;
    }
    final editing = _editing;
    if (editing != null) {
      final ok = await updateCarechecklistTask(
        editing.reference,
        title: title,
        subtitle: subtitle,
      );
      if (!context.mounted) {
        return;
      }
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the task. Please try again.'),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task updated.')),
      );
      // Stay on the list so the caregiver sees the change and can edit more.
      _cancelEdit();
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

  /// One existing task: title/details plus the control that loads it for edit.
  Widget _buildTaskRow(BuildContext context, CarechecklistRecord task) {
    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(24.0),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16.0, 8.0, 8.0, 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
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
                        ),
                  ),
                  if (task.subtitle.isNotEmpty)
                    Text(
                      task.subtitle,
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            font: GoogleFonts.nunito(
                              fontWeight:
                                  FlutterFlowTheme.of(context).bodySmall.fontWeight,
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
                          ),
                    ),
                ].divide(SizedBox(height: 2.0)),
              ),
            ),
            IconButton(
              tooltip: 'Edit task',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: 32.0,
                minHeight: 32.0,
              ),
              icon: Icon(
                Icons.edit_outlined,
                color: FlutterFlowTheme.of(context).secondaryText,
                size: 20.0,
              ),
              onPressed: () => _startEdit(task),
            ),
          ].divide(SizedBox(width: 12.0)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    final editing = _editing;

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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.existingTasksStream != null)
                StreamBuilder<List<CarechecklistRecord>>(
                  stream: widget.existingTasksStream,
                  builder: (context, snapshot) {
                    final tasks =
                        snapshot.data ?? const <CarechecklistRecord>[];
                    if (tasks.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Checklist tasks',
                          style:
                              FlutterFlowTheme.of(context).titleSmall.override(
                                    font: GoogleFonts.dmSans(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                        ),
                        ...tasks.map(
                          (task) => _buildTaskRow(context, task),
                        ),
                      ].divide(SizedBox(height: 8.0)),
                    );
                  },
                ),
              Text(
                editing == null
                    ? 'Add a checklist task'
                    : 'Edit checklist task',
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
                  await _saveTask(context);
                },
                text: editing == null ? 'Add Task' : 'Save Changes',
                options: FFButtonOptions(
                  height: 40.0,
                  padding: EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
                  iconPadding:
                      EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                  color: FlutterFlowTheme.of(context).primary,
                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                        font: GoogleFonts.dmSans(
                          fontWeight: FlutterFlowTheme.of(context)
                              .titleSmall
                              .fontWeight,
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
              if (editing != null)
                TextButton(
                  onPressed: _cancelEdit,
                  child: Text(
                    'Cancel',
                    style: FlutterFlowTheme.of(context).titleSmall.override(
                          font: GoogleFonts.dmSans(
                            fontWeight: FlutterFlowTheme.of(context)
                                .titleSmall
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .fontStyle,
                          ),
                          color: FlutterFlowTheme.of(context).secondaryText,
                          letterSpacing: 0.0,
                          fontWeight:
                              FlutterFlowTheme.of(context).titleSmall.fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).titleSmall.fontStyle,
                        ),
                  ),
                ),
            ].divide(SizedBox(height: 12.0)),
          ),
        ),
      ),
    );
  }
}
