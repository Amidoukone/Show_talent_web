import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';

/// Primitives visuelles du portail admin : surfaces, en-têtes, états vides,
/// barres d'outils. Les composants orientés données (tableau, actions de
/// ligne, panneau latéral) vivent dans `admin_table.dart` et
/// `admin_detail_panel.dart` ; la coquille de page dans `admin_page.dart`.
enum AdminBannerTone { neutral, success, warning, danger, info }

extension AdminBannerToneColors on AdminBannerTone {
  Color get color {
    switch (this) {
      case AdminBannerTone.success:
        return AdminTheme.success;
      case AdminBannerTone.warning:
        return AdminTheme.warning;
      case AdminBannerTone.danger:
        return AdminTheme.danger;
      case AdminBannerTone.info:
        return AdminTheme.cyan;
      case AdminBannerTone.neutral:
        return AdminTheme.textMuted;
    }
  }
}

/// Fond de l'application : une couleur pleine, et c'est tout.
///
/// La version précédente peignait une grille et un liseré sur toute la
/// page. Deux motifs permanents derrière chaque écran, qui rivalisaient
/// avec les bordures des cartes posées dessus.
class AdminAppBackground extends StatelessWidget {
  const AdminAppBackground({
    required this.child,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AdminTheme.background,
      child: SafeArea(
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Carte : surface pleine, filet d'un pixel. Unité de regroupement de base.
class AdminPanel extends StatelessWidget {
  const AdminPanel({
    required this.child,
    this.padding = const EdgeInsets.all(AdminTheme.space4),
    this.margin,
    this.highlight = false,
    this.accentColor,
    this.radius = AdminTheme.radiusMd,
    this.color,
    this.width,
    this.height,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// Teinte la bordure de [accentColor] : réservé à un état qui mérite
  /// d'être signalé (erreur, alerte), pas à la mise en avant décorative.
  final bool highlight;
  final Color? accentColor;
  final double radius;
  final Color? color;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: AdminTheme.panelDecoration(
        accentColor: accentColor,
        highlight: highlight,
        radius: radius,
        color: color,
      ),
      child: child,
    );
  }
}

class AdminContentFrame extends StatelessWidget {
  const AdminContentFrame({
    required this.child,
    this.maxWidth = AdminTheme.readingMaxWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

class AdminBrandMark extends StatelessWidget {
  const AdminBrandMark({this.size = 36, this.width, super.key});

  final double size;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? size,
      height: size,
      decoration: BoxDecoration(
        color: AdminTheme.accent,
        borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.2),
        child: Image.asset('assets/logo_icon_white.png', fit: BoxFit.contain),
      ),
    );
  }
}

/// Titre de section : un titre, une explication facultative, une zone
/// d'actions à droite. Le badge décoratif « Espace actif » a disparu — il
/// n'apprenait rien et volait la première ligne de chaque écran.
class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: textTheme.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: AdminTheme.space1),
          Text(
            subtitle!,
            style: textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    if (trailing == null) {
      return titleBlock;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              titleBlock,
              const SizedBox(height: AdminTheme.space3),
              trailing!,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: AdminTheme.space4),
            trailing!,
          ],
        );
      },
    );
  }
}

/// Étiquette d'état. Teinte discrète, texte lisible — pas un bouton.
class AdminPill extends StatelessWidget {
  const AdminPill({
    required this.label,
    this.icon,
    this.color = AdminTheme.textMuted,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTheme.space2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: AdminTheme.space1 + 2),
          ],
          Text(label, style: AdminType.label.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// Bandeau d'information. Un filet coloré à gauche, pas un bloc teinté :
/// un bandeau permanent qui crie finit par ne plus être lu.
///
/// [onDismiss] permet de le replier quand le message a été pris en compte.
class AdminInfoBanner extends StatelessWidget {
  const AdminInfoBanner({
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.tone = AdminBannerTone.neutral,
    this.onDismiss,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final AdminBannerTone tone;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = tone.color;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AdminTheme.space3,
        AdminTheme.space3,
        AdminTheme.space2,
        AdminTheme.space3,
      ),
      decoration: BoxDecoration(
        color: AdminTheme.surface,
        borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
        border: Border.all(color: AdminTheme.border),
        // Le sens passe par ce seul filet vertical.
        gradient: LinearGradient(
          colors: [color, color, Colors.transparent, Colors.transparent],
          stops: const [0, 0.004, 0.004, 1],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AdminTheme.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AdminType.bodyStrong),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: AdminType.caption.copyWith(
                    color: AdminTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: AdminTheme.space2),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 16),
              tooltip: 'Masquer',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

/// Grande carte de mesure, réservée à l'onglet Statistiques.
///
/// L'anneau de pourcentage a cédé la place à une barre fine : un anneau de
/// 34 px à côté d'un nombre de 29 px, c'étaient deux objets qui se
/// disputaient la même information.
class AdminMetricCard extends StatelessWidget {
  const AdminMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.accentColor = AdminTheme.accent,
    this.progress = 0.0,
    super.key,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;
  final Color accentColor;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final ratio = progress.clamp(0.0, 1.0);

    return AdminPanel(
      padding: const EdgeInsets.all(AdminTheme.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AdminTheme.textMuted),
              const SizedBox(width: AdminTheme.space2),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AdminType.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTheme.space3),
          Text(value, style: AdminType.metric),
          const SizedBox(height: AdminTheme.space3),
          ClipRRect(
            borderRadius: BorderRadius.circular(AdminTheme.radiusPill),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 3,
              backgroundColor: AdminTheme.surfaceSunken,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AdminTheme.space2),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AdminType.caption,
            ),
          ],
        ],
      ),
    );
  }
}

/// Un compteur de la bande de synthèse.
///
/// [onTap] le transforme en filtre : au lieu de lire « 3 accès suspendus »
/// puis d'aller chercher lesquels, on clique sur le compteur et la liste
/// se restreint. C'est le remplaçant des tuiles `AdminMiniStat`, qui
/// occupaient un tiers de l'écran sans jamais être actionnables.
class AdminStat {
  const AdminStat({
    required this.label,
    required this.value,
    this.tone,
    this.onTap,
    this.selected = false,
    this.tooltip,
  });

  final String label;
  final String value;

  /// Couleur d'alerte, à ne passer que quand la valeur mérite l'oeil
  /// (un compteur à zéro n'a rien à signaler).
  final Color? tone;
  final VoidCallback? onTap;
  final bool selected;
  final String? tooltip;
}

/// Bande de compteurs : une seule ligne de texte, pas une grille de cartes.
class AdminStatStrip extends StatelessWidget {
  const AdminStatStrip({required this.stats, super.key});

  final List<AdminStat> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: AdminTheme.space2,
      runSpacing: AdminTheme.space2,
      children: [for (final stat in stats) _AdminStatChip(stat: stat)],
    );
  }
}

class _AdminStatChip extends StatelessWidget {
  const _AdminStatChip({required this.stat});

  final AdminStat stat;

  @override
  Widget build(BuildContext context) {
    final tone = stat.tone;
    final interactive = stat.onTap != null;
    final borderColor = stat.selected
        ? AdminTheme.accent.withValues(alpha: 0.55)
        : AdminTheme.border;

    final content = Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: AdminTheme.space3),
      decoration: BoxDecoration(
        color: stat.selected
            ? AdminTheme.accent.withValues(alpha: 0.12)
            : AdminTheme.surface,
        borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stat.value,
            style: AdminType.numeric.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(width: AdminTheme.space2 - 2),
          Text(stat.label, style: AdminType.caption.copyWith(height: 1)),
        ],
      ),
    );

    final chip = interactive
        ? Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
              onTap: stat.onTap,
              child: content,
            ),
          )
        : content;

    if (stat.tooltip == null) {
      return chip;
    }

    return Tooltip(message: stat.tooltip!, child: chip);
  }
}

/// Carte de sous-section à l'intérieur d'un écran (formulaire, encart).
class AdminSubsectionCard extends StatelessWidget {
  const AdminSubsectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.accentColor = AdminTheme.accent,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: AdminTheme.space4),
          child,
        ],
      ),
    );
  }
}

/// Colonne de champs à largeur bornée, pour les formulaires empilés.
class AdminFormColumn extends StatelessWidget {
  const AdminFormColumn({
    required this.children,
    this.maxWidth = 520,
    this.spacing = AdminTheme.space3,
    super.key,
  });

  final List<Widget> children;
  final double maxWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final spaced = <Widget>[];
    for (var index = 0; index < children.length; index += 1) {
      if (index > 0) {
        spaced.add(SizedBox(height: spacing));
      }
      spaced.add(children[index]);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: spaced,
        ),
      ),
    );
  }
}

/// Champ de recherche de la barre d'outils.
///
/// Expose une croix d'effacement dès qu'il contient du texte : avant, il
/// fallait viser le bouton « Réinitialiser » à l'autre bout de la barre.
class AdminSearchField extends StatefulWidget {
  const AdminSearchField({
    required this.hintText,
    this.onChanged,
    this.controller,
    this.maxWidth,
    this.focusNode,
    super.key,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final double? maxWidth;
  final FocusNode? focusNode;

  @override
  State<AdminSearchField> createState() => _AdminSearchFieldState();
}

class _AdminSearchFieldState extends State<AdminSearchField> {
  TextEditingController? _fallbackController;

  TextEditingController get _controller =>
      widget.controller ?? (_fallbackController ??= TextEditingController());

  @override
  void dispose() {
    _fallbackController?.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final field = SizedBox(
      height: AdminTheme.controlHeight,
      child: TextField(
        controller: _controller,
        focusNode: widget.focusNode,
        onChanged: (value) {
          widget.onChanged?.call(value);
          setState(() {});
        },
        style: AdminType.body,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search_rounded, size: 17),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 34,
            minHeight: 34,
          ),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: _clear,
                  icon: const Icon(Icons.close_rounded, size: 15),
                  tooltip: 'Effacer la recherche',
                  visualDensity: VisualDensity.compact,
                ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
        ),
      ),
    );

    if (widget.maxWidth == null) {
      return field;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth!),
      child: field,
    );
  }
}

/// Menu déroulant de filtrage, à la hauteur des autres contrôles.
///
/// Un `DropdownButtonFormField` avec `labelText` dessine son intitulé
/// au-dessus du champ : le contrôle fait alors une cinquantaine de pixels
/// et ne s'aligne plus avec le champ de recherche posé à côté. Ici
/// l'intitulé est préfixé à la valeur — « Rôle : Tous » — et tout tient
/// sur une seule ligne de base.
class AdminFilterDropdown<T> extends StatelessWidget {
  const AdminFilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
    super.key,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AdminTheme.controlHeight,
      padding: const EdgeInsets.symmetric(horizontal: AdminTheme.space3),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
        border: Border.all(color: AdminTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
          dropdownColor: AdminTheme.surfaceRaised,
          focusColor: Colors.transparent,
          icon: const Icon(
            Icons.expand_more_rounded,
            size: 17,
            color: AdminTheme.textMuted,
          ),
          style: AdminType.body.copyWith(color: AdminTheme.textPrimary),
          // Le menu déployé n'affiche que la valeur ; l'intitulé n'est
          // utile que sur le contrôle fermé, pour savoir ce qu'on filtre.
          selectedItemBuilder: (context) => [
            for (final item in items)
              Align(
                alignment: Alignment.centerLeft,
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$label : ',
                        style: AdminType.body.copyWith(
                          color: AdminTheme.textMuted,
                        ),
                      ),
                      TextSpan(
                        text: labelBuilder(item),
                        style: AdminType.bodyStrong,
                      ),
                    ],
                  ),
                ),
              ),
          ],
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item,
                child: Text(
                  labelBuilder(item),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (next) {
            if (next != null) {
              onChanged(next);
            }
          },
        ),
      ),
    );
  }
}

/// Barre d'outils d'un écran de liste : recherche à gauche, filtres au
/// milieu, actions à droite. Tous les contrôles partagent
/// [AdminTheme.controlHeight] pour tenir sur une seule ligne de base.
///
/// Remplace `AdminFilterBar`, qui centrait ses champs dans une largeur
/// bornée au milieu de l'écran — un bloc flottant détaché du tableau qu'il
/// filtrait.
class AdminToolbar extends StatelessWidget {
  const AdminToolbar({
    required this.filters,
    this.trailing = const <Widget>[],
    this.flexes,
    this.breakpoint = 760,
    super.key,
  });

  /// Contrôles de filtrage, répartis sur la largeur disponible.
  final List<Widget> filters;

  /// Actions alignées à droite, à leur taille naturelle.
  final List<Widget> trailing;

  final List<int>? flexes;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    assert(
      flexes == null || flexes!.length == filters.length,
      'flexes doit avoir autant d’entrées que filters.',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final filter in filters) ...[
                filter,
                const SizedBox(height: AdminTheme.space2),
              ],
              if (trailing.isNotEmpty)
                Wrap(
                  spacing: AdminTheme.space2,
                  runSpacing: AdminTheme.space2,
                  children: trailing,
                ),
            ],
          );
        }

        final row = <Widget>[];
        for (var index = 0; index < filters.length; index += 1) {
          if (index > 0) {
            row.add(const SizedBox(width: AdminTheme.space2));
          }
          row.add(Expanded(flex: flexes?[index] ?? 1, child: filters[index]));
        }
        for (final action in trailing) {
          row.add(const SizedBox(width: AdminTheme.space2));
          row.add(action);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: row,
        );
      },
    );
  }
}

/// État de chargement. Discret et centré : il occupe la place de la liste,
/// il n'a pas à ressembler à une carte de plus.
class AdminLoadingState extends StatelessWidget {
  const AdminLoadingState({
    this.message = 'Chargement des données…',
    super.key,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AdminTheme.space8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AdminTheme.space3),
            Flexible(
              child: Text(
                message,
                style: AdminType.body.copyWith(color: AdminTheme.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// État vide ou en erreur : une icône discrète, une phrase, une sortie.
class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.actionIcon = Icons.refresh_rounded,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AdminTheme.space6,
          vertical: AdminTheme.space8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AdminTheme.textMuted, size: 26),
            const SizedBox(height: AdminTheme.space3),
            Text(
              title,
              // Même cran que les titres de section : un état vide est un
              // titre de section qui n'a rien à présenter.
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AdminTheme.space2 - 2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Text(
                message,
                style: AdminType.body.copyWith(
                  color: AdminTheme.textMuted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AdminTheme.space4),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon, size: 16),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AdminDataCardField {
  const AdminDataCardField({required this.label, required this.value});

  final String label;
  final Widget value;
}

/// Fiche d'un enregistrement, utilisée à la place d'une ligne de tableau
/// sur les écrans étroits. Pendant compact de `AdminTable`.
class AdminDataCard extends StatelessWidget {
  const AdminDataCard({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.fields = const <AdminDataCardField>[],
    this.actions,
    this.onTap,
    super.key,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;

  /// Marqueur d'état posé à droite du titre (pastille de statut).
  final Widget? trailing;

  final List<AdminDataCardField> fields;
  final Widget? actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = AdminPanel(
      padding: const EdgeInsets.all(AdminTheme.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AdminTheme.space3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    title,
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      subtitle!,
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AdminTheme.space2),
                trailing!,
              ],
              if (actions != null) ...[
                const SizedBox(width: AdminTheme.space2),
                actions!,
              ],
            ],
          ),
          for (final field in fields) ...[
            const SizedBox(height: AdminTheme.space3),
            Text(field.label.toUpperCase(), style: AdminType.overline),
            const SizedBox(height: AdminTheme.space1),
            DefaultTextStyle.merge(style: AdminType.body, child: field.value),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AdminTheme.radiusMd),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// Point de couleur + libellé : signale un état sans le poids visuel d'un
/// badge plein.
class AdminStatusDot extends StatelessWidget {
  const AdminStatusDot({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AdminTheme.space2 - 1),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdminType.bodyStrong.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
