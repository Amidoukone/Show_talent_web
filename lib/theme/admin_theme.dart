import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Socle visuel du portail admin.
///
/// Parti pris : des surfaces **pleines**, une bordure d'un pixel, aucune
/// ombre portée. La hiérarchie se lit par le fond et par l'espacement, pas
/// par une lueur. L'accent vert est réservé à une seule chose par écran —
/// l'action primaire — pour qu'il veuille encore dire quelque chose.
class AdminTheme {
  // --------------------------------------------------------------------
  // Surfaces : quatre niveaux, du plus profond au plus proche du lecteur.
  // Aucun dégradé, aucune ombre : deux surfaces voisines se distinguent
  // par leur valeur, ce qui suffit sur un fond sombre.
  // --------------------------------------------------------------------

  /// Fond de page.
  static const Color background = Color(0xFF0E1114);

  /// Zone en creux : en-tête de tableau, piste de jauge, encart interne.
  static const Color surfaceSunken = Color(0xFF10151B);

  /// Carte, panneau, barre d'outils — le niveau de travail courant.
  static const Color surface = Color(0xFF141922);

  /// Élément au-dessus de la carte : ligne survolée, menu, boîte de
  /// dialogue, panneau latéral.
  static const Color surfaceRaised = Color(0xFF1A2029);

  /// Remplissage des champs de saisie et des pastilles d'icône.
  static const Color surfaceSoft = Color(0xFF1A2029);

  /// Alias conservé pour les en-têtes de tableau existants, qui veulent la
  /// surface en creux. Voir [surfaceSunken].
  static const Color surfaceHighlight = surfaceSunken;

  /// Filet par défaut entre deux surfaces.
  static const Color border = Color(0xFF232B36);

  /// Filet appuyé : séparateur de section, bordure d'un élément actif.
  static const Color borderStrong = Color(0xFF2E3A45);

  /// Alias conservé pour les séparateurs existants. Voir [border].
  static const Color borderSoft = border;

  // --------------------------------------------------------------------
  // Couleurs de sens. `accent` porte l'action primaire et rien d'autre ;
  // les couleurs d'état ne signalent qu'un état réel, jamais une décoration.
  // --------------------------------------------------------------------

  static const Color accent = Color(0xFF2ED573);
  static const Color accentSoft = Color(0xFFB6F04A);
  static const Color cyan = Color(0xFF4EA8FF);
  static const Color warning = Color(0xFFE6C75A);
  static const Color danger = Color(0xFFE53935);
  static const Color success = Color(0xFF26C165);

  static const Color textPrimary = Color(0xFFEDEDED);
  // Relevés nettement par rapport aux valeurs d'origine (#9AA3AD / #8F99A3) :
  // trop pâles une fois rendus sur les cartes/tableaux réels (pas seulement
  // sur le fond de page), le texte secondaire et discret devenait illisible.
  static const Color textSecondary = Color(0xFFC3CBD3);
  static const Color textMuted = Color(0xFFA6AFB8);

  // --------------------------------------------------------------------
  // Échelle d'espacement. Un seul jeu de valeurs pour tout le portail :
  // sans ça, chaque écran réinventait ses 10/12/14/18/22 et plus rien ne
  // s'alignait d'un onglet à l'autre.
  // --------------------------------------------------------------------

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusPill = 999;

  /// Hauteur commune des contrôles d'une barre d'outils (champ de
  /// recherche, menu déroulant, bouton) : ils doivent s'aligner sur une
  /// même ligne de base, sinon la barre paraît bancale.
  static const double controlHeight = 38;

  /// Lignes de tableau. Resserrées par rapport aux 78-84 px d'origine :
  /// une ligne porte un enregistrement, pas une fiche.
  static const double tableHeaderHeight = 40;
  static const double tableRowHeight = 52;

  static const double contentMaxWidth = 1460;
  static const double readingMaxWidth = 1280;
  static const double breakpointCompact = 1120;
  static const double breakpointShellCompact = 1160;
  static const double breakpointExtendedRail = 1280;

  /// Largeur du panneau latéral de consultation d'un enregistrement.
  static const double detailPanelWidth = 440;

  /// Décoration d'une carte : surface pleine, filet d'un pixel, rien de
  /// plus. [accentColor] ne colore qu'une bordure d'état (erreur, alerte),
  /// jamais un halo décoratif.
  static BoxDecoration panelDecoration({
    Color? accentColor,
    bool highlight = false,
    double radius = radiusMd,
    Color? color,
  }) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: highlight && accentColor != null
            ? accentColor.withValues(alpha: 0.42)
            : border,
      ),
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

    // Deux rôles, pas plus : Space Grotesk porte les titres (une
    // personnalité technique assumée), Public Sans porte tout le reste —
    // y compris les TextStyle littéraux qui ne précisent pas de police,
    // puisqu'ils héritent de bodyMedium via DefaultTextStyle.
    final displayFont = GoogleFonts.spaceGrotesk();
    final bodyFont = GoogleFonts.publicSans();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      primaryColor: accent,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      dividerColor: border,
      splashFactory: NoSplash.splashFactory,
      // Sept crans pour tout le portail : 11, 12, 13, 15, 17, 22, 28. Les
      // rôles de corps vivent dans AdminType ; les rôles de titre restent
      // ici parce qu'eux doivent nommer Space Grotesk.
      textTheme: TextTheme(
        displaySmall: displayFont.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: textPrimary,
          height: 1.1,
        ),
        headlineMedium: displayFont.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: textPrimary,
          height: 1.2,
        ),
        titleLarge: displayFont.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.1,
          height: 1.25,
        ),
        titleMedium: displayFont.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.3,
        ),
        bodyLarge: bodyFont.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.35,
        ),
        bodyMedium: bodyFont.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          height: 1.45,
        ),
        bodySmall: bodyFont.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textMuted,
          height: 1.35,
        ),
        labelLarge: bodyFont.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: background,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: borderStrong),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoft,
        isDense: true,
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
        floatingLabelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: space3,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: danger, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: const WidgetStatePropertyAll(accent),
          foregroundColor: const WidgetStatePropertyAll(background),
          minimumSize: const WidgetStatePropertyAll(Size(0, controlHeight)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: space4),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),
            ),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(textPrimary),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          side: const WidgetStatePropertyAll(BorderSide(color: borderStrong)),
          minimumSize: const WidgetStatePropertyAll(Size(0, controlHeight)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: space3),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),
            ),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(cyan),
          minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: space2),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),
            ),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(textSecondary),
          minimumSize: const WidgetStatePropertyAll(Size(32, 32)),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),
            ),
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        selectedIconTheme: IconThemeData(color: textPrimary, size: 20),
        unselectedIconTheme: IconThemeData(color: textMuted, size: 20),
        selectedLabelTextStyle: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: surfaceRaised,
        groupAlignment: -0.7,
        labelType: NavigationRailLabelType.all,
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(surfaceSunken),
        dataRowColor: WidgetStatePropertyAll(Colors.transparent),
        dividerThickness: 1,
        headingRowHeight: tableHeaderHeight,
        dataRowMinHeight: tableRowHeight,
        dataRowMaxHeight: tableRowHeight,
        horizontalMargin: space4,
        columnSpacing: space5,
        headingTextStyle: TextStyle(
          color: textMuted,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.6,
        ),
        dataTextStyle: TextStyle(color: textSecondary, fontSize: 13),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          side: const BorderSide(color: borderStrong),
        ),
        textStyle: const TextStyle(color: textPrimary, fontSize: 13),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceRaised,
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          side: const BorderSide(color: borderStrong),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceRaised,
          borderRadius: BorderRadius.circular(radiusSm),
          border: Border.all(color: borderStrong),
        ),
        textStyle: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        waitDuration: const Duration(milliseconds: 400),
      ),
      scrollbarTheme: const ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(Color(0xFF39434F)),
        thickness: WidgetStatePropertyAll(8),
        radius: Radius.circular(radiusPill),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: surfaceSunken,
        circularTrackColor: surfaceSunken,
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 0,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: Border(right: BorderSide(color: border)),
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: borderStrong, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
