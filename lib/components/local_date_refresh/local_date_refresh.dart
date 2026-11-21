import 'dart:async';

import 'package:flutter/material.dart';

/// How long until the next LOCAL midnight, measured from [now].
///
/// The dose card's per-day "taken" state is decided by comparing LOCAL dates
/// (`isTakenForDay`), so the card has to be re-evaluated the moment the local
/// date changes — at local midnight, whatever the device's UTC offset is.
/// Building the target through `DateTime(...)` keeps that boundary the
/// device's own day rather than a fixed 24 hours, so it stays correct across a
/// daylight-saving change.
Duration durationUntilNextLocalMidnight(DateTime now) {
  final local = now.toLocal();
  final nextMidnight = DateTime(local.year, local.month, local.day + 1);
  final remaining = nextMidnight.difference(local);
  return remaining.isNegative ? Duration.zero : remaining;
}

/// Rebuilds its [builder] with the current local time whenever the local date
/// may have changed: at the next local midnight, and again whenever the app
/// returns to the foreground (a timer does not run reliably while the app is
/// suspended, so resuming re-checks the clock instead of trusting the timer).
///
/// Added for the Daily Dashboard's dose card, which computed `now` once per
/// build: an app left open overnight kept saying "All of today's doses are
/// taken." until some unrelated event forced a rebuild (owner report
/// 2026-11-21).
class LocalDateRefresh extends StatefulWidget {
  const LocalDateRefresh({
    super.key,
    required this.builder,
    this.clock,
  });

  /// Builds the subtree with the current local time.
  final Widget Function(BuildContext context, DateTime now) builder;

  /// Test seam: the clock to read instead of [DateTime.now]. Null in the app.
  final DateTime Function()? clock;

  @override
  State<LocalDateRefresh> createState() => _LocalDateRefreshState();
}

class _LocalDateRefreshState extends State<LocalDateRefresh>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    // The date may have changed while the app was backgrounded (the timer is
    // not guaranteed to fire there), so re-evaluate now and re-arm it.
    if (mounted) {
      setState(() {});
    }
    _scheduleMidnightRefresh();
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    // One extra second so the rebuild lands INSIDE the new local day even if
    // the timer fires a hair early.
    _midnightTimer = Timer(
      durationUntilNextLocalMidnight(_now) + const Duration(seconds: 1),
      () {
        if (!mounted) {
          return;
        }
        setState(() {});
        _scheduleMidnightRefresh();
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}
