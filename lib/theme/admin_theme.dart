import 'package:flutter/material.dart';

class AdminTheme {
  static const Color background = Color(0xFF0E1114);
  static const Color backgroundSecondary = Color(0xFF12161C);
  static const Color surface = Color(0xFF12161C);
  static const Color surfaceRaised = Color(0xFF1A1F26);
  static const Color surfaceSoft = Color(0xFF202632);
  static const Color surfaceHighlight = Color(0xFF26313D);
  static const Color surfaceOverlay = Color(0xFF18212B);
  static const Color border = Color(0xFF2E3A45);
  static const Color borderSoft = Color(0xFF202632);
  static const Color accent = Color(0xFF2ED573);
  static const Color accentSoft = Color(0xFFB6F04A);
  static const Color cyan = Color(0xFF4EA8FF);
  static const Color warning = Color(0xFFE6C75A);
  static const Color danger = Color(0xFFE53935);
  static const Color success = Color(0xFF26C165);
  static const Color textPrimary = Color(0xFFEDEDED);
  static const Color textSecondary = Color(0xFF9AA3AD);
  static const Color textMuted = Color(0xFF6E7A85);
  static const double contentMaxWidth = 1440;
  static const double readingMaxWidth = 1280;

  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0E1114),
      Color(0xFF10161B),
      Color(0xFF0E1114),
    ],
  );

  static BoxDecoration panelDecoration({
    Color? accentColor,
    bool highlight = false,
    double radius = 18,
  }) {
    final glow = accentColor ?? accent;

    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          surfaceRaised.withValues(alpha: 0.97),
          surface.withValues(alpha: 0.95),
        ],
      ),
      border: Border.all(
        color: highlight
            ? glow.withValues(alpha: 0.28)
            : border.withValues(alpha: 0.82),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
        BoxShadow(
          color: glow.withValues(alpha: highlight ? 0.1 : 0.03),
          blurRadius: 16,
          spreadRadius: 0.5,
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
          letterSpacing: 0,
          color: textPrimary,
          height: 1.05,
        ),
        headlineMedium: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          color: textPrimary,
        ),
        titleLarge: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0,
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
          letterSpacing: 0,
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
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border.withValues(alpha: 0.8)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
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
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border.withValues(alpha: 0.8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: danger, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: const WidgetStatePropertyAll(accent),
          foregroundColor: const WidgetStatePropertyAll(background),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
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
            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
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
          fontSize: 13.5,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border.withValues(alpha: 0.9)),
        ),
        textStyle: const TextStyle(color: textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceRaised,
        contentTextStyle: const TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
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
