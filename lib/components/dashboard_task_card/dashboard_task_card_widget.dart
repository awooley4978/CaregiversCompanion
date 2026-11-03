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

/// Toggles `completed` on an existing checklist document.
///
/// Returns false when the write is rejected (rules denial, offline, ...) so the
/// caller can tell the caregiver instead of failing silently.
@visibleForTesting
Future<bool> setCarechecklistCompleted(
    DocumentReference reference, bool completed) async {
  try {
    await reference.update({'completed': completed});
    return true;
  } catch (_) {
    return false;
  }
}

/// The write a row tap performs: flip `completed` on the task it shows.
typedef CarechecklistToggle = Future<bool> Function(
    DocumentReference reference, bool completed);

/// Deletes an existing checklist document; false when the delete is rejected.
@visibleForTesting
Future<bool> deleteCarechecklistTask(DocumentReference reference) async {
  try {
    await reference.delete();
    return true;
  } catch (_) {
    return false;
  }
}

class DashboardTaskCardWidget extends StatefulWidget {
  const DashboardTaskCardWidget({
    super.key,
    this.icon,
    this.subtitle,
    this.title,
    this.completed,
    this.record,
    this.toggleCompleted,
  });

  final Widget? icon;
  final String? subtitle;
  final String? title;
  final bool? completed;

  /// The checklist document this row stands for. When set, the row renders
  /// THIS record's title/subtitle/completed and a tap toggles that same
  /// document (the delete control removes it). The row never creates anything:
  /// new tasks come only from the explicit 'Edit List' add action.
  final CarechecklistRecord? record;

  /// The write a row tap performs. Production always uses
  /// [setCarechecklistCompleted]; tests inject a version that holds the write
  /// open so they can tap again while it is in flight.
  @visibleForTesting
  final CarechecklistToggle? toggleCompleted;

  @override
  State<DashboardTaskCardWidget> createState() =>
      _DashboardTaskCardWidgetState();
}

class _DashboardTaskCardWidgetState extends State<DashboardTaskCardWidget> {
  late DashboardTaskCardModel _model;

  /// True while this row's toggle write is on the wire. A second tap before it
  /// resolves is ignored: it would otherwise compute `!completed` from the same
  /// stale record and issue an overlapping write, leaving the task in a state
  /// that contradicts what the caregiver tapped.
  bool _toggleInFlight = false;

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

    // Render the record's own values; the plain params remain for any caller
    // that is not backed by a document.
    final record = widget.record;
    final title = record?.title ?? widget.title ?? '';
    final subtitle = record?.subtitle ?? widget.subtitle ?? '';
    final completed = record?.completed ?? widget.completed ?? false;

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
                        completed
                            ? FlutterFlowTheme.of(context).primary
                            : Colors.transparent,
                        FlutterFlowTheme.of(context).primary,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                      shape: BoxShape.rectangle,
                      border: Border.all(
                        color: valueOrDefault<Color>(
                          completed
                              ? FlutterFlowTheme.of(context).primary
                              : FlutterFlowTheme.of(context).alternate,
                          FlutterFlowTheme.of(context).primary,
                        ),
                        width: valueOrDefault<double>(
                          completed
                              ? 2.0
                              : 2.0,
                          2.0,
                        ),
                      ),
                    ),
                    alignment: AlignmentDirectional(0.0, 0.0),
                    child: Visibility(
                      visible: completed,
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
                        // Tapping the row ticks/untick the task it shows. It
                        // must never create a document (that fabricated a new
                        // demo task per tap); creation lives behind 'Edit
                        // List'.
                        final target = widget.record;
                        // One write at a time per row: while it is in flight
                        // the row is dimmed and further taps are ignored.
                        if (target == null || _toggleInFlight) {
                          return;
                        }
                        safeSetState(() => _toggleInFlight = true);
                        final ok = await (widget.toggleCompleted ??
                            setCarechecklistCompleted)(
                          target.reference,
                          !target.completed,
                        );
                        if (!mounted) {
                          return;
                        }
                        safeSetState(() => _toggleInFlight = false);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Could not update the task. Please try again.'),
                            ),
                          );
                        }
                      },
                      child: Opacity(
                        opacity: _toggleInFlight ? 0.4 : 1.0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
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
                              subtitle,
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
                  ),
                  if (record != null)
                    IconButton(
                      tooltip: 'Delete task',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: 32.0,
                        minHeight: 32.0,
                      ),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: FlutterFlowTheme.of(context).secondaryText,
                        size: 20.0,
                      ),
                      onPressed: () async {
                        final target = widget.record;
                        if (target == null) {
                          return;
                        }
                        // Deleting a task is permanent, so it asks first: a
                        // mis-tap on the row's bin must not lose the task.
                        final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (alertDialogContext) {
                                return AlertDialog(
                                  title: Text('Delete Task?'),
                                  content: Text(
                                      'This task will be permanently deleted'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(
                                          alertDialogContext, false),
                                      child: Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(
                                          alertDialogContext, true),
                                      child: Text('Delete'),
                                    ),
                                  ],
                                );
                              },
                            ) ??
                            false;
                        if (!confirmed) {
                          return;
                        }
                        final ok =
                            await deleteCarechecklistTask(target.reference);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Could not delete the task. Please try again.'),
                            ),
                          );
                        }
                      },
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
