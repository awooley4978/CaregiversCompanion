import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'calendar_day_model.dart';
export 'calendar_day_model.dart';

class CalendarDayWidget extends StatefulWidget {
  const CalendarDayWidget({
    super.key,
    bool? selected,
    bool? isToday,
    String? day,
    String? dotColor,
  })  : this.selected = selected ?? false,
        this.isToday = isToday ?? false,
        this.day = day ?? '11',
        this.dotColor = dotColor ?? 'transparent';

  final bool selected;
  final bool isToday;
  final String day;
  final String dotColor;

  @override
  State<CalendarDayWidget> createState() => _CalendarDayWidgetState();
}

class _CalendarDayWidgetState extends State<CalendarDayWidget> {
  late CalendarDayModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CalendarDayModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
