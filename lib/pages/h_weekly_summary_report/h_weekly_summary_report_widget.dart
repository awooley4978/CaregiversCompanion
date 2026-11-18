// Weekly Summary — real records instead of the invented report.
//
// The owner approved all eleven decisions of
// `/home/team/shared/weekly-summary-proposal-2026-11-17.md` (§13) on
// 2026-11-17. The screen keeps its existing design and structure; what changed
// is that every number, name and row on it now comes from a stored record, or
// is an honest empty state:
//
//  * the "Last 7 Days" row is a REAL range picker (the same preset sheet Doctor
//    Prep uses), defaulting to Last 7 days, and the date line prints the
//    resolved bounds;
//  * Vitals Overview: averages for BP and HR with the number of readings, the
//    LATEST reading for weight and glucose, dashes where nothing was recorded,
//    and a real daily systolic line with gaps on days with no reading;
//  * Care Logs: real care notes, vitals, water and appointments with their real
//    authors (symptoms are excluded — they store no author);
//  * Medications: the real current medication list and a real count; the
//    invented adherence donut, "2 doses missed" and "Most Frequent" are gone
//    because the app stores no dose history;
//  * Notes for Doctor: the period's important / follow-up care note, else the
//    most recent one, verbatim with its real author;
//  * both buttons are live and go to different destinations — "Export PDF
//    Report" shares/saves the generated PDF, "Print Summary" opens the print
//    dialog — and the share icon points at that same generated PDF;
//  * the page follows the app-wide selected care recipient (it takes no route
//    parameter); with no selection it shows an honest "select a care
//    recipient" state and both buttons are disabled.
//
// The PDF itself is the same care report Doctor Prep exports, over this page's
// range (`loadCareReportData` + `buildCareReportPdf`). No rules, schema or
// index change.
import '/backend/backend.dart';
import '/components/button/button_widget.dart';
import '/components/doctor_report_range_sheet/doctor_report_range_sheet_widget.dart';
import '/components/log_item/log_item_widget.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/components/section_header2/section_header2_widget.dart';
import '/components/summary_stat/summary_stat_widget.dart';
import '/flutter_flow/flutter_flow_charts.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/reports/care_report.dart';
import '/reports/care_report_pdf.dart';
import '/reports/weekly_summary.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'h_weekly_summary_report_model.dart';
export 'h_weekly_summary_report_model.dart';

/// Hands a generated PDF to a destination. Injectable so the two buttons can
/// be tested without a platform print/share sheet.
typedef WeeklySummaryPdfAction = Future<void> Function(
  Uint8List bytes,
  String fileName,
);

class HWeeklySummaryReportWidget extends StatefulWidget {
  const HWeeklySummaryReportWidget({
    super.key,
    this.now,
    this.sharePdf,
    this.printPdf,
  });

  static String routeName = 'HWeeklySummaryReport';
  static String routePath = '/hWeeklySummaryReport';

  /// Injectable 'today', so the resolved default range is deterministic in
  /// tests (the same approach the Calendar page takes).
  final DateTime? now;

  /// The "Export PDF Report" destination (defaults to the platform share /
  /// save sheet).
  final WeeklySummaryPdfAction? sharePdf;

  /// The "Print Summary" destination (defaults to the platform print dialog).
  final WeeklySummaryPdfAction? printPdf;

  @override
  State<HWeeklySummaryReportWidget> createState() =>
      _HWeeklySummaryReportWidgetState();
}

class _HWeeklySummaryReportWidgetState extends State<HWeeklySummaryReportWidget> {
  late HWeeklySummaryReportModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  /// The period this page reports on. Defaults to Last 7 days, which is what the
  /// screen is called.
  late CareReportRange _range;
  CareReportPreset _preset = CareReportPreset.last7Days;

  WeeklySummaryData? _summary;
  bool _loading = false;
  String? _loadError;

  /// True while a PDF is being built, so neither button can be tapped twice.
  bool _pdfBusy = false;

  /// Bumped on every load; a response for a previously selected recipient is
  /// discarded, so this page can never show another person's records.
  int _loadToken = 0;

  /// The recipient the currently shown data belongs to.
  String? _loadedForPath;

  /// The page takes no route parameter, so its recipient is the app-wide
  /// selection (the same fallback the Vitals tracker and water card use).
  DocumentReference? get _recipientRef => FFAppState().selectedCareRecipient;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HWeeklySummaryReportModel());
    _range = careReportRangeFor(CareReportPreset.last7Days, now: widget.now);

    FFAppState().addListener(_onAppStateChanged);
    _load();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    FFAppState().removeListener(_onAppStateChanged);
    _model.dispose();

    super.dispose();
  }

  /// The selection changed while this page is open (e.g. picked from the
  /// directory): reload for the new recipient and drop the old data.
  void _onAppStateChanged() {
    if (!mounted) {
      return;
    }
    if (FFAppState().selectedCareRecipient?.path == _loadedForPath) {
      return;
    }
    _load();
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    final ref = _recipientRef;
    _loadedForPath = ref?.path;

    if (!mounted) {
      return;
    }
    setState(() {
      _loading = ref != null;
      _loadError = null;
      _summary = null;
    });

    if (ref == null) {
      return;
    }

    try {
      final summary = await loadWeeklySummary(recipientRef: ref, range: _range);
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = 'Could not load this care recipient\'s records. '
            'Please check your connection and try again.';
      });
    }
  }

  /// The "Last 7 Days" row: a real range picker reusing the preset sheet the
  /// Doctor Prep export already uses.
  Future<void> _pickRange() async {
    final picked = await showModalBottomSheet<CareReportRange>(
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
            child: DoctorReportRangeSheetWidget(
              initialPreset: _preset,
              now: widget.now,
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _range = picked;
      _preset = _presetFor(picked);
    });
    await _load();
  }

  /// The preset behind a resolved range, so the sheet reopens on the current
  /// choice instead of jumping back to the default.
  CareReportPreset _presetFor(CareReportRange range) {
    for (final preset in CareReportPreset.values) {
      if (careReportPresetLabel(preset) == range.label) {
        return preset;
      }
    }
    return CareReportPreset.custom;
  }

  /// Builds the same care report Doctor Prep exports, over THIS page's range,
  /// and hands it to [share] (save/share sheet) or the print dialog.
  Future<void> _exportPdf({required bool share}) async {
    final ref = _recipientRef;
    if (ref == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a care recipient before exporting a summary.'),
        ),
      );
      return;
    }

    safeSetState(() => _pdfBusy = true);
    try {
      final report = await loadCareReportData(recipientRef: ref, range: _range);
      final bytes = await buildCareReportPdf(report);
      final fileName = careReportFileName(report);
      if (share) {
        await (widget.sharePdf ?? _sharePdf)(bytes, fileName);
      } else {
        await (widget.printPdf ?? _printPdf)(bytes, fileName);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not build the summary PDF. Please check your connection '
              'and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        safeSetState(() => _pdfBusy = false);
      }
    }
  }

  Future<void> _sharePdf(Uint8List bytes, String fileName) async {
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  Future<void> _printPdf(Uint8List bytes, String fileName) async {
    await Printing.layoutPdf(name: fileName, onLayout: (_) async => bytes);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    final summary = _summary;
    final hasRecipient = _recipientRef != null;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(0.0, 50.0, 0.0, 0.0),
          child: SingleChildScrollView(
            primary: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Weekly Summary', style: _titleStyle()),
                                Text(_subtitle(summary), style: _subtitleStyle()),
                              ].divide(SizedBox(height: 4.0)),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 10.0, 0.0),
                            child: FlutterFlowIconButton(
                              borderRadius: 20.0,
                              buttonSize: 40.0,
                              fillColor:
                                  FlutterFlowTheme.of(context).secondaryBackground,
                              icon: Icon(
                                Icons.share_rounded,
                                color: FlutterFlowTheme.of(context).primary,
                                size: 24.0,
                              ),
                              // The share icon now really shares this summary:
                              // the PDF generated for the period on screen.
                              onPressed: () => _exportPdf(share: true),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6.0),
                            child: FlutterFlowIconButton(
                              borderRadius: 28.0,
                              buttonSize: 40.0,
                              fillColor:
                                  FlutterFlowTheme.of(context).secondaryBackground,
                              icon: Icon(
                                Icons.menu,
                                color: FlutterFlowTheme.of(context).secondaryText,
                                size: 24.0,
                              ),
                              onPressed: () async {
                                await showModalBottomSheet(
                                  isScrollControlled: true,
                                  backgroundColor: FlutterFlowTheme.of(context)
                                      .primaryBackground,
                                  enableDrag: false,
                                  context: context,
                                  builder: (context) {
                                    return GestureDetector(
                                      onTap: () {
                                        FocusScope.of(context).unfocus();
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                      },
                                      child: Padding(
                                        padding: MediaQuery.viewInsetsOf(context),
                                        child: NavMenuDirectoryWidget(),
                                      ),
                                    );
                                  },
                                ).then((value) => safeSetState(() {}));
                              },
                            ),
                          ),
                        ],
                      ),
                      // The range row: a real picker over real dates.
                      InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: _pickRange,
                        child: Container(
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).secondaryBackground,
                            borderRadius: BorderRadius.circular(36.0),
                            shape: BoxShape.rectangle,
                            border: Border.all(
                              color: FlutterFlowTheme.of(context).alternate,
                              width: 1.0,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  color: FlutterFlowTheme.of(context).onSurface,
                                  size: 24.0,
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    _range.label,
                                    style: _rowLabelStyle(),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color:
                                      FlutterFlowTheme.of(context).secondaryText,
                                  size: 24.0,
                                ),
                              ].divide(SizedBox(width: 16.0)),
                            ),
                          ),
                        ),
                      ),
                      if (!hasRecipient)
                        _messageCard(
                          'Select a care recipient to see their weekly summary.',
                        )
                      else if (_loadError != null)
                        _messageCard(_loadError!)
                      else if (_loading || summary == null)
                        _messageCard('Loading this week\'s records…')
                      else ...[
                        _vitalsCard(summary),
                        _careLogsCard(summary),
                        _medicationsCard(summary),
                        _notesCard(summary),
                      ],
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            wrapWithModel(
                              model: _model.buttonModel1,
                              updateCallback: () => safeSetState(() {}),
                              child: ButtonWidget(
                                icon: Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: FlutterFlowTheme.of(context).primaryText,
                                  size: 24.0,
                                ),
                                iconPresent: true,
                                iconEndPresent: false,
                                content: 'Export PDF Report',
                                variant: 'primary',
                                size: 'small',
                                fullWidth: true,
                                loading: _pdfBusy,
                                disabled: !hasRecipient,
                                // Destination 1: save / share the file.
                                onPressed: () => _exportPdf(share: true),
                              ),
                            ),
                            wrapWithModel(
                              model: _model.buttonModel2,
                              updateCallback: () => safeSetState(() {}),
                              child: ButtonWidget(
                                icon: Icon(
                                  Icons.print_rounded,
                                  color: FlutterFlowTheme.of(context).primaryText,
                                  size: 24.0,
                                ),
                                iconPresent: true,
                                iconEndPresent: false,
                                content: 'Print Summary',
                                variant: 'outline',
                                size: 'small',
                                fullWidth: true,
                                loading: _pdfBusy,
                                disabled: !hasRecipient,
                                // Destination 2: the print dialog.
                                onPressed: () => _exportPdf(share: false),
                              ),
                            ),
                          ].divide(SizedBox(height: 16.0)),
                        ),
                      ),
                    ].divide(SizedBox(height: 24.0)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The date line: the resolved bounds, and whose summary it is.
  String _subtitle(WeeklySummaryData? summary) {
    final name = summary?.recipientName ?? '';
    return name.isEmpty
        ? _range.boundsLabel
        : '${_range.boundsLabel} · $name';
  }

  Widget _vitalsCard(WeeklySummaryData summary) {
    final vitals = summary.vitals;
    return _card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          wrapWithModel(
            model: _model.sectionHeaderModel1,
            updateCallback: () => safeSetState(() {}),
            child: SectionHeader2Widget(
              icon: Icon(
                Icons.help,
                color: FlutterFlowTheme.of(context).primary,
                size: 20.0,
              ),
              title: 'Vitals Overview',
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 1,
                child: wrapWithModel(
                  model: _model.summaryStatModel1,
                  updateCallback: () => safeSetState(() {}),
                  child: SummaryStatWidget(
                    label: vitals.hasBloodPressure
                        ? 'Avg. BP · ${readingsLabel(vitals.bloodPressureReadings)}'
                        : 'Avg. BP',
                    value: bloodPressureLabel(vitals) ?? '—',
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: wrapWithModel(
                  model: _model.summaryStatModel2,
                  updateCallback: () => safeSetState(() {}),
                  child: SummaryStatWidget(
                    label: vitals.hasHeartRate
                        ? 'Avg. HR · ${readingsLabel(vitals.heartRateReadings)}'
                        : 'Avg. HR',
                    value: heartRateLabel(vitals) ?? '—',
                  ),
                ),
              ),
            ].divide(SizedBox(width: 16.0)),
          ),
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 1,
                child: wrapWithModel(
                  model: _model.summaryStatModel3,
                  updateCallback: () => safeSetState(() {}),
                  child: SummaryStatWidget(
                    label: vitals.hasWeight
                        ? 'Weight · ${_shortDate(vitals.latestWeightAt)}'
                        : 'Weight',
                    value: weightLabel(vitals) ?? '—',
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: wrapWithModel(
                  model: _model.summaryStatModel4,
                  updateCallback: () => safeSetState(() {}),
                  child: SummaryStatWidget(
                    label: vitals.hasGlucose
                        ? 'Glucose · ${_shortDate(vitals.latestGlucoseAt)}'
                        : 'Glucose',
                    value: glucoseLabel(vitals) ?? '—',
                  ),
                ),
              ),
            ].divide(SizedBox(width: 16.0)),
          ),
          if (vitals.isEmpty)
            Text(
              'No vitals were recorded in this period.',
              style: _bodyStyle(),
            ),
          if (summary.dailySystolic.isEmpty)
            Text(
              'No blood pressure readings to chart in this period.',
              style: _bodyStyle(),
            )
          else
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
              child: SizedBox(
                height: 120.0,
                child: FlutterFlowLineChart(
                  data: [
                    for (final segment in summary.systolicSegments)
                      FFLineChartData(
                        xData: segment.map((point) => point.x.toDouble()).toList(),
                        yData: segment.map((point) => point.systolic).toList(),
                        settings: LineChartBarData(
                          color: FlutterFlowTheme.of(context).primary,
                          barWidth: 2.0,
                          isCurved: true,
                          // A day with no reading is a GAP: the line is drawn as
                          // one series per run of consecutive days, and an
                          // isolated day keeps its dot so it is still visible.
                          dotData: FlDotData(show: segment.length == 1),
                          belowBarData: BarAreaData(
                            show: true,
                            color: FlutterFlowTheme.of(context).primary10,
                          ),
                        ),
                      ),
                  ],
                  chartStylingInfo: ChartStylingInfo(
                    backgroundColor: Colors.transparent,
                    showBorder: false,
                  ),
                  axisBounds: AxisBounds(
                    minX: 0.0,
                    minY: summary.chartMinY,
                    maxX: summary.chartMaxX <= 0 ? 1.0 : summary.chartMaxX,
                    maxY: summary.chartMaxY,
                  ),
                  xLabels: summary.chartXLabels.isEmpty
                      ? null
                      : summary.chartXLabels,
                  xAxisLabelInfo: AxisLabelInfo(
                    showLabels: true,
                    labelTextStyle:
                        FlutterFlowTheme.of(context).bodySmall.override(
                              font: GoogleFonts.nunito(
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .fontStyle,
                              ),
                              color: FlutterFlowTheme.of(context).secondaryText,
                              fontSize: 10.0,
                              letterSpacing: 0.0,
                              fontWeight:
                                  FlutterFlowTheme.of(context).bodySmall.fontWeight,
                              fontStyle:
                                  FlutterFlowTheme.of(context).bodySmall.fontStyle,
                              lineHeight: 1.0,
                            ),
                    reservedSize: 28.0,
                  ),
                  yAxisLabelInfo: AxisLabelInfo(
                    reservedSize: 0.0,
                  ),
                ),
              ),
            ),
          if (summary.vitalsCapped)
            Text(
              'Showing the most recent $weeklySummaryVitalsLimit readings.',
              style: _captionStyle(),
            ),
        ].divide(SizedBox(height: 16.0)),
      ),
    );
  }

  Widget _careLogsCard(WeeklySummaryData summary) {
    final logModels = [
      _model.logItemModel1,
      _model.logItemModel2,
      _model.logItemModel3,
      _model.logItemModel4,
    ];
    final entries = summary.logEntries;
    return _card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          wrapWithModel(
            model: _model.sectionHeaderModel2,
            updateCallback: () => safeSetState(() {}),
            child: SectionHeader2Widget(
              icon: Icon(
                Icons.assignment_rounded,
                color: FlutterFlowTheme.of(context).primary,
                size: 20.0,
              ),
              title: 'Care Logs',
            ),
          ),
          if (entries.isEmpty)
            Text(
              'Nothing was logged in this period.',
              style: _bodyStyle(),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < entries.length && i < logModels.length; i++)
                  wrapWithModel(
                    model: logModels[i],
                    updateCallback: () => safeSetState(() {}),
                    child: LogItemWidget(
                      author: entries[i].author,
                      dotColor: _dotColor(entries[i].source),
                      text: entries[i].text,
                    ),
                  ),
              ].divide(SizedBox(height: 4.0)),
            ),
          if (summary.waterCapped)
            Text(
              'Showing the most recent $weeklySummaryWaterLimit water entries.',
              style: _captionStyle(),
            ),
        ].divide(SizedBox(height: 16.0)),
      ),
    );
  }

  /// The Medications card: the recipient's real CURRENT list and a real count.
  /// Adherence, missed doses and "most frequent" are gone — the app records no
  /// dose history, so no such number can be computed.
  Widget _medicationsCard(WeeklySummaryData summary) {
    final medications = summary.medications;
    return _card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          wrapWithModel(
            model: _model.sectionHeaderModel3,
            updateCallback: () => safeSetState(() {}),
            child: SectionHeader2Widget(
              icon: Icon(
                Icons.medication_rounded,
                color: FlutterFlowTheme.of(context).primary,
                size: 20.0,
              ),
              title: 'Medications',
            ),
          ),
          if (medications.isEmpty)
            Text('No medications on file.', style: _bodyStyle())
          else ...[
            Text(
              '${medications.length} '
              '${medications.length == 1 ? 'medication' : 'medications'} on file',
              style: _cardTitleStyle(),
            ),
            for (final medication in medications)
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      medication.name,
                      medication.dose,
                    ].where((part) => part.isNotEmpty).join(' · '),
                    style: _cardTitleStyle(),
                  ),
                  if (medication.schedule.isNotEmpty ||
                      medication.status.isNotEmpty)
                    Text(
                      [
                        medication.schedule,
                        medication.status,
                      ].where((part) => part.isNotEmpty).join(' · '),
                      style: _captionStyle(),
                    ),
                ].divide(SizedBox(height: 2.0)),
              ),
            Text(
              'This is the current medication list, not limited to the period '
              'above.',
              style: _captionStyle(),
            ),
          ],
        ].divide(SizedBox(height: 16.0)),
      ),
    );
  }

  /// Notes for Doctor: one real care note, verbatim, with its real author.
  Widget _notesCard(WeeklySummaryData summary) {
    final note = summary.doctorNote;
    return _card(
      border: Border.all(color: Color(0xFFE8DCC4), width: 1.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.sticky_note_2_rounded,
                color: FlutterFlowTheme.of(context).onSurface,
                size: 24.0,
              ),
              Text('Notes for Doctor', style: _cardTitleStyle()),
            ].divide(SizedBox(width: 8.0)),
          ),
          if (note == null)
            Text(
              'No care notes were recorded in this period.',
              style: _bodyStyle(),
            )
          else ...[
            Text(note.text, style: _bodyItalicStyle()),
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  note.author.isEmpty
                      ? _shortDate(note.at)
                      : '— ${note.author} · ${_shortDate(note.at)}',
                  style: _captionStyle(),
                ),
              ],
            ),
          ],
        ].divide(SizedBox(height: 16.0)),
      ),
    );
  }

  Widget _card({required Widget child, Border? border}) => Container(
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(36.0),
          shape: BoxShape.rectangle,
          border: border,
        ),
        child: Padding(padding: EdgeInsets.all(24.0), child: child),
      );

  /// An honest state in place of the cards (no recipient, or a failed read).
  Widget _messageCard(String message) => _card(
        child: Text(message, style: _bodyStyle()),
      );

  Color _dotColor(WeeklySummaryLogSource source) {
    switch (source) {
      case WeeklySummaryLogSource.careNote:
        return FlutterFlowTheme.of(context).tertiary;
      case WeeklySummaryLogSource.vitals:
        return FlutterFlowTheme.of(context).secondary;
      case WeeklySummaryLogSource.water:
        return FlutterFlowTheme.of(context).primary;
      case WeeklySummaryLogSource.appointment:
        return FlutterFlowTheme.of(context).warning;
    }
  }

  String _shortDate(DateTime? dateTime) =>
      dateTime == null ? '' : DateFormat('d MMM').format(dateTime.toLocal());

  TextStyle _titleStyle() => FlutterFlowTheme.of(context).headlineMedium.override(
        font: GoogleFonts.dmSans(
          fontWeight: FontWeight.bold,
          fontStyle: FlutterFlowTheme.of(context).headlineMedium.fontStyle,
        ),
        color: FlutterFlowTheme.of(context).onPrimaryContainer,
        letterSpacing: 0.0,
        fontWeight: FontWeight.bold,
        fontStyle: FlutterFlowTheme.of(context).headlineMedium.fontStyle,
        lineHeight: 1.3,
      );

  TextStyle _subtitleStyle() => FlutterFlowTheme.of(context).bodyMedium.override(
        font: GoogleFonts.nunito(
          fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
        ),
        color: FlutterFlowTheme.of(context).secondaryText,
        letterSpacing: 0.0,
        fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
        lineHeight: 1.6,
      );

  TextStyle _rowLabelStyle() => FlutterFlowTheme.of(context).bodyLarge.override(
        font: GoogleFonts.nunito(
          fontWeight: FontWeight.w500,
          fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
        ),
        color: FlutterFlowTheme.of(context).primaryText,
        letterSpacing: 0.0,
        fontWeight: FontWeight.w500,
        fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
        lineHeight: 1.6,
      );

  TextStyle _cardTitleStyle() =>
      FlutterFlowTheme.of(context).titleMedium.override(
            font: GoogleFonts.dmSans(
              fontWeight: FontWeight.bold,
              fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
            ),
            color: FlutterFlowTheme.of(context).onPrimaryContainer,
            letterSpacing: 0.0,
            fontWeight: FontWeight.bold,
            fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
            lineHeight: 1.45,
          );

  TextStyle _bodyStyle() => FlutterFlowTheme.of(context).bodyMedium.override(
        font: GoogleFonts.nunito(
          fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
        ),
        color: FlutterFlowTheme.of(context).onPrimaryContainer,
        letterSpacing: 0.0,
        fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
        lineHeight: 1.5,
      );

  TextStyle _bodyItalicStyle() => _bodyStyle().copyWith(
        fontStyle: FontStyle.italic,
      );

  TextStyle _captionStyle() => FlutterFlowTheme.of(context).labelSmall.override(
        font: GoogleFonts.nunito(
          fontWeight: FlutterFlowTheme.of(context).labelSmall.fontWeight,
          fontStyle: FlutterFlowTheme.of(context).labelSmall.fontStyle,
        ),
        color: FlutterFlowTheme.of(context).secondaryText,
        letterSpacing: 0.0,
        fontWeight: FlutterFlowTheme.of(context).labelSmall.fontWeight,
        fontStyle: FlutterFlowTheme.of(context).labelSmall.fontStyle,
        lineHeight: 1.3,
      );
}
