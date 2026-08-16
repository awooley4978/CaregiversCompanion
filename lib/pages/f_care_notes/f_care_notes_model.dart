import '/backend/backend.dart';
import '/components/button/button_widget.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/components/note_card/note_card_widget.dart';
import '/components/tab_group/tab_group_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'f_care_notes_widget.dart' show FCareNotesWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class FCareNotesModel extends FlutterFlowModel<FCareNotesWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for TabGroup.
  late TabGroupModel tabGroupModel;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;
  // Model for NoteCard.
  late NoteCardModel noteCardModel1;
  // Model for NoteCard.
  late NoteCardModel noteCardModel2;
  // Model for NoteCard.
  late NoteCardModel noteCardModel3;
  // Model for NoteCard.
  late NoteCardModel noteCardModel4;
  // Model for Button.
  late ButtonModel buttonModel;

  @override
  void initState(BuildContext context) {
    tabGroupModel = createModel(context, () => TabGroupModel());
    noteCardModel1 = createModel(context, () => NoteCardModel());
    noteCardModel2 = createModel(context, () => NoteCardModel());
    noteCardModel3 = createModel(context, () => NoteCardModel());
    noteCardModel4 = createModel(context, () => NoteCardModel());
    buttonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    tabGroupModel.dispose();
    textFieldFocusNode?.dispose();
    textController?.dispose();

    noteCardModel1.dispose();
    noteCardModel2.dispose();
    noteCardModel3.dispose();
    noteCardModel4.dispose();
    buttonModel.dispose();
  }
}
