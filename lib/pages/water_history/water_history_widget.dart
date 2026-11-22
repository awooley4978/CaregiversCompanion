// Water History — the read-only list behind the Daily Water card's "History"
// link (owner direction 2026-11-22, water-history-spec.md, unit 1 of 2).
//
// What this screen does:
//  * lists the recipient's stored `waterLogs` documents grouped by
//    DEVICE-LOCAL day, newest day first, so previous days are reached by
//    scrolling (no date picker, calendar or range selector in this unit);
//  * each day header carries the day label ('Today' / 'Yesterday' / 'Nov 20')
//    and the day's totals — INTAKE (sum of positive amounts) and, when it
//    differs, the NET figure the card shows, labelled as such;
//  * each row carries the local time of the entry, its amount and who logged
//    it (the member's display name, else their email, else 'Unknown user');
//  * a correction reads "Adjusted −16 fl oz (to 32 fl oz)" and is drawn in the
//    secondary colour with a revert icon, so it is never mistaken for water
//    that was drunk;
//  * loading, error-with-Retry and empty are three honest, separate states — an
//    empty list never disguises a failed read.
//
// What this screen never does: it writes, edits, deletes or migrates nothing.
// There is no rules change and no schema change behind it — it is a pure read
// of records the water card already created.
//
// The read is recipient-scoped and bounded (see [waterHistoryWindowDays] and
// [waterHistoryMaxEntries]): an unconstrained `waterLogs` list is denied by the
// deployed rules, and the window/limit keep the query small.
import '/backend/backend.dart';
import '/backend/org/org_service.dart';
import '/backend/water/water_history.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/button/button_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WaterHistoryWidget extends StatefulWidget {
  const WaterHistoryWidget({
    super.key,
    this.careRecipients,
    this.now,
  });

  static String routeName = 'WaterHistory';
  static String routePath = '/waterHistory';

  /// The care recipient whose water entries are shown. When null the app-wide
  /// selection (`FFAppState().selectedCareRecipient`) is used; with neither,
  /// the screen says so instead of reading anyone else's records.
  final DocumentReference? careRecipients;

  /// Injectable "today", so 'Today'/'Yesterday' labels and the read window are
  /// deterministic in tests. Null means the device clock.
  final DateTime? now;

  @override
  State<WaterHistoryWidget> createState() => _WaterHistoryWidgetState();
}

class _WaterHistoryWidgetState extends State<WaterHistoryWidget> {
  DocumentReference? _recipientRef;
  String _recipientName = '';
  List<WaterHistoryDay> _days = const [];
  bool _loading = false;
  String? _loadError;

  /// Bumped on every load; a response carrying an older token belongs to a
  /// previous recipient and is thrown away.
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DocumentReference? get _currentRecipientRef =>
      widget.careRecipients ?? FFAppState().selectedCareRecipient;

  DateTime get _now => widget.now ?? DateTime.now();

  /// Reads the recipient, the bounded window of their water entries and the
  /// display names of the members who logged them.
  ///
  /// A failure of ANY of those reads is an error state with a Retry — never an
  /// empty list.
  Future<void> _load() async {
    final token = ++_loadToken;
    final ref = _currentRecipientRef;
    final now = _now;

    if (!mounted) {
      return;
    }
    setState(() {
      _recipientRef = ref;
      _recipientName = '';
      _days = const [];
      _loadError = null;
      _loading = ref != null;
    });

    if (ref == null) {
      return;
    }

    try {
      final recipient = await CareRecipientsRecord.getDocumentOnce(ref);
      // The window and the limit live with the query (water_history.dart): only
      // the most recent [waterHistoryWindowDays] local days are requested, at
      // most [waterHistoryMaxEntries] documents — never an unbounded read.
      final logs = await waterHistoryEntriesForRecipient(
        recipientRef: ref,
        now: now,
      );

      // Author names come from the members subcollection: a `users` document is
      // readable only by its own uid under the deployed rules, while the
      // member's displayName/email is what the vitals history resolves too.
      final authorNames = <String, String>{};
      final orgId = recipient.orgId.trim();
      if (orgId.isNotEmpty) {
        for (final uid in {for (final log in logs) log.loggedByUid}) {
          if (uid.isEmpty) {
            continue;
          }
          final member = await getMembership(orgId, uid);
          final name = (member?.displayName ?? '').trim();
          final email = (member?.email ?? '').trim();
          authorNames[uid] = name.isNotEmpty ? name : email;
        }
      }

      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _recipientName = recipient.name.trim();
        _days = groupWaterHistory(logs, now: now, authorNames: authorNames);
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = waterHistoryLoadError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        backgroundColor: theme.primaryBackground,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(24.0, 24.0, 24.0, 0.0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    FlutterFlowIconButton(
                      key: const ValueKey('waterHistoryBack'),
                      borderRadius: 20.0,
                      buttonSize: 40.0,
                      fillColor: theme.secondaryBackground,
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: theme.primaryText,
                        size: 24.0,
                      ),
                      onPressed: () => context.safePop(),
                    ),
                    SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            waterHistoryTitle,
                            style: theme.headlineMedium.override(
                              font: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.bold),
                              color: theme.primaryText,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.bold,
                              lineHeight: 1.3,
                            ),
                          ),
                          Text(
                            _recipientName,
                            style: theme.bodySmall.override(
                              font: GoogleFonts.nunito(),
                              color: theme.secondaryText,
                              letterSpacing: 0.0,
                              lineHeight: 1.5,
                            ),
                          ),
                        ].divide(SizedBox(height: 4.0)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.0),
                Expanded(child: _body(context, theme)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, FlutterFlowTheme theme) {
    if (_recipientRef == null) {
      return _message(theme, waterHistoryNoRecipient,
          key: const ValueKey('waterHistoryNoRecipient'));
    }
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 24.0,
          height: 24.0,
          child: CircularProgressIndicator(
            key: const ValueKey('waterHistoryLoading'),
            color: theme.primary,
          ),
        ),
      );
    }
    if (_loadError != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _message(theme, _loadError!,
              key: const ValueKey('waterHistoryError')),
          SizedBox(height: 12.0),
          // Retry re-runs the same bounded, recipient-scoped read.
          ButtonWidget(
            content: waterHistoryRetry,
            variant: 'primary',
            size: 'small',
            onPressed: _load,
          ),
        ],
      );
    }
    if (_days.isEmpty) {
      return _message(theme, waterHistoryEmpty,
          key: const ValueKey('waterHistoryEmpty'));
    }
    return ListView.separated(
      primary: false,
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 24.0),
      itemCount: _days.length,
      separatorBuilder: (_, __) => SizedBox(height: 12.0),
      itemBuilder: (context, index) => _dayCard(theme, _days[index]),
    );
  }

  /// One day: its label and totals, then one row per stored entry.
  Widget _dayCard(FlutterFlowTheme theme, WaterHistoryDay day) {
    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(24.0),
        shape: BoxShape.rectangle,
        border: Border.all(color: theme.alternate, width: 1.0),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
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
                Expanded(
                  child: Text(
                    day.label,
                    style: theme.titleSmall.override(
                      font: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                      color: theme.primaryText,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  day.totalsLabel,
                  key: ValueKey('waterHistoryDayTotals${day.day.toIso8601String()}'),
                  style: theme.bodySmall.override(
                    font: GoogleFonts.nunito(),
                    color: theme.primaryText,
                    letterSpacing: 0.0,
                    lineHeight: 1.5,
                  ),
                ),
              ],
            ),
            ...day.rows.map((row) => _row(theme, row)),
          ].divide(SizedBox(height: 8.0)),
        ),
      ),
    );
  }

  /// One entry: local time, amount and author. A correction is drawn in the
  /// secondary colour with a revert icon and its own wording, so it never reads
  /// as water that was drunk.
  Widget _row(FlutterFlowTheme theme, WaterHistoryRow row) {
    final color = row.isAdjustment ? theme.secondaryText : theme.primaryText;
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 72.0,
          child: Text(
            row.timeLabel,
            style: theme.bodySmall.override(
              font: GoogleFonts.nunito(),
              color: theme.secondaryText,
              letterSpacing: 0.0,
              lineHeight: 1.5,
            ),
          ),
        ),
        if (row.isAdjustment)
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 4.0, 0.0),
            child: Icon(
              Icons.undo_rounded,
              color: color,
              size: 16.0,
            ),
          ),
        Expanded(
          flex: 3,
          child: Text(
            row.amountLabel,
            style: theme.bodyMedium.override(
              font: GoogleFonts.nunito(
                fontWeight: row.isAdjustment ? FontWeight.w600 : null,
              ),
              color: color,
              letterSpacing: 0.0,
              lineHeight: 1.5,
            ),
          ),
        ),
        SizedBox(width: 8.0),
        Flexible(
          flex: 2,
          child: Text(
            row.authorLabel,
            textAlign: TextAlign.end,
            style: theme.bodySmall.override(
              font: GoogleFonts.nunito(),
              color: theme.secondaryText,
              letterSpacing: 0.0,
              lineHeight: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _message(FlutterFlowTheme theme, String message, {Key? key}) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 8.0),
      child: Text(
        message,
        key: key,
        style: theme.bodyMedium.override(
          font: GoogleFonts.nunito(),
          color: theme.secondaryText,
          letterSpacing: 0.0,
        ),
      ),
    );
  }
}
