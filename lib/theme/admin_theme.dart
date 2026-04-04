import 'package:flutter/material.dart';

class AdminTheme {
  static const Color background = Color(0xFF040B09);
  static const Color backgroundSecondary = Color(0xFF071411);
  static const Color surface = Color(0xFF0C1815);
  static const Color surfaceRaised = Color(0xFF12231E);
  static const Color surfaceSoft = Color(0xFF17302A);
  static const Color surfaceHighlight = Color(0xFF1B3A31);
  static const Color border = Color(0xFF295247);
  static const Color borderSoft = Color(0xFF1F3F37);
  static const Color accent = Color(0xFF67F1AB);
  static const Color accentSoft = Color(0xFFB7F8D7);
  static const Color cyan = Color(0xFF74D9FF);
  static const Color warning = Color(0xFFF4D27A);
  static const Color danger = Color(0xFFFF7E8A);
  static const Color success = Color(0xFF7BF1B7);
  static const Color textPrimary = Color(0xFFF2FFF8);
  static const Color textSecondary = Color(0xFF9ABCB1);
  static const Color textMuted = Color(0xFF719287);

  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF040B09),
      Color(0xFF091713),
      Color(0xFF08110F),
    ],
  );

  static BoxDecoration panelDecoration({
    Color? accentColor,
    bool highlight = false,
    double radius = 30,
  }) {
    final glow = accentColor ?? accent;

    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          surfaceRaised.withValues(alpha: 0.96),
          surface.withValues(alpha: 0.96),
        ],
      ),
      border: Border.all(
        color: highlight
            ? glow.withValues(alpha: 0.32)
            : border.withValues(alpha: 0.86),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.24),
          blurRadius: 32,
          offset: const Offset(0, 16),
        ),
        BoxShadow(
          color: glow.withValues(alpha: highlight ? 0.14 : 0.06),
          blurRadius: 26,
          spreadRadius: 1,
        ),
      ],
    );
  }

  static ThemeData buildTheme() {
    const scheme = ColorScheme.dark(
      primary: accent,
      secondary: cyan,
      surface: surface,
      error: danger,
      onPrimary: background,
      onSecondary: background,
      onSurface: textPrimary,
      onError: textPrimary,
      outline: border,
    );

    final baseTextTheme = Typography.whiteMountainView;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      primaryColor: accent,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      dividerColor: borderSoft,
      splashFactory: NoSplash.splashFactory,
      textTheme: baseTextTheme.copyWith(
        displaySmall: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: textPrimary,
          height: 1.05,
        ),
        headlineMedium: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: textPrimary,
        ),
        titleLarge: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        titleMedium: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: const TextStyle(
          fontSize: 15,
          color: textPrimary,
          height: 1.45,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          color: textSecondary,
          height: 1.45,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          color: textMuted,
          height: 1.35,
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: background,
          letterSpacing: 0.1,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: border.withValues(alpha: 0.8)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: accent.withValues(alpha: 0.18)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoft.withValues(alpha: 0.72),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textMuted),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: border.withValues(alpha: 0.8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: border.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: danger, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: const WidgetStatePropertyAll(accent),
          foregroundColor: const WidgetStatePropertyAll(background),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(textPrimary),
          side: WidgetStatePropertyAll(
            BorderSide(color: accent.withValues(alpha: 0.32)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(accentSoft),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        selectedIconTheme: const IconThemeData(color: background, size: 22),
        unselectedIconTheme:
            const IconThemeData(color: textSecondary, size: 20),
        selectedLabelTextStyle: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w600,
        ),
        indicatorColor: accent,
        groupAlignment: -0.7,
        labelType: NavigationRailLabelType.all,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          surfaceHighlight.withValues(alpha: 0.72),
        ),
        dataRowColor: WidgetStatePropertyAll(
          surface.withValues(alpha: 0.16),
        ),
        dividerThickness: 0.35,
        headingTextStyle: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        dataTextStyle: const TextStyle(
          color: textSecondary,
          fontSize: 13,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border.withValues(alpha: 0.9)),
        ),
        textStyle: const TextStyle(color: textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceRaised,
        contentTextStyle: const TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: accent.withValues(alpha: 0.18)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceRaised.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border.withValues(alpha: 0.9)),
        ),
        textStyle: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        waitDuration: const Duration(milliseconds: 280),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          accent.withValues(alpha: 0.54),
        ),
        thickness: const WidgetStatePropertyAll(8),
        radius: const Radius.circular(999),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: borderSoft,
        circularTrackColor: borderSoft,
      ),
      dividerTheme: DividerThemeData(
        color: borderSoft.withValues(alpha: 0.7),
        thickness: 0.6,
        space: 0,
      ),
    );
  }
}
