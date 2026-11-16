// One day cell of the Calendar's week strip.
//
// The FlutterFlow export shipped this component as an empty `Container()`, so
// the strip the page renders never appeared. The appointments unit (part 2,
// proposal §7) makes it real: the day number comes from the device-local date,
// `isToday` marks the real today, `selected` marks the tapped day, and the dot
// under the number is shown only for a day that actually has appointments
// (colour from `appointmentType`, one neutral dot otherwise). Tapping a day
// selects it — the one behavioural addition the proposal calls for, without
// which the strip could not mean anything.
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'calendar_day_model.dart';
export 'calendar_day_model.dart';

class CalendarDayWidget extends StatefulWidget {
  const CalendarDayWidget({
    super.key,
    bool? selected,
    bool? isToday,
    String? day,
    String? dotColor,
    this.onTap,
  })  : this.selected = selected ?? false,
        this.isToday = isToday ?? false,
        this.day = day ?? '',
        this.dotColor = dotColor ?? 'transparent';

  final bool selected;
  final bool isToday;
  final String day;

  /// The dot tone: 'primary', 'tertiary', 'warning', 'success', 'error',
  /// 'neutral', or 'transparent' for a day with no appointments.
  final String dotColor;

  /// Called when the day is tapped. Null leaves the cell inert.
  final VoidCallback? onTap;

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

  Color _dotColor(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    switch (widget.dotColor) {
      case 'primary':
        return theme.primary;
      case 'tertiary':
        return theme.tertiary;
      case 'warning':
        return theme.warning;
      case 'success':
        return theme.success;
      case 'error':
        return theme.error;
      case 'accent':
        return theme.accent3;
      case 'neutral':
        return theme.secondaryText;
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final highlighted = widget.selected || widget.isToday;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(0.0, 4.0, 0.0, 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36.0,
              height: 36.0,
              decoration: BoxDecoration(
                color: widget.selected ? theme.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isToday && !widget.selected
                      ? theme.primary
                      : Colors.transparent,
                  width: 1.0,
                ),
              ),
              alignment: AlignmentDirectional(0.0, 0.0),
              child: Text(
                widget.day,
                style: theme.titleSmall.override(
                  font: GoogleFonts.dmSans(
                    fontWeight:
                        highlighted ? FontWeight.bold : FontWeight.normal,
                    fontStyle: theme.titleSmall.fontStyle,
                  ),
                  color: widget.selected ? Colors.white : theme.primaryText,
                  fontSize: 14.0,
                  letterSpacing: 0.0,
                  fontWeight:
                      highlighted ? FontWeight.bold : FontWeight.normal,
                  fontStyle: theme.titleSmall.fontStyle,
                  lineHeight: 1.4,
                ),
              ),
            ),
            SizedBox(height: 6.0),
            Container(
              width: 6.0,
              height: 6.0,
              decoration: BoxDecoration(
                color: _dotColor(context),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
