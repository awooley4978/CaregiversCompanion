// ignore_for_file: overridden_fields, annotate_overrides

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class FlutterFlowTheme {
  static FlutterFlowTheme of(BuildContext context) {
    return LightModeTheme();
  }

  @Deprecated('Use primary instead')
  Color get primaryColor => primary;
  @Deprecated('Use secondary instead')
  Color get secondaryColor => secondary;
  @Deprecated('Use tertiary instead')
  Color get tertiaryColor => tertiary;

  late Color primary;
  late Color secondary;
  late Color tertiary;
  late Color alternate;
  late Color primaryText;
  late Color secondaryText;
  late Color primaryBackground;
  late Color secondaryBackground;
  late Color accent1;
  late Color accent2;
  late Color accent3;
  late Color accent4;
  late Color success;
  late Color warning;
  late Color error;
  late Color info;

  late Color onPrimary;
  late Color primaryContainer;
  late Color onPrimaryContainer;
  late Color onSecondary;
  late Color secondaryContainer;
  late Color onSecondaryContainer;
  late Color onAccent;
  late Color accentContainer;
  late Color onAccentContainer;
  late Color onBackground;
  late Color onSurface;
  late Color surfaceVariant;
  late Color onSurfaceVariant;
  late Color onSuccess;
  late Color onWarning;
  late Color onError;
  late Color onInfo;
  late Color transparent;
  late Color fullContrast;
  late Color primary10;
  late Color info10;
  late Color info20;
  late Color secondary20;
  late Color onPrimary27;
  late Color secondary15;
  late Color secondary30;
  late Color surfaceVariant30;
  late Color onSurface80;
  late Color primary15;
  late Color accent15;
  late Color customColor1;

  FFDesignTokens get designToken => FFDesignTokens(this);

  @Deprecated('Use displaySmallFamily instead')
  String get title1Family => displaySmallFamily;
  @Deprecated('Use displaySmall instead')
  TextStyle get title1 => typography.displaySmall;
  @Deprecated('Use headlineMediumFamily instead')
  String get title2Family => typography.headlineMediumFamily;
  @Deprecated('Use headlineMedium instead')
  TextStyle get title2 => typography.headlineMedium;
  @Deprecated('Use headlineSmallFamily instead')
  String get title3Family => typography.headlineSmallFamily;
  @Deprecated('Use headlineSmall instead')
  TextStyle get title3 => typography.headlineSmall;
  @Deprecated('Use titleMediumFamily instead')
  String get subtitle1Family => typography.titleMediumFamily;
  @Deprecated('Use titleMedium instead')
  TextStyle get subtitle1 => typography.titleMedium;
  @Deprecated('Use titleSmallFamily instead')
  String get subtitle2Family => typography.titleSmallFamily;
  @Deprecated('Use titleSmall instead')
  TextStyle get subtitle2 => typography.titleSmall;
  @Deprecated('Use bodyMediumFamily instead')
  String get bodyText1Family => typography.bodyMediumFamily;
  @Deprecated('Use bodyMedium instead')
  TextStyle get bodyText1 => typography.bodyMedium;
  @Deprecated('Use bodySmallFamily instead')
  String get bodyText2Family => typography.bodySmallFamily;
  @Deprecated('Use bodySmall instead')
  TextStyle get bodyText2 => typography.bodySmall;

  String get displayLargeFamily => typography.displayLargeFamily;
  bool get displayLargeIsCustom => typography.displayLargeIsCustom;
  TextStyle get displayLarge => typography.displayLarge;
  String get displayMediumFamily => typography.displayMediumFamily;
  bool get displayMediumIsCustom => typography.displayMediumIsCustom;
  TextStyle get displayMedium => typography.displayMedium;
  String get displaySmallFamily => typography.displaySmallFamily;
  bool get displaySmallIsCustom => typography.displaySmallIsCustom;
  TextStyle get displaySmall => typography.displaySmall;
  String get headlineLargeFamily => typography.headlineLargeFamily;
  bool get headlineLargeIsCustom => typography.headlineLargeIsCustom;
  TextStyle get headlineLarge => typography.headlineLarge;
  String get headlineMediumFamily => typography.headlineMediumFamily;
  bool get headlineMediumIsCustom => typography.headlineMediumIsCustom;
  TextStyle get headlineMedium => typography.headlineMedium;
  String get headlineSmallFamily => typography.headlineSmallFamily;
  bool get headlineSmallIsCustom => typography.headlineSmallIsCustom;
  TextStyle get headlineSmall => typography.headlineSmall;
  String get titleLargeFamily => typography.titleLargeFamily;
  bool get titleLargeIsCustom => typography.titleLargeIsCustom;
  TextStyle get titleLarge => typography.titleLarge;
  String get titleMediumFamily => typography.titleMediumFamily;
  bool get titleMediumIsCustom => typography.titleMediumIsCustom;
  TextStyle get titleMedium => typography.titleMedium;
  String get titleSmallFamily => typography.titleSmallFamily;
  bool get titleSmallIsCustom => typography.titleSmallIsCustom;
  TextStyle get titleSmall => typography.titleSmall;
  String get labelLargeFamily => typography.labelLargeFamily;
  bool get labelLargeIsCustom => typography.labelLargeIsCustom;
  TextStyle get labelLarge => typography.labelLarge;
  String get labelMediumFamily => typography.labelMediumFamily;
  bool get labelMediumIsCustom => typography.labelMediumIsCustom;
  TextStyle get labelMedium => typography.labelMedium;
  String get labelSmallFamily => typography.labelSmallFamily;
  bool get labelSmallIsCustom => typography.labelSmallIsCustom;
  TextStyle get labelSmall => typography.labelSmall;
  String get bodyLargeFamily => typography.bodyLargeFamily;
  bool get bodyLargeIsCustom => typography.bodyLargeIsCustom;
  TextStyle get bodyLarge => typography.bodyLarge;
  String get bodyMediumFamily => typography.bodyMediumFamily;
  bool get bodyMediumIsCustom => typography.bodyMediumIsCustom;
  TextStyle get bodyMedium => typography.bodyMedium;
  String get bodySmallFamily => typography.bodySmallFamily;
  bool get bodySmallIsCustom => typography.bodySmallIsCustom;
  TextStyle get bodySmall => typography.bodySmall;

  Typography get typography => ThemeTypography(this);
}

class LightModeTheme extends FlutterFlowTheme {
  @Deprecated('Use primary instead')
  Color get primaryColor => primary;
  @Deprecated('Use secondary instead')
  Color get secondaryColor => secondary;
  @Deprecated('Use tertiary instead')
  Color get tertiaryColor => tertiary;

  late Color primary = const Color(0xFF8FAE9B);
  late Color secondary = const Color(0xFF8DA9C4);
  late Color tertiary = const Color(0xFFE8B8A0);
  late Color alternate = const Color(0xFFE8E4DA);
  late Color primaryText = const Color(0xFF2F3437);
  late Color secondaryText = const Color(0xFF5A6064);
  late Color primaryBackground = const Color(0xFFF8F4EC);
  late Color secondaryBackground = const Color(0xFFFFFFFF);
  late Color accent1 = const Color(0x4C4B39EF);
  late Color accent2 = const Color(0x4D39D2C0);
  late Color accent3 = const Color(0xFFA8A8A8);
  late Color accent4 = const Color(0xCCFFFFFF);
  late Color success = const Color(0xFF8FAE9B);
  late Color warning = const Color(0xFFF3DFA2);
  late Color error = const Color(0xFFD4A5A5);
  late Color info = const Color(0xFF8DA9C4);

  late Color onPrimary = const Color(0xFFFFFFFF);
  late Color primaryContainer = const Color(0x1A8FAE9B);
  late Color onPrimaryContainer = const Color(0xFF2F3437);
  late Color onSecondary = const Color(0xFFFFFFFF);
  late Color secondaryContainer = const Color(0x1A8DA9C4);
  late Color onSecondaryContainer = const Color(0xFF2F3437);
  late Color onAccent = const Color(0xFF000000);
  late Color accentContainer = const Color(0x1AE8B8A0);
  late Color onAccentContainer = const Color(0xFF2F3437);
  late Color onBackground = const Color(0xFF2F3437);
  late Color onSurface = const Color(0xFF2F3437);
  late Color surfaceVariant = const Color(0xFFF2EFE8);
  late Color onSurfaceVariant = const Color(0xFF5A6064);
  late Color onSuccess = const Color(0xFFFFFFFF);
  late Color onWarning = const Color(0xFF000000);
  late Color onError = const Color(0xFFFFFFFF);
  late Color onInfo = const Color(0xFFFFFFFF);
  late Color transparent = const Color(0x00000000);
  late Color fullContrast = const Color(0xFF000000);
  late Color primary10 = const Color(0x1A8FAE9B);
  late Color info10 = const Color(0x1A8DA9C4);
  late Color info20 = const Color(0x338DA9C4);
  late Color secondary20 = const Color(0x338DA9C4);
  late Color onPrimary27 = const Color(0x45FFFFFF);
  late Color secondary15 = const Color(0x268DA9C4);
  late Color secondary30 = const Color(0x4D8DA9C4);
  late Color surfaceVariant30 = const Color(0x4DF2EFE8);
  late Color onSurface80 = const Color(0xCC2F3437);
  late Color primary15 = const Color(0x268FAE9B);
  late Color accent15 = const Color(0x26E8B8A0);
  late Color customColor1 = const Color(0xFF49EAE3);
}

abstract class Typography {
  String get displayLargeFamily;
  bool get displayLargeIsCustom;
  TextStyle get displayLarge;
  String get displayMediumFamily;
  bool get displayMediumIsCustom;
  TextStyle get displayMedium;
  String get displaySmallFamily;
  bool get displaySmallIsCustom;
  TextStyle get displaySmall;
  String get headlineLargeFamily;
  bool get headlineLargeIsCustom;
  TextStyle get headlineLarge;
  String get headlineMediumFamily;
  bool get headlineMediumIsCustom;
  TextStyle get headlineMedium;
  String get headlineSmallFamily;
  bool get headlineSmallIsCustom;
  TextStyle get headlineSmall;
  String get titleLargeFamily;
  bool get titleLargeIsCustom;
  TextStyle get titleLarge;
  String get titleMediumFamily;
  bool get titleMediumIsCustom;
  TextStyle get titleMedium;
  String get titleSmallFamily;
  bool get titleSmallIsCustom;
  TextStyle get titleSmall;
  String get labelLargeFamily;
  bool get labelLargeIsCustom;
  TextStyle get labelLarge;
  String get labelMediumFamily;
  bool get labelMediumIsCustom;
  TextStyle get labelMedium;
  String get labelSmallFamily;
  bool get labelSmallIsCustom;
  TextStyle get labelSmall;
  String get bodyLargeFamily;
  bool get bodyLargeIsCustom;
  TextStyle get bodyLarge;
  String get bodyMediumFamily;
  bool get bodyMediumIsCustom;
  TextStyle get bodyMedium;
  String get bodySmallFamily;
  bool get bodySmallIsCustom;
  TextStyle get bodySmall;
}

class ThemeTypography extends Typography {
  ThemeTypography(this.theme);

  final FlutterFlowTheme theme;

  String get displayLargeFamily => 'DM Sans';
  bool get displayLargeIsCustom => false;
  TextStyle get displayLarge => GoogleFonts.dmSans(
        color: theme.primaryText,
        fontWeight: FontWeight.bold,
        fontSize: 58.0,
        height: 1.1,
      );
  String get displayMediumFamily => 'DM Sans';
  bool get displayMediumIsCustom => false;
  TextStyle get displayMedium => GoogleFonts.dmSans(
        color: theme.primaryText,
        fontWeight: FontWeight.bold,
        fontSize: 46.0,
        height: 1.15,
      );
  String get displaySmallFamily => 'DM Sans';
  bool get displaySmallIsCustom => false;
  TextStyle get displaySmall => GoogleFonts.dmSans(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 38.0,
        height: 1.2,
      );
  String get headlineLargeFamily => 'DM Sans';
  bool get headlineLargeIsCustom => false;
  TextStyle get headlineLarge => GoogleFonts.dmSans(
        color: theme.primaryText,
        fontWeight: FontWeight.bold,
        fontSize: 32.0,
        height: 1.25,
      );
  String get headlineMediumFamily => 'DM Sans';
  bool get headlineMediumIsCustom => false;
  TextStyle get headlineMedium => GoogleFonts.dmSans(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 28.0,
        height: 1.3,
      );
  String get headlineSmallFamily => 'DM Sans';
  bool get headlineSmallIsCustom => false;
  TextStyle get headlineSmall => GoogleFonts.dmSans(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 24.0,
        height: 1.35,
      );
  String get titleLargeFamily => 'DM Sans';
  bool get titleLargeIsCustom => false;
  TextStyle get titleLarge => GoogleFonts.dmSans(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 20.0,
        height: 1.4,
      );
  String get titleMediumFamily => 'DM Sans';
  bool get titleMediumIsCustom => false;
  TextStyle get titleMedium => GoogleFonts.dmSans(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 16.0,
        height: 1.45,
      );
  String get titleSmallFamily => 'DM Sans';
  bool get titleSmallIsCustom => false;
  TextStyle get titleSmall => GoogleFonts.dmSans(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 14.0,
        height: 1.5,
      );
  String get labelLargeFamily => 'Nunito';
  bool get labelLargeIsCustom => false;
  TextStyle get labelLarge => GoogleFonts.nunito(
        color: theme.secondaryText,
        fontWeight: FontWeight.w600,
        fontSize: 14.0,
        height: 1.4,
      );
  String get labelMediumFamily => 'Nunito';
  bool get labelMediumIsCustom => false;
  TextStyle get labelMedium => GoogleFonts.nunito(
        color: theme.secondaryText,
        fontWeight: FontWeight.w600,
        fontSize: 12.0,
        height: 1.4,
      );
  String get labelSmallFamily => 'Nunito';
  bool get labelSmallIsCustom => false;
  TextStyle get labelSmall => GoogleFonts.nunito(
        color: theme.secondaryText,
        fontWeight: FontWeight.w600,
        fontSize: 10.0,
        height: 1.3,
      );
  String get bodyLargeFamily => 'Nunito';
  bool get bodyLargeIsCustom => false;
  TextStyle get bodyLarge => GoogleFonts.nunito(
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 16.0,
        height: 1.6,
      );
  String get bodyMediumFamily => 'Nunito';
  bool get bodyMediumIsCustom => false;
  TextStyle get bodyMedium => GoogleFonts.nunito(
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 14.0,
        height: 1.6,
      );
  String get bodySmallFamily => 'Nunito';
  bool get bodySmallIsCustom => false;
  TextStyle get bodySmall => GoogleFonts.nunito(
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 12.0,
        height: 1.5,
      );
}

class FFDesignTokens {
  const FFDesignTokens(this.theme);
  final FlutterFlowTheme theme;
  FFSpacing get spacing => const FFSpacing();
  FFRadius get radius => const FFRadius();
  FFShadows get shadow => FFShadows(theme);
}

class FFSpacing {
  const FFSpacing();
  double get none => 0.0;
  double get xs => 4.0;
  double get sm => 8.0;
  double get md => 16.0;
  double get lg => 24.0;
  double get xl => 32.0;
  double get xxl => 48.0;
  double get xxxl => 64.0;
}

class FFRadius {
  const FFRadius();
  double get none => 0.0;
  double get xs => 8.0;
  double get sm => 12.0;
  double get md => 20.0;
  double get lg => 28.0;
  double get xl => 36.0;
  double get xxl => 48.0;
  double get full => 9999.0;
}

class FFShadows {
  const FFShadows(this.theme);
  final FlutterFlowTheme theme;
  BoxShadow get none => const BoxShadow(
      blurRadius: 0.0,
      color: const Color(0x00000000),
      offset: const Offset(0.0, 0.0),
      spreadRadius: 0.0);
  BoxShadow get xs => const BoxShadow(
      blurRadius: 2.0,
      color: const Color(0x052F3437),
      offset: const Offset(0.0, 1.0),
      spreadRadius: 0.0);
  BoxShadow get sm => const BoxShadow(
      blurRadius: 4.0,
      color: const Color(0x082F3437),
      offset: const Offset(0.0, 2.0),
      spreadRadius: 0.0);
  BoxShadow get md => const BoxShadow(
      blurRadius: 8.0,
      color: const Color(0x0A2F3437),
      offset: const Offset(0.0, 4.0),
      spreadRadius: 0.0);
  BoxShadow get lg => const BoxShadow(
      blurRadius: 16.0,
      color: const Color(0x0D2F3437),
      offset: const Offset(0.0, 8.0),
      spreadRadius: 0.0);
  BoxShadow get xl => const BoxShadow(
      blurRadius: 24.0,
      color: const Color(0x0F2F3437),
      offset: const Offset(0.0, 12.0),
      spreadRadius: 0.0);
  BoxShadow get xxl => const BoxShadow(
      blurRadius: 32.0,
      color: const Color(0x142F3437),
      offset: const Offset(0.0, 16.0),
      spreadRadius: 0.0);
}

extension TextStyleHelper on TextStyle {
  TextStyle override({
    TextStyle? font,
    String? fontFamily,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    FontStyle? fontStyle,
    bool useGoogleFonts = false,
    TextDecoration? decoration,
    double? lineHeight,
    List<Shadow>? shadows,
    String? package,
  }) {
    if (useGoogleFonts && fontFamily != null && fontFamily.isNotEmpty) {
      font = GoogleFonts.getFont(fontFamily,
          fontWeight: fontWeight ?? this.fontWeight,
          fontStyle: fontStyle ?? this.fontStyle);
    }

    return font != null
        ? font.copyWith(
            color: color ?? this.color,
            fontSize: fontSize ?? this.fontSize,
            letterSpacing: letterSpacing ?? this.letterSpacing,
            fontWeight: fontWeight ?? this.fontWeight,
            fontStyle: fontStyle ?? this.fontStyle,
            decoration: decoration,
            height: lineHeight,
            shadows: shadows,
          )
        : copyWith(
            fontFamily: fontFamily,
            package: package,
            color: color,
            fontSize: fontSize,
            letterSpacing: letterSpacing,
            fontWeight: fontWeight,
            fontStyle: fontStyle,
            decoration: decoration,
            height: lineHeight,
            shadows: shadows,
          );
  }
}
