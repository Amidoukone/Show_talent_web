import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/contact_intake_controller.dart';
import '../models/contact_intake.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';
import '../utils/admin_date_format.dart';
import '../widgets/admin_detail_panel.dart';
import '../widgets/admin_feedback.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_table.dart';
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
  static const int _rowsPerPage = 25;

  /// Largeur en deçà de laquelle le tableau défile horizontalement. Sert
  /// aussi à AdminWorkspace pour décider si la fiche tient à côté.
  static const double _tableMinWidth = 1020;
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

  /// Dossier ouvert dans la fiche latérale. On garde l'identifiant plutôt
  /// que l'objet : la liste se rafraîchit en continu depuis Firestore, et
  /// une copie figée afficherait un suivi périmé après une mise à jour.
  String? _selectedIntakeId;

  bool _isCompactLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AdminTheme.breakpointCompact;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Date inconnue';
    }

    return formatAdminDateTime(value);
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
      return 'Mis à jour aujourd’hui';
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
                    : 'Avancer l’opportunité',
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
                                  ? FontWeight.w700
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
                        style: AdminType.caption,
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
        title: 'Suivi mis à jour',
        message:
            'Suivi mis à jour : ${AgencyFollowUpStatus.label(draft.status)}.',
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
                        fontWeight: FontWeight.w700,
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

    if (!confirmed || !mounted) {
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
        title: 'Suppression impossible',
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

  Future<void> _deleteContactIntakeConversation(ContactIntake intake) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Supprimer la conversation'),
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Cette action supprime uniquement la conversation liée et ses messages. Le dossier de suivi agence reste en place.',
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
                  label: const Text('Supprimer la conversation'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _actionIntakeId = intake.id;
    });

    final response = await _contactIntakeController
        .deleteContactIntakeConversation(intake: intake);

    if (response.success) {
      showAdminFeedback(
        title: 'Conversation supprimée',
        message:
            'La conversation liée a été supprimée. Le dossier de suivi reste actif.',
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

  /// Cellule « acteur » : le nom, puis le rôle et l'organisation sur une
  /// seule ligne discrète.
  Widget _buildActorCell({
    required String name,
    required String roleLabel,
    String? organization,
  }) {
    final detail = organization?.trim().isNotEmpty == true
        ? '$roleLabel · ${organization!.trim()}'
        : roleLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AdminType.bodyStrong,
        ),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AdminType.caption,
        ),
      ],
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

  /// Retour du participant, réduit à son état. L'auteur et la note
  /// complète sont dans la fiche : trois lignes de texte par cellule
  /// imposaient des lignes de 140 px et restaient tronquées.
  Widget _buildParticipantSignalCell(ContactIntake intake) {
    if (!intake.hasParticipantFeedback) {
      return const Text('En attente', style: AdminType.caption);
    }

    return AdminPill(
      label: intake.participantFeedbackLabel,
      color: _participantSignalColor(intake),
    );
  }

  /// Actions d'une ligne : faire avancer le dossier d'une étape, ouvrir la
  /// mise à jour du suivi. Les suppressions restent sous « … ».
  Widget _buildActionMenuCell(ContactIntake intake) {
    final nextStatus = _nextStatus(intake.agencyFollowUpStatus);
    final conversationId = intake.conversationId;

    return AdminRowActions(
      busy: _actionIntakeId == intake.id,
      primary: [
        AdminRowAction(
          icon: Icons.arrow_forward_rounded,
          label: nextStatus == null
              ? 'Dossier au dernier statut'
              : _nextActionLabel(intake.agencyFollowUpStatus),
          color: AdminTheme.accent,
          onPressed: nextStatus == null
              ? null
              : () => _updateFollowUp(intake, initialStatus: nextStatus),
        ),
        AdminRowAction(
          icon: Icons.edit_note_rounded,
          label: 'Mettre à jour le suivi',
          color: AdminTheme.cyan,
          onPressed: () => _updateFollowUp(intake),
        ),
      ],
      overflow: [
        if (conversationId != null && conversationId.isNotEmpty)
          AdminRowAction(
            icon: Icons.forum_outlined,
            label: 'Supprimer la conversation',
            color: AdminTheme.warning,
            onPressed: () => _deleteContactIntakeConversation(intake),
          ),
        AdminRowAction(
          icon: Icons.delete_outline_rounded,
          label: 'Supprimer',
          color: AdminTheme.danger,
          onPressed: () => _deleteContactIntake(intake),
        ),
      ],
    );
  }

  Widget _buildIntakeCard(ContactIntake intake) {
    return AdminDataCard(
      onTap: () => setState(() => _selectedIntakeId = intake.id),
      title: Text(
        '${intake.requesterDisplayName} → ${intake.targetDisplayName}',
        style: AdminType.bodyStrong,
      ),
      subtitle: Text(
        'Créé le ${_formatDate(intake.createdAt)}',
        style: AdminType.caption,
      ),
      trailing: AdminPill(
        label: intake.followUpLabel,
        color: _followUpColor(intake.agencyFollowUpStatus),
      ),
      fields: [
        AdminDataCardField(
          label: 'Retour utilisateur',
          value: _buildParticipantSignalCell(intake),
        ),
        AdminDataCardField(
          label: 'Priorité',
          value: AdminPill(
            label: _priorityLabel(intake),
            color: _priorityColor(intake),
          ),
        ),
      ],
      actions: _buildActionMenuCell(intake),
    );
  }

  /// Fiche d'un dossier de mise en relation.
  ///
  /// Le motif, le contexte, le message d'introduction et la note de suivi
  /// vivaient dans quatre colonnes tronquées à deux ou trois lignes. Ils
  /// sont ici en entier, et la file s'enchaîne avec les flèches.
  Widget _buildDetailPanel(ContactIntake intake, List<ContactIntake> queue) {
    final index = queue.indexWhere((item) => item.id == intake.id);
    final note = intake.latestParticipantFeedbackNote?.trim();
    final nextStatus = _nextStatus(intake.agencyFollowUpStatus);

    return AdminDetailPanel(
      title: '${intake.requesterDisplayName} → ${intake.targetDisplayName}',
      subtitle: 'Créé le ${_formatDate(intake.createdAt)}',
      position: index < 0 ? null : '${index + 1} / ${queue.length}',
      onPrevious: index > 0
          ? () => setState(() => _selectedIntakeId = queue[index - 1].id)
          : null,
      onNext: index >= 0 && index < queue.length - 1
          ? () => setState(() => _selectedIntakeId = queue[index + 1].id)
          : null,
      onClose: () => setState(() => _selectedIntakeId = null),
      actions: [
        OutlinedButton(
          onPressed: _actionIntakeId == intake.id
              ? null
              : () => _updateFollowUp(intake),
          child: const Text('Mettre à jour'),
        ),
        if (nextStatus != null)
          ElevatedButton(
            onPressed: _actionIntakeId == intake.id
                ? null
                : () => _updateFollowUp(intake, initialStatus: nextStatus),
            child: Text(_nextActionLabel(intake.agencyFollowUpStatus)),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AdminDetailSection(
            title: 'Suivi',
            children: [
              AdminDetailField(
                label: 'Statut',
                value: intake.followUpLabel,
                child: AdminPill(
                  label: intake.followUpLabel,
                  color: _followUpColor(intake.agencyFollowUpStatus),
                ),
              ),
              AdminDetailField(
                label: 'Priorité',
                value: _priorityLabel(intake),
                child: AdminPill(
                  label: _priorityLabel(intake),
                  color: _priorityColor(intake),
                ),
              ),
              AdminDetailField(
                label: 'Activité',
                value: _activityLabel(intake),
              ),
              AdminDetailField(
                label: 'Note de suivi',
                value: intake.agencyFollowUpNote ?? '',
              ),
            ],
          ),
          AdminDetailSection(
            title: 'Demandeur',
            children: [
              AdminDetailField(
                label: 'Nom',
                value: intake.requesterDisplayName,
              ),
              AdminDetailField(label: 'Rôle', value: intake.requesterRoleLabel),
              AdminDetailField(
                label: 'Organisation',
                value: intake.requesterOrganization ?? '',
              ),
            ],
          ),
          AdminDetailSection(
            title: 'Cible',
            children: [
              AdminDetailField(label: 'Nom', value: intake.targetDisplayName),
              AdminDetailField(label: 'Rôle', value: intake.targetRoleLabel),
              AdminDetailField(
                label: 'Organisation',
                value: intake.targetOrganization ?? '',
              ),
            ],
          ),
          AdminDetailSection(
            title: 'Demande',
            children: [
              AdminDetailField(label: 'Motif', value: intake.reasonLabel),
              AdminDetailField(
                label: 'Contexte',
                value: intake.contextTitle?.trim().isNotEmpty == true
                    ? '${intake.contextLabel} - ${intake.contextTitle!.trim()}'
                    : intake.contextLabel,
              ),
            ],
          ),
          AdminDetailSection(
            title: 'Message d’introduction',
            children: [
              SelectableText(
                intake.introMessage.isEmpty
                    ? 'Aucun message transmis.'
                    : intake.introMessage,
                style: AdminType.prose.copyWith(
                  color: intake.introMessage.isEmpty
                      ? AdminTheme.textMuted
                      : AdminTheme.textSecondary,
                ),
              ),
            ],
          ),
          AdminDetailSection(
            title: 'Retour utilisateur',
            children: [
              AdminDetailField(
                label: 'Signal',
                value: intake.participantFeedbackLabel,
                child: _buildParticipantSignalCell(intake),
              ),
              if (intake.hasParticipantFeedback)
                AdminDetailField(
                  label: 'Signalé par',
                  value: intake.participantFeedbackActorLabel,
                ),
              if (note != null && note.isNotEmpty)
                AdminDetailField(label: 'Commentaire', value: note),
            ],
          ),
        ],
      ),
    );
  }

  /// Le parcours de suivi, en une ligne de compteurs cliquables.
  ///
  /// Il occupait cinq cartes de 238 px sur deux rangées, sous sept tuiles
  /// de statistiques — soit douze encadrés avant d'atteindre le tableau.
  /// Les compteurs filtrent toujours la liste au clic, ce qui était déjà
  /// la seule chose utile que faisaient les cartes.
  AdminStatStrip _buildPipelineStrip({
    required Map<String, int> stageCounts,
    required int strongSignalCount,
    required int issueSignalCount,
  }) {
    return AdminStatStrip(
      stats: [
        for (final stage in _pipelineStages)
          AdminStat(
            label: stage.title.toLowerCase(),
            value: '${stageCounts[stage.status] ?? 0}',
            tooltip: stage.description,
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
        AdminStat(
          label: 'signaux forts',
          value: '$strongSignalCount',
          tone: strongSignalCount > 0 ? AdminTheme.success : null,
          tooltip: 'Essai programmé ou opportunité jugée sérieuse',
        ),
        AdminStat(
          label: 'alertes',
          value: '$issueSignalCount',
          tone: issueSignalCount > 0 ? AdminTheme.warning : null,
          tooltip: 'Problème signalé par un participant',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);
    final statusItems = <String>[
      'Tous',
      ...ContactIntakeController.followUpStatuses,
    ];

    final toolbar = AdminToolbar(
      flexes: const [3, 2],
      trailing: [
        IconButton(
          onPressed: _selectedFollowUpStatus == 'Tous' && _searchQuery.isEmpty
              ? null
              : () {
                  setState(() {
                    _selectedFollowUpStatus = 'Tous';
                    _searchQuery = '';
                    _searchController.clear();
                    _currentPage = 0;
                  });
                },
          icon: const Icon(Icons.filter_alt_off_rounded, size: 17),
          tooltip: 'Voir tout',
        ),
        IconButton(
          onPressed: _contactIntakeController.refreshContactIntakes,
          icon: const Icon(Icons.refresh_rounded, size: 17),
          tooltip: 'Recharger',
        ),
      ],
      filters: [
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
        AdminFilterDropdown<String>(
          label: 'Suivi',
          value: _selectedFollowUpStatus,
          items: statusItems,
          labelBuilder: (status) =>
              status == 'Tous' ? status : AgencyFollowUpStatus.label(status),
          onChanged: (value) {
            setState(() {
              _selectedFollowUpStatus = value;
              _currentPage = 0;
            });
          },
        ),
      ],
    );

    return Obx(() {
      final allIntakes = _contactIntakeController.contactIntakes;

      if (_contactIntakeController.isLoading.value) {
        return const AdminLoadingState(
          message: 'Chargement des mises en relation…',
        );
      }

      final loadError = _contactIntakeController.lastError.value;
      if (loadError.isNotEmpty) {
        return AdminEmptyState(
          title: 'Chargement incomplet',
          message: loadError,
          icon: Icons.error_outline_rounded,
          actionLabel: 'Réessayer',
          actionIcon: Icons.refresh_rounded,
          onAction: _contactIntakeController.refreshContactIntakes,
        );
      }

      if (allIntakes.isEmpty) {
        return AdminEmptyState(
          title: 'Aucune mise en relation à suivre',
          message:
              'Les premiers contacts qualifiés apparaîtront ici dès qu’un '
              'utilisateur lancera une mise en relation.',
          icon: Icons.support_agent_outlined,
          actionLabel: 'Recharger',
          actionIcon: Icons.refresh_rounded,
          onAction: _contactIntakeController.refreshContactIntakes,
        );
      }

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

      final Widget body;
      if (filtered.isEmpty) {
        body = AdminEmptyState(
          title: 'Aucune opportunité dans cette vue',
          message:
              'Aucun dossier ne correspond aux filtres actuels. Changez '
              'd’étape ou élargissez la recherche.',
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
        );
      } else if (compact) {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final intake in displayed) ...[
              _buildIntakeCard(intake),
              const SizedBox(height: AdminTheme.space2),
            ],
          ],
        );
      } else {
        body = AdminTable(
          minWidth: _tableMinWidth,
          columns: const [
            AdminColumn(label: 'Créé le', width: 108),
            AdminColumn(label: 'Demandeur', flex: 3),
            AdminColumn(label: 'Cible', flex: 3),
            AdminColumn(label: 'Suivi', width: 140),
            AdminColumn(label: 'Retour utilisateur', width: 150),
            AdminColumn(label: 'Priorité', width: 120),
            AdminColumn(label: '', width: 96, alignRight: true),
          ],
          rowCount: displayed.length,
          selectedRow: _selectedIntakeId == null
              ? null
              : displayed.indexWhere(
                  (intake) => intake.id == _selectedIntakeId,
                ),
          onRowTap: (index) =>
              setState(() => _selectedIntakeId = displayed[index].id),
          cellsBuilder: (index) {
            final intake = displayed[index];

            return [
              Text(
                _formatDate(intake.createdAt),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              _buildActorCell(
                name: intake.requesterDisplayName,
                roleLabel: intake.requesterRoleLabel,
                organization: intake.requesterOrganization,
              ),
              _buildActorCell(
                name: intake.targetDisplayName,
                roleLabel: intake.targetRoleLabel,
                organization: intake.targetOrganization,
              ),
              AdminPill(
                label: intake.followUpLabel,
                color: _followUpColor(intake.agencyFollowUpStatus),
              ),
              _buildParticipantSignalCell(intake),
              AdminPill(
                label: _priorityLabel(intake),
                color: _priorityColor(intake),
              ),
              _buildActionMenuCell(intake),
            ];
          },
        );
      }

      final selected = _selectedIntakeId == null
          ? null
          : filtered
                .where((intake) => intake.id == _selectedIntakeId)
                .firstOrNull;

      return AdminWorkspace(
        compact: compact,
        bodyMinWidth: _tableMinWidth,
        toolbar: toolbar,
        stats: _buildPipelineStrip(
          stageCounts: stageCounts,
          strongSignalCount: strongSignalCount,
          issueSignalCount: issueSignalCount,
        ),
        body: body,
        detail: selected == null ? null : _buildDetailPanel(selected, filtered),
        footer: filtered.isEmpty
            ? null
            : AdminListFooter(
                rangeStart: start + 1,
                rangeEnd: end,
                filteredCount: filtered.length,
                currentPage: safePage,
                totalPages: totalPages,
                itemLabel: 'mises en relation',
                hasMore: _contactIntakeController.hasMore.value,
                onLoadMore: _contactIntakeController.loadMoreContactIntakes,
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

class _FollowUpUpdateDraft {
  const _FollowUpUpdateDraft({required this.status, required this.note});

  final String status;
  final String note;
}
