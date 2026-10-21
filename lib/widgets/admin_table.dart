import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';

/// Tableau de travail du portail admin.
///
/// Remplace `DataTable` enveloppé dans `AdminDataTableCard`. Trois raisons :
///
/// 1. `DataTable` fait défiler son en-tête de colonnes avec les lignes.
///    Passé la dixième ligne, on ne sait plus ce qu'on lit. Ici l'en-tête
///    est figé et seules les lignes défilent.
/// 2. Les hauteurs de ligne étaient fixées écran par écran (78 px, 84 px)
///    parce qu'une cellule empilait trois textes. Une ligne porte un
///    enregistrement : [AdminTheme.tableRowHeight] pour tout le portail.
/// 3. Une ligne entière est cliquable et réagit au survol, ce qui permet
///    d'ouvrir la fiche latérale sans viser une icône.
class AdminColumn {
  const AdminColumn({
    required this.label,
    this.flex = 1,
    this.width,
    this.alignRight = false,
    this.tooltip,
  });

  final String label;

  /// Explication de la colonne, au survol de son intitulé. Évite d'avoir à
  /// poser un bandeau permanent en haut de l'écran pour une règle qui ne
  /// concerne qu'une colonne.
  final String? tooltip;

  /// Part de la largeur restante, quand [width] n'est pas fixée.
  final int flex;

  /// Largeur fixe, pour les colonnes dont le contenu ne varie pas
  /// (statut, actions).
  final double? width;

  final bool alignRight;
}

class AdminTable extends StatelessWidget {
  const AdminTable({
    required this.columns,
    required this.rowCount,
    required this.cellsBuilder,
    this.minWidth = 880,
    this.rowHeight = AdminTheme.tableRowHeight,
    this.onRowTap,
    this.selectedRow,
    this.rowKey,
    this.scrollController,
    super.key,
  });

  final List<AdminColumn> columns;
  final int rowCount;

  /// Cellules d'une ligne, dans l'ordre de [columns].
  final List<Widget> Function(int index) cellsBuilder;

  /// En deçà de cette largeur, le tableau défile horizontalement plutôt
  /// que de comprimer ses colonnes jusqu'à l'illisible.
  final double minWidth;

  /// Hauteur d'une ligne. Les écrans vidéo la relèvent pour loger une
  /// vignette ; partout ailleurs la valeur du thème suffit.
  final double rowHeight;

  final void Function(int index)? onRowTap;

  /// Index de la ligne actuellement ouverte dans la fiche latérale.
  final int? selectedRow;

  final Key? Function(int index)? rowKey;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < minWidth
            ? minWidth
            : constraints.maxWidth;

        return Container(
          decoration: BoxDecoration(
            color: AdminTheme.surface,
            borderRadius: BorderRadius.circular(AdminTheme.radiusMd),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdminTheme.radiusMd),
            border: Border.all(color: AdminTheme.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AdminTheme.radiusMd),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                height: constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AdminTableHeader(columns: columns),
                    if (constraints.maxHeight.isFinite)
                      Expanded(child: _buildBody())
                    else
                      _buildBody(shrinkWrap: true),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody({bool shrinkWrap = false}) {
    return ListView.builder(
      controller: shrinkWrap ? null : scrollController,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.zero,
      itemCount: rowCount,
      itemExtent: rowHeight,
      itemBuilder: (context, index) {
        return _AdminTableRow(
          key: rowKey?.call(index),
          columns: columns,
          cells: cellsBuilder(index),
          selected: selectedRow == index,
          isLast: index == rowCount - 1,
          onTap: onRowTap == null ? null : () => onRowTap!(index),
        );
      },
    );
  }
}

class _AdminTableHeader extends StatelessWidget {
  const _AdminTableHeader({required this.columns});

  final List<AdminColumn> columns;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AdminTheme.tableHeaderHeight,
      decoration: const BoxDecoration(
        color: AdminTheme.surfaceSunken,
        border: Border(bottom: BorderSide(color: AdminTheme.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AdminTheme.space4),
      child: Row(
        children: [
          for (var index = 0; index < columns.length; index += 1)
            _column(
              columns[index],
              _headerLabel(columns[index]),
              isLast: index == columns.length - 1,
            ),
        ],
      ),
    );
  }
}

Widget _headerLabel(AdminColumn column) {
  final label = Text(
    column.label.toUpperCase(),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: column.alignRight ? TextAlign.right : TextAlign.left,
    style: AdminType.overline,
  );

  final tooltip = column.tooltip;
  if (tooltip == null) {
    return label;
  }

  return Tooltip(
    message: tooltip,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: label),
        const SizedBox(width: AdminTheme.space1),
        const Icon(
          Icons.info_outline_rounded,
          size: 11,
          color: AdminTheme.textMuted,
        ),
      ],
    ),
  );
}

class _AdminTableRow extends StatefulWidget {
  const _AdminTableRow({
    required this.columns,
    required this.cells,
    required this.selected,
    required this.isLast,
    this.onTap,
    super.key,
  });

  final List<AdminColumn> columns;
  final List<Widget> cells;
  final bool selected;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  State<_AdminTableRow> createState() => _AdminTableRowState();
}

class _AdminTableRowState extends State<_AdminTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    assert(
      widget.cells.length == widget.columns.length,
      'Une ligne doit fournir autant de cellules que le tableau a de '
      'colonnes.',
    );

    final highlighted = widget.selected || _hovered;

    final row = Container(
      decoration: BoxDecoration(
        color: highlighted ? AdminTheme.surfaceRaised : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: widget.isLast ? Colors.transparent : AdminTheme.border,
          ),
          // Repère de la ligne ouverte dans la fiche latérale : sans lui,
          // on perd de vue à quel enregistrement la fiche correspond.
          left: BorderSide(
            color: widget.selected ? AdminTheme.accent : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AdminTheme.space4 - 1),
      child: Row(
        children: [
          for (var index = 0; index < widget.columns.length; index += 1)
            _column(
              widget.columns[index],
              widget.cells[index],
              isLast: index == widget.columns.length - 1,
            ),
        ],
      ),
    );

    if (widget.onTap == null) {
      return row;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: row,
      ),
    );
  }
}

Widget _column(AdminColumn column, Widget child, {required bool isLast}) {
  final aligned = Align(
    alignment: column.alignRight ? Alignment.centerRight : Alignment.centerLeft,
    child: child,
  );

  final padded = Padding(
    padding: EdgeInsets.only(right: isLast ? 0 : AdminTheme.space4),
    child: aligned,
  );

  if (column.width != null) {
    return SizedBox(width: column.width, child: padded);
  }

  return Expanded(flex: column.flex, child: padded);
}

/// Cellule « identité » : un libellé fort, une précision discrète dessous.
/// Deux lignes maximum — la troisième ne tient pas dans
/// [AdminTheme.tableRowHeight] et, surtout, personne ne la lit.
class AdminCellIdentity extends StatelessWidget {
  const AdminCellIdentity({
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: iconColor ?? AdminTheme.textMuted),
          const SizedBox(width: AdminTheme.space2 + 2),
        ],
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminType.bodyStrong,
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminType.caption,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Une action applicable à un enregistrement.
class AdminRowAction {
  const AdminRowAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;

  /// `null` désactive l'action tout en la laissant visible : l'opérateur
  /// voit ce qui existe et comprend que ce n'est pas disponible ici.
  final VoidCallback? onPressed;

  final Color? color;
}

/// Actions d'une ligne : les plus fréquentes en clair, le reste sous « … ».
///
/// Avant, *toutes* les actions vivaient dans un `PopupMenuButton` : deux
/// clics pour certifier un profil, deux clics pour suspendre un accès,
/// deux clics pour tout. Les trois premières sont désormais à un clic.
class AdminRowActions extends StatelessWidget {
  const AdminRowActions({
    required this.primary,
    this.overflow = const <AdminRowAction>[],
    this.busy = false,
    this.busyLabel,
    this.overflowTooltip = 'Autres actions',
    super.key,
  });

  final List<AdminRowAction> primary;
  final List<AdminRowAction> overflow;
  final bool busy;
  final String? busyLabel;
  final String overflowTooltip;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          if (busyLabel != null) ...[
            const SizedBox(width: AdminTheme.space2),
            Flexible(
              child: Text(
                busyLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminType.caption,
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (final action in primary)
          Tooltip(
            message: action.label,
            child: IconButton(
              onPressed: action.onPressed,
              icon: Icon(action.icon, size: 17),
              color: action.color ?? AdminTheme.textSecondary,
              disabledColor: AdminTheme.textMuted.withValues(alpha: 0.35),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              padding: EdgeInsets.zero,
              // Sans ça, chaque bouton réserve les 48 px de la cible
              // tactile Material et la rangée déborde de sa colonne.
              style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        if (overflow.isNotEmpty)
          // Taille forcée : sans ça, `PopupMenuButton` s'habille d'une
          // cible tactile de 48 px, les quatre contrôles dépassaient la
          // largeur de la colonne et le dernier sortait du tableau.
          SizedBox(
            width: 30,
            height: 30,
            child: PopupMenuButton<int>(
              tooltip: overflowTooltip,
              position: PopupMenuPosition.under,
              icon: const Icon(Icons.more_horiz_rounded, size: 17),
              iconColor: AdminTheme.textSecondary,
              constraints: const BoxConstraints(minWidth: 220),
              padding: EdgeInsets.zero,
              splashRadius: 16,
              onSelected: (index) => overflow[index].onPressed?.call(),
              itemBuilder: (context) => [
                for (var index = 0; index < overflow.length; index += 1)
                  PopupMenuItem<int>(
                    value: index,
                    enabled: overflow[index].onPressed != null,
                    height: 36,
                    child: Row(
                      children: [
                        Icon(
                          overflow[index].icon,
                          size: 16,
                          color: overflow[index].color ?? AdminTheme.textMuted,
                        ),
                        const SizedBox(width: AdminTheme.space3),
                        Flexible(
                          child: Text(
                            overflow[index].label,
                            overflow: TextOverflow.ellipsis,
                            style: AdminType.body.copyWith(
                              color:
                                  overflow[index].color ??
                                  AdminTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Pied de liste : position dans le jeu de résultats à gauche, navigation
/// à droite, sur une seule ligne.
///
/// Fusionne `AdminPaginationBar` et `AdminLoadMoreBar`, qui s'empilaient
/// sous sept écrans en disant deux choses contradictoires : « Page 1 sur
/// 3 » puis « 25 chargés, d'autres sont peut-être disponibles ». La
/// pagination porte sur la fenêtre chargée, pas sur le jeu complet — c'est
/// maintenant dit en une phrase.
class AdminListFooter extends StatelessWidget {
  const AdminListFooter({
    required this.rangeStart,
    required this.rangeEnd,
    required this.filteredCount,
    required this.currentPage,
    required this.totalPages,
    this.onPrevious,
    this.onNext,
    this.hasMore = false,
    this.onLoadMore,
    this.itemLabel = 'éléments',
    super.key,
  });

  /// Index 1-based du premier élément affiché.
  final int rangeStart;
  final int rangeEnd;
  final int filteredCount;
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// Vrai quand le contrôleur peut encore aller chercher des documents.
  final bool hasMore;
  final VoidCallback? onLoadMore;
  final String itemLabel;

  @override
  Widget build(BuildContext context) {
    final position = filteredCount == 0
        ? 'Aucun résultat'
        : '$rangeStart-$rangeEnd sur $filteredCount $itemLabel';

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AdminTheme.space4),
      decoration: BoxDecoration(
        color: AdminTheme.surface,
        borderRadius: BorderRadius.circular(AdminTheme.radiusMd),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              hasMore ? '$position chargés' : position,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AdminType.caption,
            ),
          ),
          const Spacer(),
          if (hasMore && onLoadMore != null) ...[
            TextButton(
              onPressed: onLoadMore,
              child: const Text('Charger plus'),
            ),
            const SizedBox(width: AdminTheme.space2),
          ],
          if (totalPages > 1) ...[
            Text(
              '${currentPage + 1} / $totalPages',
              style: AdminType.caption.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: AdminTheme.space2),
            IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded, size: 19),
              tooltip: 'Page précédente',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded, size: 19),
              tooltip: 'Page suivante',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
          ],
        ],
      ),
    );
  }
}
