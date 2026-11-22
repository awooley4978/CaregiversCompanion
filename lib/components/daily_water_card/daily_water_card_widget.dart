import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/backend/backend.dart';
import '/backend/water/water_intake.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';

/// Upper bound on the per-recipient water read.
///
/// The card only ever shows TODAY's total, and a day with more than this many
/// entries is not plausible (200 entries would be 1600 fl oz), so the read is
/// bounded rather than unbounded. The query is recipient-scoped and ordered
/// `intakeAt` descending — the field set the owner-approved `waterLogs` rules
/// and the composite index expect.
const int waterHistoryReadLimit = 200;

/// The resolved recipient's water entries, newest first.
///
/// Reads are recipient-scoped by the merged rules: a bare collection list or an
/// `orgId`-only query is DENIED, so every read must filter `careRecipientRef`.
/// With no recipient there is nothing to address and nothing is queried.
@visibleForTesting
Stream<List<WaterLogsRecord>> waterLogsForRecipient({
  required DocumentReference? recipientRef,
}) {
  if (recipientRef == null) {
    return Stream.value(const []);
  }
  return queryWaterLogsRecord(
    queryBuilder: (q) => q
        .where('careRecipientRef', isEqualTo: recipientRef)
        .orderBy('intakeAt', descending: true),
    limit: waterHistoryReadLimit,
  );
}

/// The Dashboard's "Daily Water Intake" card — the existing static card, made
/// real.
///
/// Owner decisions of 2026-11-13 (proposal §4/§9):
///  * tapping any glass logs ONE 8 fl oz entry at now for the resolved
///    recipient, attributed to the caller;
///  * a "Custom amount" affordance opens a one-field fl-oz sheet;
///  * a quick-add offers a ~5 s Undo that deletes exactly the document that
///    action created (and says so honestly when it cannot);
///  * tapping a drop BELOW today's total lowers it: ONE negative adjustment
///    document is written (owner decision 2026-11-22), capped at the caller's
///    own intake today so another caregiver's water is never reduced, and
///    nothing that already exists is edited or deleted. Undo removes exactly
///    that adjustment;
///  * the total is the real `sum(amountFlOz)` over the DEVICE-LOCAL day, and
///    each filled glass is 8 fl oz of intake actually logged today, capped at
///    the nine icons the design draws — the glasses are not a target and the
///    card carries no goal language;
///  * a failed read shows an honest error state, never a fabricated zero.
class DailyWaterCardWidget extends StatefulWidget {
  const DailyWaterCardWidget({
    super.key,
    required this.recipientRef,
    this.streamOverride,
  });

  /// The care recipient the card reads and writes for.
  final DocumentReference? recipientRef;

  /// Test-only stream override, so the honest failure state can be exercised
  /// without a network.
  @visibleForTesting
  final Stream<List<WaterLogsRecord>>? streamOverride;

  @override
  State<DailyWaterCardWidget> createState() => _DailyWaterCardWidgetState();
}

class _DailyWaterCardWidgetState extends State<DailyWaterCardWidget> {
  Stream<List<WaterLogsRecord>>? _stream;

  /// True while a write is in flight: the taps and the sheet's Add are
  /// disabled, so a double tap cannot create two records.
  bool _writing = false;

  /// The card's own status line (a rejected write, a missing household, …).
  String? _status;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _syncStream();
  }

  @override
  void didUpdateWidget(covariant DailyWaterCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipientRef?.path != widget.recipientRef?.path ||
        oldWidget.streamOverride != widget.streamOverride) {
      // The previous recipient's records are discarded the moment the
      // recipient changes: one recipient's intake is never shown under
      // another.
      _syncStream();
      _status = null;
      _statusIsError = false;
    }
  }

  void _syncStream() {
    _stream = widget.streamOverride ??
        waterLogsForRecipient(recipientRef: widget.recipientRef);
  }

  void _setStatus(String message, {required bool isError}) {
    if (!mounted) {
      return;
    }
    setState(() {
      _status = message;
      _statusIsError = isError;
    });
  }

  /// Writes ONE `waterLogs` document for the resolved recipient.
  ///
  /// `orgId` comes from the recipient record itself (never from local state),
  /// `loggedByUid` is the caller, and `intakeAt` is now — the three fields the
  /// owner-approved rules validate.
  ///
  /// Intake is written with a positive [amountFlOz]. A correction
  /// ([isAdjustment]) is written with a NEGATIVE [amountFlOz], a positive
  /// `amount` (the magnitude the rules require) and the `targetFlOz` drop it
  /// landed on, so a correction is always distinguishable from intake. Either
  /// way it is ONE new document: nothing existing is edited or deleted.
  Future<void> _writeWaterEntry({
    required double amountFlOz,
    required bool isAdjustment,
    double? targetFlOz,
    required String snackbarMessage,
    required bool offersUndo,
  }) async {
    final recipientRef = widget.recipientRef;
    if (recipientRef == null) {
      _setStatus(waterSelectRecipient, isError: true);
      return;
    }
    if (_writing) {
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _setStatus('You must be signed in to log water.', isError: true);
      return;
    }
    setState(() {
      _writing = true;
      _status = null;
    });

    try {
      final recipient = await CareRecipientsRecord.getDocumentOnce(recipientRef);
      final orgId = recipient.orgId.trim();
      if (orgId.isEmpty) {
        _setStatus(
          'This care recipient is not linked to a household, so water cannot '
          'be logged.',
          isError: true,
        );
        if (mounted) {
          setState(() => _writing = false);
        }
        return;
      }
      final docRef = WaterLogsRecord.collection.doc();
      await docRef.set(
        createWaterLogsRecordData(
          careRecipientRef: recipientRef,
          orgId: orgId,
          loggedByUid: uid,
          intakeAt: DateTime.now(),
          amount: amountFlOz.abs(),
          unit: waterUnitFlOz,
          amountFlOz: amountFlOz,
          adjustment: isAdjustment ? true : null,
          targetFlOz: isAdjustment ? targetFlOz : null,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() => _writing = false);
      // Re-read so the drops and the total always agree with Firestore.
      _syncStream();
      setState(() {});
      if (offersUndo) {
        _showUndo(docRef, snackbarMessage);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(snackbarMessage)),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _writing = false);
      _setStatus(
        'Could not save this water entry. Please try again.',
        isError: true,
      );
    }
  }

  /// A quick-add or a custom amount: one positive intake record.
  Future<void> _addWater(double amountFlOz, {required bool isQuickAdd}) {
    return _writeWaterEntry(
      amountFlOz: amountFlOz,
      isAdjustment: false,
      snackbarMessage: '${formatWaterFlOz(amountFlOz)} added',
      offersUndo: isQuickAdd,
    );
  }

  /// One tap on drop [glassNumber], decided from the records on screen.
  ///
  /// Above the total → fill (one positive record). Exactly at the total →
  /// nothing. Below the total → ONE negative adjustment, capped at the
  /// caller's own intake today; with none of their own, nothing is written and
  /// the honest reason is shown.
  Future<void> _onGlassTap(
    int glassNumber,
    List<WaterLogsRecord> records,
  ) async {
    final outcome = waterTapOutcome(
      glassNumber: glassNumber,
      logs: records,
      now: DateTime.now(),
      uid: FirebaseAuth.instance.currentUser?.uid ?? '',
    );
    if (outcome.isCorrection) {
      await _writeWaterEntry(
        amountFlOz: -outcome.amountFlOz,
        isAdjustment: true,
        targetFlOz: outcome.targetFlOz,
        snackbarMessage: outcome.message!,
        offersUndo: true,
      );
      return;
    }
    if (outcome.writes) {
      await _addWater(outcome.amountFlOz, isQuickAdd: true);
      return;
    }
    final message = outcome.message;
    if (message != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// The ~5 s Undo for an accidental quick-add or correction. Undo deletes
  /// exactly [docRef] — the document this action created — never "the latest
  /// record", and never anything that existed before the tap.
  void _showUndo(DocumentReference docRef, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: waterUndoWindow,
        content: Text(message),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _undo(docRef),
        ),
      ),
    );
  }

  /// Deletes the entry a quick-add created, under the caller's own author
  /// permission. A refused delete keeps the entry and says so.
  Future<void> _undo(DocumentReference docRef) async {
    try {
      await docRef.delete();
      if (!mounted) {
        return;
      }
      _syncStream();
      setState(() {});
    } catch (_) {
      if (!mounted) {
        return;
      }
      _setStatus(waterUndoKept, isError: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(waterUndoKept)),
      );
    }
  }

  Future<void> _openCustomAmountSheet() async {
    if (widget.recipientRef == null || _writing) {
      return;
    }
    final amount = await showModalBottomSheet<double>(
      isScrollControlled: true,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Padding(
            padding: MediaQuery.viewInsetsOf(context),
            child: const WaterCustomAmountSheetWidget(),
          ),
        );
      },
    );
    if (amount == null || !mounted) {
      return;
    }
    await _addWater(amount, isQuickAdd: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final hasRecipient = widget.recipientRef != null;

    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(36.0),
        shape: BoxShape.rectangle,
        border: Border.all(color: theme.tertiary, width: 1.0),
      ),
      // A minimum rather than a fixed height: the card grew a total/status line
      // and an honest error message must wrap instead of overflowing.
      constraints: const BoxConstraints(minHeight: 130.0),
      child: StreamBuilder<List<WaterLogsRecord>>(
        stream: _stream,
        builder: (context, snapshot) {
          final failed = snapshot.hasError;
          final loaded = snapshot.hasData;
          final records = snapshot.data ?? const <WaterLogsRecord>[];
          final now = DateTime.now();
          final total = waterTotalFlOz(records, now);
          final filled = failed ? 0 : waterGlassesFilled(total);
          final canAdd = hasRecipient && !_writing;
          // What each of the nine drops does, decided once per build from the
          // records on screen: fill, correction, or nothing.
          final tapOutcomes = [
            for (var glass = 1; glass <= waterGlassCount; glass++)
              waterTapOutcome(
                glassNumber: glass,
                logs: records,
                now: now,
                uid: FirebaseAuth.instance.currentUser?.uid ?? '',
              ),
          ];

          return Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58.2,
                height: 96.8,
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40.0),
                  ),
                ),
                child: Align(
                  alignment: AlignmentDirectional(0.0, 1.0),
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(15.0, 0.0, 0.0, 9.0),
                    child: Container(
                      width: 48.0,
                      height: 48.0,
                      decoration: BoxDecoration(
                        color: theme.tertiary,
                        borderRadius: BorderRadius.circular(28.0),
                        shape: BoxShape.rectangle,
                      ),
                      alignment: AlignmentDirectional(0.0, 0.0),
                      child: Icon(
                        Icons.water_drop,
                        color: theme.primaryText,
                        size: 24.0,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Water Intake',
                        style: theme.bodyLarge.override(
                          font: GoogleFonts.nunito(
                            fontWeight: FontWeight.w600,
                            fontStyle: theme.bodyLarge.fontStyle,
                          ),
                          color: theme.primaryText,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w600,
                          fontStyle: theme.bodyLarge.fontStyle,
                          lineHeight: 1.6,
                        ),
                      ),
                      Text(
                        'Click to add water',
                        style: theme.bodyLarge.override(
                          font: GoogleFonts.nunito(
                            fontWeight: FontWeight.w600,
                            fontStyle: theme.bodyLarge.fontStyle,
                          ),
                          color: theme.primaryText,
                          fontSize: 10.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w600,
                          fontStyle: theme.bodyLarge.fontStyle,
                          lineHeight: 1.6,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            0.0, 3.0, 0.0, 0.0),
                        child: Container(
                          key: const ValueKey('waterGlasses'),
                          width: 241.2,
                          height: 42.49,
                          decoration: BoxDecoration(
                            color: theme.secondaryBackground,
                            borderRadius: BorderRadius.circular(28.0),
                            shape: BoxShape.rectangle,
                          ),
                          alignment: AlignmentDirectional(0.0, 0.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              for (var glass = 0;
                                  glass < waterGlassCount;
                                  glass++)
                                Semantics(
                                  button: true,
                                  label:
                                      'Fill up to ${formatWaterFlOz((glass + 1) * waterGlassFlOz)}',
                                  child: GestureDetector(
                                    key: ValueKey('waterGlass$glass'),
                                    behavior: HitTestBehavior.opaque,
                                    // Tapping a drop ABOVE the total fills every
                                    // drop up to it in ONE record; tapping a drop
                                    // BELOW the total writes ONE negative
                                    // adjustment, capped at the caller's own
                                    // intake today; tapping the drop already at
                                    // the total writes nothing. A tap that has
                                    // something to say (no intake of your own to
                                    // give back) stays live so it can say it.
                                    onTap: canAdd &&
                                            (tapOutcomes[glass].writes ||
                                                tapOutcomes[glass].message !=
                                                    null)
                                        ? () => _onGlassTap(
                                              glass + 1,
                                              records,
                                            )
                                        : null,
                                    child: SizedBox(
                                      width: 26.0,
                                      height: 30.0,
                                      child: OverflowBox(
                                        maxWidth: 30.0,
                                        maxHeight: 30.0,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          alignment: AlignmentDirectional(
                                              0.0, 0.0),
                                          children: [
                                            Icon(
                                              Icons.water_drop_outlined,
                                              color: theme.primaryText,
                                              size: 30.0,
                                            ),
                                            if (glass < filled)
                                              Icon(
                                                Icons.water_drop,
                                                color: theme.primaryText,
                                                size: 30.0,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            2.0, 5.0, 0.0, 0.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (!hasRecipient)
                              Flexible(
                                child: Text(
                                  waterSelectRecipient,
                                  style: _smallStyle(theme),
                                ),
                              )
                            else if (failed)
                              Flexible(
                                child: Text(
                                  waterCouldNotLoad,
                                  key: const ValueKey('waterLoadError'),
                                  style: _smallStyle(theme),
                                ),
                              )
                            else if (loaded)
                              Text(
                                formatWaterFlOz(total),
                                key: const ValueKey('waterTotal'),
                                style: _smallStyle(theme),
                              ),
                            if (hasRecipient) ...[
                              SizedBox(width: 10.0),
                              InkWell(
                                key: const ValueKey('waterCustomAmount'),
                                onTap: canAdd ? _openCustomAmountSheet : null,
                                child: Text(
                                  'Custom amount',
                                  style: _smallStyle(theme).override(
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_status != null)
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              2.0, 4.0, 0.0, 0.0),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _status!,
                              key: const ValueKey('waterStatus'),
                              style: _smallStyle(theme).override(
                                color: _statusIsError
                                    ? theme.error
                                    : theme.primaryText,
                              ),
                            ),
                          ),
                        ),
                    ].divide(SizedBox(height: 2.0)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  TextStyle _smallStyle(FlutterFlowTheme theme) => theme.bodyLarge.override(
        font: GoogleFonts.nunito(
          fontWeight: FontWeight.w600,
          fontStyle: theme.bodyLarge.fontStyle,
        ),
        color: theme.primaryText,
        fontSize: 10.0,
        letterSpacing: 0.0,
        fontWeight: FontWeight.w600,
        fontStyle: theme.bodyLarge.fontStyle,
        lineHeight: 1.6,
      );
}

/// The "Custom amount" sheet: one fl-oz field plus Add and Cancel.
///
/// Invalid input names the field and its range, writes nothing, and is
/// announced through a live region — the app never guesses a value.
class WaterCustomAmountSheetWidget extends StatefulWidget {
  const WaterCustomAmountSheetWidget({super.key});

  @override
  State<WaterCustomAmountSheetWidget> createState() =>
      _WaterCustomAmountSheetWidgetState();
}

class _WaterCustomAmountSheetWidgetState
    extends State<WaterCustomAmountSheetWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final validation = validateWaterAmount(_controller.text);
    if (!validation.isValid) {
      setState(() => _error = validation.error);
      return;
    }
    Navigator.pop(context, validation.amount);
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add water',
                style: theme.titleMedium.override(
                  font: GoogleFonts.dmSans(
                    fontWeight: theme.titleMedium.fontWeight,
                    fontStyle: theme.titleMedium.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight: theme.titleMedium.fontWeight,
                  fontStyle: theme.titleMedium.fontStyle,
                ),
              ),
              TextField(
                key: const ValueKey('waterAmountField'),
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Amount (fl oz)',
                  hintStyle: theme.bodyMedium.override(
                    font: GoogleFonts.nunito(),
                    color: theme.secondaryText,
                  ),
                  filled: true,
                  fillColor: theme.secondaryBackground,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide(
                      color: theme.alternate,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide(
                      color: theme.alternate,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide(
                      color: theme.primary,
                      width: 1.0,
                    ),
                  ),
                ),
                style: theme.bodyMedium.override(
                  font: GoogleFonts.nunito(),
                  letterSpacing: 0.0,
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    key: const ValueKey('waterAmountError'),
                    style: theme.bodySmall.override(
                      font: GoogleFonts.nunito(),
                      color: theme.error,
                      letterSpacing: 0.0,
                    ),
                  ),
                ),
              FFButtonWidget(
                key: const ValueKey('waterAmountAdd'),
                onPressed: _submit,
                text: 'Add',
                options: FFButtonOptions(
                  height: 40.0,
                  padding:
                      EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
                  iconPadding:
                      EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                  color: theme.primary,
                  textStyle: theme.titleSmall.override(
                    font: GoogleFonts.dmSans(
                      fontWeight: theme.titleSmall.fontWeight,
                      fontStyle: theme.titleSmall.fontStyle,
                    ),
                    color: theme.onPrimary,
                    letterSpacing: 0.0,
                    fontWeight: theme.titleSmall.fontWeight,
                    fontStyle: theme.titleSmall.fontStyle,
                  ),
                  elevation: 0.0,
                  borderSide: BorderSide(
                    color: Colors.transparent,
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(24.0),
                ),
              ),
              FFButtonWidget(
                key: const ValueKey('waterAmountCancel'),
                onPressed: () => Navigator.pop(context),
                text: 'Cancel',
                options: FFButtonOptions(
                  height: 40.0,
                  padding:
                      EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
                  iconPadding:
                      EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                  color: theme.secondaryBackground,
                  textStyle: theme.titleSmall.override(
                    font: GoogleFonts.dmSans(
                      fontWeight: theme.titleSmall.fontWeight,
                      fontStyle: theme.titleSmall.fontStyle,
                    ),
                    color: theme.primaryText,
                    letterSpacing: 0.0,
                    fontWeight: theme.titleSmall.fontWeight,
                    fontStyle: theme.titleSmall.fontStyle,
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
      ),
    );
  }
}
