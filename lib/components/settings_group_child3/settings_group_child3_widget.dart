import '/components/settings_item/settings_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'settings_group_child3_model.dart';
export 'settings_group_child3_model.dart';

class SettingsGroupChild3Widget extends StatefulWidget {
  const SettingsGroupChild3Widget({super.key});

  @override
  State<SettingsGroupChild3Widget> createState() =>
      _SettingsGroupChild3WidgetState();
}

class _SettingsGroupChild3WidgetState extends State<SettingsGroupChild3Widget> {
  late SettingsGroupChild3Model _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SettingsGroupChild3Model());

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
              Icons.lock_outline_rounded,
              color: FlutterFlowTheme.of(context).secondaryText,
              size: 20.0,
            ),
            iconBg: FlutterFlowTheme.of(context).primaryBackground,
            iconColor: FlutterFlowTheme.of(context).secondaryText,
            label: 'Change Password',
            showArrow: true,
            subtitle: '3 people have access',
            onTap: 'navigate:ClientProfiles',
          ),
        ),
        // U2 (owner decision 2026-11-11): the "Biometric Login" row is hidden
        // until it has real functionality — there is no biometric plugin or
        // stored opt-in behind it. Only the Change Password row remains.
      ],
    );
  }
}
