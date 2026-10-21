import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/offre_controller.dart';
import '../models/offre.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';
import '../utils/admin_date_format.dart';
import '../widgets/admin_detail_panel.dart';
import '../widgets/admin_feedback.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_table.dart';
import '../widgets/admin_ui.dart';

class OfferManagementWidget extends StatefulWidget {
  const OfferManagementWidget({super.key});

  @override
  State<OfferManagementWidget> createState() => _OfferManagementWidgetState();
}

class _OfferManagementWidgetState extends State<OfferManagementWidget> {
  static const int _rowsPerPage = 25;

  /// Largeur en deçà de laquelle le tableau défile horizontalement. Sert
  /// aussi à AdminWorkspace pour décider si la fiche tient à côté.
  static const double _tableMinWidth = 940;

  final OffreController _offreController = Get.find<OffreController>();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedStatus = 'Tous';
  int _currentPage = 0;
  String? _actionOfferId;

  /// Offre ouverte dans la fiche latérale. On garde l'identifiant plutôt
  /// que l'objet : la liste se rafraîchit en continu depuis Firestore, et
  /// une copie figée afficherait un statut périmé après une action.
  String? _selectedOfferId;

  bool _isCompactLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AdminTheme.breakpointCompact;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedStatus = 'Tous';
      _currentPage = 0;
      _searchController.clear();
    });
  }

  void _toggleStatusFilter(String status) {
    setState(() {
      _selectedStatus = _selectedStatus == status ? 'Tous' : status;
      _currentPage = 0;
    });
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'brouillon':
        return 'Brouillon';
      case 'ouverte':
        return 'Ouverte';
      case 'fermee':
        return 'Fermée';
      case 'archivee':
        return 'Archivée';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'brouillon':
        return AdminTheme.warning;
      case 'ouverte':
        return AdminTheme.success;
      case 'fermee':
        return AdminTheme.danger;
      case 'archivee':
        return AdminTheme.cyan;
      default:
        return AdminTheme.accent;
    }
  }

  Future<void> _updateStatus({
    required Offre offre,
    required String nextStatus,
  }) async {
    setState(() {
      _actionOfferId = offre.id;
    });

    final response = await _offreController.setOfferStatus(
      offerId: offre.id,
      status: nextStatus,
    );

    if (response.success) {
      showAdminFeedback(
        title: 'Statut mis à jour',
        message: 'Statut de l’offre mis à jour : ${_statusLabel(nextStatus)}.',
        tone: AdminBannerTone.success,
        position: SnackPosition.BOTTOM,
      );
    } else {
      showAdminFeedback(
        title: 'Mise à jour impossible',
        message: response.message,
        tone: AdminBannerTone.danger,
        position: SnackPosition.BOTTOM,
      );
    }

    if (mounted) {
      setState(() {
        _actionOfferId = null;
      });
    }
  }

  Future<void> _confirmDelete(Offre offre) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer l’offre'),
          content: Text('Supprimer l’offre "${offre.titre}" ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.danger,
                foregroundColor: AdminTheme.background,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _actionOfferId = offre.id;
    });

    final response = await _offreController.deleteOffer(offre.id);

    if (response.success) {
      showAdminFeedback(
        title: 'Offre supprimée',
        message: 'Offre supprimée.',
        tone: AdminBannerTone.success,
        position: SnackPosition.BOTTOM,
      );
      if (mounted && _selectedOfferId == offre.id) {
        setState(() {
          _selectedOfferId = null;
        });
      }
    } else {
      showAdminFeedback(
        title: 'Suppression impossible',
        message: response.message,
        tone: AdminBannerTone.danger,
        position: SnackPosition.BOTTOM,
      );
    }

    if (mounted) {
      setState(() {
        _actionOfferId = null;
      });
    }
  }

  /// Actions d'une ligne : les deux bascules de statut les plus courantes
  /// en clair, les quatre statuts explicites et la suppression sous « … ».
  AdminRowActions _buildRowActions(Offre offre) {
    final status = Offre.normalizeStatus(offre.statut);
    final isOpen = status == 'ouverte';

    return AdminRowActions(
      busy: _actionOfferId == offre.id,
      primary: [
        AdminRowAction(
          icon: isOpen
              ? Icons.pause_circle_outline_rounded
              : Icons.play_circle_outline_rounded,
          label: isOpen ? 'Fermer l’offre' : 'Ouvrir l’offre',
          color: isOpen ? AdminTheme.warning : AdminTheme.success,
          onPressed: () => _updateStatus(
            offre: offre,
            nextStatus: isOpen ? 'fermee' : 'ouverte',
          ),
        ),
        AdminRowAction(
          icon: Icons.archive_outlined,
          label: 'Archiver',
          onPressed: status == 'archivee'
              ? null
              : () => _updateStatus(offre: offre, nextStatus: 'archivee'),
        ),
      ],
      overflow: [
        for (final candidate in OffreController.moderationStatuses)
          AdminRowAction(
            icon: Icons.flag_outlined,
            label: 'Statut : ${_statusLabel(candidate)}',
            color: _statusColor(candidate),
            onPressed: candidate == status
                ? null
                : () => _updateStatus(offre: offre, nextStatus: candidate),
          ),
        AdminRowAction(
          icon: Icons.delete_outline_rounded,
          label: 'Supprimer',
          color: AdminTheme.danger,
          onPressed: () => _confirmDelete(offre),
        ),
      ],
    );
  }

  /// La ligne de contexte d'une offre, dans le vocabulaire code.
  ///
  /// Elle lisait `posteRecherche` et `niveau`, du texte libre que le mobile
  /// n'ecrit plus depuis 06b4e43 : elle se reduisait a la localisation, et
  /// personne ne pouvait s'en apercevoir, une cle absente se lisant comme
  /// nulle. `AgeCategory` n'a pas de libelle francais -- son code (« U19 »,
  /// « Senior ») est deja ce qu'un moderateur lit.
  String _offerMetaLine(Offre offre) {
    final niveau = [
      ...offre.ageCategories.map((category) => category.code),
      if (offre.clubLevel != null) offre.clubLevel!.labelFr,
    ].join(' · ');

    return [
      offre.positionCodes.map((position) => position.labelFr).join(', '),
      offre.localisation ?? '',
      niveau,
    ].where((value) => value.trim().isNotEmpty).join(' | ');
  }

  /// Ce sur quoi la recherche doit tomber pour une offre.
  ///
  /// Codes et libelles ensemble : un moderateur tape « attaquant » aussi bien
  /// que « ST », et la recherche ne trouvait plus ni l'un ni l'autre.
  List<String> _offerFootballSearchTerms(Offre offre) => [
    for (final position in offre.positionCodes) ...[
      position.code,
      position.labelFr,
      position.labelEn,
    ],
    ...offre.ageCategories.map((category) => category.code),
    if (offre.clubLevel != null) ...[
      offre.clubLevel!.code,
      offre.clubLevel!.labelFr,
    ],
  ];

  Widget _buildOfferCard(Offre offre) {
    final status = Offre.normalizeStatus(offre.statut);
    final offerMeta = _offerMetaLine(offre);

    return AdminDataCard(
      onTap: () => setState(() => _selectedOfferId = offre.id),
      title: Text(offre.titre, style: AdminType.bodyStrong),
      subtitle: offerMeta.isNotEmpty
          ? Text(offerMeta, style: AdminType.caption)
          : null,
      trailing: AdminPill(
        label: _statusLabel(status),
        color: _statusColor(status),
      ),
      fields: [
        AdminDataCardField(
          label: 'Recruteur',
          value: Text(
            offre.recruteur.nom.isEmpty ? 'Inconnu' : offre.recruteur.nom,
          ),
        ),
        AdminDataCardField(
          label: 'Période',
          value: Text(
            '${formatAdminDate(offre.dateDebut)} - '
            '${formatAdminDate(offre.dateFin)}',
          ),
        ),
        AdminDataCardField(
          label: 'Candidats',
          value: Text('${offre.candidats.length}'),
        ),
      ],
      actions: _buildRowActions(offre),
    );
  }

  /// Fiche latérale d'une offre.
  ///
  /// La description et la rémunération n'étaient visibles nulle part dans
  /// le portail : le tableau n'a pas la place, et il n'existait aucune vue
  /// de détail. Tout vient de l'offre déjà chargée, sans lecture
  /// supplémentaire.
  Widget _buildDetailPanel(Offre offre, List<Offre> queue) {
    final index = queue.indexWhere((item) => item.id == offre.id);
    final status = Offre.normalizeStatus(offre.statut);

    return AdminDetailPanel(
      title: offre.titre,
      subtitle: offre.recruteur.nom.isEmpty ? null : offre.recruteur.nom,
      position: index < 0 ? null : '${index + 1} / ${queue.length}',
      onPrevious: index > 0
          ? () => setState(() => _selectedOfferId = queue[index - 1].id)
          : null,
      onNext: index >= 0 && index < queue.length - 1
          ? () => setState(() => _selectedOfferId = queue[index + 1].id)
          : null,
      onClose: () => setState(() => _selectedOfferId = null),
      actions: [
        OutlinedButton(
          onPressed: _actionOfferId == offre.id
              ? null
              : () => _confirmDelete(offre),
          child: const Text('Supprimer'),
        ),
        ElevatedButton(
          onPressed: _actionOfferId == offre.id
              ? null
              : () => _updateStatus(
                  offre: offre,
                  nextStatus: status == 'ouverte' ? 'fermee' : 'ouverte',
                ),
          child: Text(status == 'ouverte' ? 'Fermer' : 'Ouvrir'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AdminDetailSection(
            title: 'Statut',
            children: [
              AdminDetailField(
                label: 'Statut',
                value: _statusLabel(status),
                child: AdminPill(
                  label: _statusLabel(status),
                  color: _statusColor(status),
                ),
              ),
              AdminDetailField(
                label: 'Période',
                value:
                    '${formatAdminDate(offre.dateDebut)} - '
                    '${formatAdminDate(offre.dateFin)}',
              ),
              AdminDetailField(
                label: 'Candidats',
                value: '${offre.candidats.length}',
              ),
              AdminDetailField(label: 'Vues', value: '${offre.vues ?? 0}'),
            ],
          ),
          AdminDetailSection(
            title: 'Recherche',
            children: [
              AdminDetailField(
                label: 'Postes',
                value: offre.positionCodes
                    .map((position) => position.labelFr)
                    .join(', '),
              ),
              AdminDetailField(
                label: 'Catégories',
                value: offre.ageCategories
                    .map((category) => category.code)
                    .join(' · '),
              ),
              AdminDetailField(
                label: 'Niveau',
                value: offre.clubLevel?.labelFr ?? '',
              ),
              AdminDetailField(
                label: 'Localisation',
                value: offre.localisation ?? '',
              ),
              AdminDetailField(
                label: 'Rémunération',
                value: offre.remuneration ?? '',
              ),
            ],
          ),
          AdminDetailSection(
            title: 'Description',
            children: [
              SelectableText(
                offre.description.isEmpty
                    ? 'Aucune description fournie.'
                    : offre.description,
                style: AdminType.prose.copyWith(
                  color: offre.description.isEmpty
                      ? AdminTheme.textMuted
                      : AdminTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);
    final hasFilters =
        _searchQuery.trim().isNotEmpty || _selectedStatus != 'Tous';
    final statusItems = <String>['Tous', ...OffreController.moderationStatuses];

    final toolbar = AdminToolbar(
      flexes: const [3, 2],
      filters: [
        AdminSearchField(
          controller: _searchController,
          hintText: 'Rechercher une offre',
          onChanged: (value) {
            setState(() {
              _searchQuery = value.trim().toLowerCase();
              _currentPage = 0;
            });
          },
        ),
        AdminFilterDropdown<String>(
          label: 'Statut',
          value: _selectedStatus,
          items: statusItems,
          labelBuilder: (status) =>
              status == 'Tous' ? status : _statusLabel(status),
          onChanged: (value) {
            setState(() {
              _selectedStatus = value;
              _currentPage = 0;
            });
          },
        ),
      ],
      trailing: [
        IconButton(
          onPressed: hasFilters ? _clearFilters : null,
          icon: const Icon(Icons.filter_alt_off_rounded, size: 17),
          tooltip: 'Réinitialiser les filtres',
        ),
        IconButton(
          onPressed: _offreController.getAllOffres,
          icon: const Icon(Icons.refresh_rounded, size: 17),
          tooltip: 'Recharger',
        ),
      ],
    );

    return Obx(() {
      final allOffres = _offreController.offres;

      if (_offreController.isLoading.value) {
        return const AdminLoadingState(message: 'Chargement des offres…');
      }

      final loadError = _offreController.lastError.value;
      if (loadError.isNotEmpty) {
        return AdminEmptyState(
          title: 'Chargement incomplet',
          message: loadError,
          icon: Icons.error_outline_rounded,
          actionLabel: 'Réessayer',
          actionIcon: Icons.refresh_rounded,
          onAction: _offreController.getAllOffres,
        );
      }

      final filtered = allOffres.where((offre) {
        final status = Offre.normalizeStatus(offre.statut);
        final statusMatch =
            _selectedStatus == 'Tous' || status == _selectedStatus;
        final searchMatch =
            _searchQuery.isEmpty ||
            [
              offre.titre,
              offre.description,
              offre.recruteur.nom,
              offre.localisation,
              offre.remuneration,
              ..._offerFootballSearchTerms(offre),
            ].whereType<String>().any(
              (value) => value.toLowerCase().contains(_searchQuery),
            );
        return statusMatch && searchMatch;
      }).toList();

      final totalPagesRaw = (filtered.length / _rowsPerPage).ceil();
      final totalPages = totalPagesRaw < 1 ? 1 : totalPagesRaw;
      final safePage = _currentPage >= totalPages
          ? totalPages - 1
          : _currentPage.clamp(0, totalPages - 1);
      final startIndex = safePage * _rowsPerPage;
      final endIndex = (startIndex + _rowsPerPage).clamp(0, filtered.length);
      final displayed = filtered.sublist(startIndex, endIndex);

      final openedCount = allOffres
          .where((offre) => Offre.normalizeStatus(offre.statut) == 'ouverte')
          .length;
      final archivedCount = allOffres
          .where((offre) => Offre.normalizeStatus(offre.statut) == 'archivee')
          .length;
      final totalViews = allOffres.fold<int>(
        0,
        (sum, offre) => sum + (offre.vues ?? 0),
      );

      final stats = AdminStatStrip(
        stats: [
          AdminStat(label: 'affichées', value: '${filtered.length}'),
          AdminStat(
            label: 'ouvertes',
            value: '$openedCount',
            selected: _selectedStatus == 'ouverte',
            onTap: () => _toggleStatusFilter('ouverte'),
            tooltip: 'Ne montrer que les offres ouvertes',
          ),
          AdminStat(
            label: 'archivées',
            value: '$archivedCount',
            selected: _selectedStatus == 'archivee',
            onTap: () => _toggleStatusFilter('archivee'),
            tooltip: 'Ne montrer que les offres archivées',
          ),
          AdminStat(label: 'vues cumulées', value: '$totalViews'),
        ],
      );

      final Widget body;
      if (filtered.isEmpty) {
        body = allOffres.isEmpty
            ? AdminEmptyState(
                title: 'Aucune offre à modérer',
                message: 'Aucune offre n’a encore été créée.',
                icon: Icons.work_outline_rounded,
                actionLabel: 'Recharger',
                actionIcon: Icons.refresh_rounded,
                onAction: _offreController.getAllOffres,
              )
            : AdminEmptyState(
                title: 'Aucune offre dans cette vue',
                message: 'Aucune offre ne correspond aux filtres actuels.',
                icon: Icons.filter_alt_off_outlined,
                actionLabel: 'Réinitialiser',
                actionIcon: Icons.filter_alt_off_rounded,
                onAction: _clearFilters,
              );
      } else if (compact) {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final offre in displayed) ...[
              _buildOfferCard(offre),
              const SizedBox(height: AdminTheme.space2),
            ],
          ],
        );
      } else {
        body = AdminTable(
          minWidth: _tableMinWidth,
          columns: const [
            AdminColumn(label: 'Offre', flex: 4),
            AdminColumn(label: 'Recruteur', flex: 2),
            AdminColumn(label: 'Période', width: 190),
            AdminColumn(label: 'Candidats', width: 92, alignRight: true),
            AdminColumn(label: 'Statut', width: 104),
            AdminColumn(label: '', width: 96, alignRight: true),
          ],
          rowCount: displayed.length,
          selectedRow: _selectedOfferId == null
              ? null
              : displayed.indexWhere((offre) => offre.id == _selectedOfferId),
          onRowTap: (index) =>
              setState(() => _selectedOfferId = displayed[index].id),
          cellsBuilder: (index) {
            final offre = displayed[index];
            final status = Offre.normalizeStatus(offre.statut);

            return [
              AdminCellIdentity(
                title: offre.titre,
                subtitle: _offerMetaLine(offre),
              ),
              Text(
                offre.recruteur.nom.isEmpty ? 'Inconnu' : offre.recruteur.nom,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${formatAdminDate(offre.dateDebut)} - '
                '${formatAdminDate(offre.dateFin)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text('${offre.candidats.length}'),
              AdminPill(
                label: _statusLabel(status),
                color: _statusColor(status),
              ),
              _buildRowActions(offre),
            ];
          },
        );
      }

      final selected = _selectedOfferId == null
          ? null
          : filtered.where((offre) => offre.id == _selectedOfferId).firstOrNull;

      return AdminWorkspace(
        compact: compact,
        bodyMinWidth: _tableMinWidth,
        toolbar: toolbar,
        stats: stats,
        body: body,
        detail: selected == null ? null : _buildDetailPanel(selected, filtered),
        footer: filtered.isEmpty
            ? null
            : AdminListFooter(
                rangeStart: startIndex + 1,
                rangeEnd: endIndex,
                filteredCount: filtered.length,
                currentPage: safePage,
                totalPages: totalPages,
                itemLabel: 'offres',
                hasMore: _offreController.hasMore.value,
                onLoadMore: _offreController.loadMoreOffres,
                onPrevious: safePage > 0
                    ? () => setState(() => _currentPage = safePage - 1)
                    : null,
                onNext: safePage < totalPages - 1
                    ? () => setState(() => _currentPage = safePage + 1)
                    : null,
              ),
      );
    });
  }
}
