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

class BlockedUsersWidget extends StatefulWidget {
  const BlockedUsersWidget({super.key});

  @override
  State<BlockedUsersWidget> createState() => _BlockedUsersWidgetState();
}

class _BlockedUsersWidgetState extends State<BlockedUsersWidget> {
  static const int rowsPerPage = 4;

  static const String _actionUnblock = 'unblock';
  static const String _actionDelete = 'delete';
  static const String _actionDisableAuth = 'disable_auth';
  static const String _actionEnableAuth = 'enable_auth';
  static const String _actionChangeRole = 'change_role';
  static const String _actionResendInvite = 'resend_invite';

  final UserController userController = Get.find<UserController>();
  final ManagedAccountService _managedAccountService = ManagedAccountService();

  int currentPage = 0;
  String? _actionInFlightUid;
  String? _actionInFlightLabel;

  @override
  void initState() {
    super.initState();
    userController.fetchUsers();
  }

  bool _isCompactLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 1120;

  bool _isManagedAccount(AppUser user) {
    return user.createdByAdmin || managedAccountRoles.contains(user.role);
  }

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
        title: 'Succes',
        message: successMessage,
        tone: AdminBannerTone.success,
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }

      showAdminFeedback(
        title: 'Erreur',
        message: error.message ?? 'Operation ${action.callableName} refusee.',
        tone: AdminBannerTone.danger,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      showAdminFeedback(
        title: 'Erreur',
        message: 'Operation ${action.callableName} impossible : $error',
        tone: AdminBannerTone.danger,
      );
    } finally {
      _clearActionInFlight();
    }
  }

  Future<void> _showInviteResultDialog(
    ManagedAccountProvisionResult result,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return ManagedAccountInviteResultDialog(
          result: result,
          title: resendManagedAccountInviteAction.label,
          subtitle:
              'Les liens retournes par le backend partage peuvent etre copies depuis cette boite de dialogue.',
        );
      },
    );
  }

  Future<void> _unblockManagedAccount(AppUser user) async {
    final confirmed = await _confirmAction(
      title: unblockManagedAccountAction.label,
      message:
          'Cette action retire seulement le blocage applicatif du compte ${user.email}.',
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
          'Le blocage applicatif a ete retire pour ${user.email}. Firebase Auth n a pas ete modifie.',
    );
  }

  Future<void> _deleteManagedAccount(AppUser user) async {
    final confirmed = await _confirmAction(
      title: deleteManagedAccountAction.label,
      message:
          'Cette suppression passe par le backend partage et peut supprimer l acces du compte ${user.email}.',
      confirmLabel: 'Supprimer',
    );
    if (!confirmed) {
      return;
    }

    await _runVoidAction(
      user: user,
      action: deleteManagedAccountAction,
      request: () => _managedAccountService.deleteManagedAccount(uid: user.uid),
      successMessage: 'La suppression admin a ete demandee pour ${user.email}.',
    );
  }

  Future<void> _disableManagedAccountAuth(AppUser user) async {
    final confirmed = await _confirmAction(
      title: disableManagedAccountAuthAction.label,
      message:
          'Cette action desactive seulement Firebase Auth pour ${user.email}. Le blocage applicatif ne change pas.',
      confirmLabel: 'Desactiver Auth',
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
          'Firebase Auth a ete desactive pour ${user.email}. Le blocage applicatif n a pas ete modifie.',
    );
  }

  Future<void> _enableManagedAccountAuth(AppUser user) async {
    await _runVoidAction(
      user: user,
      action: enableManagedAccountAuthAction,
      request: () =>
          _managedAccountService.enableManagedAccountAuth(uid: user.uid),
      successMessage:
          'Firebase Auth a ete reactive pour ${user.email}. Le blocage applicatif n a pas ete modifie.',
    );
  }

  Future<void> _changeManagedAccountRole(AppUser user) async {
    if (!_isManagedAccount(user)) {
      showAdminFeedback(
        title: 'Action indisponible',
        message: 'Le changement de role n est propose que pour les comptes geres.',
        tone: AdminBannerTone.warning,
      );
      return;
    }

    final selectedManagedRole = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String nextRole = managedAccountRoles.contains(user.role)
            ? user.role
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
                      labelText: 'Nouveau role',
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

    if (selectedManagedRole == null || selectedManagedRole == user.role) {
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
          'Le role de ${user.email} a ete change vers $selectedManagedRole.',
    );
  }

  Future<void> _resendManagedAccountInvite(AppUser user) async {
    if (!_isManagedAccount(user)) {
      showAdminFeedback(
        title: 'Action indisponible',
        message:
            'Le renvoi d invitation n est propose que pour les comptes geres.',
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
        title: 'Succes',
        message: 'Les liens d invitation ont ete regeneres pour ${user.email}.',
        tone: AdminBannerTone.success,
      );
      await _showInviteResultDialog(result);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }

      showAdminFeedback(
        title: 'Erreur',
        message:
            error.message ??
            'Impossible de renvoyer les liens d invitation pour ce compte.',
        tone: AdminBannerTone.danger,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      showAdminFeedback(
        title: 'Erreur',
        message: 'Impossible de renvoyer les liens d invitation : $error',
        tone: AdminBannerTone.danger,
      );
    } finally {
      _clearActionInFlight();
    }
  }

  List<PopupMenuEntry<String>> _buildActionMenuItems(AppUser user) {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(
        value: _actionUnblock,
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 18, color: AdminTheme.success),
            SizedBox(width: 8),
            Text('Debloquer'),
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
              color: user.authDisabled ? AdminTheme.success : AdminTheme.warning,
            ),
            const SizedBox(width: 8),
            Text(user.authDisabled ? 'Reactiver Auth' : 'Desactiver Auth'),
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
              Icon(Icons.manage_accounts_outlined, size: 18, color: AdminTheme.cyan),
              SizedBox(width: 8),
              Text('Changer le role'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _actionResendInvite,
          child: Row(
            children: const [
              Icon(Icons.mark_email_read_outlined, size: 18, color: AdminTheme.accent),
              SizedBox(width: 8),
              Text('Renvoyer l invitation'),
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
            Icon(Icons.delete_outline_rounded, size: 18, color: AdminTheme.danger),
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
      accentColor: AdminTheme.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminSectionHeader(
            badge: 'Blocked accounts',
            title: 'Utilisateurs bloques',
            subtitle:
                'Controle du blocage applicatif, des statuts Auth et des actions correctives.',
          ),
          SizedBox(height: spacing),
          const AdminInfoBanner(
            title: 'Regles de deblocage',
            message:
                'Debloquer retire seulement le blocage applicatif. Les actions Auth restent separees. Le changement de role et le renvoi d invitation sont limites aux comptes geres.',
            icon: Icons.gpp_maybe_outlined,
            tone: AdminBannerTone.warning,
          ),
          Obx(() {
            final blockedUsers =
                userController.userList.where((user) => user.estBloque).toList();
            final totalPages = (blockedUsers.length / rowsPerPage).ceil();
            final startIndex = currentPage * rowsPerPage;
            final endIndex = (startIndex + rowsPerPage).clamp(
              0,
              blockedUsers.length,
            );
            final displayedUsers = blockedUsers.sublist(startIndex, endIndex);

            if (blockedUsers.isEmpty) {
              return AdminEmptyState(
                title: 'Aucun utilisateur bloque',
                message:
                    'Aucun compte n est actuellement signale comme bloque dans le portail.',
                icon: Icons.shield_outlined,
                actionLabel: 'Recharger la liste',
                onAction: () => userController.fetchUsers(),
              );
            }

            final managedUsers =
                blockedUsers.where((user) => _isManagedAccount(user)).length;
            final authDisabledUsers =
                blockedUsers.where((user) => user.authDisabled).length;

            return Column(
              children: [
                Wrap(
                  spacing: compact ? 10 : 12,
                  runSpacing: compact ? 10 : 12,
                  children: [
                    AdminMiniStat(
                      label: 'Comptes bloques',
                      value: '${blockedUsers.length}',
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
                      value: '$authDisabledUsers',
                      icon: Icons.lock_person_outlined,
                      accentColor: AdminTheme.warning,
                      subtitle: 'Couches cumulees',
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
                        label: Text(
                          'Nom',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Email',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Role',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Statut',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Actions',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    rows: List<DataRow>.generate(
                      displayedUsers.length,
                      (index) => DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                const Icon(
                                  Icons.block_rounded,
                                  color: AdminTheme.danger,
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
                                    'cree par admin',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AdminTheme.accent,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          DataCell(
                            AdminAccountStatusChips(user: displayedUsers[index]),
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
                                      Text(_actionInFlightLabel ?? 'Traitement...'),
                                    ],
                                  )
                                : PopupMenuButton<String>(
                                    tooltip: 'Actions utilisateur',
                                    onSelected: (value) => _handleActionSelection(
                                      value,
                                      displayedUsers[index],
                                    ),
                                    itemBuilder: (context) =>
                                        _buildActionMenuItems(displayedUsers[index]),
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
