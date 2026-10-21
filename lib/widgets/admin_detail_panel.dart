import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';

/// Fiche d'un enregistrement, affichée à droite de la liste.
///
/// Remplace les boîtes de dialogue de consultation. Une modale oblige à
/// fermer pour passer au dossier suivant ; ici [onPrevious] / [onNext]
/// enchaînent la file sans jamais perdre la liste de vue, et la ligne
/// correspondante reste marquée dans le tableau.
class AdminDetailPanel extends StatelessWidget {
  const AdminDetailPanel({
    required this.title,
    required this.child,
    required this.onClose,
    this.subtitle,
    this.position,
    this.onPrevious,
    this.onNext,
    this.actions = const <Widget>[],
    this.leading,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback onClose;

  /// Rang de l'enregistrement dans la file, par exemple « 3 / 128 ».
  final String? position;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// Actions appliquées à l'enregistrement, épinglées en bas du panneau
  /// pour rester atteignables quelle que soit la longueur de la fiche.
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminTheme.surface,
        borderRadius: BorderRadius.circular(AdminTheme.radiusMd),
      ),
      // Même raison que dans AdminTable : le filet passe au-dessus du
      // contenu clippé, sinon l'en-tête en creux le mange aux angles.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AdminTheme.radiusMd),
        border: Border.all(color: AdminTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AdminTheme.radiusMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AdminTheme.space4),
                child: child,
              ),
            ),
            if (actions.isNotEmpty) _buildActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final navigable = onPrevious != null || onNext != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AdminTheme.space4,
        AdminTheme.space3,
        AdminTheme.space2,
        AdminTheme.space3,
      ),
      decoration: const BoxDecoration(
        color: AdminTheme.surfaceSunken,
        border: Border(bottom: BorderSide(color: AdminTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (navigable) ...[
                IconButton(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left_rounded, size: 19),
                  tooltip: 'Dossier précédent',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right_rounded, size: 19),
                  tooltip: 'Dossier suivant',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
                if (position != null) ...[
                  const SizedBox(width: AdminTheme.space2 - 2),
                  Text(
                    position!,
                    style: AdminType.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
              const Spacer(),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 17),
                tooltip: 'Fermer la fiche',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: AdminTheme.space2),
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
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AdminType.caption,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(AdminTheme.space3),
      decoration: const BoxDecoration(
        color: AdminTheme.surfaceSunken,
        border: Border(top: BorderSide(color: AdminTheme.border)),
      ),
      child: Wrap(
        spacing: AdminTheme.space2,
        runSpacing: AdminTheme.space2,
        alignment: WrapAlignment.end,
        children: actions,
      ),
    );
  }
}

/// Bloc de la fiche : un intitulé discret, une suite de champs.
class AdminDetailSection extends StatelessWidget {
  const AdminDetailSection({
    required this.title,
    required this.children,
    this.trailing,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AdminTheme.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title.toUpperCase(), style: AdminType.overline),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AdminTheme.space2),
          ...children,
        ],
      ),
    );
  }
}

/// Un couple intitulé / valeur de la fiche.
///
/// Les intitulés sont alignés sur une colonne fixe : une fiche se parcourt
/// verticalement du regard, elle n'a pas à être relue mot à mot.
class AdminDetailField extends StatelessWidget {
  const AdminDetailField({
    required this.label,
    required this.value,
    this.valueColor,
    this.child,
    super.key,
  });

  final String label;
  final String value;
  final Color? valueColor;

  /// Remplace [value] quand la valeur n'est pas du texte (pastille, lien).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AdminTheme.space2 + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 132, child: Text(label, style: AdminType.caption)),
          const SizedBox(width: AdminTheme.space3),
          Expanded(
            child:
                child ??
                SelectableText(
                  value.isEmpty ? '—' : value,
                  style: AdminType.body.copyWith(
                    color: value.isEmpty
                        ? AdminTheme.textMuted
                        : valueColor ?? AdminTheme.textPrimary,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
