import '/backend/backend.dart';
import '/components/add_meal_widget.dart';
import '/components/button/button_widget.dart';
import '/components/dashboard_notes_form/dashboard_notes_form_widget.dart';
import '/components/dashboard_task_card/dashboard_task_card_widget.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/components/patent_picker_sheet_widget.dart';
import '/components/section_header/section_header_widget.dart';
import '/components/vital_chip/vital_chip_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'c_daily_dashboard_widget.dart' show CDailyDashboardWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class CDailyDashboardModel extends FlutterFlowModel<CDailyDashboardWidget> {
  ///  Local state fields for this page.

  bool water1Done = false;

  DateTime? selectedDate;

  ///  State fields for stateful widgets in this page.

  // Model for SectionHeader.
  late SectionHeaderModel sectionHeaderModel1;
  // Model for VitalChip.
  late VitalChipModel vitalChipModel1;
  // Model for VitalChip.
  late VitalChipModel vitalChipModel2;
  // Model for VitalChip.
  late VitalChipModel vitalChipModel3;
  // Model for VitalChip.
  late VitalChipModel vitalChipModel4;
  // Model for SectionHeader.
  late SectionHeaderModel sectionHeaderModel2;
  // Model for Button.
  late ButtonModel buttonModel1;
  // Model for SectionHeader.
  late SectionHeaderModel sectionHeaderModel3;
  // Model for SectionHeader.
  late SectionHeaderModel sectionHeaderModel4;
  // Model for Button.
  late ButtonModel buttonModel3;

  @override
  void initState(BuildContext context) {
    sectionHeaderModel1 = createModel(context, () => SectionHeaderModel());
    vitalChipModel1 = createModel(context, () => VitalChipModel());
    vitalChipModel2 = createModel(context, () => VitalChipModel());
    vitalChipModel3 = createModel(context, () => VitalChipModel());
    vitalChipModel4 = createModel(context, () => VitalChipModel());
    sectionHeaderModel2 = createModel(context, () => SectionHeaderModel());
    buttonModel1 = createModel(context, () => ButtonModel());
    sectionHeaderModel3 = createModel(context, () => SectionHeaderModel());
    sectionHeaderModel4 = createModel(context, () => SectionHeaderModel());
    buttonModel3 = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    sectionHeaderModel1.dispose();
    vitalChipModel1.dispose();
    vitalChipModel2.dispose();
    vitalChipModel3.dispose();
    vitalChipModel4.dispose();
    sectionHeaderModel2.dispose();
    buttonModel1.dispose();
    sectionHeaderModel3.dispose();
    sectionHeaderModel4.dispose();
    buttonModel3.dispose();
  }
}
