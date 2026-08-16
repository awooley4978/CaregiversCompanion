import '/components/button/button_widget.dart';
import '/components/med_card/med_card_widget.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/components/refill_item/refill_item_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'd_medication_tracker_widget.dart' show DMedicationTrackerWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';

class DMedicationTrackerModel
    extends FlutterFlowModel<DMedicationTrackerWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for MedCard.
  late MedCardModel medCardModel1;
  // Model for MedCard.
  late MedCardModel medCardModel2;
  // Model for MedCard.
  late MedCardModel medCardModel3;
  // Model for MedCard.
  late MedCardModel medCardModel4;
  // Model for RefillItem.
  late RefillItemModel refillItemModel1;
  // Model for RefillItem.
  late RefillItemModel refillItemModel2;
  // Model for Button.
  late ButtonModel buttonModel;

  @override
  void initState(BuildContext context) {
    medCardModel1 = createModel(context, () => MedCardModel());
    medCardModel2 = createModel(context, () => MedCardModel());
    medCardModel3 = createModel(context, () => MedCardModel());
    medCardModel4 = createModel(context, () => MedCardModel());
    refillItemModel1 = createModel(context, () => RefillItemModel());
    refillItemModel2 = createModel(context, () => RefillItemModel());
    buttonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    medCardModel1.dispose();
    medCardModel2.dispose();
    medCardModel3.dispose();
    medCardModel4.dispose();
    refillItemModel1.dispose();
    refillItemModel2.dispose();
    buttonModel.dispose();
  }
}
