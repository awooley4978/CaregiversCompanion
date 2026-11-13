import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Product name shown in the Settings footer.
const String kAppProductName = 'Caregivers Companion';

/// Reads the app's version from the installed package (the `version:` in
/// `pubspec.yaml`, e.g. `1.0.0`), so the footer can never drift from the
/// build. Returns null when it cannot be read — no platform implementation
/// (a plain widget test throws `MissingPluginException`) or an empty version.
Future<String?> readAppPackageVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.trim();
    return version.isEmpty ? null : version;
  } catch (_) {
    return null;
  }
}

/// The footer text: the product name, plus the runtime version when one is
/// known. When the version is unavailable the product name renders alone —
/// never an error, never a placeholder or hardcoded version.
String appFooterLabel(String? version) {
  final trimmed = version?.trim() ?? '';
  return trimmed.isEmpty ? kAppProductName : '$kAppProductName v$trimmed';
}

/// The Settings footer's product/version line.
///
/// The version is read ONCE from [versionLoader] (default:
/// [readAppPackageVersion]) and the label degrades to the product name alone
/// if that lookup fails, so rendering never depends on the plugin being
/// present.
class AppVersionLabel extends StatefulWidget {
  const AppVersionLabel({super.key, this.versionLoader, this.style});

  /// Injectable version source (tests supply a fixed value or a failing one).
  final Future<String?> Function()? versionLoader;

  final TextStyle? style;

  @override
  State<AppVersionLabel> createState() => _AppVersionLabelState();
}

class _AppVersionLabelState extends State<AppVersionLabel> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final loader = widget.versionLoader ?? readAppPackageVersion;
    String? version;
    try {
      version = await loader();
    } catch (_) {
      version = null;
    }
    if (!mounted) {
      return;
    }
    setState(() => _version = version);
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      appFooterLabel(_version),
      style: widget.style,
    );
  }
}
