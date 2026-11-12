import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/pages/group/household_widget.dart' show HouseholdWidget;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'settings_group_child_model.dart';
export 'settings_group_child_model.dart';

class SettingsGroupChildWidget extends StatefulWidget {
  const SettingsGroupChildWidget({super.key});

  @override
  State<SettingsGroupChildWidget> createState() =>
      _SettingsGroupChildWidgetState();
}

class _SettingsGroupChildWidgetState extends State<SettingsGroupChildWidget> {
  late SettingsGroupChildModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SettingsGroupChildModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // SHARED CARE contents (U2, owner decision 2026-11-11): the Household card
    // moved here from between the SECURITY and SUPPORT groups. Same card,
    // styling and navigation as before — it just lives in its group now.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16.0),
        onTap: () => context.push(HouseholdWidget.routePath),
        child: Container(
          padding: EdgeInsetsDirectional.fromSTEB(20.0, 16.0, 20.0, 16.0),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(
                Icons.family_restroom_rounded,
                color: FlutterFlowTheme.of(context).primary,
              ),
              SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Household',
                      style: FlutterFlowTheme.of(context).titleMedium,
                    ),
                    Text(
                      'Members, invites, and roles in your Care Circle',
                      style: FlutterFlowTheme.of(context).bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
