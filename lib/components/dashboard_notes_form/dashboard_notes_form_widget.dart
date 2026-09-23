import '/backend/backend.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dashboard_notes_form_model.dart';
export 'dashboard_notes_form_model.dart';

class DashboardNotesFormWidget extends StatefulWidget {
  const DashboardNotesFormWidget({
    super.key,
    Color? authorBg,
    String? authorInitials,
    String? authorName,
    String? content,
    String? time,
    bool? isPrivate,
    this.careRecipientRef,
    this.note,
  })  : this.authorBg = authorBg ?? const Color(0x00000000),
        this.authorInitials = authorInitials ?? 'S',
        this.authorName = authorName ?? 'Sarah (Primary)',
        this.content = content ??
            'Mom had a small appetite this morning. Ate about half of her breakfast (oatmeal with berries). Hydration is looking good today.',
        this.time = time ?? '10:30 AM',
        this.isPrivate = isPrivate ?? false;

  final Color authorBg;
  final String authorInitials;
  final String authorName;
  final String content;
  final String time;
  final bool isPrivate;

  /// The care recipient a NEW note is written for — the Daily Dashboard
  /// resolves it (route param or the app-wide selection) and passes it in.
  /// The `careNotes` record is ref-linked to it, which is exactly what the
  /// Phase-4 rules gate the write on (the recipient's org).
  final DocumentReference? careRecipientRef;

  /// An EXISTING note this sheet edits. Null means "compose a new note": the
  /// composer starts empty, Save creates the record and Delete is not offered
  /// (there is nothing to delete yet). With a note attached, Save updates it in
  /// place and Delete removes it — the controls the design already rendered.
  final CareNotesRecord? note;

  @override
  State<DashboardNotesFormWidget> createState() =>
      _DashboardNotesFormWidgetState();
}

class _DashboardNotesFormWidgetState extends State<DashboardNotesFormWidget> {
  late DashboardNotesFormModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DashboardNotesFormModel());
    _model.noteTextController ??= TextEditingController(
      text: widget.note?.noteText ?? '',
    );
    _model.noteTextFocusNode ??= FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  /// Author stamped on a NEW note: the signed-in caregiver — the same rule the
  /// Care Notes composer uses (PR #12): display name, else email, else
  /// 'Caregiver'. The previous hardcoded 'Sarah (Primary)' is no longer shown
  /// or written.
  String _signedInAuthor() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName;
    }
    final email = user?.email?.trim() ?? '';
    return email.isNotEmpty ? email : 'Caregiver';
  }

  /// The author shown in the header: the note's own author when editing an
  /// existing note, else the signed-in caregiver.
  String _displayAuthor() {
    final note = widget.note;
    if (note != null && note.createdBy.trim().isNotEmpty) {
      return note.createdBy.trim();
    }
    return _signedInAuthor();
  }

  String _initialsFor(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  /// Saves the composer's text: creates a `careNotes` record ref-linked to the
  /// resolved care recipient (author = signed-in user, server timestamps — the
  /// exact write shape of the Care Notes composer), or updates the note this
  /// sheet was opened for.
  Future<void> _saveNote(BuildContext context) async {
    final text = _model.noteTextController?.text.trim() ?? '';
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write a note before saving.')),
      );
      return;
    }
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save a note.')),
      );
      return;
    }
    final existing = widget.note;
    if (existing == null && widget.careRecipientRef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a care recipient to add a note.'),
        ),
      );
      return;
    }
    try {
      if (existing != null) {
        await existing.reference.update(
          mapToFirestore({
            'noteText': text,
            'updatedAt': FieldValue.serverTimestamp(),
          }),
        );
      } else {
        await CareNotesRecord.collection.doc().set({
          ...createCareNotesRecordData(
            careRecipientRef: widget.careRecipientRef,
            noteText: text,
            createdBy: _signedInAuthor(),
          ),
          ...mapToFirestore({
            'noteDateTime': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }),
        });
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existing == null ? 'Note added.' : 'Note updated.'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the note. Please try again.'),
          ),
        );
      }
    }
  }

  /// Deletes the note this sheet was opened for — the sheet's existing confirm
  /// dialog, which used to pop a bool and delete nothing.
  Future<void> _deleteNote(BuildContext context) async {
    final note = widget.note;
    if (note == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (alertDialogContext) {
            return AlertDialog(
              title: Text('Delete Note?'),
              content: Text('This note will be permanently deleted'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(alertDialogContext, false),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(alertDialogContext, true),
                  child: Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await note.reference.delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note deleted.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete the note.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final authorName = _displayAuthor();
    final authorInitials = _initialsFor(authorName);
    // A new note has no timestamp yet (server-assigned on save); the header's
    // time slot is only meaningful for an existing note.
    final timeLabel = note == null ? 'New note' : widget.time;
    return Stack(
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 16.0),
          child: Container(
            child: Container(
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(28.0),
                shape: BoxShape.rectangle,
              ),
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Container(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                              Container(
                                width: 32.0,
                                height: 32.0,
                                decoration: BoxDecoration(
                                  color: valueOrDefault<Color>(
                                    widget!.authorBg,
                                    FlutterFlowTheme.of(context).primary,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                alignment: AlignmentDirectional(0.0, 0.0),
                                child: Text(
                                  authorInitials,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  style: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .override(
                                        font: GoogleFonts.nunito(
                                          fontWeight: FontWeight.w600,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelMedium
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .onSurface,
                                        fontSize: 12.16,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontStyle,
                                        lineHeight: 1.4,
                                      ),
                                  overflow: TextOverflow.clip,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    authorName,
                                    style: FlutterFlowTheme.of(context)
                                        .labelLarge
                                        .override(
                                          font: GoogleFonts.nunito(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelLarge
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelLarge
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .labelLarge
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelLarge
                                                  .fontStyle,
                                          lineHeight: 1.4,
                                        ),
                                  ),
                                  Text(
                                    timeLabel,
                                    style: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .override(
                                          font: GoogleFonts.nunito(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelSmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelSmall
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .labelSmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelSmall
                                                  .fontStyle,
                                          lineHeight: 1.3,
                                        ),
                                  ),
                                ].divide(SizedBox(height: 2.0)),
                              ),
                            ].divide(SizedBox(width: 8.0)),
                          ),
                          if (valueOrDefault<bool>(
                            widget!.isPrivate,
                            false,
                          ))
                            Container(
                              decoration: BoxDecoration(
                                color: valueOrDefault<Color>(
                                  valueOrDefault<bool>(
                                    widget!.isPrivate,
                                    false,
                                  )
                                      ? FlutterFlowTheme.of(context).warning
                                      : Colors.transparent,
                                  Colors.transparent,
                                ),
                                borderRadius: BorderRadius.circular(20.0),
                                shape: BoxShape.rectangle,
                              ),
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    8.0, 4.0, 8.0, 4.0),
                                child: Container(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.lock_rounded,
                                        color: valueOrDefault<Color>(
                                          valueOrDefault<bool>(
                                            widget!.isPrivate,
                                            false,
                                          )
                                              ? FlutterFlowTheme.of(context)
                                                  .onWarning
                                              : FlutterFlowTheme.of(context)
                                                  .secondaryText,
                                          FlutterFlowTheme.of(context)
                                              .secondaryText,
                                        ),
                                        size: 12.0,
                                      ),
                                      Text(
                                        'Private',
                                        style: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .override(
                                              font: GoogleFonts.nunito(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontStyle,
                                              ),
                                              color: valueOrDefault<Color>(
                                                valueOrDefault<bool>(
                                                  widget!.isPrivate,
                                                  false,
                                                )
                                                    ? FlutterFlowTheme.of(
                                                            context)
                                                        .onWarning
                                                    : FlutterFlowTheme.of(
                                                            context)
                                                        .secondaryText,
                                                FlutterFlowTheme.of(context)
                                                    .secondaryText,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelSmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelSmall
                                                      .fontStyle,
                                              lineHeight: 1.3,
                                            ),
                                      ),
                                    ].divide(SizedBox(width: 4.0)),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      // The composer. Before this the slot rendered a
                      // hardcoded demo sentence and Save was a print stub, so
                      // the sheet could not write a note at all. Same look as
                      // the Care Notes composer (filled, borderless, rounded).
                      TextField(
                        controller: _model.noteTextController,
                        focusNode: _model.noteTextFocusNode,
                        autofocus: false,
                        maxLines: 4,
                        minLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Write a care note…',
                          hintStyle:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.nunito(),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                  ),
                          filled: true,
                          fillColor:
                              FlutterFlowTheme.of(context).primaryBackground,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.0),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      Divider(
                        height: 16.0,
                        thickness: 1.0,
                        indent: 0.0,
                        endIndent: 0.0,
                        color: FlutterFlowTheme.of(context).alternate,
                      ),
                      Align(
                        alignment: AlignmentDirectional(0.0, 0.0),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 0.0, 10.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_model.showOldButton)
                                Expanded(
                                  child: Align(
                                    alignment: AlignmentDirectional(-1.0, 0.0),
                                    child: wrapWithModel(
                                      model: _model.buttonModel1,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ButtonWidget(
                                        icon: Icon(
                                          Icons.edit_rounded,
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          size: 24.0,
                                        ),
                                        iconPresent: true,
                                        iconEndPresent: false,
                                        content: 'Edit',
                                        variant: 'ghost',
                                        size: 'small',
                                        fullWidth: false,
                                        loading: false,
                                        disabled: false,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_model.showOldButton)
                                Expanded(
                                  child: Align(
                                    alignment: AlignmentDirectional(-1.0, 0.0),
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 0.0, 40.0, 0.0),
                                      child: wrapWithModel(
                                        model: _model.buttonModel2,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: ButtonWidget(
                                          icon: Icon(
                                            Icons.delete_outline_rounded,
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            size: 24.0,
                                          ),
                                          iconPresent: true,
                                          iconEndPresent: false,
                                          content: 'Delete',
                                          variant: 'ghost',
                                          size: 'small',
                                          fullWidth: false,
                                          loading: false,
                                          disabled: false,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (_model.showOldButton)
                                Expanded(
                                  child: Align(
                                    alignment: AlignmentDirectional(-1.0, 0.0),
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 0.0, 40.0, 0.0),
                                      child: wrapWithModel(
                                        model: _model.buttonModel3,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: ButtonWidget(
                                          icon: Icon(
                                            Icons.delete_outline_rounded,
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            size: 24.0,
                                          ),
                                          iconPresent: true,
                                          iconEndPresent: false,
                                          content: 'Delete',
                                          variant: 'ghost',
                                          size: 'small',
                                          fullWidth: false,
                                          loading: false,
                                          disabled: false,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              // Delete needs a note to delete: it is only
                              // offered when this sheet was opened for an
                              // existing note (composing a new one has nothing
                              // to remove). It now really deletes.
                              if (note != null)
                                Align(
                                alignment: AlignmentDirectional(0.0, 0.0),
                                child: FFButtonWidget(
                                  onPressed: () => _deleteNote(context),
                                  text: 'Delete',
                                  options: FFButtonOptions(
                                    width: 90.0,
                                    height: 30.0,
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        16.0, 0.0, 16.0, 0.0),
                                    iconPadding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 0.0),
                                    color: FlutterFlowTheme.of(context)
                                        .accentContainer,
                                    textStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .override(
                                          font: GoogleFonts.dmSans(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontStyle,
                                          ),
                                          color: Color(0xFFCA7676),
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontStyle,
                                        ),
                                    elevation: 0.0,
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                    ),
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                ),
                              ),
                              FFButtonWidget(
                                onPressed: () => _saveNote(context),
                                text: 'Save',
                                options: FFButtonOptions(
                                  width: 90.0,
                                  height: 30.0,
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      16.0, 0.0, 16.0, 0.0),
                                  iconPadding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 0.0),
                                  color: FlutterFlowTheme.of(context).primary,
                                  textStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .override(
                                        font: GoogleFonts.dmSans(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .fontStyle,
                                      ),
                                  elevation: 0.0,
                                  borderSide: BorderSide(
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                  ),
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                              ),
                            ]
                                .divide(SizedBox(width: 17.0))
                                .around(SizedBox(width: 17.0)),
                          ),
                        ),
                      ),
                    ].divide(SizedBox(height: 16.0)),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_model.showOldButton)
          Align(
            alignment: AlignmentDirectional(-1.0, 0.0),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 40.0, 0.0),
              child: wrapWithModel(
                model: _model.buttonModel4,
                updateCallback: () => safeSetState(() {}),
                child: ButtonWidget(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: FlutterFlowTheme.of(context).primaryText,
                    size: 24.0,
                  ),
                  iconPresent: true,
                  iconEndPresent: false,
                  content: 'Delete',
                  variant: 'ghost',
                  size: 'small',
                  fullWidth: false,
                  loading: false,
                  disabled: false,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
