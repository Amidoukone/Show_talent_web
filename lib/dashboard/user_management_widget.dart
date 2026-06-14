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
    this.userController,
    this.managedAccountService,
    super.key,
  });

  final String selectedRole;
  final UserController? userController;
  final ManagedAccountService? managedAccountService;

  @override
  State<UserManagementWidget> createState() => _UserManagementWidgetState();
}

class _UserManagementWidgetState extends State<UserManagementWidget> {
  static const int rowsPerPage = 4;

  static const String _actionDelete = 'delete';
  static const String _actionDisableAuth = 'disable_auth';
  static const String _actionEnableAuth = 'enable_auth';
  static const String _actionChangeRole = 'change_role';
  static const String _actionResendInvite = 'resend_invite';
  static const String _actionReviewProfile = 'review_profile';
  static const String _actionVerifyProfile = 'verify_profile';
  static const String _actionUnverifyProfile = 'unverify_profile';

  final TextEditingController _searchController = TextEditingController();

  late final UserController _userController;
  late final ManagedAccountService _managedAccountService;
  String searchQuery = '';
  String? selectedRole;
  int currentPage = 0;
  String? _actionInFlightUid;
  String? _actionInFlightLabel;

  @override
  void initState() {
    super.initState();
    _userController = widget.userController ?? Get.find<UserController>();
    _managedAccountService =
        widget.managedAccountService ?? ManagedAccountService();
    selectedRole = widget.selectedRole;
    _userController.fetchUsers();
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

  bool _isAdminManagedAccount(AppUser user) {
    return user.createdByAdmin || isManagedAccountRole(user.role);
  }

  bool _canManageProfileVerification(AppUser user) {
    return _isAdminManagedAccount(user) && !isAdminPortalOnlyRole(user.role);
  }

  String _verifyProfileActionLabel(AppUser user) {
    return user.profileVerificationNeedsReview
        ? 'Revalider le profil'
        : 'Certifier le profil';
  }

  Color get _panelAccentColor => AdminTheme.accent;

  IconData get _rowLeadingIcon => Icons.person_rounded;

  Color get _rowLeadingColor => AdminTheme.cyan;

  String get _headerBadge => 'Opérations utilisateurs';

  String get _headerTitle => 'Gestion des utilisateurs';

  String get _headerSubtitle =>
      'Recherche, rôles, statuts Auth, profils certifiés et actions admin centralisées.';

  String get _bannerTitle => 'Gouvernance des profils';

  String get _bannerMessage =>
      "La certification profil est un signal de confiance séparé de l'e-mail vérifié. Si l'utilisateur modifie une information de confiance côté mobile, le profil repasse à revalider avant d'afficher le badge Adfoot.";

  String get _searchHint => 'Rechercher un utilisateur';

  String get _emptyTitle => 'Aucun utilisateur trouvé';

  String get _emptyMessage =>
      'Ajustez le filtre ou la recherche pour afficher des comptes.';

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
          'Cette action désactive immédiatement l’accès Firebase Auth pour ${user.email}. La session mobile sera fermée et les prochaines connexions seront refusées avec un message cohérent.',
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
          'L’accès Auth a été désactivé pour ${user.email}. Le compte ne pourra plus se reconnecter tant qu’il ne sera pas réactivé.',
    );
  }

  Future<void> _enableManagedAccountAuth(AppUser user) async {
    await _runVoidAction(
      user: user,
      action: enableManagedAccountAuthAction,
      request: () =>
          _managedAccountService.enableManagedAccountAuth(uid: user.uid),
      successMessage: 'L’accès Auth a été réactivé pour ${user.email}.',
    );
  }

  Future<void> _changeManagedAccountRole(AppUser user) async {
    if (!_isAdminManagedAccount(user)) {
      showAdminFeedback(
        title: 'Action indisponible',
        message:
            'Le changement de rôle n’est proposé que pour les comptes créés par l’administration.',
        tone: AdminBannerTone.warning,
      );
      return;
    }

    final selectedManagedRole = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final currentRole = normalizeUserRole(user.role);
        String nextRole = isAdminProvisionedRole(currentRole)
            ? currentRole
            : adminProvisionedRoles.first;

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
                    items: adminProvisionedRoles
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
    if (!_isAdminManagedAccount(user)) {
      showAdminFeedback(
        title: 'Action indisponible',
        message:
            'Le renvoi d’invitation n’est proposé que pour les comptes créés par l’administration.',
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

  Future<String?> _requestProfileVerificationNote({
    required AppUser user,
    required bool verifying,
  }) async {
    var note = '';

    final result = await showDialog<String?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            verifying
                ? _verifyProfileActionLabel(user)
                : 'Retirer la certification profil',
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Compte cible : ${user.nom} (${user.email})'),
                const SizedBox(height: 12),
                Text(
                  verifying
                      ? 'Confirmez que les informations du profil sont cohérentes avec le contrat mobile et suffisamment fiables pour afficher un signal de confiance.'
                      : 'La certification sera retirée du profil. Le compte reste actif si Auth et l’e-mail sont valides.',
                  style: const TextStyle(color: AdminTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) {
                    note = value;
                  },
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note interne optionnelle',
                    hintText: 'Ex. identité et dossier profil contrôlés',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(note.trim()),
              icon: Icon(
                verifying
                    ? Icons.verified_rounded
                    : Icons.remove_moderator_outlined,
                size: 18,
              ),
              label: Text(verifying ? 'Certifier' : 'Retirer'),
            ),
          ],
        );
      },
    );

    return result;
  }

  Future<void> _verifyManagedAccountProfile(AppUser user) async {
    if (!_canManageProfileVerification(user)) {
      showAdminFeedback(
        title: 'Action indisponible',
        message:
            'La certification profil est réservée aux comptes gérés par l’administration et exclut les comptes admin.',
        tone: AdminBannerTone.warning,
      );
      return;
    }

    if (user.profileVerified) {
      showAdminFeedback(
        title: 'Profil déjà certifié',
        message: '${user.nom} possède déjà le signal de confiance profil.',
        tone: AdminBannerTone.info,
      );
      return;
    }

    if (!user.isEffectivelyActiveAccount) {
      showAdminFeedback(
        title: 'Compte non éligible',
        message:
            'Activez d’abord Auth et la vérification e-mail avant de certifier le profil.',
        tone: AdminBannerTone.warning,
      );
      return;
    }

    if (!user.isMvpProfileComplete) {
      showAdminFeedback(
        title: 'Profil incomplet',
        message:
            'Le profil doit au minimum respecter les champs essentiels utilisés par le mobile avant certification.',
        tone: AdminBannerTone.warning,
      );
      return;
    }

    final note = await _requestProfileVerificationNote(
      user: user,
      verifying: true,
    );
    if (note == null) {
      return;
    }

    await _runVoidAction(
      user: user,
      action: updateManagedAccountProfileAction,
      request: () => _managedAccountService.verifyManagedAccountProfile(
        uid: user.uid,
        note: note,
      ),
      successMessage:
          'Le profil de ${user.nom} est maintenant certifié par l’administration.',
    );
  }

  Future<void> _unverifyManagedAccountProfile(AppUser user) async {
    if (!_canManageProfileVerification(user)) {
      showAdminFeedback(
        title: 'Action indisponible',
        message:
            'La certification profil est réservée aux comptes gérés par l’administration et exclut les comptes admin.',
        tone: AdminBannerTone.warning,
      );
      return;
    }

    if (!user.profileVerified) {
      showAdminFeedback(
        title: 'Profil non certifié',
        message: 'Aucune certification profil active à retirer.',
        tone: AdminBannerTone.info,
      );
      return;
    }

    final note = await _requestProfileVerificationNote(
      user: user,
      verifying: false,
    );
    if (note == null) {
      return;
    }

    await _runVoidAction(
      user: user,
      action: updateManagedAccountProfileAction,
      request: () => _managedAccountService.unverifyManagedAccountProfile(
        uid: user.uid,
        note: note,
      ),
      successMessage: 'La certification profil de ${user.nom} a été retirée.',
    );
  }

  Future<void> _showProfileReviewDialog(AppUser user) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.fact_check_outlined),
              const SizedBox(width: 10),
              Expanded(child: Text('Revue profil - ${user.nom}')),
            ],
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: _ProfileReviewContent(user: user),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
            if (_canManageProfileVerification(user))
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (user.profileVerified) {
                    _unverifyManagedAccountProfile(user);
                  } else {
                    _verifyManagedAccountProfile(user);
                  }
                },
                icon: Icon(
                  user.profileVerified
                      ? Icons.remove_moderator_outlined
                      : Icons.verified_outlined,
                  size: 18,
                ),
                label: Text(
                  user.profileVerified
                      ? 'Retirer la certification'
                      : _verifyProfileActionLabel(user),
                ),
              ),
          ],
        );
      },
    );
  }

  List<PopupMenuEntry<String>> _buildActionMenuItems(AppUser user) {
    final items = <PopupMenuEntry<String>>[
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
            Flexible(
              child: Text(
                user.authDisabled ? 'Réactiver Auth' : 'Désactiver Auth',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ];

    items.add(const PopupMenuDivider());
    items.add(
      const PopupMenuItem(
        value: _actionReviewProfile,
        child: Row(
          children: [
            Icon(Icons.fact_check_outlined, size: 18, color: AdminTheme.cyan),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Revoir le profil',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    if (_canManageProfileVerification(user)) {
      items.add(
        PopupMenuItem(
          value: user.profileVerified
              ? _actionUnverifyProfile
              : _actionVerifyProfile,
          child: Row(
            children: [
              Icon(
                user.profileVerified
                    ? Icons.remove_moderator_outlined
                    : Icons.verified_outlined,
                size: 18,
                color: user.profileVerified
                    ? AdminTheme.warning
                    : AdminTheme.success,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  user.profileVerified
                      ? 'Retirer certification'
                      : _verifyProfileActionLabel(user),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isAdminManagedAccount(user)) {
      items.add(const PopupMenuDivider());
      items.addAll([
        PopupMenuItem(
          value: _actionChangeRole,
          child: Row(
            children: const [
              Icon(Icons.manage_accounts_outlined,
                  size: 18, color: AdminTheme.cyan),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Changer le rôle',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
              Flexible(
                child: Text(
                  'Renvoyer l’invitation',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
            Flexible(
              child: Text(
                'Supprimer',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    return items;
  }

  Future<void> _handleActionSelection(String value, AppUser user) async {
    switch (value) {
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
      case _actionReviewProfile:
        await _showProfileReviewDialog(user);
        break;
      case _actionVerifyProfile:
        await _verifyManagedAccountProfile(user);
        break;
      case _actionUnverifyProfile:
        await _unverifyManagedAccountProfile(user);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);
    final panelPadding = compact ? 16.0 : 22.0;
    final spacing = compact ? 12.0 : 16.0;
    final tableColumnSpacing = compact ? 16.0 : 24.0;
    final rowHeight = compact ? 86.0 : 92.0;

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
                  ...adminProvisionedRoles,
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
            icon: Icons.rule_folder_outlined,
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
            final filteredUsers = _userController.userList.where((user) {
              final matchesRole =
                  selectedRole == 'Tous' || user.role == selectedRole;
              final normalizedQuery = searchQuery.toLowerCase();
              final matchesSearch = normalizedQuery.isEmpty ||
                  [
                    user.nom,
                    user.email,
                    user.phone,
                    user.city,
                    user.region,
                    user.country,
                    user.team,
                    user.nomClub,
                    user.entreprise,
                    user.position,
                    user.clubActuel,
                    user.profileTrustLabel,
                    user.profileVerificationStatusLabel,
                  ].whereType<String>().any(
                        (value) =>
                            value.toLowerCase().contains(normalizedQuery),
                      );

              return matchesRole && matchesSearch;
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
                icon: Icons.person_search_rounded,
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
                    _userController.fetchUsers();
                  }
                },
              );
            }

            final managedUsers = filteredUsers
                .where((user) => _isAdminManagedAccount(user))
                .length;
            final advancedProfiles =
                filteredUsers.where((user) => user.hasAdvancedProfile).length;
            final verifiedProfiles =
                filteredUsers.where((user) => user.profileVerified).length;
            final readyForVerification = filteredUsers
                .where((user) =>
                    !user.profileVerified && user.canBeProfileVerifiedByAdmin)
                .length;
            final pendingReview = filteredUsers
                .where((user) => user.profileVerificationNeedsReview)
                .length;

            return Column(
              children: [
                Wrap(
                  spacing: compact ? 10 : 12,
                  runSpacing: compact ? 10 : 12,
                  children: [
                    AdminMiniStat(
                      label: 'Résultats',
                      value: '${filteredUsers.length}',
                      icon: Icons.groups_2_rounded,
                      accentColor: AdminTheme.cyan,
                      subtitle: 'Comptes visibles',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Comptes administres',
                      value: '$managedUsers',
                      icon: Icons.manage_accounts_outlined,
                      accentColor: AdminTheme.accent,
                      subtitle: 'Dans la sélection',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Auth désactivée',
                      value:
                          '${filteredUsers.where((user) => user.authDisabled).length}',
                      icon: Icons.lock_person_outlined,
                      accentColor: AdminTheme.warning,
                      subtitle: 'Accès suspendus',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Profils certifiés',
                      value: '$verifiedProfiles',
                      icon: Icons.verified_rounded,
                      accentColor: AdminTheme.success,
                      subtitle: 'Signal de confiance',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'A revalider',
                      value: '$pendingReview',
                      icon: Icons.fact_check_outlined,
                      accentColor: AdminTheme.warning,
                      subtitle: 'Modifies cote mobile',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Prets a verifier',
                      value: '$readyForVerification',
                      icon: Icons.rule_folder_outlined,
                      accentColor: AdminTheme.cyan,
                      subtitle: 'Eligibles',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Profils avancés',
                      value: '$advancedProfiles',
                      icon: Icons.verified_outlined,
                      accentColor: AdminTheme.success,
                      subtitle: 'Données mobile pro',
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
                                Text(
                                  displayedUsers[index].profileLevelLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AdminTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  displayedUsers[index].profileTrustLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: displayedUsers[index].profileVerified
                                        ? AdminTheme.success
                                        : displayedUsers[index]
                                                .profileVerificationNeedsReview
                                            ? AdminTheme.warning
                                            : AdminTheme.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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

class _ProfileReviewContent extends StatelessWidget {
  const _ProfileReviewContent({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AdminPill(
              label: user.profileTrustLabel,
              icon: user.profileVerified
                  ? Icons.verified_rounded
                  : Icons.fact_check_outlined,
              color:
                  user.profileVerified ? AdminTheme.success : AdminTheme.cyan,
            ),
            AdminPill(
              label: user.profileLevelLabel,
              icon: Icons.military_tech_outlined,
              color: user.hasAdvancedProfile
                  ? AdminTheme.accent
                  : AdminTheme.textMuted,
            ),
            AdminPill(
              label: user.profilePublic ? 'Profil public' : 'Profil restreint',
              icon: user.profilePublic
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color:
                  user.profilePublic ? AdminTheme.success : AdminTheme.warning,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ProfileReviewSection(
          title: 'Éligibilité confiance',
          children: [
            _ProfileReviewItem.boolean(
              label: 'Compte actif et e-mail vérifié',
              value: user.isEffectivelyActiveAccount,
            ),
            _ProfileReviewItem.boolean(
              label: 'Profil de base complet',
              value: user.isMvpProfileComplete,
            ),
            _ProfileReviewItem.boolean(
              label: 'Profil avancé mobile renseigné',
              value: user.hasAdvancedProfile,
            ),
            if (user.isPlayer)
              _ProfileReviewItem.boolean(
                label: 'Dossier scout exploitable',
                value: user.hasScoutReadyProfile,
              ),
            _ProfileReviewItem(
              label: 'Statut actuel',
              value: user.profileVerificationStatusLabel,
            ),
            if (user.profileVerificationNeedsReview)
              _ProfileReviewItem(
                label: 'Action requise',
                value: 'Revalidation Adfoot apres modification utilisateur',
              ),
            if (user.profileVerificationInvalidatedAt != null)
              _ProfileReviewItem(
                label: 'A revalider depuis',
                value:
                    user.profileVerificationInvalidatedAt!.toLocal().toString(),
              ),
            if (user.profileVerificationInvalidatedBy != null)
              _ProfileReviewItem(
                label: 'Modification par',
                value: user.profileVerificationInvalidatedBy!,
              ),
            if (user.profileVerificationInvalidationReason != null)
              _ProfileReviewItem(
                label: 'Cause',
                value: user.profileVerificationInvalidationReason!,
              ),
            if (user.profileVerifiedAt != null)
              _ProfileReviewItem(
                label: user.profileVerified
                    ? 'Certifie le'
                    : 'Derniere certification',
                value: user.profileVerifiedAt!.toLocal().toString(),
              ),
            if (user.profileVerificationNote != null)
              _ProfileReviewItem(
                label: 'Note interne',
                value: user.profileVerificationNote!,
              ),
          ],
        ),
        const SizedBox(height: 14),
        _ProfileReviewSection(
          title: 'Identité et contact',
          children: [
            _ProfileReviewItem(label: 'Nom', value: user.nom),
            _ProfileReviewItem(label: 'E-mail', value: user.email),
            _ProfileReviewItem(label: 'Rôle', value: user.role),
            _ProfileReviewItem(
              label: 'Téléphone',
              value: user.phone ?? 'Non renseigné',
            ),
            _ProfileReviewItem(
              label: 'Localisation',
              value: user.primaryLocation ?? 'Non renseignée',
            ),
            _ProfileReviewItem(
              label: 'Langues',
              value: user.languages?.join(', ') ?? 'Non renseignées',
            ),
            _ProfileReviewItem.boolean(
              label: 'Ouvert aux opportunités',
              value: user.openToOpportunities == true,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ProfileReviewSection(
          title: 'Profil métier mobile',
          children: _buildRoleProfileItems(user),
        ),
      ],
    );
  }

  static List<_ProfileReviewItem> _buildRoleProfileItems(AppUser user) {
    if (user.isPlayer) {
      return [
        _ProfileReviewItem(
          label: 'Poste',
          value: user.position ?? 'Non renseigné',
        ),
        _ProfileReviewItem(
          label: 'Équipe',
          value: user.team ?? user.clubActuel ?? 'Non renseignée',
        ),
        _ProfileReviewItem(
          label: 'CV',
          value: user.cvUrl?.isNotEmpty == true ? 'Présent' : 'Absent',
        ),
        _ProfileReviewItem(
          label: 'Profil joueur avancé',
          value: _formatMapSummary(user.playerProfile),
        ),
      ];
    }

    if (user.isClub) {
      return [
        _ProfileReviewItem(
          label: 'Club',
          value: user.nomClub ?? user.nom,
        ),
        _ProfileReviewItem(
          label: 'Ligue',
          value: user.ligue ?? 'Non renseignée',
        ),
        _ProfileReviewItem(
          label: 'Profil club avancé',
          value: _formatMapSummary(user.clubProfile),
        ),
      ];
    }

    if (user.isRecruiter) {
      return [
        _ProfileReviewItem(
          label: 'Organisation',
          value: user.entreprise ?? 'Non renseignée',
        ),
        _ProfileReviewItem(
          label: 'Recrutements',
          value: user.nombreDeRecrutements?.toString() ?? 'Non renseigné',
        ),
        _ProfileReviewItem(
          label: 'Profil agent/recruteur',
          value: _formatMapSummary(user.agentProfile),
        ),
      ];
    }

    return [
      _ProfileReviewItem(
        label: 'Profil',
        value: user.bio ?? 'Aucune donnée métier avancée pour ce rôle.',
      ),
    ];
  }

  static String _formatMapSummary(Map<String, dynamic>? value) {
    if (value == null || value.isEmpty) {
      return 'Non renseigné';
    }

    return value.entries
        .take(4)
        .map((entry) => '${entry.key}: ${_formatValue(entry.value)}')
        .join(' | ');
  }

  static String _formatValue(dynamic value) {
    if (value is List) {
      return value.join(', ');
    }
    if (value is Map) {
      return '${value.length} champs';
    }
    return value?.toString() ?? 'Non renseigné';
  }
}

class _ProfileReviewSection extends StatelessWidget {
  const _ProfileReviewSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminTheme.surface.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminTheme.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AdminTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileReviewItem extends StatelessWidget {
  const _ProfileReviewItem({
    required this.label,
    required this.value,
  }) : success = null;

  const _ProfileReviewItem.boolean({
    required this.label,
    required bool value,
  })  : value = value ? 'Oui' : 'Non',
        success = value;

  final String label;
  final String value;
  final bool? success;

  @override
  Widget build(BuildContext context) {
    final successValue = success;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (successValue != null) ...[
            Icon(
              successValue
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              size: 18,
              color: successValue ? AdminTheme.success : AdminTheme.warning,
            ),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 190,
            child: Text(
              label,
              style: const TextStyle(
                color: AdminTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AdminTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
