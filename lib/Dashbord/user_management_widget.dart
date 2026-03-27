import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/user_controller.dart';
import '../models/managed_account_provision_result.dart';
import '../models/user.dart';
import '../services/managed_account_service.dart';
import '../utils/account_role_policy.dart';
import '../utils/admin_callable_action_catalog.dart';
import '../widgets/admin_account_status_chips.dart';
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

class _UserManagementWidgetState extends State<UserManagementWidget> {
  static const int rowsPerPage = 4;

  static const String _actionBlock = 'block';
  static const String _actionDelete = 'delete';
  static const String _actionDisableAuth = 'disable_auth';
  static const String _actionEnableAuth = 'enable_auth';
  static const String _actionChangeRole = 'change_role';
  static const String _actionResendInvite = 'resend_invite';

  final UserController userController = Get.find<UserController>();
  final ManagedAccountService _managedAccountService = ManagedAccountService();

  String searchQuery = '';
  String? selectedRole;
  int currentPage = 0;
  String? _actionInFlightUid;
  String? _actionInFlightLabel;

  @override
  void initState() {
    super.initState();
    selectedRole = widget.selectedRole;
    userController.fetchUsers();
  }

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

      Get.snackbar('Succes', successMessage);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }

      Get.snackbar(
        'Erreur',
        error.message ?? 'Operation ${action.callableName} refusee.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      Get.snackbar(
        'Erreur',
        'Operation ${action.callableName} impossible : $error',
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

  Future<void> _blockManagedAccount(AppUser user) async {
    final confirmed = await _confirmAction(
      title: blockManagedAccountAction.label,
      message:
          'Cette action active seulement le blocage applicatif du compte ${user.email}.',
      confirmLabel: 'Bloquer',
    );
    if (!confirmed) {
      return;
    }

    await _runVoidAction(
      user: user,
      action: blockManagedAccountAction,
      request: () => _managedAccountService.blockManagedAccount(uid: user.uid),
      successMessage:
          'Le blocage applicatif a ete active pour ${user.email}. Firebase Auth n a pas ete modifie.',
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
      Get.snackbar(
        'Action indisponible',
        'Le changement de role n est propose que pour les comptes geres.',
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
      Get.snackbar(
        'Action indisponible',
        'Le renvoi d invitation n est propose que pour les comptes geres.',
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

      Get.snackbar(
        'Succes',
        'Les liens d invitation ont ete regeneres pour ${user.email}.',
      );
      await _showInviteResultDialog(result);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }

      Get.snackbar(
        'Erreur',
        error.message ??
            'Impossible de renvoyer les liens d invitation pour ce compte.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      Get.snackbar(
        'Erreur',
        'Impossible de renvoyer les liens d invitation : $error',
      );
    } finally {
      _clearActionInFlight();
    }
  }

  List<PopupMenuEntry<String>> _buildActionMenuItems(AppUser user) {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(
        value: _actionBlock,
        child: Text('Bloquer'),
      ),
      PopupMenuItem(
        value: user.authDisabled ? _actionEnableAuth : _actionDisableAuth,
        child: Text(user.authDisabled ? 'Reactiver Auth' : 'Desactiver Auth'),
      ),
    ];

    if (_isManagedAccount(user)) {
      items.add(const PopupMenuDivider());
      items.addAll(const [
        PopupMenuItem(
          value: _actionChangeRole,
          child: Text('Changer le role'),
        ),
        PopupMenuItem(
          value: _actionResendInvite,
          child: Text('Renvoyer l invitation'),
        ),
      ]);
    }

    items.add(const PopupMenuDivider());
    items.add(
      const PopupMenuItem(
        value: _actionDelete,
        child: Text('Supprimer'),
      ),
    );

    return items;
  }

  Future<void> _handleActionSelection(String value, AppUser user) async {
    switch (value) {
      case _actionBlock:
        await _blockManagedAccount(user);
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
    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          width: MediaQuery.of(context).size.width * 0.95,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                spreadRadius: 2,
                blurRadius: 8,
              ),
            ],
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gestion des utilisateurs',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  DropdownButton<String>(
                    value: selectedRole,
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
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Toutes les mutations cross-user passent desormais par les callables du backend partage. '
                  'Blocage applicatif, Auth et activite restent distingues. '
                  'Le changement de role et le renvoi d invitation sont limites aux comptes geres.',
                  style: TextStyle(color: Colors.black87),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Rechercher un utilisateur',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    prefixIcon: const Icon(Icons.search),
                  ),
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
                  final isBlocked = user.estBloque;
                  final matchesRole =
                      selectedRole == 'Tous' || user.role == selectedRole;
                  final normalizedQuery = searchQuery.toLowerCase();
                  final matchesSearch =
                      user.nom.toLowerCase().contains(normalizedQuery) ||
                          user.email.toLowerCase().contains(normalizedQuery);

                  return matchesRole &&
                      matchesSearch &&
                      (widget.showBlockedUsers ? isBlocked : !isBlocked);
                }).toList();

                final totalPages = (filteredUsers.length / rowsPerPage).ceil();
                final startIndex = currentPage * rowsPerPage;
                final endIndex =
                    (startIndex + rowsPerPage).clamp(0, filteredUsers.length);
                final displayedUsers =
                    filteredUsers.sublist(startIndex, endIndex);

                if (filteredUsers.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucun utilisateur trouve.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    DataTable(
                      columnSpacing: 24,
                      horizontalMargin: 12,
                      columns: const [
                        DataColumn(
                          label: Expanded(
                            child: Text(
                              'Nom',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Expanded(
                            child: Text(
                              'Email',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Expanded(
                            child: Text(
                              'Role',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Expanded(
                            child: Text(
                              'Statut',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Expanded(
                            child: Text(
                              'Actions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
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
                                    Icons.person,
                                    color: Colors.blueAccent,
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
                                        color: Colors.teal,
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
                                        Text(
                                          _actionInFlightLabel ??
                                              'Traitement...',
                                        ),
                                      ],
                                    )
                                  : PopupMenuButton<String>(
                                      onSelected: (value) =>
                                          _handleActionSelection(
                                        value,
                                        displayedUsers[index],
                                      ),
                                      itemBuilder: (context) =>
                                          _buildActionMenuItems(
                                        displayedUsers[index],
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      headingRowColor:
                          WidgetStateProperty.all(Colors.grey.shade200),
                      dataRowColor:
                          WidgetStateProperty.all(Colors.grey.shade50),
                      dividerThickness: 1,
                      dataRowMinHeight: 56,
                      dataRowMaxHeight: 56,
                      headingRowHeight: 56,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Page ${currentPage + 1} sur $totalPages',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: currentPage > 0
                                  ? () {
                                      setState(() {
                                        currentPage--;
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Precedent'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: currentPage < totalPages - 1
                                  ? () {
                                      setState(() {
                                        currentPage++;
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('Suivant'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
