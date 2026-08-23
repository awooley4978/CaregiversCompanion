import '/backend/backend.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'f_care_notes_model.dart';
export 'f_care_notes_model.dart';

class FCareNotesWidget extends StatefulWidget {
  const FCareNotesWidget({super.key});

  static String routeName = 'FCareNotes';
  static String routePath = '/fCareNotes';

  @override
  State<FCareNotesWidget> createState() => _FCareNotesWidgetState();
}

class _FCareNotesWidgetState extends State<FCareNotesWidget> {
  late FCareNotesModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  /// The selected care recipient's name, shown on each note so the reader
  /// always knows which patient the note belongs to. This page is scoped to
  /// the currently selected care recipient.
  String _patientName = '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FCareNotesModel());
    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _openMenu(BuildContext context) async {
    await showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      enableDrag: false,
      context: context,
      builder: (context) => GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Padding(
          padding: MediaQuery.viewInsetsOf(context),
          child: NavMenuDirectoryWidget(),
        ),
      ),
    );
  }

  /// Writes a new note into `careNotes`, ref-linked to the selected care
  /// recipient. The Phase-4 rules enforce the parent-org gate via
  /// `careRecipientRef`, so this write path is org-scoped exactly like the
  /// existing note-card save — no rules change, no cross-user leakage.
  Future<void> _addNote(BuildContext context) async {
    final text = _model.textController?.text.trim() ?? '';
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write a note before saving.')),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save a note.')),
      );
      return;
    }
    final selected = FFAppState().selectedCareRecipient;
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a care recipient to add a note.'),
        ),
      );
      return;
    }
    // Author = the signed-in user; the created date/time is captured at
    // creation via server timestamps.
    final authorName = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : ((user.email?.trim().isNotEmpty ?? false)
            ? user.email!.trim()
            : 'Caregiver');
    try {
      await CareNotesRecord.collection.doc().set({
        ...createCareNotesRecordData(
          careRecipientRef: selected,
          noteText: text,
          createdBy: authorName,
        ),
        ...mapToFirestore({
          'noteDateTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      });
      _model.textController?.clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note added.')),
        );
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

  Future<void> _deleteNote(BuildContext context, CareNotesRecord note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text(
            'This note will be removed for everyone in the care circle.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await note.reference.delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note deleted.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete the note.')),
        );
      }
    }
  }

  Widget _buildNoteCard(
    BuildContext context,
    CareNotesRecord note,
    String patientName,
  ) {
    final theme = FlutterFlowTheme.of(context);
    final when = note.noteDateTime ?? note.createdAt;
    final timeLabel =
        when != null ? dateTimeFormat('MMM d, yyyy · hh:mm a', when) : '';
    final author =
        note.createdBy.trim().isNotEmpty ? note.createdBy.trim() : 'Caregiver';
    final initials = author
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(24.0),
        shape: BoxShape.rectangle,
      ),
      padding: EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36.0,
                height: 36.0,
                decoration: BoxDecoration(
                  color: theme.primary,
                  shape: BoxShape.circle,
                ),
                alignment: AlignmentDirectional(0.0, 0.0),
                child: Text(
                  initials.isEmpty ? 'C' : initials,
                  textAlign: TextAlign.center,
                  style: theme.labelMedium.override(
                    font: GoogleFonts.nunito(
                      fontWeight: FontWeight.w600,
                      color: theme.primaryText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author,
                      style: theme.titleSmall.override(
                        font: GoogleFonts.nunito(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (patientName.isNotEmpty)
                      Text(
                        'for $patientName',
                        style: theme.bodySmall.override(
                          font: GoogleFonts.nunito(),
                          color: theme.secondaryText,
                        ),
                      ),
                    if (timeLabel.isNotEmpty)
                      Text(
                        timeLabel,
                        style: theme.bodySmall.override(
                          font: GoogleFonts.nunito(),
                          color: theme.secondaryText,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.secondaryText,
                  size: 20.0,
                ),
                tooltip: 'Delete note',
                onPressed: () => _deleteNote(context, note),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Text(
            note.noteText,
            style: theme.bodyMedium.override(
              font: GoogleFonts.nunito(),
              color: theme.primaryText,
              lineHeight: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);
    final selected = FFAppState().selectedCareRecipient;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: theme.primaryBackground,
        body: SafeArea(
          child: SingleChildScrollView(
            primary: false,
            padding: EdgeInsetsDirectional.fromSTEB(20.0, 24.0, 20.0, 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header row: title + menu button.
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Care Notes',
                      style: theme.headlineSmall.override(
                        font: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    FlutterFlowIconButton(
                      borderRadius: 28.0,
                      buttonSize: 40.0,
                      fillColor: theme.secondaryBackground,
                      icon: Icon(
                        Icons.menu,
                        color: theme.secondaryText,
                        size: 24.0,
                      ),
                      onPressed: () => _openMenu(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                // Which patient these notes belong to.
                if (selected != null)
                  StreamBuilder<CareRecipientsRecord>(
                    stream: CareRecipientsRecord.getDocument(selected),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final name = snapshot.data!.name;
                        if (name.isNotEmpty && name != _patientName) {
                          _patientName = name;
                        }
                        return Text(
                          'Notes for ${name.isEmpty ? 'this care recipient' : name}',
                          style: theme.bodyMedium.override(
                            font: GoogleFonts.nunito(),
                            color: theme.secondaryText,
                          ),
                        );
                      }
                      return Text(
                        'Notes for this care recipient',
                        style: theme.bodyMedium.override(
                          font: GoogleFonts.nunito(),
                          color: theme.secondaryText,
                        ),
                      );
                    },
                  )
                else
                  Text(
                    'Select a care recipient to view and add notes.',
                    style: theme.bodyMedium.override(
                      font: GoogleFonts.nunito(),
                      color: theme.secondaryText,
                    ),
                  ),
                const SizedBox(height: 20.0),
                // Composer: write a new note.
                Container(
                  decoration: BoxDecoration(
                    color: theme.secondaryBackground,
                    borderRadius: BorderRadius.circular(20.0),
                    shape: BoxShape.rectangle,
                  ),
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _model.textController,
                        focusNode: _model.textFieldFocusNode,
                        autofocus: false,
                        maxLines: 4,
                        minLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Write a care note…',
                          hintStyle: theme.bodyMedium.override(
                            font: GoogleFonts.nunito(),
                            color: theme.secondaryText,
                          ),
                          filled: true,
                          fillColor: theme.primaryBackground,
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
                      const SizedBox(height: 12.0),
                      Align(
                        alignment: AlignmentDirectional(1.0, 0.0),
                        child: FFButtonWidget(
                          onPressed: () => _addNote(context),
                          text: 'Add Note',
                          icon: const Icon(
                            Icons.add_rounded,
                            size: 20.0,
                          ),
                          options: FFButtonOptions(
                            width: 150.0,
                            height: 44.0,
                            padding: EdgeInsetsDirectional.fromSTEB(
                                16.0, 0.0, 16.0, 0.0),
                            color: theme.primary,
                            textStyle: theme.titleSmall.override(
                              font: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28.0),
                Text(
                  'All Notes',
                  style: theme.titleMedium.override(
                    font: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12.0),
                // The notes list — a real stream, not a single record.
                StreamBuilder<List<CareNotesRecord>>(
                  stream: selected == null
                      ? Stream<List<CareNotesRecord>>.value(const [])
                      : queryCareNotesRecord(
                          queryBuilder: (careNotesRecord) => careNotesRecord
                              .where(
                                'careRecipientRef',
                                isEqualTo: selected,
                              )
                              .orderBy('createdAt', descending: true),
                        ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Text(
                          'Could not load notes. Please try again.',
                          textAlign: TextAlign.center,
                          style: theme.bodyMedium.override(
                            font: GoogleFonts.nunito(),
                            color: theme.secondaryText,
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48.0),
                          child: SizedBox(
                            width: 40.0,
                            height: 40.0,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.primary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    final notes = snapshot.data!;
                    if (notes.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        decoration: BoxDecoration(
                          color: theme.secondaryBackground,
                          borderRadius: BorderRadius.circular(20.0),
                          shape: BoxShape.rectangle,
                        ),
                        child: Text(
                          'No notes yet. Add your first note above.',
                          textAlign: TextAlign.center,
                          style: theme.bodyMedium.override(
                            font: GoogleFonts.nunito(),
                            color: theme.secondaryText,
                          ),
                        ),
                      );
                    }
                    final cards = <Widget>[];
                    for (var i = 0; i < notes.length; i++) {
                      cards.add(_buildNoteCard(context, notes[i], _patientName));
                      if (i < notes.length - 1) {
                        cards.add(const SizedBox(height: 12.0));
                      }
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: cards,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
