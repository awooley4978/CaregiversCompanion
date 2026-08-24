// "Preferred Pharmacy" row for the Settings PREFERENCES group.
//
// Shows the currently chosen pharmacy and opens the picker on tap (set-once
// but editable). Writes the non-sensitive choice to the user's own
// `users/{uid}` doc via PharmacyService. Nothing sensitive is stored.
import 'package:flutter/material.dart';
import '/backend/pharmacy/pharmacy_service.dart';
import '/components/pharmacy_picker/pharmacy_picker.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';

class PharmacySettingRow extends StatefulWidget {
  const PharmacySettingRow({super.key});
  @override
  State<PharmacySettingRow> createState() => _PharmacySettingRowState();
}

class _PharmacySettingRowState extends State<PharmacySettingRow> {
  String? _currentId;
  String? _currentLabel;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = PharmacyService.currentUid();
    if (uid == null) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    final pref = await PharmacyService().getPreferredPharmacy(uid);
    if (mounted) {
      setState(() {
        _currentId = pref.id;
        _currentLabel = pref.label;
        _loaded = true;
      });
    }
  }

  Future<void> _edit() async {
    final uid = PharmacyService.currentUid();
    if (uid == null) return;
    final choice = await showPreferredPharmacyPicker(
      context,
      currentId: _currentId,
      currentLabel: _currentLabel,
    );
    if (choice == null || !mounted) return;
    await PharmacyService().setPreferredPharmacy(
      uid,
      id: choice.id,
      label: choice.label,
    );
    if (mounted) {
      setState(() {
        _currentId = choice.id;
        _currentLabel = choice.label;
      });
      showSnackbar(
        context,
        'Preferred pharmacy saved as '
        '${pharmacyDisplayName(choice.id, choice.label)}.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final display = !_loaded
        ? '…'
        : pharmacyDisplayName(_currentId, _currentLabel);
    return InkWell(
      onTap: _edit,
      child: Container(
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(24.0, 16.0, 24.0, 16.0),
          child: Container(
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36.0,
                  height: 36.0,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).accent15,
                    borderRadius: BorderRadius.circular(20.0),
                    shape: BoxShape.rectangle,
                  ),
                  alignment: AlignmentDirectional(0.0, 0.0),
                  child: Icon(
                    Icons.local_pharmacy_rounded,
                    color: FlutterFlowTheme.of(context).onSurface,
                    size: 20.0,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preferred Pharmacy',
                        style: FlutterFlowTheme.of(context).bodyLarge.override(
                              fontWeight: FontWeight.w600,
                              color: FlutterFlowTheme.of(context).primaryText,
                            ),
                      ),
                      Text(
                        display,
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              color: FlutterFlowTheme.of(context).secondaryText,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: FlutterFlowTheme.of(context).secondaryText,
                  size: 24.0,
                ),
              ].divide(SizedBox(width: 16.0)),
            ),
          ),
        ),
      ),
    );
  }
}
