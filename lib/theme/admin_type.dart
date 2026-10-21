import 'package:flutter/material.dart';

import 'admin_theme.dart';

/// Les styles de texte du portail admin.
///
/// Le thème définissait déjà une échelle, mais les écrans ne s'en
/// servaient pas : on comptait treize tailles distinctes posées en dur
/// (10, 10.5, 11.5, 12, 12.5, 13, 13.5, 14, 15, 17, 22, 28, 30) sur
/// soixante-seize `TextStyle` littéraux. Deux textes de même rôle
/// n'avaient pas la même taille d'un écran à l'autre, et personne ne
/// pouvait s'en apercevoir en lisant un seul fichier.
///
/// L'échelle est ramenée à **sept** crans — 11, 12, 13, 15, 17, 22, 28 —
/// et chaque cran porte un rôle nommé. Pour changer la densité du portail,
/// il n'y a plus qu'un endroit à modifier.
///
/// Les styles de corps n'indiquent pas de police : ils héritent de Public
/// Sans par `DefaultTextStyle`. Les styles de titre vivent dans
/// `AdminTheme.buildTheme()` parce qu'eux doivent nommer Space Grotesk, et
/// `GoogleFonts` n'est pas constant.
abstract final class AdminType {
  /// Chiffres à chasse fixe : sans eux, une colonne de nombres se décale
  /// d'une ligne à l'autre parce que le « 1 » est plus étroit que le « 8 ».
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Intitulé de colonne, titre de bloc dans une fiche, étiquette de
  /// groupe dans la navigation. Toujours en capitales.
  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    height: 1.2,
    color: AdminTheme.textMuted,
  );

  /// Précision discrète : deuxième ligne d'une cellule, légende, aide.
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AdminTheme.textMuted,
  );

  /// Étiquette d'état (pastille), libellé court mis en avant.
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// Texte courant : cellule de tableau, valeur d'un champ de fiche.
  static const TextStyle body = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: AdminTheme.textSecondary,
  );

  /// Texte courant qui porte l'identité d'une ligne : nom d'un compte,
  /// titre d'une offre.
  static const TextStyle bodyStrong = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: AdminTheme.textPrimary,
  );

  /// Paragraphe à lire en entier : description d'une offre, message
  /// d'introduction d'une mise en relation. Interligne plus ouvert.
  static const TextStyle prose = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AdminTheme.textSecondary,
  );

  /// Nombre dans un tableau ou une bande de compteurs.
  static const TextStyle numeric = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.35,
    fontFeatures: _tabular,
    color: AdminTheme.textPrimary,
  );

  /// Libellé compact mis en avant : nom de la session en pied de rail,
  /// où la largeur disponible ne permet pas le cran de corps.
  static const TextStyle labelStrong = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AdminTheme.textPrimary,
  );

  /// Mot-marque « Adfoot » dans le rail de navigation. Seul texte du
  /// portail dont la taille ne sert qu'à lui.
  static const TextStyle brand = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.2,
    color: AdminTheme.textPrimary,
  );

  /// Grand nombre d'un indicateur, sur l'écran Statistiques.
  static const TextStyle metric = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1,
    fontFeatures: _tabular,
    color: AdminTheme.textPrimary,
  );
}
