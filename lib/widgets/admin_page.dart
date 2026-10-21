import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

/// Bandeau de page : le titre de l'écran courant et les actions de
/// session. Une seule ligne, haute de [height].
///
/// Remplace le panneau d'en-tête précédent, qui réaffichait le titre *et*
/// le sous-titre déjà présents dans la navigation, sous un badge « Espace
/// actif », avec « Déconnexion » en bouton vert plein — l'élément le plus
/// voyant de chacun des neuf écrans.
class AdminPageBar extends StatelessWidget {
  const AdminPageBar({
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const <Widget>[],
    super.key,
  });

  static const double height = 52;

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.headlineMedium,
    );

    return SizedBox(
      height: height,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AdminTheme.space2),
          ],
          Flexible(
            child: subtitle == null
                ? titleWidget
                // Le sous-titre explicatif passe en infobulle : utile la
                // première semaine, du bruit ensuite.
                : Tooltip(message: subtitle!, child: titleWidget),
          ),
          const Spacer(),
          for (final action in actions) ...[
            const SizedBox(width: AdminTheme.space2),
            action,
          ],
        ],
      ),
    );
  }
}

/// Gabarit commun aux neuf écrans de travail.
///
/// L'ordre est le même partout : avis éventuel, barre d'outils, bande de
/// compteurs, liste, pied de liste — et la fiche à droite quand un
/// enregistrement est ouvert.
///
/// Sur grand écran, seule la liste défile : la barre d'outils et le pied
/// restent en place. Avant, toute la page tenait dans un unique
/// `SingleChildScrollView` et les filtres disparaissaient dès la dixième
/// ligne.
class AdminWorkspace extends StatelessWidget {
  const AdminWorkspace({
    required this.toolbar,
    required this.body,
    this.notice,
    this.stats,
    this.footer,
    this.detail,
    this.compact = false,
    this.bodyMinWidth = 880,
    super.key,
  });

  final Widget toolbar;

  /// Tableau sur grand écran, liste de fiches en disposition compacte.
  final Widget body;

  final Widget? notice;
  final Widget? stats;
  final Widget? footer;

  /// Fiche latérale, `null` quand aucun enregistrement n'est ouvert.
  final Widget? detail;

  final bool compact;

  /// Largeur en deçà de laquelle le tableau de [body] se met à défiler
  /// horizontalement — la même que celle passée à `AdminTable.minWidth`.
  /// Sert à décider si la fiche peut se poser à côté sans rogner la liste.
  final double bodyMinWidth;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      // En disposition compacte il n'y a pas la place pour deux colonnes :
      // la fiche prend toute la zone de contenu, comme un écran de détail.
      if (detail != null) {
        return detail!;
      }

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (notice != null) ...[
              notice!,
              const SizedBox(height: AdminTheme.space3),
            ],
            toolbar,
            if (stats != null) ...[
              const SizedBox(height: AdminTheme.space3),
              stats!,
            ],
            const SizedBox(height: AdminTheme.space3),
            body,
            if (footer != null) ...[
              const SizedBox(height: AdminTheme.space3),
              footer!,
            ],
          ],
        ),
      );
    }

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (notice != null) ...[
          notice!,
          const SizedBox(height: AdminTheme.space3),
        ],
        toolbar,
        if (stats != null) ...[
          const SizedBox(height: AdminTheme.space3),
          stats!,
        ],
        const SizedBox(height: AdminTheme.space3),
        Expanded(child: body),
        if (footer != null) ...[
          const SizedBox(height: AdminTheme.space3),
          footer!,
        ],
      ],
    );

    if (detail == null) {
      return main;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Une fiche posée à côté d'un tableau trop étroit ne rend service à
        // personne : la liste se met à défiler horizontalement, la colonne
        // d'actions sort de l'écran, et on perd justement ce qu'on voulait
        // garder sous les yeux. En dessous, la fiche prend toute la zone de
        // contenu — la file reste parcourable avec ses flèches.
        final sideBySide =
            constraints.maxWidth >=
            bodyMinWidth + AdminTheme.detailPanelWidth + AdminTheme.space3;

        if (!sideBySide) {
          return detail!;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: main),
            const SizedBox(width: AdminTheme.space3),
            SizedBox(width: AdminTheme.detailPanelWidth, child: detail!),
          ],
        );
      },
    );
  }
}
