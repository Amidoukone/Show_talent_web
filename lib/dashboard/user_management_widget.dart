import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/user_controller.dart';
import '../models/managed_account_provision_result.dart';
import '../models/user.dart';
import '../services/managed_account_service.dart';
import '../theme/admin_theme.dart';
import '../utils/account_role_policy.dart';
import '../utils/admin_callable_action_catalog.dart';
import '../widgets/admin_account_status_chips.dart';
import '../widgets/admin_feedback.dart';
import '../widgets/admin_ui.dart';
import '../widgets/managed_account_invite_result_dialog.dart';

class UserManagementWidget extends StatefulWidget {
  const UserManagementWidget({
    required this.selectedRole,
    this.showBlockedUsers = false,
    super.key,
  });

  final String selectedRole;
  final bool showBlockedUsers;

  @override
  State<UserManagementWidget> createState() => _UserManagementWidgetState();
}

class _BlockRequestDraft {
  const _BlockRequestDraft({
    required this.isTemporary,
    required this.durationDays,
    required this.reason,
  });

  final bool isTemporary;
  final int? durationDays;
  final String? reason;
}

class _UserManagementWidgetState extends State<UserManagementWidget> {
  static const int rowsPerPage = 4;

  static const String _actionBlock = 'block';
  static const String _actionUnblock = 'unblock';
  static const String _actionDelete = 'delete';
  static const String _actionDisableAuth = 'disable_auth';
  static const String _actionEnableAuth = 'enable_auth';
  static const String _actionChangeRole = 'change_role';
  static const String _actionResendInvite = 'resend_invite';

  final UserController userController = Get.find<UserController>();
  final ManagedAccountService _managedAccountService = ManagedAccountService();
  final TextEditingController _searchController = TextEditingController();

  String searchQuery = '';
  String? selectedRole;
  int currentPage = 0;
  String? _actionInFlightUid;
  String? _actionInFlightLabel;

  bool get _showBlockedUsers => widget.showBlockedUsers;

  @override
  void initState() {
    super.initState();
    selectedRole = widget.selectedRole;
    userController.fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isCompactLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 1120;

  void _clearFilters() {
    setState(() {
      searchQuery = '';
      selectedRole = 'Tous';
      currentPage = 0;
      _searchController.clear();
    });
  }

  bool _isManagedAccount(AppUser user) {
    return user.createdByAdmin || isManagedAccountRole(user.role);
  }

  Color get _panelAccentColor =>
      _showBlockedUsers ? AdminTheme.warning : AdminTheme.accent;

  IconData get _rowLeadingIcon =>
      _showBlockedUsers ? Icons.block_rounded : Icons.person_rounded;

  Color get _rowLeadingColor =>
      _showBlockedUsers ? AdminTheme.danger : AdminTheme.cyan;

  String get _headerBadge =>
      _showBlockedUsers ? 'Comptes bloqués' : 'Opérations utilisateurs';

  String get _headerTitle =>
      _showBlockedUsers ? 'Utilisateurs bloqués' : 'Gestion des utilisateurs';

  String get _headerSubtitle => _showBlockedUsers
      ? 'Contrôle du blocage applicatif, des statuts Auth et des actions correctives.'
      : 'Recherche, rôles, statuts et actions admin centralisées.';

  String get _bannerTitle =>
      _showBlockedUsers ? 'Règles de déblocage' : 'Règles de mutation';

  String get _bannerMessage => _showBlockedUsers
      ? 'Débloquer retire seulement le blocage applicatif. Les actions Auth restent séparées. Le changement de rôle et le renvoi d’invitation sont limités aux comptes gérés.'
      : 'Toutes les mutations cross-user passent désormais par les callables du backend partagé. Blocage applicatif, Auth et activité restent distingués. Le changement de rôle et le renvoi d’invitation sont limités aux comptes gérés.';

  String get _searchHint =>
      _showBlockedUsers ? 'Rechercher un compte bloqué' : 'Rechercher un utilisateur';

  String get _emptyTitle =>
      _showBlockedUsers ? 'Aucun utilisateur bloqué' : 'Aucun utilisateur trouvé';

  String get _emptyMessage => _showBlockedUsers
      ? 'Aucun compte n’est actuellement signalé comme bloqué dans le portail.'
      : 'Ajustez le filtre ou la recherche pour afficher des comptes.';

  void _setActionInFlight(AppUser user, String label) {
    setState(() {
      _actionInFlightUid = user.uid;
      _actionInFlightLabel = label;
    });
  }

  void _clearActionInFlight() {
    if (!mounted) {
      return;
    }

    setState(() {
      _actionInFlightUid = null;
      _actionInFlightLabel = null;
    });
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    Color confirmColor = Colors.red,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: confirmColor),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<void> _runVoidAction({
    required AppUser user,
    required AdminCallableActionDescriptor action,
    required Future<void> Function() request,
    required String successMessage,
  }) async {
    _setActionInFlight(user, action.label);

    try {
      await request();
      if (!mounted) {
        return;
      }

      showAdminFeedback(
        title: 'Succès',
        message: successMessage,
        tone: AdminBannerTone.success,
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }

      showAdminFeedback(
        title: 'Erreur',
        message: error.message ?? 'Opération ${action.callableName} refusée.',
        tone: AdminBannerTone.danger,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      showAdminFeedback(
        title: 'Erreur',
        message: 'Opération ${action.callableName} impossible : $error',
        tone: AdminBannerTone.danger,
      );
    } finally {
      _clearActionInFlight();
    }
  }

  Future<void> _showInviteResultDialog(
    ManagedAccountProvisionResult result,
    String? recipientName,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return ManagedAccountInviteResultDialog(
          result: result,
          recipientName: recipientName,
          title: resendManagedAccountInviteAction.label,
          subtitle:
              'Le message ci-dessous est déjà ordonné pour le titulaire. Copiez-le tel quel ou réutilisez les liens individuellement.',
        );
      },
    );
  }

  Future<_BlockRequestDraft?> _promptBlockReason(AppUser user) async {
    final reasonController = TextEditingController();
    final draft = await showDialog<_BlockRequestDraft>(
      context: context,
      builder: (BuildContext context) {
        bool isTemporary = true;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(blockManagedAccountAction.label),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Le compte ${user.email} sera retiré de la session mobile en cours. Choisissez une suspension temporaire ou un blocage permanent.',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: isTemporary ? 'temporary_15' : 'permanent',
                      decoration: const InputDecoration(
                        labelText: 'Type de sanction',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'temporary_15',
                          child: Text('Suspendre 15 jours'),
                        ),
                        DropdownMenuItem(
                          value: 'permanent',
                          child: Text('Bloquer définitivement'),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          isTemporary = value != 'permanent';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText:
                            'Motif visible par l’utilisateur (optionnel)',
                        hintText: isTemporary
                            ? 'Exemple : vidéo non adaptée, suspension de 15 jours'
                            : 'Exemple : récidive grave, compte bloqué définitivement',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(
                    _BlockRequestDraft(
                      isTemporary: isTemporary,
                      durationDays: isTemporary ? 15 : null,
                      reason: reasonController.text,
                    ),
                  ),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text(isTemporary ? 'Suspendre' : 'Bloquer'),
                ),
              ],
            );
          },
        );
      },
    );

    reasonController.dispose();
    return draft;
  }

  Future<void> _blockManagedAccount(AppUser user) async {
    final draft = await _promptBlockReason(user);
    if (draft == null) {
      return;
    }

    final normalizedReason = draft.reason?.trim() ?? '';
    await _runVoidAction(
      user: user,
      action: blockManagedAccountAction,
      request: () => _managedAccountService.blockManagedAccount(
        uid: user.uid,
        reason: normalizedReason.isEmpty ? null : normalizedReason,
        durationDays: draft.durationDays,
      ),
      successMessage: draft.isTemporary
          ? 'Le compte ${user.email} est suspendu pendant ${draft.durationDays} jours. L’accès mobile est coupé immédiatement${normalizedReason.isEmpty ? '.' : ' et le motif sera affiché à l’utilisateur.'}'
          : 'Le compte ${user.email} est bloqué définitivement. L’accès mobile est coupé immédiatement${normalizedReason.isEmpty ? '.' : ' et le motif sera affiché à l’utilisateur.'}',
    );
  }

  Future<void> _unblockManagedAccount(AppUser user) async {
    final confirmed = await _confirmAction(
      title: unblockManagedAccountAction.label,
      message:
          'Cette action retablit l acces applicatif du compte ${user.email}. Si Firebase Auth reste desactive, la connexion restera refusee.',
      confirmLabel: 'Debloquer',
      confirmColor: Colors.green,
    );
    if (!confirmed) {
      return;
    }

    await _runVoidAction(
      user: user,
      action: unblockManagedAccountAction,
      request: () =>
          _managedAccountService.unblockManagedAccount(uid: user.uid),
      successMessage:
          'L acces applicatif a ete retabli pour ${user.email}. Firebase Auth n a pas ete modifie.',
    );
  }

  Future<void> _deleteManagedAccount(AppUser user) async {
    final confirmed = await _confirmAction(
      title: deleteManagedAccountAction.label,
      message:
          'Cette suppression passe par le backend partagé et peut supprimer l’accès du compte ${user.email}.',
      confirmLabel: 'Supprimer',
    );
    if (!confirmed) {
      return;
    }

    await _runVoidAction(
      user: user,
      action: deleteManagedAccountAction,
      request: () => _managedAccountService.deleteManagedAccount(uid: user.uid),
      successMessage: 'La suppression admin a été demandée pour ${user.email}.',
    );
  }

  Future<void> _disableManagedAccountAuth(AppUser user) async {
    final confirmed = await _confirmAction(
      title: disableManagedAccountAuthAction.label,
      message:
          'Cette action désactive Firebase Auth pour ${user.email}. Si le compte est déjà bloqué applicativement, la session mobile restera également fermée.',
      confirmLabel: 'Désactiver Auth',
    );
    if (!confirmed) {
      return;
    }

    await _runVoidAction(
      user: user,
      action: disableManagedAccountAuthAction,
      request: () =>
          _managedAccountService.disableManagedAccountAuth(uid: user.uid),
      successMessage:
          'Firebase Auth a été désactivé pour ${user.email}. Le blocage applicatif n’a pas été modifié.',
    );
  }

  Future<void> _enableManagedAccountAuth(AppUser user) async {
    await _runVoidAction(
      user: user,
      action: enableManagedAccountAuthAction,
      request: () =>
          _managedAccountService.enableManagedAccountAuth(uid: user.uid),
      successMessage:
          'Firebase Auth a été réactivé pour ${user.email}. Le blocage applicatif n’a pas été modifié.',
    );
  }

  Future<void> _changeManagedAccountRole(AppUser user) async {
    if (!_isManagedAccount(user)) {
      showAdminFeedback(
        title: 'Action indisponible',
        message:
            'Le changement de rôle n’est proposé que pour les comptes gérés.',
        tone: AdminBannerTone.warning,
      );
      return;
    }

    final selectedManagedRole = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final currentRole = normalizeUserRole(user.role);
        String nextRole = isManagedAccountRole(currentRole)
            ? currentRole
            : managedAccountRoles.first;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(changeManagedAccountRoleAction.label),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Compte cible : ${user.email}'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: nextRole,
                    decoration: const InputDecoration(
                      labelText: 'Nouveau rôle',
                      border: OutlineInputBorder(),
                    ),
                    items: managedAccountRoles
                        .map(
                          (role) => DropdownMenuItem<String>(
                            value: role,
                            child: Text(role),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setDialogState(() {
                        nextRole = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(nextRole),
                  child: const Text('Valider'),
                ),
              ],
            );
          },
        );
      },
    );

    final currentRole = normalizeUserRole(user.role);
    if (selectedManagedRole == null || selectedManagedRole == currentRole) {
      return;
    }

    await _runVoidAction(
      user: user,
      action: changeManagedAccountRoleAction,
      request: () => _managedAccountService.changeManagedAccountRole(
        uid: user.uid,
        role: selectedManagedRole,
      ),
      successMessage:
          'Le rôle de ${user.email} a été changé vers $selectedManagedRole.',
    );
  }

  Future<void> _resendManagedAccountInvite(AppUser user) async {
    if (!_isManagedAccount(user)) {
      showAdminFeedback(
        title: 'Action indisponible',
        message:
            'Le renvoi d’invitation n’est proposé que pour les comptes gérés.',
        tone: AdminBannerTone.warning,
      );
      return;
    }

    _setActionInFlight(user, resendManagedAccountInviteAction.label);

    try {
      final result = await _managedAccountService.resendManagedAccountInvite(
        uid: user.uid,
      );
      if (!mounted) {
        return;
      }

      showAdminFeedback(
        title: 'Succès',
        message: 'Les liens d’invitation ont été régénérés pour ${user.email}.',
        tone: AdminBannerTone.success,
      );
      await _showInviteResultDialog(result, user.nom);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }

      showAdminFeedback(
        title: 'Erreur',
        message: error.message ??
            'Impossible de renvoyer les liens d’invitation pour ce compte.',
        tone: AdminBannerTone.danger,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      showAdminFeedback(
        title: 'Erreur',
        message: 'Impossible de renvoyer les liens d’invitation : $error',
        tone: AdminBannerTone.danger,
      );
    } finally {
      _clearActionInFlight();
    }
  }

  List<PopupMenuEntry<String>> _buildActionMenuItems(AppUser user) {
    final items = <PopupMenuEntry<String>>[
      PopupMenuItem(
        value: _showBlockedUsers ? _actionUnblock : _actionBlock,
        child: Row(
          children: [
            Icon(
              _showBlockedUsers
                  ? Icons.check_circle_outline_rounded
                  : Icons.block_rounded,
              size: 18,
              color:
                  _showBlockedUsers ? AdminTheme.success : AdminTheme.danger,
            ),
            const SizedBox(width: 8),
            Text(_showBlockedUsers ? 'Debloquer' : 'Bloquer'),
          ],
        ),
      ),
      PopupMenuItem(
        value: user.authDisabled ? _actionEnableAuth : _actionDisableAuth,
        child: Row(
          children: [
            Icon(
              user.authDisabled
                  ? Icons.lock_open_rounded
                  : Icons.lock_outline_rounded,
              size: 18,
              color:
                  user.authDisabled ? AdminTheme.success : AdminTheme.warning,
            ),
            const SizedBox(width: 8),
            Text(user.authDisabled ? 'Réactiver Auth' : 'Désactiver Auth'),
          ],
        ),
      ),
    ];

    if (_isManagedAccount(user)) {
      items.add(const PopupMenuDivider());
      items.addAll([
        PopupMenuItem(
          value: _actionChangeRole,
          child: Row(
            children: const [
              Icon(Icons.manage_accounts_outlined,
                  size: 18, color: AdminTheme.cyan),
              SizedBox(width: 8),
              Text('Changer le rôle'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _actionResendInvite,
          child: Row(
            children: const [
              Icon(Icons.mark_email_read_outlined,
                  size: 18, color: AdminTheme.accent),
              SizedBox(width: 8),
              Text('Renvoyer l’invitation'),
            ],
          ),
        ),
      ]);
    }

    items.add(const PopupMenuDivider());
    items.add(
      const PopupMenuItem(
        value: _actionDelete,
        child: Row(
          children: [
            Icon(Icons.delete_outline_rounded,
                size: 18, color: AdminTheme.danger),
            SizedBox(width: 8),
            Text('Supprimer'),
          ],
        ),
      ),
    );

    return items;
  }

  Future<void> _handleActionSelection(String value, AppUser user) async {
    switch (value) {
      case _actionBlock:
        await _blockManagedAccount(user);
        break;
      case _actionUnblock:
        await _unblockManagedAccount(user);
        break;
      case _actionDelete:
        await _deleteManagedAccount(user);
        break;
      case _actionDisableAuth:
        await _disableManagedAccountAuth(user);
        break;
      case _actionEnableAuth:
        await _enableManagedAccountAuth(user);
        break;
      case _actionChangeRole:
        await _changeManagedAccountRole(user);
        break;
      case _actionResendInvite:
        await _resendManagedAccountInvite(user);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);
    final panelPadding = compact ? 16.0 : 22.0;
    final spacing = compact ? 12.0 : 16.0;
    final tableColumnSpacing = compact ? 16.0 : 24.0;
    final rowHeight = compact ? 52.0 : 56.0;

    return AdminGlassPanel(
      padding: EdgeInsets.all(panelPadding),
      highlight: true,
      accentColor: _panelAccentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSectionHeader(
            badge: _headerBadge,
            title: _headerTitle,
            subtitle: _headerSubtitle,
            trailing: AdminGlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              radius: 18,
              accentColor: AdminTheme.cyan,
              child: DropdownButton<String>(
                value: selectedRole,
                dropdownColor: AdminTheme.surfaceRaised,
                underline: const SizedBox.shrink(),
                items: <String>[
                  'Tous',
                  'joueur',
                  'club',
                  'recruteur',
                  'agent',
                  'fan',
                ].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedRole = newValue;
                    currentPage = 0;
                  });
                },
              ),
            ),
          ),
          SizedBox(height: spacing),
          AdminInfoBanner(
            title: _bannerTitle,
            message: _bannerMessage,
            icon: _showBlockedUsers
                ? Icons.gpp_maybe_outlined
                : Icons.rule_folder_outlined,
            tone: AdminBannerTone.warning,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
            child: AdminSearchField(
              controller: _searchController,
              hintText: _searchHint,
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                  currentPage = 0;
                });
              },
            ),
          ),
          Obx(() {
            final filteredUsers = userController.userList.where((user) {
              final isBlocked = user.hasActiveAppBlock;
              final matchesRole =
                  selectedRole == 'Tous' || user.role == selectedRole;
              final normalizedQuery = searchQuery.toLowerCase();
              final matchesSearch =
                  user.nom.toLowerCase().contains(normalizedQuery) ||
                      user.email.toLowerCase().contains(normalizedQuery);

              return matchesRole &&
                  matchesSearch &&
                  (_showBlockedUsers ? isBlocked : !isBlocked);
            }).toList();

            final totalPages = (filteredUsers.length / rowsPerPage).ceil();
            final startIndex = currentPage * rowsPerPage;
            final endIndex = (startIndex + rowsPerPage).clamp(
              0,
              filteredUsers.length,
            );
            final displayedUsers = filteredUsers.sublist(startIndex, endIndex);

            if (filteredUsers.isEmpty) {
              final hasFilters =
                  searchQuery.trim().isNotEmpty || selectedRole != 'Tous';

              return AdminEmptyState(
                title: _emptyTitle,
                message: _emptyMessage,
                icon: _showBlockedUsers
                    ? Icons.shield_outlined
                    : Icons.person_search_rounded,
                actionLabel: hasFilters
                    ? 'Réinitialiser les filtres'
                    : 'Recharger la liste',
                actionIcon: hasFilters
                    ? Icons.filter_alt_off_rounded
                    : Icons.refresh_rounded,
                onAction: () {
                  if (hasFilters) {
                    _clearFilters();
                  } else {
                    userController.fetchUsers();
                  }
                },
              );
            }

            final managedUsers =
                filteredUsers.where((user) => _isManagedAccount(user)).length;

            return Column(
              children: [
                Wrap(
                  spacing: compact ? 10 : 12,
                  runSpacing: compact ? 10 : 12,
                  children: _showBlockedUsers
                      ? [
                          AdminMiniStat(
                            label: 'Comptes bloques',
                            value: '${filteredUsers.length}',
                            icon: Icons.block_rounded,
                            accentColor: AdminTheme.danger,
                            subtitle: 'File active',
                            minWidth: compact ? 180 : 220,
                          ),
                          AdminMiniStat(
                            label: 'Comptes geres',
                            value: '$managedUsers',
                            icon: Icons.manage_accounts_outlined,
                            accentColor: AdminTheme.accent,
                            subtitle: 'Parmi les bloques',
                            minWidth: compact ? 180 : 220,
                          ),
                          AdminMiniStat(
                            label: 'Auth desactivee',
                            value:
                                '${filteredUsers.where((user) => user.authDisabled).length}',
                            icon: Icons.lock_person_outlined,
                            accentColor: AdminTheme.warning,
                            subtitle: 'Couches cumulees',
                            minWidth: compact ? 180 : 220,
                          ),
                        ]
                      : [
                    AdminMiniStat(
                      label: 'Resultats',
                      value: '${filteredUsers.length}',
                      icon: Icons.groups_2_rounded,
                      accentColor: AdminTheme.cyan,
                      subtitle: 'Comptes visibles',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Comptes gérés',
                      value: '$managedUsers',
                      icon: Icons.manage_accounts_outlined,
                      accentColor: AdminTheme.accent,
                      subtitle: 'Dans la selection',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Action en cours',
                      value: _actionInFlightUid == null ? '0' : '1',
                      icon: Icons.bolt_rounded,
                      accentColor: AdminTheme.warning,
                      subtitle: _actionInFlightLabel ?? 'Aucune',
                      minWidth: compact ? 180 : 220,
                    ),
                  ],
                ),
                SizedBox(height: spacing),
                AdminDataTableCard(
                  compact: compact,
                  child: DataTable(
                    columnSpacing: tableColumnSpacing,
                    horizontalMargin: compact ? 10 : 12,
                    columns: const [
                      DataColumn(
                          label: Text('Nom', textAlign: TextAlign.center)),
                      DataColumn(
                        label: Text('Email', textAlign: TextAlign.center),
                      ),
                      DataColumn(
                          label: Text('Rôle', textAlign: TextAlign.center)),
                      DataColumn(
                        label: Text('Statut', textAlign: TextAlign.center),
                      ),
                      DataColumn(
                        label: Text('Actions', textAlign: TextAlign.center),
                      ),
                    ],
                    rows: List<DataRow>.generate(
                      displayedUsers.length,
                      (index) => DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                Icon(
                                  _rowLeadingIcon,
                                  color: _rowLeadingColor,
                                ),
                                const SizedBox(width: 8),
                                Text(displayedUsers[index].nom),
                              ],
                            ),
                          ),
                          DataCell(Text(displayedUsers[index].email)),
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(displayedUsers[index].role),
                                if (displayedUsers[index].createdByAdmin)
                                  const Text(
                                    'créé par admin',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AdminTheme.accent,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          DataCell(
                            AdminAccountStatusChips(
                              user: displayedUsers[index],
                            ),
                          ),
                          DataCell(
                            _actionInFlightUid == displayedUsers[index].uid
                                ? Row(
                                    children: [
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(_actionInFlightLabel ??
                                          'Traitement...'),
                                    ],
                                  )
                                : PopupMenuButton<String>(
                                    tooltip: 'Actions utilisateur',
                                    onSelected: (value) =>
                                        _handleActionSelection(
                                      value,
                                      displayedUsers[index],
                                    ),
                                    itemBuilder: (context) =>
                                        _buildActionMenuItems(
                                            displayedUsers[index]),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    headingRowColor: WidgetStateProperty.all(
                      AdminTheme.surfaceHighlight.withValues(alpha: 0.72),
                    ),
                    dataRowColor: WidgetStateProperty.all(
                      AdminTheme.surface.withValues(alpha: 0.14),
                    ),
                    dividerThickness: 1,
                    dataRowMinHeight: rowHeight,
                    dataRowMaxHeight: rowHeight,
                    headingRowHeight: rowHeight,
                  ),
                ),
                SizedBox(height: spacing),
                AdminPaginationBar(
                  currentPage: currentPage,
                  totalPages: totalPages,
                  onPrevious: currentPage > 0
                      ? () {
                          setState(() {
                            currentPage--;
                          });
                        }
                      : null,
                  onNext: currentPage < totalPages - 1
                      ? () {
                          setState(() {
                            currentPage++;
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
