import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/event_controller.dart';
import '../models/event.dart';
import '../theme/admin_theme.dart';
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

  String _statusLabel(String status) {
    switch (status) {
      case 'brouillon':
        return 'Brouillon';
      case 'ouvert':
        return 'Ouvert';
      case 'ferme':
        return 'Ferme';
      case 'archive':
        return 'Archive';
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
        title: 'Succès',
        message:
            'Statut de l’événement mis à jour : ${_statusLabel(nextStatus)}.',
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
        _actionEventId = null;
      });
    }
  }

  Future<void> _confirmDelete(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: Text('Supprimer l’événement "${event.titre}" ?'),
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
      _actionEventId = event.id;
    });

    final response = await _eventController.deleteEvent(event.id);

    if (response.success) {
      showAdminFeedback(
        title: 'Succès',
        message: 'Événement supprimé.',
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
        _actionEventId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);

    return AdminGlassPanel(
      padding: EdgeInsets.all(compact ? 16 : 22),
      highlight: true,
      accentColor: AdminTheme.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminSectionHeader(
            badge: 'Modération des événements',
            title: 'Gestion des événements',
            subtitle:
                'Supervision des événements avec statuts admin et suppression via backend partagé.',
          ),
          const SizedBox(height: 14),
          const AdminInfoBanner(
            title: 'Traitement centralise',
            message:
                'Toutes les mutations de modération passent par les callables admin vérifiés.',
            icon: Icons.event_note_rounded,
            tone: AdminBannerTone.info,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 760;
              final statusItems = <String>[
                'Tous',
                ...EventController.moderationStatuses,
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
                      hintText: 'Rechercher un événement',
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
                      hintText: 'Rechercher un événement',
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
            final allEvents = _eventController.events;

            final filtered = allEvents.where((event) {
              final status = Event.normalizeStatus(event.statut);
              final statusMatch =
                  _selectedStatus == 'Tous' || status == _selectedStatus;
              final searchMatch = _searchQuery.isEmpty ||
                  event.titre.toLowerCase().contains(_searchQuery) ||
                  event.description.toLowerCase().contains(_searchQuery) ||
                  event.organisateur.nom.toLowerCase().contains(_searchQuery) ||
                  event.lieu.toLowerCase().contains(_searchQuery);
              return statusMatch && searchMatch;
            }).toList();

            final totalPages = (filtered.length / _rowsPerPage).ceil();
            final startIndex = _currentPage * _rowsPerPage;
            final endIndex =
                (startIndex + _rowsPerPage).clamp(0, filtered.length);
            final displayed = filtered.sublist(startIndex, endIndex);

            if (_eventController.isLoading.value) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (filtered.isEmpty) {
              return AdminEmptyState(
                title: 'Aucun événement à modérer',
                message:
                    'Aucun événement ne correspond aux filtres appliqués pour le moment.',
                icon: Icons.event_busy_rounded,
                actionLabel: 'Recharger',
                actionIcon: Icons.refresh_rounded,
                onAction: _eventController.refreshEvents,
              );
            }

            final openedCount = allEvents
                .where(
                    (event) => Event.normalizeStatus(event.statut) == 'ouvert')
                .length;
            final archivedCount = allEvents
                .where(
                    (event) => Event.normalizeStatus(event.statut) == 'archive')
                .length;

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
                      subtitle: 'Catalogue global',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Événements archivés',
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
                      DataColumn(label: Text('Organisateur')),
                      DataColumn(label: Text('Periode')),
                      DataColumn(label: Text('Lieu')),
                      DataColumn(label: Text('Participants')),
                      DataColumn(label: Text('Statut')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: List<DataRow>.generate(
                      displayed.length,
                      (index) {
                        final event = displayed[index];
                        final status = Event.normalizeStatus(event.statut);
                        final color = _statusColor(status);
                        final isActionInFlight = _actionEventId == event.id;

                        return DataRow(
                          cells: [
                            DataCell(
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 220),
                                child: Text(
                                  event.titre,
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
                                event.organisateur.nom.isEmpty
                                    ? 'Inconnu'
                                    : event.organisateur.nom,
                              ),
                            ),
                            DataCell(
                              Text(
                                '${event.dateDebut.day}/${event.dateDebut.month}/${event.dateDebut.year} - '
                                '${event.dateFin.day}/${event.dateFin.month}/${event.dateFin.year}',
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 180),
                                child: Text(
                                  event.lieu,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
                                          ...EventController.moderationStatuses
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
