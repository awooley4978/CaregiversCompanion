import '/components/settings_item/settings_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'settings_group_child4_model.dart';
export 'settings_group_child4_model.dart';

class SettingsGroupChild4Widget extends StatefulWidget {
  const SettingsGroupChild4Widget({super.key});

  @override
  State<SettingsGroupChild4Widget> createState() =>
      _SettingsGroupChild4WidgetState();
}

class _SettingsGroupChild4WidgetState extends State<SettingsGroupChild4Widget> {
  late SettingsGroupChild4Model _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SettingsGroupChild4Model());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        wrapWithModel(
          model: _model.settingsItemModel1,
          updateCallback: () => safeSetState(() {}),
          child: SettingsItemWidget(
            hasSubtitle: false,
            icon: Icon(
              Icons.help_outline_rounded,
              color: FlutterFlowTheme.of(context).secondaryText,
              size: 20.0,
            ),
            iconBg: FlutterFlowTheme.of(context).primaryBackground,
            iconColor: FlutterFlowTheme.of(context).secondaryText,
            label: 'Help Center',
            showArrow: true,
            subtitle: '3 people have access',
            onTap: 'navigate:ClientProfiles',
          ),
        ),
        Divider(
          height: 16.0,
          thickness: 1.0,
          indent: 24.0,
          endIndent: 0.0,
          color: FlutterFlowTheme.of(context).alternate,
        ),
        wrapWithModel(
          model: _model.settingsItemModel2,
          updateCallback: () => safeSetState(() {}),
          child: SettingsItemWidget(
            hasSubtitle: false,
            icon: Icon(
              Icons.description_rounded,
              color: FlutterFlowTheme.of(context).secondaryText,
              size: 20.0,
            ),
            iconBg: FlutterFlowTheme.of(context).primaryBackground,
            iconColor: FlutterFlowTheme.of(context).secondaryText,
            label: 'Terms of Service',
            showArrow: true,
            subtitle: '3 people have access',
            onTap: 'navigate:ClientProfiles',
          ),
        ),
      ],
    );
  }
}
