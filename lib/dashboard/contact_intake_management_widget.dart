import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/contact_intake_controller.dart';
import '../models/contact_intake.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_feedback.dart';
import '../widgets/admin_ui.dart';

class _PipelineStage {
  const _PipelineStage({
    required this.status,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String status;
  final String title;
  final String description;
  final IconData icon;
}

class ContactIntakeManagementWidget extends StatefulWidget {
  const ContactIntakeManagementWidget({super.key});

  @override
  State<ContactIntakeManagementWidget> createState() =>
      _ContactIntakeManagementWidgetState();
}

class _ContactIntakeManagementWidgetState
    extends State<ContactIntakeManagementWidget> {
  static const int _rowsPerPage = 6;
  static const List<_PipelineStage> _pipelineStages = <_PipelineStage>[
    _PipelineStage(
      status: AgencyFollowUpStatus.newLead,
      title: 'Nouveau lead',
      description: 'Premier contact reçu, qualification initiale à faire.',
      icon: Icons.fiber_new_rounded,
    ),
    _PipelineStage(
      status: AgencyFollowUpStatus.reviewing,
      title: 'En revue',
      description: 'Vérification du contexte, du profil et de la pertinence.',
      icon: Icons.fact_check_outlined,
    ),
    _PipelineStage(
      status: AgencyFollowUpStatus.inProgress,
      title: 'En accompagnement',
      description: 'Opportunité suivie avec une action terrain ou relation.',
      icon: Icons.handshake_outlined,
    ),
    _PipelineStage(
      status: AgencyFollowUpStatus.qualified,
      title: 'Qualifié',
      description: 'Mise en relation crédible, exploitable ou confirmée.',
      icon: Icons.verified_rounded,
    ),
    _PipelineStage(
      status: AgencyFollowUpStatus.closed,
      title: 'Clos',
      description: 'Dossier archivé avec une conclusion claire.',
      icon: Icons.archive_outlined,
    ),
  ];

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

  Map<String, int> _buildStageCounts(List<ContactIntake> intakes) {
    final counts = <String, int>{
      for (final stage in _pipelineStages) stage.status: 0,
    };

    for (final intake in intakes) {
      final status = AgencyFollowUpStatus.normalize(
        intake.agencyFollowUpStatus,
      );
      counts[status] = (counts[status] ?? 0) + 1;
    }

    return counts;
  }

  String? _nextStatus(String status) {
    switch (AgencyFollowUpStatus.normalize(status)) {
      case AgencyFollowUpStatus.newLead:
        return AgencyFollowUpStatus.reviewing;
      case AgencyFollowUpStatus.reviewing:
        return AgencyFollowUpStatus.inProgress;
      case AgencyFollowUpStatus.inProgress:
        return AgencyFollowUpStatus.qualified;
      case AgencyFollowUpStatus.qualified:
        return AgencyFollowUpStatus.closed;
      case AgencyFollowUpStatus.closed:
      default:
        return null;
    }
  }

  String _nextActionLabel(String status) {
    switch (_nextStatus(status)) {
      case AgencyFollowUpStatus.reviewing:
        return 'Mettre en revue';
      case AgencyFollowUpStatus.inProgress:
        return 'Accompagner';
      case AgencyFollowUpStatus.qualified:
        return 'Qualifier';
      case AgencyFollowUpStatus.closed:
        return 'Clore';
      default:
        return 'Avancer';
    }
  }

  bool _requiresFollowUpNote(String status) {
    return AgencyFollowUpStatus.normalize(status) !=
        AgencyFollowUpStatus.newLead;
  }

  DateTime? _lastFollowUpActivity(ContactIntake intake) {
    return intake.agencyLastUpdatedAt ?? intake.updatedAt ?? intake.createdAt;
  }

  int _daysSinceLastActivity(ContactIntake intake) {
    final activity = _lastFollowUpActivity(intake);
    if (activity == null) {
      return 0;
    }
    final days = DateTime.now().difference(activity).inDays;
    return days < 0 ? 0 : days;
  }

  String _priorityLabel(ContactIntake intake) {
    final status = AgencyFollowUpStatus.normalize(intake.agencyFollowUpStatus);
    final days = _daysSinceLastActivity(intake);

    if (status == AgencyFollowUpStatus.closed) {
      return 'Archive';
    }
    if (intake.hasParticipantFeedback) {
      switch (ParticipantFeedbackStatus.normalize(
        intake.latestParticipantFeedbackStatus,
      )) {
        case ParticipantFeedbackStatus.issueReported:
          return 'À vérifier';
        case ParticipantFeedbackStatus.trialScheduled:
        case ParticipantFeedbackStatus.opportunitySerious:
          return 'Fort potentiel';
        case ParticipantFeedbackStatus.discussionStarted:
          return 'Signal positif';
        case ParticipantFeedbackStatus.noResponse:
          return days >= 2 ? 'Relance' : 'À suivre';
        case ParticipantFeedbackStatus.notRelevant:
          return 'À clore';
      }
    }
    if (status == AgencyFollowUpStatus.qualified) {
      return days >= 7 ? 'À confirmer' : 'Qualifié';
    }
    if (status == AgencyFollowUpStatus.inProgress) {
      return days >= 7 ? 'Relance terrain' : 'En cours';
    }
    if (status == AgencyFollowUpStatus.reviewing) {
      return days >= 3 ? 'Relance revue' : 'Analyse';
    }
    return days >= 2 ? 'Urgent' : 'À traiter';
  }

  Color _priorityColor(ContactIntake intake) {
    final label = _priorityLabel(intake);
    if (label == 'Urgent' ||
        label == 'À vérifier' ||
        label.startsWith('Relance')) {
      return AdminTheme.warning;
    }
    if (label == 'À confirmer' ||
        label == 'Qualifié' ||
        label == 'Fort potentiel' ||
        label == 'Signal positif') {
      return AdminTheme.success;
    }
    if (label == 'Archive') {
      return AdminTheme.textMuted;
    }
    return AdminTheme.cyan;
  }

  String _activityLabel(ContactIntake intake) {
    final days = _daysSinceLastActivity(intake);
    if (days == 0) {
      return 'Mis à jour aujourd\'hui';
    }
    if (days == 1) {
      return 'Mis à jour hier';
    }
    return 'Inactif depuis $days j';
  }

  Future<_FollowUpUpdateDraft?> _showFollowUpDialog(
    ContactIntake intake, {
    String? initialStatus,
  }) {
    final noteController = TextEditingController(
      text: intake.agencyFollowUpNote ?? '',
    );
    var selectedStatus = AgencyFollowUpStatus.normalize(
      initialStatus ?? intake.agencyFollowUpStatus,
    );
    String? validationError;

    return showDialog<_FollowUpUpdateDraft>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                initialStatus == null
                    ? 'Mettre à jour le suivi agence'
                    : 'Avancer l\'opportunité',
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
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
                        'Motif : ${intake.reasonLabel}',
                        style: const TextStyle(color: AdminTheme.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _pipelineStages.map((stage) {
                          final selected = selectedStatus == stage.status;
                          final color = _followUpColor(stage.status);
                          return ChoiceChip(
                            label: Text(stage.title),
                            selected: selected,
                            showCheckmark: false,
                            selectedColor: color.withValues(alpha: 0.22),
                            backgroundColor: AdminTheme.surfaceSoft.withValues(
                              alpha: 0.48,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? color.withValues(alpha: 0.72)
                                  : AdminTheme.border.withValues(alpha: 0.74),
                            ),
                            labelStyle: TextStyle(
                              color: selected
                                  ? color
                                  : AdminTheme.textSecondary,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                            onSelected: (_) {
                              setDialogState(() {
                                selectedStatus = stage.status;
                                validationError = null;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
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
                            validationError = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        maxLines: 4,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: 'Note agence',
                          hintText:
                              'Contexte terrain, action demandée ou suite donnée.',
                          errorText: validationError,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _requiresFollowUpNote(selectedStatus)
                            ? 'Note requise pour garder une trace exploitable de la décision.'
                            : 'La note reste optionnelle au stade nouveau lead.',
                        style: const TextStyle(
                          color: AdminTheme.textMuted,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final note = noteController.text.trim();
                    if (_requiresFollowUpNote(selectedStatus) &&
                        note.length < 8) {
                      setDialogState(() {
                        validationError =
                            'Ajoutez une note concrète avant de changer ce statut.';
                      });
                      return;
                    }

                    Navigator.of(dialogContext).pop(
                      _FollowUpUpdateDraft(status: selectedStatus, note: note),
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

  Future<void> _updateFollowUp(
    ContactIntake intake, {
    String? initialStatus,
  }) async {
    final draft = await _showFollowUpDialog(
      intake,
      initialStatus: initialStatus,
    );
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
        title: 'Succès',
        message:
            'Suivi mis à jour : ${AgencyFollowUpStatus.label(draft.status)}.',
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

  Future<void> _deleteContactIntake(ContactIntake intake) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Supprimer la mise en relation'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${intake.requesterDisplayName} -> ${intake.targetDisplayName}',
                      style: const TextStyle(
                        color: AdminTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Cette action supprime le dossier de suivi côté admin. Si une conversation liée existe encore, elle sera supprimée avec ses messages.',
                      style: TextStyle(
                        color: AdminTheme.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.danger,
                    foregroundColor: AdminTheme.background,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Supprimer'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    setState(() {
      _actionIntakeId = intake.id;
    });

    final response = await _contactIntakeController.deleteContactIntake(
      intake: intake,
    );

    if (response.success) {
      showAdminFeedback(
        title: 'Mise en relation supprimée',
        message:
            'Le dossier de suivi a été supprimé. La conversation liée a été nettoyée si elle existait encore.',
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
      intake.participantFeedbackLabel,
      intake.latestParticipantFeedbackNote ?? '',
      intake.participantFeedbackActorLabel,
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
                ? '$roleLabel  -  ${organization!.trim()}'
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

  Widget _buildPriorityCell(ContactIntake intake) {
    final color = _priorityColor(intake);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PriorityPill(label: _priorityLabel(intake), color: color),
          const SizedBox(height: 6),
          Text(
            _activityLabel(intake),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AdminTheme.textMuted,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Color _participantSignalColor(ContactIntake intake) {
    switch (ParticipantFeedbackStatus.normalize(
      intake.latestParticipantFeedbackStatus,
    )) {
      case ParticipantFeedbackStatus.issueReported:
        return AdminTheme.warning;
      case ParticipantFeedbackStatus.trialScheduled:
      case ParticipantFeedbackStatus.opportunitySerious:
        return AdminTheme.success;
      case ParticipantFeedbackStatus.discussionStarted:
        return AdminTheme.cyan;
      case ParticipantFeedbackStatus.notRelevant:
        return AdminTheme.textMuted;
      case ParticipantFeedbackStatus.noResponse:
      default:
        return AdminTheme.accent;
    }
  }

  Widget _buildParticipantSignalCell(ContactIntake intake) {
    if (!intake.hasParticipantFeedback) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: const Text(
          'En attente de retour',
          style: TextStyle(
            color: AdminTheme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final color = _participantSignalColor(intake);
    final note = intake.latestParticipantFeedbackNote?.trim();
    final actor = intake.participantFeedbackActorLabel;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PriorityPill(label: intake.participantFeedbackLabel, color: color),
          const SizedBox(height: 6),
          Text(
            'Signalé par : $actor',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AdminTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (note?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              note!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AdminTheme.textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionMenuCell(ContactIntake intake) {
    final nextStatus = _nextStatus(intake.agencyFollowUpStatus);

    return PopupMenuButton<String>(
      tooltip: 'Actions mise en relation',
      onSelected: (value) {
        if (value == 'follow_up') {
          _updateFollowUp(intake);
          return;
        }

        if (value == 'next_status' && nextStatus != null) {
          _updateFollowUp(intake, initialStatus: nextStatus);
          return;
        }

        if (value == 'delete') {
          _deleteContactIntake(intake);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'follow_up',
          child: Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 18, color: AdminTheme.cyan),
              SizedBox(width: 8),
              Text('Mettre à jour le suivi'),
            ],
          ),
        ),
        if (nextStatus != null)
          PopupMenuItem(
            value: 'next_status',
            child: Row(
              children: [
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: AdminTheme.accent,
                ),
                const SizedBox(width: 8),
                Text(_nextActionLabel(intake.agencyFollowUpStatus)),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: AdminTheme.danger,
              ),
              SizedBox(width: 8),
              Text('Supprimer'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPipelineOverview({
    required List<ContactIntake> intakes,
    required Map<String, int> stageCounts,
    required bool compact,
  }) {
    final openCount = intakes.where((intake) {
      return AgencyFollowUpStatus.normalize(intake.agencyFollowUpStatus) !=
          AgencyFollowUpStatus.closed;
    }).length;

    return AdminSubsectionCard(
      title: 'Parcours de suivi',
      subtitle:
          '$openCount dossier(s) ouvert(s). Sélectionnez une étape pour filtrer la liste.',
      accentColor: AdminTheme.cyan,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 780;
          final cardWidth = stacked
              ? constraints.maxWidth
              : (compact ? 218.0 : 238.0);
          final cards = _pipelineStages.map((stage) {
            final count = stageCounts[stage.status] ?? 0;
            return SizedBox(
              width: cardWidth,
              child: _PipelineStageCard(
                stage: stage,
                count: count,
                total: intakes.length,
                color: _followUpColor(stage.status),
                selected: _selectedFollowUpStatus == stage.status,
                onTap: () {
                  setState(() {
                    _selectedFollowUpStatus =
                        _selectedFollowUpStatus == stage.status
                        ? 'Tous'
                        : stage.status;
                    _currentPage = 0;
                  });
                },
              ),
            );
          }).toList();

          final resetButton = Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _selectedFollowUpStatus == 'Tous'
                  ? null
                  : () {
                      setState(() {
                        _selectedFollowUpStatus = 'Tous';
                        _currentPage = 0;
                      });
                    },
              icon: const Icon(Icons.layers_clear_outlined, size: 18),
              label: const Text('Voir tout'),
            ),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                resetButton,
                const SizedBox(height: 8),
                Wrap(spacing: 10, runSpacing: 10, children: cards),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              resetButton,
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: cards
                      .map(
                        (card) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: card,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);
    final statusItems = <String>[
      'Tous',
      ...ContactIntakeController.followUpStatuses,
    ];
    final statusDropdown = DropdownButtonFormField<String>(
      initialValue: _selectedFollowUpStatus,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Suivi'),
      items: statusItems
          .map(
            (status) => DropdownMenuItem(
              value: status,
              child: Text(
                status == 'Tous' ? status : AgencyFollowUpStatus.label(status),
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

    return AdminGlassPanel(
      padding: EdgeInsets.all(compact ? 16 : 22),
      highlight: true,
      accentColor: AdminTheme.accentSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminSectionHeader(
            badge: 'Mises en relation',
            title: 'Mises en relation',
            subtitle:
                'Suivi des premiers contacts qualifiés et des retours utilisateurs.',
          ),
          const SizedBox(height: 14),
          const AdminInfoBanner(
            title: 'Suivi opérationnel',
            message:
                'Qualifiez, accompagnez ou clôturez chaque dossier depuis une vue unique.',
            icon: Icons.support_agent_rounded,
            tone: AdminBannerTone.info,
          ),
          const SizedBox(height: 12),
          AdminFilterBar(
            maxWidth: 900,
            flexes: const [3, 2],
            children: [
              AdminSearchField(
                controller: _searchController,
                hintText: 'Rechercher un contact, un contexte ou une note',
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                    _currentPage = 0;
                  });
                },
              ),
              statusDropdown,
            ],
          ),
          const SizedBox(height: 12),
          Obx(() {
            final allIntakes = _contactIntakeController.contactIntakes;
            final filtered = allIntakes.where((intake) {
              final normalizedStatus = AgencyFollowUpStatus.normalize(
                intake.agencyFollowUpStatus,
              );
              final matchesStatus =
                  _selectedFollowUpStatus == 'Tous' ||
                  normalizedStatus == _selectedFollowUpStatus;
              return matchesStatus && _matchesSearch(intake);
            }).toList();
            final stageCounts = _buildStageCounts(allIntakes);

            if (_contactIntakeController.isLoading.value) {
              return const Center(
                child: AdminLoadingState(
                  message: 'Chargement des mises en relation...',
                ),
              );
            }

            if (allIntakes.isEmpty) {
              return AdminEmptyState(
                title: 'Aucune mise en relation à suivre',
                message:
                    'Les premiers contacts qualifiés apparaîtront ici dès qu\'un utilisateur lancera une mise en relation.',
                icon: Icons.support_agent_outlined,
                actionLabel: 'Recharger',
                actionIcon: Icons.refresh_rounded,
                onAction: () {
                  _contactIntakeController.refreshContactIntakes();
                },
              );
            }

            final newLeadCount = stageCounts[AgencyFollowUpStatus.newLead] ?? 0;
            final activeCount = allIntakes.where((item) {
              final normalized = AgencyFollowUpStatus.normalize(
                item.agencyFollowUpStatus,
              );
              return normalized == AgencyFollowUpStatus.reviewing ||
                  normalized == AgencyFollowUpStatus.inProgress;
            }).length;
            final qualifiedCount =
                stageCounts[AgencyFollowUpStatus.qualified] ?? 0;
            final closedCount = stageCounts[AgencyFollowUpStatus.closed] ?? 0;
            final strongSignalCount = allIntakes.where((item) {
              final signal = ParticipantFeedbackStatus.normalize(
                item.latestParticipantFeedbackStatus,
              );
              return signal == ParticipantFeedbackStatus.trialScheduled ||
                  signal == ParticipantFeedbackStatus.opportunitySerious;
            }).length;
            final issueSignalCount = allIntakes
                .where(
                  (item) =>
                      ParticipantFeedbackStatus.normalize(
                        item.latestParticipantFeedbackStatus,
                      ) ==
                      ParticipantFeedbackStatus.issueReported,
                )
                .length;

            final totalPagesRaw = (filtered.length / _rowsPerPage).ceil();
            final totalPages = totalPagesRaw < 1 ? 1 : totalPagesRaw;
            final safePage = _currentPage >= totalPages
                ? totalPages - 1
                : _currentPage.clamp(0, totalPages - 1);
            final start = safePage * _rowsPerPage;
            final end = (start + _rowsPerPage).clamp(0, filtered.length);
            final displayed = filtered.sublist(start, end);
            final tableColumns = compact
                ? const <DataColumn>[
                    DataColumn(label: Text('Créé le')),
                    DataColumn(label: Text('Demandeur')),
                    DataColumn(label: Text('Cible')),
                    DataColumn(label: Text('Suivi')),
                    DataColumn(label: Text('Retour utilisateur')),
                    DataColumn(label: Text('Priorité')),
                    DataColumn(label: Text('Actions')),
                  ]
                : const <DataColumn>[
                    DataColumn(label: Text('Créé le')),
                    DataColumn(label: Text('Demandeur')),
                    DataColumn(label: Text('Cible')),
                    DataColumn(label: Text('Motif')),
                    DataColumn(label: Text('Contexte')),
                    DataColumn(label: Text('Suivi')),
                    DataColumn(label: Text('Retour utilisateur')),
                    DataColumn(label: Text('Priorité')),
                    DataColumn(label: Text('Introduction')),
                    DataColumn(label: Text('Actions')),
                  ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    AdminMiniStat(
                      label: 'Résultats',
                      value: '${filtered.length}',
                      icon: Icons.filter_alt_outlined,
                      accentColor: AdminTheme.cyan,
                      subtitle: 'Après filtres',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Nouveaux contacts',
                      value: '$newLeadCount',
                      icon: Icons.fiber_new_rounded,
                      accentColor: AdminTheme.accent,
                      subtitle: 'À traiter',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Suivis actifs',
                      value: '$activeCount',
                      icon: Icons.track_changes_rounded,
                      accentColor: AdminTheme.warning,
                      subtitle: 'En cours de suivi',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Qualifiées',
                      value: '$qualifiedCount',
                      icon: Icons.verified_rounded,
                      accentColor: AdminTheme.success,
                      subtitle: 'Dossiers validés',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Signaux forts',
                      value: '$strongSignalCount',
                      icon: Icons.insights_rounded,
                      accentColor: AdminTheme.success,
                      subtitle: 'Retours positifs',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Alertes',
                      value: '$issueSignalCount',
                      icon: Icons.report_problem_outlined,
                      accentColor: AdminTheme.warning,
                      subtitle: 'Problèmes signalés',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Clôturées',
                      value: '$closedCount',
                      icon: Icons.archive_outlined,
                      accentColor: AdminTheme.textMuted,
                      subtitle: 'Historique',
                      minWidth: compact ? 180 : 220,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildPipelineOverview(
                  intakes: allIntakes,
                  stageCounts: stageCounts,
                  compact: compact,
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  AdminEmptyState(
                    title: 'Aucune opportunité dans cette vue',
                    message:
                        'Aucun dossier ne correspond aux filtres actuels. Changez de statut ou élargissez la recherche.',
                    icon: Icons.filter_alt_off_outlined,
                    actionLabel: 'Voir tout',
                    actionIcon: Icons.layers_clear_outlined,
                    onAction: () {
                      setState(() {
                        _selectedFollowUpStatus = 'Tous';
                        _searchQuery = '';
                        _searchController.clear();
                        _currentPage = 0;
                      });
                    },
                  )
                else
                  AdminDataTableCard(
                    compact: compact,
                    child: DataTable(
                      columnSpacing: compact ? 14 : 20,
                      horizontalMargin: compact ? 8 : 10,
                      columns: tableColumns,
                      rows: List<DataRow>.generate(displayed.length, (index) {
                        final intake = displayed[index];
                        final isActionInFlight = _actionIntakeId == intake.id;
                        final actionCell = DataCell(
                          isActionInFlight
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : _buildActionMenuCell(intake),
                        );

                        return DataRow(
                          cells: compact
                              ? <DataCell>[
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 140,
                                      ),
                                      child: Text(
                                        _formatDate(intake.createdAt),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    _buildActorCell(
                                      name: intake.requesterDisplayName,
                                      roleLabel: intake.requesterRoleLabel,
                                      organization:
                                          intake.requesterOrganization,
                                    ),
                                  ),
                                  DataCell(
                                    _buildActorCell(
                                      name: intake.targetDisplayName,
                                      roleLabel: intake.targetRoleLabel,
                                      organization: intake.targetOrganization,
                                    ),
                                  ),
                                  DataCell(_buildFollowUpCell(intake)),
                                  DataCell(_buildParticipantSignalCell(intake)),
                                  DataCell(_buildPriorityCell(intake)),
                                  actionCell,
                                ]
                              : <DataCell>[
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 150,
                                      ),
                                      child: Text(
                                        _formatDate(intake.createdAt),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    _buildActorCell(
                                      name: intake.requesterDisplayName,
                                      roleLabel: intake.requesterRoleLabel,
                                      organization:
                                          intake.requesterOrganization,
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
                                      constraints: const BoxConstraints(
                                        maxWidth: 160,
                                      ),
                                      child: Text(
                                        intake.reasonLabel,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 180,
                                      ),
                                      child: Text(
                                        intake.contextTitle
                                                    ?.trim()
                                                    .isNotEmpty ==
                                                true
                                            ? '${intake.contextLabel} - ${intake.contextTitle!.trim()}'
                                            : intake.contextLabel,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(_buildFollowUpCell(intake)),
                                  DataCell(_buildParticipantSignalCell(intake)),
                                  DataCell(_buildPriorityCell(intake)),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 260,
                                      ),
                                      child: Text(
                                        intake.introMessage,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  actionCell,
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
                      dataRowMinHeight: compact ? 94 : 124,
                      dataRowMaxHeight: compact ? 112 : 140,
                      headingRowHeight: compact ? 50 : 54,
                    ),
                  ),
                if (filtered.isNotEmpty) ...[
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
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _PipelineStageCard extends StatelessWidget {
  const _PipelineStageCard({
    required this.stage,
    required this.count,
    required this.total,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final _PipelineStage stage;
  final int count;
  final int total;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : count / total;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : AdminTheme.surfaceSoft.withValues(alpha: 0.36),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.72)
                  : AdminTheme.border.withValues(alpha: 0.72),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(stage.icon, color: color, size: 19),
                  ),
                  const Spacer(),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                stage.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AdminTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                stage.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AdminTheme.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: ratio.clamp(0.0, 1.0).toDouble(),
                  backgroundColor: AdminTheme.borderSoft.withValues(alpha: 0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _FollowUpUpdateDraft {
  const _FollowUpUpdateDraft({required this.status, required this.note});

  final String status;
  final String note;
}
