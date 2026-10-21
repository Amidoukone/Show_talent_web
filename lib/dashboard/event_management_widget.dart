import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/event_controller.dart';
import '../models/event.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';
import '../utils/admin_date_format.dart';
import '../widgets/admin_detail_panel.dart';
import '../widgets/admin_feedback.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_table.dart';
import '../widgets/admin_ui.dart';

class EventManagementWidget extends StatefulWidget {
  const EventManagementWidget({super.key});

  @override
  State<EventManagementWidget> createState() => _EventManagementWidgetState();
}

class _EventManagementWidgetState extends State<EventManagementWidget> {
  static const int _rowsPerPage = 25;

  /// Largeur en deçà de laquelle le tableau défile horizontalement. Sert
  /// aussi à AdminWorkspace pour décider si la fiche tient à côté.
  static const double _tableMinWidth = 1040;

  final EventController _eventController = Get.find<EventController>();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedStatus = 'Tous';
  int _currentPage = 0;
  String? _actionEventId;

  /// Événement ouvert dans la fiche latérale. On garde l'identifiant
  /// plutôt que l'objet : la liste se rafraîchit en continu depuis
  /// Firestore, et une copie figée afficherait un statut périmé.
  String? _selectedEventId;

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

    if (confirmed != true || !mounted) {
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
      if (mounted && _selectedEventId == event.id) {
        setState(() {
          _selectedEventId = null;
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
        _actionEventId = null;
      });
    }
  }

  /// Actions d'une ligne : la bascule ouvert/fermé et l'archivage en
  /// clair, les quatre statuts explicites et la suppression sous « … ».
  AdminRowActions _buildRowActions(Event event) {
    final status = Event.normalizeStatus(event.statut);
    final isOpen = status == 'ouvert';

    return AdminRowActions(
      busy: _actionEventId == event.id,
      primary: [
        AdminRowAction(
          icon: isOpen
              ? Icons.event_busy_outlined
              : Icons.event_available_outlined,
          label: isOpen ? 'Fermer l’événement' : 'Ouvrir l’événement',
          color: isOpen ? AdminTheme.warning : AdminTheme.success,
          onPressed: () => _updateStatus(
            event: event,
            nextStatus: isOpen ? 'ferme' : 'ouvert',
          ),
        ),
        AdminRowAction(
          icon: Icons.archive_outlined,
          label: 'Archiver',
          onPressed: status == 'archive'
              ? null
              : () => _updateStatus(event: event, nextStatus: 'archive'),
        ),
      ],
      overflow: [
        for (final candidate in EventController.moderationStatuses)
          AdminRowAction(
            icon: Icons.flag_outlined,
            label: 'Statut : ${_statusLabel(candidate)}',
            color: _statusColor(candidate),
            onPressed: candidate == status
                ? null
                : () => _updateStatus(event: event, nextStatus: candidate),
          ),
        AdminRowAction(
          icon: Icons.delete_outline_rounded,
          label: 'Supprimer',
          color: AdminTheme.danger,
          onPressed: () => _confirmDelete(event),
        ),
      ],
    );
  }

  String _tagsLabel(Event event) =>
      event.tags
          ?.where((value) => value.trim().isNotEmpty)
          .take(3)
          .join(' · ') ??
      '';

  String _capacityLabel(Event event) => event.capaciteMax == null
      ? '${event.participants.length}'
      : '${event.participants.length}/${event.capaciteMax}';

  Widget _buildEventCard(Event event) {
    final status = Event.normalizeStatus(event.statut);
    final tagsLabel = _tagsLabel(event);

    return AdminDataCard(
      onTap: () => setState(() => _selectedEventId = event.id),
      title: Text(event.titre, style: AdminType.bodyStrong),
      subtitle: tagsLabel.isEmpty
          ? null
          : Text(tagsLabel, style: AdminType.caption),
      trailing: AdminPill(
        label: _statusLabel(status),
        color: _statusColor(status),
      ),
      fields: [
        AdminDataCardField(
          label: 'Organisateur',
          value: Text(
            event.organisateur.nom.isEmpty ? 'Inconnu' : event.organisateur.nom,
          ),
        ),
        AdminDataCardField(
          label: 'Période',
          value: Text(
            '${formatAdminDate(event.dateDebut)} - '
            '${formatAdminDate(event.dateFin)}',
          ),
        ),
        AdminDataCardField(label: 'Lieu', value: Text(event.lieu)),
        AdminDataCardField(
          label: 'Participants',
          value: Text(_capacityLabel(event)),
        ),
      ],
      actions: _buildRowActions(event),
    );
  }

  /// Fiche latérale d'un événement : la description, le flyer et le lien
  /// de diffusion n'apparaissaient nulle part dans le portail. Tout vient
  /// de l'événement déjà chargé, sans lecture supplémentaire.
  Widget _buildDetailPanel(Event event, List<Event> queue) {
    final index = queue.indexWhere((item) => item.id == event.id);
    final status = Event.normalizeStatus(event.statut);

    return AdminDetailPanel(
      title: event.titre,
      subtitle: event.organisateur.nom.isEmpty ? null : event.organisateur.nom,
      position: index < 0 ? null : '${index + 1} / ${queue.length}',
      onPrevious: index > 0
          ? () => setState(() => _selectedEventId = queue[index - 1].id)
          : null,
      onNext: index >= 0 && index < queue.length - 1
          ? () => setState(() => _selectedEventId = queue[index + 1].id)
          : null,
      onClose: () => setState(() => _selectedEventId = null),
      actions: [
        OutlinedButton(
          onPressed: _actionEventId == event.id
              ? null
              : () => _confirmDelete(event),
          child: const Text('Supprimer'),
        ),
        ElevatedButton(
          onPressed: _actionEventId == event.id
              ? null
              : () => _updateStatus(
                  event: event,
                  nextStatus: status == 'ouvert' ? 'ferme' : 'ouvert',
                ),
          child: Text(status == 'ouvert' ? 'Fermer' : 'Ouvrir'),
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
                    '${formatAdminDate(event.dateDebut)} - '
                    '${formatAdminDate(event.dateFin)}',
              ),
              AdminDetailField(label: 'Lieu', value: event.lieu),
              AdminDetailField(
                label: 'Participants',
                value: _capacityLabel(event),
              ),
              AdminDetailField(label: 'Vues', value: '${event.views ?? 0}'),
            ],
          ),
          AdminDetailSection(
            title: 'Diffusion',
            children: [
              AdminDetailField(
                label: 'Lien de diffusion',
                value: event.streamingUrl ?? '',
              ),
              AdminDetailField(label: 'Flyer', value: event.flyerUrl ?? ''),
              AdminDetailField(label: 'Tags', value: _tagsLabel(event)),
            ],
          ),
          AdminDetailSection(
            title: 'Description',
            children: [
              SelectableText(
                event.description.isEmpty
                    ? 'Aucune description fournie.'
                    : event.description,
                style: AdminType.prose.copyWith(
                  color: event.description.isEmpty
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
    final statusItems = <String>['Tous', ...EventController.moderationStatuses];

    final toolbar = AdminToolbar(
      flexes: const [3, 2],
      trailing: [
        IconButton(
          onPressed: hasFilters ? _clearFilters : null,
          icon: const Icon(Icons.filter_alt_off_rounded, size: 17),
          tooltip: 'Réinitialiser les filtres',
        ),
        IconButton(
          onPressed: _eventController.refreshEvents,
          icon: const Icon(Icons.refresh_rounded, size: 17),
          tooltip: 'Recharger',
        ),
      ],
      filters: [
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
    );

    return Obx(() {
      final allEvents = _eventController.events;

      if (_eventController.isLoading.value) {
        return const AdminLoadingState(message: 'Chargement des événements…');
      }

      final loadError = _eventController.lastError.value;
      if (loadError.isNotEmpty) {
        return AdminEmptyState(
          title: 'Chargement incomplet',
          message: loadError,
          icon: Icons.error_outline_rounded,
          actionLabel: 'Réessayer',
          actionIcon: Icons.refresh_rounded,
          onAction: _eventController.refreshEvents,
        );
      }

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
      final endIndex = (startIndex + _rowsPerPage).clamp(0, filtered.length);
      final displayed = filtered.sublist(startIndex, endIndex);

      final openedCount = allEvents
          .where((event) => Event.normalizeStatus(event.statut) == 'ouvert')
          .length;
      final archivedCount = allEvents
          .where((event) => Event.normalizeStatus(event.statut) == 'archive')
          .length;
      final totalViews = allEvents.fold<int>(
        0,
        (sum, event) => sum + (event.views ?? 0),
      );

      final stats = AdminStatStrip(
        stats: [
          AdminStat(label: 'affichés', value: '${filtered.length}'),
          AdminStat(
            label: 'ouverts',
            value: '$openedCount',
            selected: _selectedStatus == 'ouvert',
            onTap: () => _toggleStatusFilter('ouvert'),
            tooltip: 'Ne montrer que les événements ouverts',
          ),
          AdminStat(
            label: 'archivés',
            value: '$archivedCount',
            selected: _selectedStatus == 'archive',
            onTap: () => _toggleStatusFilter('archive'),
            tooltip: 'Ne montrer que les événements archivés',
          ),
          AdminStat(label: 'vues cumulées', value: '$totalViews'),
        ],
      );

      final Widget body;
      if (filtered.isEmpty) {
        body = allEvents.isEmpty
            ? AdminEmptyState(
                title: 'Aucun événement à modérer',
                message: 'Aucun événement n’a encore été créé.',
                icon: Icons.event_busy_rounded,
                actionLabel: 'Recharger',
                actionIcon: Icons.refresh_rounded,
                onAction: _eventController.refreshEvents,
              )
            : AdminEmptyState(
                title: 'Aucun événement dans cette vue',
                message: 'Aucun événement ne correspond aux filtres actuels.',
                icon: Icons.filter_alt_off_outlined,
                actionLabel: 'Réinitialiser',
                actionIcon: Icons.filter_alt_off_rounded,
                onAction: _clearFilters,
              );
      } else if (compact) {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final event in displayed) ...[
              _buildEventCard(event),
              const SizedBox(height: AdminTheme.space2),
            ],
          ],
        );
      } else {
        body = AdminTable(
          minWidth: _tableMinWidth,
          columns: const [
            AdminColumn(label: 'Événement', flex: 4),
            AdminColumn(label: 'Organisateur', flex: 2),
            AdminColumn(label: 'Période', width: 190),
            AdminColumn(label: 'Lieu', flex: 2),
            AdminColumn(label: 'Places', width: 80, alignRight: true),
            AdminColumn(label: 'Statut', width: 104),
            AdminColumn(label: '', width: 96, alignRight: true),
          ],
          rowCount: displayed.length,
          selectedRow: _selectedEventId == null
              ? null
              : displayed.indexWhere((event) => event.id == _selectedEventId),
          onRowTap: (index) =>
              setState(() => _selectedEventId = displayed[index].id),
          cellsBuilder: (index) {
            final event = displayed[index];
            final status = Event.normalizeStatus(event.statut);

            return [
              AdminCellIdentity(
                title: event.titre,
                subtitle: _tagsLabel(event),
              ),
              Text(
                event.organisateur.nom.isEmpty
                    ? 'Inconnu'
                    : event.organisateur.nom,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${formatAdminDate(event.dateDebut)} - '
                '${formatAdminDate(event.dateFin)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(event.lieu, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(_capacityLabel(event)),
              AdminPill(
                label: _statusLabel(status),
                color: _statusColor(status),
              ),
              _buildRowActions(event),
            ];
          },
        );
      }

      final selected = _selectedEventId == null
          ? null
          : filtered.where((event) => event.id == _selectedEventId).firstOrNull;

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
                itemLabel: 'événements',
                hasMore: _eventController.hasMore.value,
                onLoadMore: _eventController.loadMoreEvents,
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
