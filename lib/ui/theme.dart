import 'package:flutter/material.dart';

import '../core/brand.dart';

ThemeData buildTheme(Brightness brightness, Color seed) {
  var scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    // Keeps the primary close to the chosen accent instead of a muted tone.
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  if (brightness == Brightness.dark) {
    // Burrow's dark mode sits on deep ink rather than neutral grey.
    scheme = scheme.copyWith(
      surface: Brand.ink,
      surfaceContainerLowest: const Color(0xFF0F0D17),
      surfaceContainerLow: const Color(0xFF1C1829),
      surfaceContainer: const Color(0xFF211D30),
      surfaceContainerHigh: const Color(0xFF2A2540),
      surfaceContainerHighest: const Color(0xFF332D4B),
      onSurface: const Color(0xFFF3EFFA),
      onSurfaceVariant: const Color(0xFFB9B2CC),
      outlineVariant: const Color(0xFF3A3452),
    );
  }
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness, fontFamily: Brand.fontFamily);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    chipTheme: base.chipTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
    listTileTheme: ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
    ),
  );
}

/// Layout breakpoints (Material 3 window size classes).
class Breakpoints {
  static const compact = 600.0;
  static const expanded = 1000.0;

  static bool isCompact(BuildContext context) => MediaQuery.sizeOf(context).width < compact;
  static bool isExpanded(BuildContext context) => MediaQuery.sizeOf(context).width >= expanded;
}

/// Constrains page content on very wide screens so lines don't stretch.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 1280});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

EdgeInsets pagePadding(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  final h = w < Breakpoints.compact ? 16.0 : (w < Breakpoints.expanded ? 24.0 : 32.0);
  return EdgeInsets.symmetric(horizontal: h);
}
