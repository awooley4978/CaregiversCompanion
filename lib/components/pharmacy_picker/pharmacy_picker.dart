// Preferred Pharmacy picker (modal bottom sheet).
//
// Shown from the Settings PREFERENCES row and from the medication Reorder
// action when no pharmacy is set yet (owner req 4: prompt instead of doing
// nothing). The user picks one of the supported pharmacies, or "Other" and
// optionally types their pharmacy's name/label. Only the non-sensitive slug +
// optional label are returned/stored.
import 'package:flutter/material.dart';
import '/backend/pharmacy/pharmacy_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';

/// The result of picking a pharmacy in the sheet.
class PharmacyChoice {
  const PharmacyChoice({required this.id, this.label});
  final String id;
  final String? label;
}

/// Shows the preferred-pharmacy chooser. Returns the chosen pharmacy or null
/// if the user dismissed the sheet without picking.
Future<PharmacyChoice?> showPreferredPharmacyPicker(
  BuildContext context, {
  String? currentId,
  String? currentLabel,
}) {
  return showModalBottomSheet<PharmacyChoice>(
    isScrollControlled: true,
    backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
    context: context,
    builder: (context) => _PharmacyPickerSheet(
      currentId: currentId,
      currentLabel: currentLabel,
    ),
  );
}

class _PharmacyPickerSheet extends StatefulWidget {
  const _PharmacyPickerSheet({this.currentId, this.currentLabel});
  final String? currentId;
  final String? currentLabel;

  @override
  State<_PharmacyPickerSheet> createState() => _PharmacyPickerSheetState();
}

class _PharmacyPickerSheetState extends State<_PharmacyPickerSheet> {
  final _otherCtrl = TextEditingController();
  bool _showOtherField = false;

  @override
  void initState() {
    super.initState();
    _showOtherField = widget.currentId == kPharmacyOther;
    if (widget.currentLabel != null) {
      _otherCtrl.text = widget.currentLabel!;
    }
  }

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  void _pick(String id) {
    if (id != kPharmacyOther) {
      Navigator.of(context).pop(PharmacyChoice(id: id));
      return;
    }
    setState(() => _showOtherField = true);
  }

  void _confirmOther() {
    Navigator.of(context).pop(
      PharmacyChoice(id: kPharmacyOther, label: _otherCtrl.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Preferred Pharmacy',
                  style: FlutterFlowTheme.of(context)
                      .titleLarge
                      .override(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your pharmacy is used only to hand you off to its own '
                  'refill page. We never store your login or place orders for '
                  'you.',
                  style: FlutterFlowTheme.of(context).bodyMedium,
                ),
                const SizedBox(height: 16),
                for (final p in kPharmacies) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      p.id == kPharmacyOther
                          ? Icons.local_pharmacy_rounded
                          : Icons.storefront_rounded,
                      color: FlutterFlowTheme.of(context).onSurface,
                    ),
                    title: Text(p.name,
                        style: FlutterFlowTheme.of(context).bodyLarge),
                    trailing: widget.currentId == p.id &&
                            p.id != kPharmacyOther
                        ? Icon(Icons.check_circle_rounded,
                            color: FlutterFlowTheme.of(context).success)
                        : null,
                    onTap: () => _pick(p.id),
                  ),
                  if (p.id == kPharmacyOther) const Divider(height: 4),
                ],
                if (_showOtherField) ...[
                  TextField(
                    controller: _otherCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Pharmacy name/label (optional)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. Costco',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _confirmOther,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlutterFlowTheme.of(context).primary,
                        foregroundColor:
                            FlutterFlowTheme.of(context).onPrimary,
                      ),
                      child: const Text('Use this pharmacy'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
