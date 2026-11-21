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
  /// Live "taken" state for this card, seeded from the widget's `taken` param
  /// and flipped by the trailing check-circle control. The parent persists it
  /// back to the `medications` collection via `onTakenChanged`.
  ///
  /// This replaces the old read-only `taken` constructor value, which could
  /// never change after construction (audit-part3 §1a — the dead "Taken" stub).
  ///
  /// It starts at `false` and is seeded by [MedCardWidget]'s `initState`
  /// (`_model.taken = widget.taken`), NOT here: `FlutterFlowModel._init` runs
  /// `initState(context)` BEFORE it attaches the widget, so reading `widget!`
  /// in this method always threw "Null check operator used on a null value" and
  /// every medication card (and therefore the whole Medications page) rendered
  /// as a gray error block (owner report 2026-11-21).
  bool taken = false;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
