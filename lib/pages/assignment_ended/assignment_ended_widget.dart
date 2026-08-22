// "Assignment ended" state — Professional product (D7 hard cutoff).
//
// Security phase 5 hardening (design §3.2, §6.3 item 10, §6.4 Professional).
// Under D7, a professional staff member's temporary assignment is hard-cut off
// exactly at `validUntil`; the rules then deny every further read and the app
// must never show a raw permission error for that mid-shift expiry. The
// Professional workflow does not exist yet, so this is a minimal, model-ready
// route/state that follows the existing design language (icon + message +
// primary action, matching the Household empty/denied states). It is clearly
// marked for the Professional product; the Care Circle surface never routes
// here (a family denial routes to the Household picker instead).
import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/a_client_directory/a_client_directory_widget.dart';

class AssignmentEndedWidget extends StatelessWidget {
  const AssignmentEndedWidget({super.key});

  static String routeName = 'AssignmentEnded';
  static String routePath = '/assignment-ended';

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.primary,
        foregroundColor: theme.onPrimary,
        title: Text('Assignment ended',
            style: theme.titleLarge?.copyWith(color: theme.onPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.safePop(),
        ),
      ),
      backgroundColor: theme.primaryBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_late_rounded,
                  size: 48.0, color: theme.secondaryText),
              const SizedBox(height: 12.0),
              Text(
                'This care assignment has ended',
                textAlign: TextAlign.center,
                style: theme.titleMedium,
              ),
              const SizedBox(height: 8.0),
              Text(
                'Your temporary care team assignment is no longer active. '
                'Contact your care organization to be assigned to a recipient '
                'again.',
                textAlign: TextAlign.center,
                style: theme.bodyMedium,
              ),
              const SizedBox(height: 8.0),
              Text(
                'Professional care assignment',
                style: theme.bodySmall?.copyWith(
                  color: theme.secondaryText,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16.0),
              FilledButton(
                onPressed: () =>
                    context.go(AClientDirectoryWidget.routePath),
                child: const Text('Back to care'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
