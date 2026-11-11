import '/components/pharmacy_setting_row/pharmacy_setting_row.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'settings_group_child2_model.dart';
export 'settings_group_child2_model.dart';

class SettingsGroupChild2Widget extends StatefulWidget {
  const SettingsGroupChild2Widget({super.key});

  @override
  State<SettingsGroupChild2Widget> createState() =>
      _SettingsGroupChild2WidgetState();
}

class _SettingsGroupChild2WidgetState extends State<SettingsGroupChild2Widget> {
  late SettingsGroupChild2Model _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SettingsGroupChild2Model());

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
        // U2 (owner decision 2026-11-11): the "Push Notifications" and
        // "Private Notes" switch rows are hidden until they have real
        // functionality. Neither switch persisted anything, and no push or
        // private-notes feature exists behind them. Only the functional
        // Preferred Pharmacy row remains in this group.
        const PharmacySettingRow(),
      ],
    );
  }
}
