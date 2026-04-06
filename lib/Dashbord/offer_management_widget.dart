import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/offre_controller.dart';
import '../models/offre.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_feedback.dart';
import '../widgets/admin_ui.dart';

class OfferManagementWidget extends StatefulWidget {
  const OfferManagementWidget({super.key});

  @override
  State<OfferManagementWidget> createState() => _OfferManagementWidgetState();
}

class _OfferManagementWidgetState extends State<OfferManagementWidget> {
  static const int _rowsPerPage = 5;

  final OffreController _offreController = Get.find<OffreController>();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedStatus = 'Tous';
  int _currentPage = 0;
  String? _actionOfferId;

  bool _isCompactLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 1120;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'brouillon':
        return 'Brouillon';
      case 'ouverte':
        return 'Ouverte';
      case 'fermee':
        return 'Fermee';
      case 'archivee':
        return 'Archivee';
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
        title: 'Succes',
        message: 'Statut offre mis a jour: ${_statusLabel(nextStatus)}.',
        tone: AdminBannerTone.success,
        position: SnackPosition.BOTTOM,
      );
    } else {
      showAdminFeedback(
        title: 'Erreur',
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
          title: const Text('Confirmation'),
          content: Text(
            'Supprimer l offre "${offre.titre}" ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _actionOfferId = offre.id;
    });

    final response = await _offreController.deleteOffer(offre.id);

    if (response.success) {
      showAdminFeedback(
        title: 'Succes',
        message: 'Offre supprimee.',
        tone: AdminBannerTone.success,
        position: SnackPosition.BOTTOM,
      );
    } else {
      showAdminFeedback(
        title: 'Erreur',
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

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);

    return AdminGlassPanel(
      padding: EdgeInsets.all(compact ? 16 : 22),
      highlight: true,
      accentColor: AdminTheme.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminSectionHeader(
            badge: 'Offer moderation',
            title: 'Gestion des offres',
            subtitle:
                'Supervision des offres avec statuts admin et suppression via backend partage.',
          ),
          const SizedBox(height: 14),
          const AdminInfoBanner(
            title: 'Mutation protegee',
            message:
                'Les changements de statut et suppressions passent uniquement par les callables admin.',
            icon: Icons.gavel_rounded,
            tone: AdminBannerTone.info,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 760;
              final statusItems = <String>[
                'Tous',
                ...OffreController.moderationStatuses,
              ];

              final statusDropdown = DropdownButtonFormField<String>(
                value: _selectedStatus,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Statut',
                ),
                items: statusItems
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(
                          status == 'Tous' ? status : _statusLabel(status),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedStatus = value;
                    _currentPage = 0;
                  });
                },
              );

              if (stacked) {
                return Column(
                  children: [
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
                    const SizedBox(height: 10),
                    statusDropdown,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: AdminSearchField(
                      controller: _searchController,
                      hintText: 'Rechercher une offre',
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.trim().toLowerCase();
                          _currentPage = 0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: statusDropdown,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Obx(() {
            final allOffres = _offreController.offres;

            final filtered = allOffres.where((offre) {
              final status = Offre.normalizeStatus(offre.statut);
              final statusMatch =
                  _selectedStatus == 'Tous' || status == _selectedStatus;
              final searchMatch = _searchQuery.isEmpty ||
                  offre.titre.toLowerCase().contains(_searchQuery) ||
                  offre.description.toLowerCase().contains(_searchQuery) ||
                  offre.recruteur.nom.toLowerCase().contains(_searchQuery);
              return statusMatch && searchMatch;
            }).toList();

            final totalPages = (filtered.length / _rowsPerPage).ceil();
            final startIndex = _currentPage * _rowsPerPage;
            final endIndex =
                (startIndex + _rowsPerPage).clamp(0, filtered.length);
            final displayed = filtered.sublist(startIndex, endIndex);

            if (_offreController.isLoading.value) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (filtered.isEmpty) {
              return AdminEmptyState(
                title: 'Aucune offre a moderer',
                message:
                    'Aucune offre ne correspond aux filtres appliques pour le moment.',
                icon: Icons.work_outline_rounded,
                actionLabel: 'Recharger',
                actionIcon: Icons.refresh_rounded,
                onAction: () {
                  _offreController.getAllOffres();
                },
              );
            }

            final openedCount = allOffres
                .where(
                    (offre) => Offre.normalizeStatus(offre.statut) == 'ouverte')
                .length;
            final archivedCount = allOffres
                .where((offre) =>
                    Offre.normalizeStatus(offre.statut) == 'archivee')
                .length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    AdminMiniStat(
                      label: 'Offres visibles',
                      value: '${filtered.length}',
                      icon: Icons.filter_alt_outlined,
                      accentColor: AdminTheme.cyan,
                      subtitle: 'Apres filtres',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Offres ouvertes',
                      value: '$openedCount',
                      icon: Icons.work_history_outlined,
                      accentColor: AdminTheme.success,
                      subtitle: 'Catalogue global',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Offres archivees',
                      value: '$archivedCount',
                      icon: Icons.archive_outlined,
                      accentColor: AdminTheme.warning,
                      subtitle: 'Catalogue global',
                      minWidth: compact ? 180 : 220,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AdminDataTableCard(
                  compact: compact,
                  child: DataTable(
                    columnSpacing: compact ? 14 : 22,
                    horizontalMargin: compact ? 8 : 10,
                    columns: const [
                      DataColumn(label: Text('Titre')),
                      DataColumn(label: Text('Recruteur')),
                      DataColumn(label: Text('Periode')),
                      DataColumn(label: Text('Candidats')),
                      DataColumn(label: Text('Statut')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: List<DataRow>.generate(
                      displayed.length,
                      (index) {
                        final offre = displayed[index];
                        final status = Offre.normalizeStatus(offre.statut);
                        final color = _statusColor(status);
                        final isActionInFlight = _actionOfferId == offre.id;

                        return DataRow(
                          cells: [
                            DataCell(
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 220),
                                child: Text(
                                  offre.titre,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AdminTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                offre.recruteur.nom.isEmpty
                                    ? 'Inconnu'
                                    : offre.recruteur.nom,
                              ),
                            ),
                            DataCell(
                              Text(
                                '${offre.dateDebut.day}/${offre.dateDebut.month}/${offre.dateDebut.year} - '
                                '${offre.dateFin.day}/${offre.dateFin.month}/${offre.dateFin.year}',
                              ),
                            ),
                            DataCell(Text('${offre.candidats.length}')),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  _statusLabel(status),
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              isActionInFlight
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : PopupMenuButton<String>(
                                      tooltip: 'Actions offre',
                                      onSelected: (value) {
                                        if (value.startsWith('status:')) {
                                          final status = value.split(':').last;
                                          _updateStatus(
                                            offre: offre,
                                            nextStatus: status,
                                          );
                                          return;
                                        }

                                        if (value == 'delete') {
                                          _confirmDelete(offre);
                                        }
                                      },
                                      itemBuilder: (context) {
                                        return [
                                          ...OffreController.moderationStatuses
                                              .map(
                                            (status) => PopupMenuItem(
                                              value: 'status:$status',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.flag_outlined,
                                                    color: _statusColor(status),
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Statut: ${_statusLabel(status)}',
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const PopupMenuDivider(),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete_outline_rounded,
                                                  color: AdminTheme.danger,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text('Supprimer'),
                                              ],
                                            ),
                                          ),
                                        ];
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                    headingRowColor: WidgetStateProperty.all(
                      AdminTheme.surfaceHighlight.withValues(alpha: 0.72),
                    ),
                    dataRowColor: WidgetStateProperty.all(
                      AdminTheme.surface.withValues(alpha: 0.14),
                    ),
                    dividerThickness: 1,
                    dataRowMinHeight: compact ? 62 : 68,
                    dataRowMaxHeight: compact ? 62 : 68,
                    headingRowHeight: compact ? 50 : 54,
                  ),
                ),
                const SizedBox(height: 12),
                AdminPaginationBar(
                  currentPage: _currentPage,
                  totalPages: totalPages,
                  onPrevious: _currentPage > 0
                      ? () {
                          setState(() {
                            _currentPage -= 1;
                          });
                        }
                      : null,
                  onNext: _currentPage < totalPages - 1
                      ? () {
                          setState(() {
                            _currentPage += 1;
                          });
                        }
                      : null,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
