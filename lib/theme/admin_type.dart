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
/// L'échelle tient en **sept** crans — 12, 13, 14, 15, 17, 22, 28 — et
/// chaque cran porte un rôle nommé. Pour changer la densité du portail,
/// il n'y a plus qu'un endroit à modifier.
///
/// ## Pourquoi le corps vit à 13/14 et non plus à 11/12/13
///
/// Le portail est peint par CanvasKit : Flutter dessine les glyphes dans
/// un canvas WebGL et le navigateur n'affiche aucun texte. Mesuré sur la
/// production le 26 octobre 2026, la longueur du texte présent dans le
/// DOM vaut zéro. Il n'y a donc ni lissage sous-pixel ni hinting de
/// police, et sur un écran en `devicePixelRatio: 1` la rastérisation
/// laisse un voile laiteux, visible à l'oeil nu en dessous de 13 px.
///
/// Le cran le plus employé était `caption`, à 12 px et en gris atténué :
/// trente-six usages, contre quinze pour `body`. L'essentiel de ce qu'on
/// lit à l'écran, les adresses e-mail sous les noms et les secondes
/// lignes de cellule, se rendait donc dans le plus petit cran et le plus
/// flou. Le contraste n'était pas en cause : mesuré, `textMuted` tient
/// 7,4:1 sur la surface la plus claire, là où la norme AA demande 4,5:1.
///
/// ## Pourquoi les hauteurs de ligne sont écrites en division
///
/// Une hauteur de ligne fractionnaire pose les lignes sur des
/// demi-pixels, et CanvasKit étale alors chaque glyphe sur deux rangées
/// de pixels. Aucune des combinaisons précédentes ne tombait juste :
/// 11 × 1,2 = 13,2 ; 12 × 1,35 = 16,2 ; 13 × 1,45 = 18,85. Chaque
/// `height` s'écrit désormais `cible / taille`, pour que la boîte de
/// ligne tombe sur un pixel entier et pour que la cible visée se lise
/// dans le code.
///
/// ## Pourquoi chaque style nomme sa police
///
/// Les styles de corps héritaient de Public Sans par `DefaultTextStyle`,
/// parce que `GoogleFonts` renvoie un style construit à l'exécution et ne
/// peut donc pas vivre dans une constante. Les polices étant désormais
/// embarquées, le nom de famille est une simple chaîne constante : chaque
/// style la nomme, ne dépend plus du contexte de rendu, et reste `const`.
///
/// Les styles de titre restent dans `AdminTheme.buildTheme()` : eux doivent
/// nommer Space Grotesk et porter son repli vers Inter.
abstract final class AdminType {
  /// Chiffres à chasse fixe : sans eux, une colonne de nombres se décale
  /// d'une ligne à l'autre parce que le « 1 » est plus étroit que le « 8 ».
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Intitulé de colonne, titre de bloc dans une fiche, étiquette de
  /// groupe dans la navigation. Toujours en capitales.
  ///
  /// L'interlettrage descend de 0,6 à 0,5 : le cran ayant gagné un pixel,
  /// 0,6 séparait assez les capitales pour qu'un intitulé se lise lettre
  /// à lettre au lieu de se lire d'un bloc.
  static const TextStyle overline = TextStyle(
    fontFamily: AdminTheme.fontBody,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    height: 16 / 12,
    color: AdminTheme.textMuted,
  );

  /// Précision discrète : deuxième ligne d'une cellule, légende, aide.
  static const TextStyle caption = TextStyle(
    fontFamily: AdminTheme.fontBody,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 18 / 13,
    color: AdminTheme.textMuted,
  );

  /// Étiquette d'état (pastille), libellé court mis en avant.
  static const TextStyle label = TextStyle(
    fontFamily: AdminTheme.fontBody,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 18 / 13,
  );

  /// Texte courant : cellule de tableau, valeur d'un champ de fiche.
  static const TextStyle body = TextStyle(
    fontFamily: AdminTheme.fontBody,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
    color: AdminTheme.textSecondary,
  );

  /// Texte courant qui porte l'identité d'une ligne : nom d'un compte,
  /// titre d'une offre.
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: AdminTheme.fontBody,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 18 / 14,
    color: AdminTheme.textPrimary,
  );

  /// Paragraphe à lire en entier : description d'une offre, message
  /// d'introduction d'une mise en relation. Interligne plus ouvert.
  static const TextStyle prose = TextStyle(
    fontFamily: AdminTheme.fontBody,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 22 / 14,
    color: AdminTheme.textSecondary,
  );

  /// Nombre dans un tableau ou une bande de compteurs.
  static const TextStyle numeric = TextStyle(
    fontFamily: AdminTheme.fontBody,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 18 / 14,
    fontFeatures: _tabular,
    color: AdminTheme.textPrimary,
  );

  /// Libellé compact mis en avant : nom de la session en pied de rail,
  /// où la largeur disponible ne permet pas le cran de corps.
  static const TextStyle labelStrong = TextStyle(
    fontFamily: AdminTheme.fontBody,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 18 / 13,
    color: AdminTheme.textPrimary,
  );

  /// Mot-marque « Adfoot » dans le rail de navigation. Seul texte du
  /// portail dont la taille ne sert qu'à lui.
  static const TextStyle brand = TextStyle(
    fontFamily: AdminTheme.fontBody,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 18 / 15,
    color: AdminTheme.textPrimary,
  );

  /// Grand nombre d'un indicateur, sur l'écran Statistiques.
  static const TextStyle metric = TextStyle(
    fontFamily: AdminTheme.fontBody,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1,
    fontFeatures: _tabular,
    color: AdminTheme.textPrimary,
  );
}
