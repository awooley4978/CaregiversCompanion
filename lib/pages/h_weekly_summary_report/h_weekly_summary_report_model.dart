import '/components/button/button_widget.dart';
import '/components/log_item/log_item_widget.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/components/section_header2/section_header2_widget.dart';
import '/components/share_menu/share_menu_widget.dart';
import '/components/summary_stat/summary_stat_widget.dart';
import '/flutter_flow/flutter_flow_charts.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'h_weekly_summary_report_widget.dart' show HWeeklySummaryReportWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class HWeeklySummaryReportModel
    extends FlutterFlowModel<HWeeklySummaryReportWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for SectionHeader.
  late SectionHeader2Model sectionHeaderModel1;
  // Model for SummaryStat.
  late SummaryStatModel summaryStatModel1;
  // Model for SummaryStat.
  late SummaryStatModel summaryStatModel2;
  // Model for SummaryStat.
  late SummaryStatModel summaryStatModel3;
  // Model for SummaryStat.
  late SummaryStatModel summaryStatModel4;
  // Model for SectionHeader.
  late SectionHeader2Model sectionHeaderModel2;
  // Model for LogItem.
  late LogItemModel logItemModel1;
  // Model for LogItem.
  late LogItemModel logItemModel2;
  // Model for LogItem.
  late LogItemModel logItemModel3;
  // Model for LogItem.
  late LogItemModel logItemModel4;
  // Model for SectionHeader.
  late SectionHeader2Model sectionHeaderModel3;
  // Model for Button.
  late ButtonModel buttonModel1;
  // Model for Button.
  late ButtonModel buttonModel2;

  @override
  void initState(BuildContext context) {
    sectionHeaderModel1 = createModel(context, () => SectionHeader2Model());
    summaryStatModel1 = createModel(context, () => SummaryStatModel());
    summaryStatModel2 = createModel(context, () => SummaryStatModel());
    summaryStatModel3 = createModel(context, () => SummaryStatModel());
    summaryStatModel4 = createModel(context, () => SummaryStatModel());
    sectionHeaderModel2 = createModel(context, () => SectionHeader2Model());
    logItemModel1 = createModel(context, () => LogItemModel());
    logItemModel2 = createModel(context, () => LogItemModel());
    logItemModel3 = createModel(context, () => LogItemModel());
    logItemModel4 = createModel(context, () => LogItemModel());
    sectionHeaderModel3 = createModel(context, () => SectionHeader2Model());
    buttonModel1 = createModel(context, () => ButtonModel());
    buttonModel2 = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    sectionHeaderModel1.dispose();
    summaryStatModel1.dispose();
    summaryStatModel2.dispose();
    summaryStatModel3.dispose();
    summaryStatModel4.dispose();
    sectionHeaderModel2.dispose();
    logItemModel1.dispose();
    logItemModel2.dispose();
    logItemModel3.dispose();
    logItemModel4.dispose();
    sectionHeaderModel3.dispose();
    buttonModel1.dispose();
    buttonModel2.dispose();
  }
}
