import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/reports/care_report.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'doctor_report_range_sheet_model.dart';
export 'doctor_report_range_sheet_model.dart';

/// The date-range picker behind the Doctor Prep page's 'Export' action.
///
/// Owner-approved spec (2026-11-03): the report covers a user-selected range
/// with presets and no fixed window, defaulting to the last 30 days. The sheet
/// pops with the resolved [CareReportRange] (or null when dismissed), so the
/// page never has to guess what the caregiver picked.
class DoctorReportRangeSheetWidget extends StatefulWidget {
  const DoctorReportRangeSheetWidget({
    super.key,
    this.initialPreset = defaultCareReportPreset,
    this.now,
  });

  /// The preset the sheet starts on ('Last 30 days' by default).
  final CareReportPreset initialPreset;

  /// Injectable 'today', so the resolved dates are deterministic in tests.
  final DateTime? now;

  @override
  State<DoctorReportRangeSheetWidget> createState() =>
      _DoctorReportRangeSheetState();
}

class _DoctorReportRangeSheetState extends State<DoctorReportRangeSheetWidget> {
  late DoctorReportRangeSheetModel _model;

  late CareReportPreset _preset;
  DateTime? _customStart;
  DateTime? _customEnd;

  DateTime get _today => CareReportRange.dayOnly(widget.now ?? DateTime.now());

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DoctorReportRangeSheetModel());
    _preset = widget.initialPreset;
    // A custom range starts from the default period, so the pickers open on
    // something sensible instead of empty fields.
    _customStart = _today.subtract(const Duration(days: 29));
    _customEnd = _today;
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  CareReportRange get _range => careReportRangeFor(
        _preset,
        now: _today,
        customStart: _customStart,
        customEnd: _customEnd,
      );

  Future<void> _pickCustomDate({required bool isStart}) async {
    final initial = (isStart ? _customStart : _customEnd) ?? _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(_today) ? _today : initial,
      firstDate: DateTime(2000),
      lastDate: _today,
      helpText: isStart ? 'Report start date' : 'Report end date',
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isStart) {
        _customStart = CareReportRange.dayOnly(picked);
      } else {
        _customEnd = CareReportRange.dayOnly(picked);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

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
                'Choose a date range',
                style: theme.titleMedium.override(
                  font: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'The report includes only records saved in this period.',
                style: theme.bodySmall.override(
                  font: GoogleFonts.nunito(),
                  color: theme.secondaryText,
                  letterSpacing: 0.0,
                ),
              ),
              ...CareReportPreset.values.map(
                (preset) => _presetRow(context, preset),
              ),
              if (_preset == CareReportPreset.custom) ...[
                _customDateRow(context, isStart: true),
                _customDateRow(context, isStart: false),
              ],
              SizedBox(height: 8.0),
              wrapWithModel(
                model: _model.buttonModel,
                updateCallback: () => setState(() {}),
                child: ButtonWidget(
                  icon: Icon(
                    Icons.picture_as_pdf_rounded,
                    color: theme.onSecondary,
                    size: 24.0,
                  ),
                  iconPresent: true,
                  iconEndPresent: false,
                  content: 'Generate PDF',
                  variant: 'secondary',
                  size: 'medium',
                  fullWidth: true,
                  loading: false,
                  disabled: false,
                  onPressed: () => Navigator.of(context).pop(_range),
                ),
              ),
              SizedBox(height: 4.0),
              Text(
                'Covers ${_range.boundsLabel}',
                textAlign: TextAlign.center,
                style: theme.bodySmall.override(
                  font: GoogleFonts.nunito(),
                  color: theme.secondaryText,
                  letterSpacing: 0.0,
                ),
              ),
            ].divide(SizedBox(height: 8.0)),
          ),
        ),
      ),
    );
  }

  Widget _presetRow(BuildContext context, CareReportPreset preset) {
    final theme = FlutterFlowTheme.of(context);
    final selected = _preset == preset;
    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () => setState(() => _preset = preset),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? theme.secondary15 : Colors.transparent,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: selected ? theme.secondary30 : theme.alternate,
            width: 1.0,
          ),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(12.0, 10.0, 12.0, 10.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? theme.primary : theme.secondaryText,
                size: 20.0,
              ),
              Expanded(
                child: Text(
                  careReportPresetLabel(preset),
                  style: theme.bodyMedium.override(
                    font: GoogleFonts.nunito(),
                    color: theme.primaryText,
                    letterSpacing: 0.0,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              if (preset == CareReportPreset.custom)
                Text(
                  '${careReportDate(_customStart ?? _today)} - '
                  '${careReportDate(_customEnd ?? _today)}',
                  style: theme.labelSmall.override(
                    font: GoogleFonts.nunito(),
                    color: theme.secondaryText,
                    letterSpacing: 0.0,
                  ),
                ),
            ].divide(SizedBox(width: 12.0)),
          ),
        ),
      ),
    );
  }

  Widget _customDateRow(BuildContext context, {required bool isStart}) {
    final theme = FlutterFlowTheme.of(context);
    final value = (isStart ? _customStart : _customEnd) ?? _today;
    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () => _pickCustomDate(isStart: isStart),
      child: Container(
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(12.0, 10.0, 12.0, 10.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                isStart ? 'Start date' : 'End date',
                style: theme.bodyMedium.override(
                  font: GoogleFonts.nunito(),
                  color: theme.primaryText,
                  letterSpacing: 0.0,
                ),
              ),
              Text(
                careReportDate(value),
                style: theme.bodyMedium.override(
                  font: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                  color: theme.primary,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
