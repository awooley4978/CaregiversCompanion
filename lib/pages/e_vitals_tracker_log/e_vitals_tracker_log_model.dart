import '/components/button/button_widget.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/components/tracker_card/tracker_card_widget.dart';
import '/components/trend_chip/trend_chip_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'e_vitals_tracker_log_widget.dart' show EVitalsTrackerLogWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class EVitalsTrackerLogModel extends FlutterFlowModel<EVitalsTrackerLogWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for TrackerCard.
  late TrackerCardModel trackerCardModel1;
  // Model for TrendChip.
  late TrendChipModel trendChipModel1;
  // Model for TrendChip.
  late TrendChipModel trendChipModel2;
  // Model for TrackerCard.
  late TrackerCardModel trackerCardModel2;
  // Model for TrackerCard.
  late TrackerCardModel trackerCardModel3;
  // Model for TextField.
  late TextFieldModel textFieldModel;
  // Model for Button.
  late ButtonModel buttonModel1;
  // Model for Button.
  late ButtonModel buttonModel2;

  @override
  void initState(BuildContext context) {
    trackerCardModel1 = createModel(context, () => TrackerCardModel());
    trendChipModel1 = createModel(context, () => TrendChipModel());
    trendChipModel2 = createModel(context, () => TrendChipModel());
    trackerCardModel2 = createModel(context, () => TrackerCardModel());
    trackerCardModel3 = createModel(context, () => TrackerCardModel());
    textFieldModel = createModel(context, () => TextFieldModel());
    buttonModel1 = createModel(context, () => ButtonModel());
    buttonModel2 = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    trackerCardModel1.dispose();
    trendChipModel1.dispose();
    trendChipModel2.dispose();
    trackerCardModel2.dispose();
    trackerCardModel3.dispose();
    textFieldModel.dispose();
    buttonModel1.dispose();
    buttonModel2.dispose();
  }
}
