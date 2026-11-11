// Edit-identity sheet (U2).
//
// Shown from the pencil on the Settings identity card. It only collects the
// caregiver's own display name and returns it (trimmed) — the caller does the
// `users/{uid}` write, so a failed save can be reported there. A blank name is
// rejected in the sheet: the sheet stays open with an inline error and nothing
// is returned. Design language follows the existing FlutterFlow modal sheets
// (e.g. the preferred-pharmacy picker): primaryBackground, 24px padding, a
// bold titleLarge heading, an outline-bordered TextField and a full-width
// primary button.
import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_theme.dart';

/// Shows the "edit your name" sheet. Returns the trimmed new name, or null if
/// the user dismissed it without saving.
Future<String?> showIdentityEditSheet(
  BuildContext context, {
  String? currentName,
}) {
  return showModalBottomSheet<String>(
    isScrollControlled: true,
    backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
    context: context,
    builder: (context) => _IdentityEditSheet(currentName: currentName),
  );
}

class _IdentityEditSheet extends StatefulWidget {
  const _IdentityEditSheet({this.currentName});

  final String? currentName;

  @override
  State<_IdentityEditSheet> createState() => _IdentityEditSheetState();
}

class _IdentityEditSheetState extends State<_IdentityEditSheet> {
  late final TextEditingController _nameCtrl;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.currentName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    Navigator.of(context).pop(name);
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
                  'Edit your name',
                  style: FlutterFlowTheme.of(context)
                      .titleLarge
                      .override(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'This is the name shown on your Settings card and to the '
                  'people in your Care Circle.',
                  style: FlutterFlowTheme.of(context).bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. Maria Alvarez',
                  ),
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error,
                    style: FlutterFlowTheme.of(context)
                        .bodySmall
                        .override(color: FlutterFlowTheme.of(context).error),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlutterFlowTheme.of(context).primary,
                      foregroundColor: FlutterFlowTheme.of(context).onPrimary,
                    ),
                    child: const Text('Save name'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
