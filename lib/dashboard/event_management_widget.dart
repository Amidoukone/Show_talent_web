import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/event_controller.dart';
import '../models/event.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_date_format.dart';
import '../widgets/admin_feedback.dart';
import '../widgets/admin_ui.dart';

class EventManagementWidget extends StatefulWidget {
  const EventManagementWidget({super.key});

  @override
  State<EventManagementWidget> createState() => _EventManagementWidgetState();
}

class _EventManagementWidgetState extends State<EventManagementWidget> {
  static const int _rowsPerPage = 5;

  final EventController _eventController = Get.find<EventController>();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedStatus = 'Tous';
  int _currentPage = 0;
  String? _actionEventId;

  bool _isCompactLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 1120;

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

  String _statusLabel(String status) {
    switch (status) {
      case 'brouillon':
        return 'Brouillon';
      case 'ouvert':
        return 'Ouvert';
      case 'ferme':
        return 'Fermé';
      case 'archive':
        return 'Archivé';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'brouillon':
        return AdminTheme.warning;
      case 'ouvert':
        return AdminTheme.success;
      case 'ferme':
        return AdminTheme.danger;
      case 'archive':
        return AdminTheme.cyan;
      default:
        return AdminTheme.accent;
    }
  }

  Future<void> _updateStatus({
    required Event event,
    required String nextStatus,
  }) async {
    setState(() {
      _actionEventId = event.id;
    });

    final response = await _eventController.setEventStatus(
      eventId: event.id,
      status: nextStatus,
    );

    if (response.success) {
      showAdminFeedback(
        title: 'Statut mis à jour',
        message:
            'Statut de l’événement mis à jour : ${_statusLabel(nextStatus)}.',
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
        _actionEventId = null;
      });
    }
  }

  Future<void> _confirmDelete(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer l’événement'),
          content: Text('Supprimer l’événement "${event.titre}" ?'),
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

    if (confirmed != true) {
      return;
    }

    setState(() {
      _actionEventId = event.id;
    });

    final response = await _eventController.deleteEvent(event.id);

    if (response.success) {
      showAdminFeedback(
        title: 'Événement supprimé',
        message: 'Événement supprimé.',
        tone: AdminBannerTone.success,
        position: SnackPosition.BOTTOM,
      );
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
        _actionEventId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);
    final hasFilters =
        _searchQuery.trim().isNotEmpty || _selectedStatus != 'Tous';
    final statusItems = <String>['Tous', ...EventController.moderationStatuses];
    final statusDropdown = DropdownButtonFormField<String>(
      initialValue: _selectedStatus,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Statut'),
      items: statusItems
          .map(
            (status) => DropdownMenuItem(
              value: status,
              child: Text(status == 'Tous' ? status : _statusLabel(status)),
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

    return AdminGlassPanel(
      padding: EdgeInsets.all(compact ? 16 : 22),
      highlight: true,
      accentColor: AdminTheme.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminFilterBar(
            maxWidth: 900,
            flexes: const [3, 2, 2],
            children: [
              AdminSearchField(
                controller: _searchController,
                hintText: 'Rechercher un événement',
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                    _currentPage = 0;
                  });
                },
              ),
              statusDropdown,
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: hasFilters ? _clearFilters : null,
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  label: const Text('Réinitialiser'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() {
            final allEvents = _eventController.events;

            final filtered = allEvents.where((event) {
              final status = Event.normalizeStatus(event.statut);
              final statusMatch =
                  _selectedStatus == 'Tous' || status == _selectedStatus;
              final searchMatch =
                  _searchQuery.isEmpty ||
                  [
                    event.titre,
                    event.description,
                    event.organisateur.nom,
                    event.lieu,
                    event.streamingUrl,
                    event.flyerUrl,
                    ...?event.tags,
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
            final endIndex = (startIndex + _rowsPerPage).clamp(
              0,
              filtered.length,
            );
            final displayed = filtered.sublist(startIndex, endIndex);

            if (_eventController.isLoading.value) {
              return const Center(
                child: AdminLoadingState(
                  message: 'Chargement des événements...',
                ),
              );
            }

            if (filtered.isEmpty) {
              if (allEvents.isEmpty) {
                return AdminEmptyState(
                  title: 'Aucun événement à modérer',
                  message: 'Aucun événement n\'a encore été créé.',
                  icon: Icons.event_busy_rounded,
                  actionLabel: 'Recharger',
                  actionIcon: Icons.refresh_rounded,
                  onAction: _eventController.refreshEvents,
                );
              }

              return AdminEmptyState(
                title: 'Aucun événement dans cette vue',
                message: 'Aucun événement ne correspond aux filtres actuels.',
                icon: Icons.filter_alt_off_outlined,
                actionLabel: 'Réinitialiser',
                actionIcon: Icons.filter_alt_off_rounded,
                onAction: _clearFilters,
              );
            }

            final openedCount = allEvents
                .where(
                  (event) => Event.normalizeStatus(event.statut) == 'ouvert',
                )
                .length;
            final archivedCount = allEvents
                .where(
                  (event) => Event.normalizeStatus(event.statut) == 'archive',
                )
                .length;
            final totalViews = allEvents.fold<int>(
              0,
              (sum, event) => sum + (event.views ?? 0),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    AdminMiniStat(
                      label: 'Événements visibles',
                      value: '${filtered.length}',
                      icon: Icons.filter_alt_outlined,
                      accentColor: AdminTheme.cyan,
                      subtitle: 'Après filtres',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Événements ouverts',
                      value: '$openedCount',
                      icon: Icons.event_available_outlined,
                      accentColor: AdminTheme.success,
                      subtitle: 'Catalogue',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Événements archivés',
                      value: '$archivedCount',
                      icon: Icons.archive_outlined,
                      accentColor: AdminTheme.warning,
                      subtitle: 'Catalogue',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Vues',
                      value: '$totalViews',
                      icon: Icons.visibility_outlined,
                      accentColor: AdminTheme.accentSoft,
                      subtitle: 'Côté application',
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
                      DataColumn(label: Text('Organisateur')),
                      DataColumn(label: Text('Période')),
                      DataColumn(label: Text('Lieu')),
                      DataColumn(label: Text('Participants')),
                      DataColumn(label: Text('Statut')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: List<DataRow>.generate(displayed.length, (index) {
                      final event = displayed[index];
                      final status = Event.normalizeStatus(event.statut);
                      final color = _statusColor(status);
                      final isActionInFlight = _actionEventId == event.id;
                      final tagsLabel = event.tags
                          ?.where((value) => value.trim().isNotEmpty)
                          .take(3)
                          .join(' | ');
                      final capacityLabel = event.capaciteMax == null
                          ? ''
                          : '${event.participants.length}/${event.capaciteMax} places';

                      return DataRow(
                        cells: [
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.titre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AdminTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (tagsLabel?.isNotEmpty == true) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      tagsLabel!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AdminTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              event.organisateur.nom.isEmpty
                                  ? 'Inconnu'
                                  : event.organisateur.nom,
                            ),
                          ),
                          DataCell(
                            Text(
                              '${formatAdminDate(event.dateDebut)} - '
                              '${formatAdminDate(event.dateFin)}',
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.lieu,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (capacityLabel.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      capacityLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AdminTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          DataCell(Text('${event.participants.length}')),
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
                                    tooltip: 'Actions événement',
                                    onSelected: (value) {
                                      if (value.startsWith('status:')) {
                                        final status = value.split(':').last;
                                        _updateStatus(
                                          event: event,
                                          nextStatus: status,
                                        );
                                        return;
                                      }

                                      if (value == 'delete') {
                                        _confirmDelete(event);
                                      }
                                    },
                                    itemBuilder: (context) {
                                      return [
                                        ...EventController.moderationStatuses.map(
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
                                                  'Statut : ${_statusLabel(status)}',
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
                    }),
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
                  currentPage: safePage,
                  totalPages: totalPages,
                  onPrevious: safePage > 0
                      ? () {
                          setState(() {
                            _currentPage = safePage - 1;
                          });
                        }
                      : null,
                  onNext: safePage < totalPages - 1
                      ? () {
                          setState(() {
                            _currentPage = safePage + 1;
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
