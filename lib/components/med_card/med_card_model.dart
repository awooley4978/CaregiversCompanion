import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'med_card_widget.dart' show MedCardWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class MedCardModel extends FlutterFlowModel<MedCardWidget> {
  /// Live "taken" state for this card, initialized from the widget's `taken`
  /// param and flipped by the trailing check-circle control. The parent
  /// persists it back to the `medications` collection via `onTakenChanged`.
  ///
  /// This replaces the old read-only `taken` constructor value, which could
  /// never change after construction (audit-part3 §1a — the dead "Taken" stub).
  late bool taken;

  @override
  void initState(BuildContext context) {
    taken = widget!.taken;
  }

  @override
  void dispose() {}
}
