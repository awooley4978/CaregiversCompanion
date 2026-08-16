import '/components/calendar_day_widget.dart';
import '/components/event_item_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'calendar_page_widget.dart' show CalendarPageWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class CalendarPageModel extends FlutterFlowModel<CalendarPageWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for CalendarDay.
  late CalendarDayModel calendarDayModel1;
  // Model for CalendarDay.
  late CalendarDayModel calendarDayModel2;
  // Model for CalendarDay.
  late CalendarDayModel calendarDayModel3;
  // Model for CalendarDay.
  late CalendarDayModel calendarDayModel4;
  // Model for CalendarDay.
  late CalendarDayModel calendarDayModel5;
  // Model for CalendarDay.
  late CalendarDayModel calendarDayModel6;
  // Model for CalendarDay.
  late CalendarDayModel calendarDayModel7;
  // Model for EventItem.
  late EventItemModel eventItemModel1;
  // Model for EventItem.
  late EventItemModel eventItemModel2;
  // Model for EventItem.
  late EventItemModel eventItemModel3;

  @override
  void initState(BuildContext context) {
    calendarDayModel1 = createModel(context, () => CalendarDayModel());
    calendarDayModel2 = createModel(context, () => CalendarDayModel());
    calendarDayModel3 = createModel(context, () => CalendarDayModel());
    calendarDayModel4 = createModel(context, () => CalendarDayModel());
    calendarDayModel5 = createModel(context, () => CalendarDayModel());
    calendarDayModel6 = createModel(context, () => CalendarDayModel());
    calendarDayModel7 = createModel(context, () => CalendarDayModel());
    eventItemModel1 = createModel(context, () => EventItemModel());
    eventItemModel2 = createModel(context, () => EventItemModel());
    eventItemModel3 = createModel(context, () => EventItemModel());
  }

  @override
  void dispose() {
    calendarDayModel1.dispose();
    calendarDayModel2.dispose();
    calendarDayModel3.dispose();
    calendarDayModel4.dispose();
    calendarDayModel5.dispose();
    calendarDayModel6.dispose();
    calendarDayModel7.dispose();
    eventItemModel1.dispose();
    eventItemModel2.dispose();
    eventItemModel3.dispose();
  }
}
