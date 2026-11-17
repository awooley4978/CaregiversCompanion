import '/backend/backend.dart';
import '/backend/org/org_service.dart';
import '/backend/symptoms/symptom_history.dart';
import '/components/symptom_log/symptom_log_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The recipient's REAL symptom history, opened by Doctor Visit Prep's
/// "Recent Observations" history icon.
///
/// Appointments unit, part 3 (owner decision 2026-11-16, proposal §7 item 9 =
/// option (a)). It lists the same `symptomEntries` documents the dashboard's
/// symptom flow writes — every one of them, newest first — through the same
/// recipient-scoped stream the dashboard uses, so a caregiver can read the
/// history behind the three-row summary on the page.
///
/// Nothing is invented: a recipient with no symptoms gets an honest empty
/// state, a failed read says so, and an entry with no logged time is shown
/// without a made-up timestamp.
class SymptomHistorySheetWidget extends StatefulWidget {
  const SymptomHistorySheetWidget({
    super.key,
    required this.recipientRef,
    this.now,
  });

  /// The care recipient whose symptoms are shown. Null means none is selected
  /// and the sheet says so instead of reading someone else's records.
  final DocumentReference? recipientRef;

  /// Injectable "today", so 'Today'/'Yesterday' labels are deterministic in
  /// tests. Null means the device clock.
  final DateTime? now;

  @override
  State<SymptomHistorySheetWidget> createState() =>
      _SymptomHistorySheetWidgetState();
}

class _SymptomHistorySheetWidgetState extends State<SymptomHistorySheetWidget> {
  /// Subscribed once (in initState) so a rebuild never re-subscribes.
  Stream<List<SymptomEntriesRecord>>? _symptoms;

  @override
  void initState() {
    super.initState();
    _symptoms = symptomEntriesForRecipient(recipientRef: widget.recipientRef);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.primaryBackground,
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
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  symptomHistoryTitle,
                  style: theme.titleMedium.override(
                    font: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FlutterFlowIconButton(
                  borderRadius: 20.0,
                  buttonSize: 40.0,
                  fillColor: theme.secondaryBackground,
                  icon: Icon(
                    Icons.close_rounded,
                    color: theme.secondaryText,
                    size: 24.0,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            SizedBox(height: 12.0),
            if (widget.recipientRef == null)
              _message(context, symptomHistoryNoRecipient)
            else
              StreamBuilder<List<SymptomEntriesRecord>>(
                stream: _symptoms,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _message(context, symptomHistoryLoadError);
                  }
                  if (!snapshot.hasData) {
                    return Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: SizedBox(
                          width: 24.0,
                          height: 24.0,
                          child: CircularProgressIndicator(
                            color: theme.primary,
                          ),
                        ),
                      ),
                    );
                  }
                  final records =
                      sortSymptomsNewestFirst(snapshot.data ?? const []);
                  if (records.isEmpty) {
                    return _message(context, symptomHistoryEmpty);
                  }
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.6,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: records.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12.0),
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return SymptomLogWidget(
                          color: record.isResolved
                              ? theme.success
                              : theme.primary,
                          icon: Icon(
                            record.isResolved
                                ? Icons.check_circle_outline_rounded
                                : Icons.medical_information_rounded,
                            color: record.isResolved
                                ? theme.success
                                : theme.primary,
                            size: 20.0,
                          ),
                          label: symptomEntryHeadline(record),
                          note: symptomEntryNote(record),
                          time: symptomEntrySubtitle(record, now: widget.now),
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _message(BuildContext context, String message) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 8.0),
      child: Text(
        message,
        style: theme.bodyMedium.override(
          font: GoogleFonts.nunito(),
          color: theme.secondaryText,
          letterSpacing: 0.0,
        ),
      ),
    );
  }
}
