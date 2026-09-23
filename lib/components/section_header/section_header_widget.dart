import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'section_header_model.dart';
export 'section_header_model.dart';

class SectionHeaderWidget extends StatefulWidget {
  const SectionHeaderWidget({
    super.key,
    String? action,
    String? title,
    this.onAction,
  })  : this.action = action ?? 'Log New',
        this.title = title ?? 'Morning Vitals';

  final String action;
  final String title;

  /// Optional tap action for the header's trailing button.
  ///
  /// The exported component built that button with NO `onPressed` and no
  /// surrounding InkWell, so every section header that passed an [action]
  /// ('Log New', 'View Schedule', ...) rendered a button that looked tappable
  /// and did nothing (owner round-5 finding #3: "multiple 'Add New' on the page
  /// but none are clickable").
  ///
  /// When this is null the header renders NO button at all: a section whose
  /// create flow does not exist yet must not advertise one. That also removes
  /// the misleading label the export produced for `action: ''`
  /// (`valueOrDefault` treated the empty string as absent and fell back to the
  /// component's 'Log New' default).
  final VoidCallback? onAction;

  @override
  State<SectionHeaderWidget> createState() => _SectionHeaderWidgetState();
}

class _SectionHeaderWidgetState extends State<SectionHeaderWidget> {
  late SectionHeaderModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SectionHeaderModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 16.0),
      child: Container(
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              valueOrDefault<String>(
                widget!.title,
                'Morning Vitals',
              ),
              style: FlutterFlowTheme.of(context).titleMedium.override(
                    font: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleMedium.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).primaryText,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleMedium.fontStyle,
                    lineHeight: 1.45,
                  ),
            ),
            // No action -> no button. The header then renders exactly as it did
            // visually for a section with nothing to tap, instead of an inert
            // button-shaped label.
            if (widget!.onAction != null)
              wrapWithModel(
                model: _model.buttonModel,
                updateCallback: () => safeSetState(() {}),
                child: ButtonWidget(
                  iconPresent: false,
                  iconEndPresent: false,
                  content: valueOrDefault<String>(
                    widget!.action,
                    'Log New',
                  ),
                  variant: 'ghost',
                  size: 'small',
                  fullWidth: false,
                  loading: false,
                  disabled: false,
                  onPressed: widget!.onAction,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
