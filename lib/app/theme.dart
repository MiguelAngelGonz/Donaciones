import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Official DonaPlus brand color palette (RNF-03).
abstract final class DonaPlusColors {
  static const Color primary = Color(0xFF004D64);
  static const Color secondary = Color(0xFF00A896);
  static const Color accentMint = Color(0xFFA7E6A6);
  static const Color accentYellow = Color(0xFFFFF86A);
  static const Color surfaceLight = Color(0xFFF6F9FA);
  static const Color borderLight = Color(0xFFD5E1E5);
}

/// Immutable user accessibility preferences applied across the app (RNF-03).
@immutable
class AccessibilitySettings {
  final double textScaleFactor;
  final bool highContrast;
  final bool reduceMotion;

  const AccessibilitySettings({
    this.textScaleFactor = 1.0,
    this.highContrast = false,
    this.reduceMotion = false,
  });

  bool get isLargeText => textScaleFactor > 1.0;

  AccessibilitySettings copyWith({
    double? textScaleFactor,
    bool? highContrast,
    bool? reduceMotion,
  }) {
    return AccessibilitySettings(
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
      highContrast: highContrast ?? this.highContrast,
      reduceMotion: reduceMotion ?? this.reduceMotion,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccessibilitySettings &&
        other.textScaleFactor == textScaleFactor &&
        other.highContrast == highContrast &&
        other.reduceMotion == reduceMotion;
  }

  @override
  int get hashCode => Object.hash(textScaleFactor, highContrast, reduceMotion);
}

/// Riverpod notifier managing live accessibility toggles.
class AccessibilityNotifier extends Notifier<AccessibilitySettings> {
  @override
  AccessibilitySettings build() => const AccessibilitySettings();

  void toggleTextScale() {
    state = state.copyWith(textScaleFactor: state.isLargeText ? 1.0 : 1.25);
  }

  void setTextScaleFactor(double factor) {
    state = state.copyWith(textScaleFactor: factor);
  }

  void setLargeText(bool enabled) {
    setTextScaleFactor(enabled ? 1.25 : 1.0);
  }

  void toggleHighContrast() {
    state = state.copyWith(highContrast: !state.highContrast);
  }

  void setHighContrast(bool value) {
    state = state.copyWith(highContrast: value);
  }

  void toggleReduceMotion() {
    state = state.copyWith(reduceMotion: !state.reduceMotion);
  }

  void setReduceMotion(bool value) {
    state = state.copyWith(reduceMotion: value);
  }

  void reset() {
    state = const AccessibilitySettings();
  }
}

/// Shared accessibility preferences provider.
final accessibilityProvider =
    NotifierProvider<AccessibilityNotifier, AccessibilitySettings>(
      AccessibilityNotifier.new,
    );

class _NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

/// Builds the Material 3 theme for DonaPlus respecting contrast and motion settings.
ThemeData buildDonaPlusTheme({
  required bool highContrast,
  required bool reduceMotion,
}) {
  final ColorScheme colorScheme;
  if (highContrast) {
    colorScheme = const ColorScheme.highContrastLight(
      primary: Color(0xFF002B38),
      onPrimary: Colors.white,
      secondary: Color(0xFF006359),
      onSecondary: Colors.white,
      tertiary: DonaPlusColors.accentMint,
      onTertiary: Colors.black,
      surface: Colors.white,
      onSurface: Colors.black,
      outline: Colors.black,
    );
  } else {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: DonaPlusColors.primary,
      brightness: Brightness.light,
    );
    colorScheme = baseScheme.copyWith(
      primary: DonaPlusColors.primary,
      onPrimary: Colors.white,
      secondary: DonaPlusColors.secondary,
      onSecondary: Colors.white,
      tertiary: DonaPlusColors.accentMint,
      onTertiary: DonaPlusColors.primary,
      surface: Colors.white,
      onSurface: const Color(0xFF0E242B),
      surfaceContainerHighest: const Color(0xFFE7EFF2),
      outline: DonaPlusColors.borderLight,
    );
  }

  final borderSide = BorderSide(
    color: highContrast ? Colors.black : DonaPlusColors.borderLight,
    width: highContrast ? 2.0 : 1.0,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: highContrast
        ? Colors.white
        : DonaPlusColors.surfaceLight,
    pageTransitionsTheme: reduceMotion
        ? const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: _NoAnimationPageTransitionsBuilder(),
              TargetPlatform.iOS: _NoAnimationPageTransitionsBuilder(),
              TargetPlatform.macOS: _NoAnimationPageTransitionsBuilder(),
              TargetPlatform.linux: _NoAnimationPageTransitionsBuilder(),
              TargetPlatform.windows: _NoAnimationPageTransitionsBuilder(),
            },
          )
        : const PageTransitionsTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: highContrast ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: borderSide,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: borderSide,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: borderSide,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: colorScheme.secondary,
          width: highContrast ? 2.5 : 2.0,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.secondary,
        foregroundColor: colorScheme.onSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        side: BorderSide(
          color: highContrast ? Colors.black : colorScheme.primary,
          width: highContrast ? 2.0 : 1.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: borderSide,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: highContrast
          ? DonaPlusColors.accentYellow
          : DonaPlusColors.accentMint.withValues(alpha: 0.6),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected
              ? colorScheme.primary
              : (highContrast ? Colors.black : const Color(0xFF455A64)),
        );
      }),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
