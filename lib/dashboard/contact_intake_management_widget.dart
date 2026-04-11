import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/contact_intake_controller.dart';
import '../models/contact_intake.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_feedback.dart';
import '../widgets/admin_ui.dart';

class ContactIntakeManagementWidget extends StatefulWidget {
  const ContactIntakeManagementWidget({super.key});

  @override
  State<ContactIntakeManagementWidget> createState() =>
      _ContactIntakeManagementWidgetState();
}

class _ContactIntakeManagementWidgetState
    extends State<ContactIntakeManagementWidget> {
  static const int _rowsPerPage = 6;

  final ContactIntakeController _contactIntakeController =
      Get.find<ContactIntakeController>();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedFollowUpStatus = 'Tous';
  int _currentPage = 0;
  String? _actionIntakeId;

  bool _isCompactLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 1260;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Date inconnue';
    }

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/$year - $hour:$minute';
  }

  Color _followUpColor(String status) {
    switch (AgencyFollowUpStatus.normalize(status)) {
      case AgencyFollowUpStatus.reviewing:
        return AdminTheme.warning;
      case AgencyFollowUpStatus.inProgress:
        return AdminTheme.cyan;
      case AgencyFollowUpStatus.qualified:
        return AdminTheme.success;
      case AgencyFollowUpStatus.closed:
        return AdminTheme.textMuted;
      case AgencyFollowUpStatus.newLead:
      default:
        return AdminTheme.accent;
    }
  }

  Future<_FollowUpUpdateDraft?> _showFollowUpDialog(ContactIntake intake) {
    final noteController = TextEditingController(
      text: intake.agencyFollowUpNote ?? '',
    );
    var selectedStatus =
        AgencyFollowUpStatus.normalize(intake.agencyFollowUpStatus);

    return showDialog<_FollowUpUpdateDraft>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Mettre a jour le suivi agence'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${intake.requesterDisplayName} -> ${intake.targetDisplayName}',
                      style: const TextStyle(
                        color: AdminTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Motif: ${intake.reasonLabel}',
                      style: const TextStyle(color: AdminTheme.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Statut de suivi',
                      ),
                      items: ContactIntakeController.followUpStatuses
                          .map(
                            (status) => DropdownMenuItem<String>(
                              value: status,
                              child: Text(AgencyFollowUpStatus.label(status)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedStatus = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Note agence',
                        hintText:
                            'Contexte terrain, action demandee ou suite donnee.',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      _FollowUpUpdateDraft(
                        status: selectedStatus,
                        note: noteController.text.trim(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(noteController.dispose);
  }

  Future<void> _updateFollowUp(ContactIntake intake) async {
    final draft = await _showFollowUpDialog(intake);
    if (draft == null) {
      return;
    }

    setState(() {
      _actionIntakeId = intake.id;
    });

    final response = await _contactIntakeController.setAgencyFollowUpStatus(
      contactIntakeId: intake.id,
      status: draft.status,
      note: draft.note,
    );

    if (response.success) {
      showAdminFeedback(
        title: 'Succes',
        message:
            'Suivi agence mis a jour: ${AgencyFollowUpStatus.label(draft.status)}.',
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
        _actionIntakeId = null;
      });
    }
  }

  bool _matchesSearch(ContactIntake intake) {
    if (_searchQuery.isEmpty) {
      return true;
    }

    final haystack = <String>[
      intake.requesterDisplayName,
      intake.targetDisplayName,
      intake.requesterRoleLabel,
      intake.targetRoleLabel,
      intake.requesterOrganization ?? '',
      intake.targetOrganization ?? '',
      intake.reasonLabel,
      intake.contextLabel,
      intake.contextTitle ?? '',
      intake.introMessage,
      intake.agencyFollowUpNote ?? '',
    ].join(' ').toLowerCase();

    return haystack.contains(_searchQuery);
  }

  Widget _buildActorCell({
    required String name,
    required String roleLabel,
    String? organization,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 190),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AdminTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            organization?.trim().isNotEmpty == true
                ? '$roleLabel • ${organization!.trim()}'
                : roleLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AdminTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpCell(ContactIntake intake) {
    final color = _followUpColor(intake.agencyFollowUpStatus);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Text(
              intake.followUpLabel,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          if (intake.hasAgencyNote) ...[
            const SizedBox(height: 6),
            Text(
              intake.agencyFollowUpNote!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AdminTheme.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);

    return AdminGlassPanel(
      padding: EdgeInsets.all(compact ? 16 : 22),
      highlight: true,
      accentColor: AdminTheme.accentSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminSectionHeader(
            badge: 'Mise en relation agence',
            title: 'Contact intakes',
            subtitle:
                'Pilotage des premiers contacts qualifies pour garder la relation dans le circuit Adfoot.',
          ),
          const SizedBox(height: 14),
          const AdminInfoBanner(
            title: 'Suivi centralise',
            message:
                'Chaque premier contact peut etre qualifie, accompagne puis clos sans casser la conversation utilisateur.',
            icon: Icons.support_agent_rounded,
            tone: AdminBannerTone.info,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 760;
              final statusItems = <String>[
                'Tous',
                ...ContactIntakeController.followUpStatuses,
              ];

              final statusDropdown = DropdownButtonFormField<String>(
                value: _selectedFollowUpStatus,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Suivi agence'),
                items: statusItems
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(
                          status == 'Tous'
                              ? status
                              : AgencyFollowUpStatus.label(status),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedFollowUpStatus = value;
                    _currentPage = 0;
                  });
                },
              );

              if (stacked) {
                return Column(
                  children: [
                    AdminSearchField(
                      controller: _searchController,
                      hintText:
                          'Rechercher un contact, un contexte ou une note agence',
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
                      hintText:
                          'Rechercher un contact, un contexte ou une note agence',
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
            final allIntakes = _contactIntakeController.contactIntakes;
            final filtered = allIntakes.where((intake) {
              final normalizedStatus = AgencyFollowUpStatus.normalize(
                intake.agencyFollowUpStatus,
              );
              final matchesStatus = _selectedFollowUpStatus == 'Tous' ||
                  normalizedStatus == _selectedFollowUpStatus;
              return matchesStatus && _matchesSearch(intake);
            }).toList();

            if (_contactIntakeController.isLoading.value) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (filtered.isEmpty) {
              return AdminEmptyState(
                title: 'Aucune mise en relation a suivre',
                message:
                    'Aucun contact intake ne correspond aux filtres appliques pour le moment.',
                icon: Icons.support_agent_outlined,
                actionLabel: 'Recharger',
                actionIcon: Icons.refresh_rounded,
                onAction: () {
                  _contactIntakeController.refreshContactIntakes();
                },
              );
            }

            final newLeadCount = allIntakes
                .where((item) =>
                    AgencyFollowUpStatus.normalize(item.agencyFollowUpStatus) ==
                    AgencyFollowUpStatus.newLead)
                .length;
            final activeCount = allIntakes.where((item) {
              final normalized = AgencyFollowUpStatus.normalize(
                item.agencyFollowUpStatus,
              );
              return normalized == AgencyFollowUpStatus.reviewing ||
                  normalized == AgencyFollowUpStatus.inProgress;
            }).length;
            final closedCount = allIntakes
                .where((item) =>
                    AgencyFollowUpStatus.normalize(item.agencyFollowUpStatus) ==
                    AgencyFollowUpStatus.closed)
                .length;

            final totalPagesRaw = (filtered.length / _rowsPerPage).ceil();
            final totalPages = totalPagesRaw < 1 ? 1 : totalPagesRaw;
            final safePage = _currentPage >= totalPages
                ? totalPages - 1
                : _currentPage.clamp(0, totalPages - 1);
            final start = safePage * _rowsPerPage;
            final end = (start + _rowsPerPage).clamp(0, filtered.length);
            final displayed = filtered.sublist(start, end);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    AdminMiniStat(
                      label: 'Resultats visibles',
                      value: '${filtered.length}',
                      icon: Icons.filter_alt_outlined,
                      accentColor: AdminTheme.cyan,
                      subtitle: 'Apres filtres',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Nouveaux leads',
                      value: '$newLeadCount',
                      icon: Icons.fiber_new_rounded,
                      accentColor: AdminTheme.accent,
                      subtitle: 'A traiter',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Suivis actifs',
                      value: '$activeCount',
                      icon: Icons.track_changes_rounded,
                      accentColor: AdminTheme.warning,
                      subtitle: 'En revue ou accompagnes',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Clotures',
                      value: '$closedCount',
                      icon: Icons.verified_rounded,
                      accentColor: AdminTheme.success,
                      subtitle: 'Historique',
                      minWidth: compact ? 180 : 220,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AdminDataTableCard(
                  compact: compact,
                  child: DataTable(
                    columnSpacing: compact ? 14 : 20,
                    horizontalMargin: compact ? 8 : 10,
                    columns: const [
                      DataColumn(label: Text('Emission')),
                      DataColumn(label: Text('Demandeur')),
                      DataColumn(label: Text('Cible')),
                      DataColumn(label: Text('Motif')),
                      DataColumn(label: Text('Contexte')),
                      DataColumn(label: Text('Suivi agence')),
                      DataColumn(label: Text('Introduction')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: List<DataRow>.generate(
                      displayed.length,
                      (index) {
                        final intake = displayed[index];
                        final isActionInFlight = _actionIntakeId == intake.id;

                        return DataRow(
                          cells: [
                            DataCell(
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 150),
                                child: Text(_formatDate(intake.createdAt)),
                              ),
                            ),
                            DataCell(
                              _buildActorCell(
                                name: intake.requesterDisplayName,
                                roleLabel: intake.requesterRoleLabel,
                                organization: intake.requesterOrganization,
                              ),
                            ),
                            DataCell(
                              _buildActorCell(
                                name: intake.targetDisplayName,
                                roleLabel: intake.targetRoleLabel,
                                organization: intake.targetOrganization,
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 160),
                                child: Text(
                                  intake.reasonLabel,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 180),
                                child: Text(
                                  intake.contextTitle?.trim().isNotEmpty == true
                                      ? '${intake.contextLabel} - ${intake.contextTitle!.trim()}'
                                      : intake.contextLabel,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(_buildFollowUpCell(intake)),
                            DataCell(
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 260),
                                child: Text(
                                  intake.introMessage,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
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
                                  : OutlinedButton.icon(
                                      onPressed: () => _updateFollowUp(intake),
                                      icon: const Icon(
                                        Icons.edit_note_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Suivi'),
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
                    dataRowMinHeight: compact ? 88 : 96,
                    dataRowMaxHeight: compact ? 88 : 96,
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

class _FollowUpUpdateDraft {
  const _FollowUpUpdateDraft({
    required this.status,
    required this.note,
  });

  final String status;
  final String note;
}
