import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/user_controller.dart';
import '../models/managed_account_provision_result.dart';
import '../models/football_vocabulary.dart';
import '../models/membership.dart';
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
  static const String _actionEditProfile = 'edit_profile';
  static const String _actionVerifyProfile = 'verify_profile';
  static const String _actionUnverifyProfile = 'unverify_profile';
  static const String _actionManageMembership = 'manage_membership';

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
      MediaQuery.sizeOf(context).width < AdminTheme.breakpointCompact;

  Widget _buildRoleFilterField() {
    return AdminGlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      radius: 16,
      accentColor: AdminTheme.cyan,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedRole,
          isExpanded: true,
          dropdownColor: AdminTheme.surfaceRaised,
          iconEnabledColor: AdminTheme.textSecondary,
          items: <String>['Tous', ...adminProvisionedRoles]
              .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, overflow: TextOverflow.ellipsis),
                );
              })
              .toList(),
          onChanged: (String? newValue) {
            setState(() {
              selectedRole = newValue;
              currentPage = 0;
            });
          },
        ),
      ),
    );
  }

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

  /// Les mutations admin d'un compte sont refusées pour un compte du portail
  /// et pour un compte que l'administration ne suit pas : même garde ici que
  /// dans les callables, pour ne pas proposer une action déjà perdue.
  bool _isMutableManagedAccount(AppUser user) {
    return _isAdminManagedAccount(user) && !isAdminPortalOnlyRole(user.role);
  }

  bool _canManageProfileVerification(AppUser user) {
    return _isMutableManagedAccount(user);
  }

  String _verifyProfileActionLabel(AppUser user) {
    return user.profileVerificationNeedsReview
        ? 'Réexaminer le profil'
        : 'Certifier le profil';
  }

  Color get _panelAccentColor => AdminTheme.accent;

  IconData get _rowLeadingIcon => Icons.person_rounded;

  Color get _rowLeadingColor => AdminTheme.cyan;

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
    Color confirmColor = AdminTheme.danger,
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                foregroundColor: AdminTheme.background,
              ),
              onPressed: () => Navigator.of(context).pop(true),
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
        title: action.label,
        message: successMessage,
        tone: AdminBannerTone.success,
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }

      showAdminFeedback(
        title: 'Action impossible',
        message: error.message ?? 'Opération ${action.label} refusée.',
        tone: AdminBannerTone.danger,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      showAdminFeedback(
        title: 'Action impossible',
        message: 'Opération impossible : $error',
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
          'Cette suppression passe par le service sécurisé et peut supprimer l’accès du compte ${user.email}.',
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
          'Cette action désactive immédiatement l’accès au compte ${user.email}. La session mobile sera fermée et les prochaines connexions seront refusées.',
      confirmLabel: 'Désactiver',
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
          'L’accès a été désactivé pour ${user.email}. Le compte ne pourra plus se reconnecter tant qu’il ne sera pas réactivé.',
    );
  }

  Future<void> _enableManagedAccountAuth(AppUser user) async {
    await _runVoidAction(
      user: user,
      action: enableManagedAccountAuthAction,
      request: () =>
          _managedAccountService.enableManagedAccountAuth(uid: user.uid),
      successMessage: 'L’accès a été réactivé pour ${user.email}.',
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
                    initialValue: nextRole,
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
        title: 'Invitation renvoyée',
        message: 'Les liens d’invitation ont été régénérés pour ${user.email}.',
        tone: AdminBannerTone.success,
      );
      await _showInviteResultDialog(result, user.nom);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }

      showAdminFeedback(
        title: 'Envoi impossible',
        message:
            error.message ??
            'Impossible de renvoyer les liens d’invitation pour ce compte.',
        tone: AdminBannerTone.danger,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      showAdminFeedback(
        title: 'Envoi impossible',
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
                      ? 'Confirmez que les informations du profil sont cohérentes et suffisamment fiables pour afficher un signal de confiance.'
                      : 'La certification sera retirée du profil. Le compte reste actif si son accès et son e-mail sont valides.',
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

  Future<void> _editManagedAccountProfile(AppUser user) async {
    if (!_canManageProfileVerification(user)) {
      showAdminFeedback(
        title: 'Action indisponible',
        message:
            'La modification du profil est réservée aux comptes gérés par l’administration et exclut les comptes admin.',
        tone: AdminBannerTone.warning,
      );
      return;
    }

    final patch = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => _ManagedProfileEditDialog(user: user),
    );

    if (patch == null) {
      return;
    }

    if (patch.isEmpty) {
      showAdminFeedback(
        title: 'Aucune modification',
        message: 'Aucun champ n’a été modifié pour ${user.nom}.',
        tone: AdminBannerTone.info,
      );
      return;
    }

    await _runVoidAction(
      user: user,
      action: updateManagedAccountProfileAction,
      request: () => _managedAccountService.updateManagedAccountProfile(
        uid: user.uid,
        patch: patch,
      ),
      successMessage: 'Le profil de ${user.nom} a été mis à jour.',
    );
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
            'Réactivez d’abord l’accès et la vérification e-mail avant de certifier le profil.',
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

  Future<void> _setManagedAccountMembership(AppUser user) async {
    if (!_isMutableManagedAccount(user)) {
      showAdminFeedback(
        title: 'Action indisponible',
        message:
            'Les droits ne se gèrent que sur les comptes suivis par l’administration, comptes du portail exclus.',
        tone: AdminBannerTone.warning,
      );
      return;
    }

    final decision = await showDialog<_MembershipDecision>(
      context: context,
      builder: (context) => _ManagedMembershipDialog(user: user),
    );

    if (decision == null) {
      return;
    }

    final current = user.membership;
    // Réenvoyer le dossier à l'identique redémarrerait la date de début côté
    // backend : autant le dire plutôt que d'écrire pour rien.
    if (decision.tier == current.tier &&
        decision.validUntil == current.validUntil &&
        decision.reference == current.reference) {
      showAdminFeedback(
        title: 'Aucune modification',
        message: 'Les droits de ${user.nom} sont déjà dans cet état.',
        tone: AdminBannerTone.info,
      );
      return;
    }

    await _runVoidAction(
      user: user,
      action: setManagedAccountMembershipAction,
      request: () => _managedAccountService.setManagedAccountMembership(
        uid: user.uid,
        tier: decision.tier,
        validUntil: decision.validUntil,
        reference: decision.reference,
      ),
      successMessage: decision.tier == MembershipTier.none
          ? 'Les droits de ${user.nom} ont été retirés.'
          : 'Droits enregistrés pour ${user.nom} : ${decision.summaryLabel}.',
    );
  }

  Future<void> _showProfileReviewDialog(AppUser user) async {
    // phone/email/authDisabledReason/profileVerificationNote were moved out
    // of the bulk users snapshot into users/{uid}/private/contact and
    // users/{uid}/private/adminNotes, so the review dialog needs an
    // on-demand fetch to show them (admin claims grant access to both).
    final enrichedUser = await _userController.fetchUserWithPrivateFields(user);

    if (!mounted) {
      return;
    }

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
              child: _ProfileReviewContent(user: enrichedUser),
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
                  _editManagedAccountProfile(user);
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Modifier le profil'),
              ),
            if (_isMutableManagedAccount(user))
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _setManagedAccountMembership(user);
                },
                icon: const Icon(
                  Icons.workspace_premium_outlined,
                  size: 18,
                ),
                label: const Text('Gérer les droits'),
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
              color: user.authDisabled
                  ? AdminTheme.success
                  : AdminTheme.warning,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                user.authDisabled ? 'Réactiver l’accès' : 'Suspendre l’accès',
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
              child: Text('Revoir le profil', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );

    if (_canManageProfileVerification(user)) {
      items.add(
        const PopupMenuItem(
          value: _actionEditProfile,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: AdminTheme.cyan),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Modifier le profil',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
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

    if (_isMutableManagedAccount(user)) {
      items.add(
        PopupMenuItem(
          value: _actionManageMembership,
          child: Row(
            children: [
              Icon(
                user.membership.isRecorded
                    ? Icons.workspace_premium_rounded
                    : Icons.workspace_premium_outlined,
                size: 18,
                color: user.membership.isActiveAt(DateTime.now())
                    ? AdminTheme.accent
                    : AdminTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Gérer les droits',
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
              Icon(
                Icons.manage_accounts_outlined,
                size: 18,
                color: AdminTheme.cyan,
              ),
              SizedBox(width: 8),
              Flexible(
                child: Text('Changer le rôle', overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: _actionResendInvite,
          child: Row(
            children: const [
              Icon(
                Icons.mark_email_read_outlined,
                size: 18,
                color: AdminTheme.accent,
              ),
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
            Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: AdminTheme.danger,
            ),
            SizedBox(width: 8),
            Flexible(child: Text('Supprimer', overflow: TextOverflow.ellipsis)),
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
      case _actionEditProfile:
        await _editManagedAccountProfile(user);
        break;
      case _actionVerifyProfile:
        await _verifyManagedAccountProfile(user);
        break;
      case _actionUnverifyProfile:
        await _unverifyManagedAccountProfile(user);
        break;
      case _actionManageMembership:
        await _setManagedAccountMembership(user);
        break;
    }
  }

  Widget _buildActionCell(AppUser user) {
    if (_actionInFlightUid == user.uid) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(_actionInFlightLabel ?? 'Traitement...'),
        ],
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Actions utilisateur',
      onSelected: (value) => _handleActionSelection(value, user),
      itemBuilder: (context) => _buildActionMenuItems(user),
    );
  }

  Widget _buildUserCard(AppUser user) {
    return AdminDataCard(
      leading: Icon(_rowLeadingIcon, color: _rowLeadingColor, size: 22),
      title: Text(
        user.nom,
        style: const TextStyle(
          color: AdminTheme.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        user.email,
        style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 12),
      ),
      fields: [
        AdminDataCardField(
          label: 'Rôle',
          value: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.role),
              Text(
                user.profileLevelLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: AdminTheme.textSecondary,
                ),
              ),
              Text(
                user.profileTrustLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: user.profileVerified
                      ? AdminTheme.success
                      : user.profileVerificationNeedsReview
                      ? AdminTheme.warning
                      : AdminTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (user.createdByAdmin)
                const Text(
                  'créé par l\'administration',
                  style: TextStyle(fontSize: 12, color: AdminTheme.accent),
                ),
            ],
          ),
        ),
        AdminDataCardField(
          label: 'Statut',
          value: AdminAccountStatusChips(user: user),
        ),
      ],
      actions: _buildActionCell(user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);
    final panelPadding = compact ? 16.0 : 20.0;
    final spacing = compact ? 12.0 : 18.0;
    final tableColumnSpacing = compact ? 16.0 : 20.0;
    final headingRowHeight = compact ? 54.0 : 58.0;
    final dataRowHeight = compact ? 78.0 : 84.0;
    final hasFilters = searchQuery.trim().isNotEmpty || selectedRole != 'Tous';

    return AdminGlassPanel(
      padding: EdgeInsets.all(panelPadding),
      highlight: true,
      accentColor: _panelAccentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminInfoBanner(
            title: _bannerTitle,
            message: _bannerMessage,
            icon: Icons.rule_folder_outlined,
            tone: AdminBannerTone.warning,
          ),
          SizedBox(height: spacing),
          AdminFilterBar(
            maxWidth: 1180,
            breakpoint: 900,
            spacing: compact ? 10 : 12,
            flexes: const [5, 3, 2],
            children: [
              AdminSearchField(
                controller: _searchController,
                hintText: _searchHint,
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                    currentPage = 0;
                  });
                },
              ),
              _buildRoleFilterField(),
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
          SizedBox(height: spacing),
          Obx(() {
            final filteredUsers = _userController.userList.where((user) {
              final matchesRole =
                  selectedRole == 'Tous' || user.role == selectedRole;
              final normalizedQuery = searchQuery.toLowerCase();
              final matchesSearch =
                  normalizedQuery.isEmpty ||
                  // email/phone dropped: they no longer come back on the
                  // bulk users snapshot (see UserController.fetchUsers),
                  // only on the on-demand private-fields fetch used by the
                  // profile review dialog.
                  [
                    user.nom,
                    user.city,
                    user.region,
                    user.country,
                    user.team,
                    user.nomClub,
                    user.entreprise,
                    user.clubActuel,
                    user.profileTrustLabel,
                    user.profileVerificationStatusLabel,
                  ].whereType<String>().any(
                    (value) => value.toLowerCase().contains(normalizedQuery),
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

            if (_userController.isLoading.value) {
              return const Center(
                child: AdminLoadingState(
                  message: 'Chargement des utilisateurs...',
                ),
              );
            }

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
            final advancedProfiles = filteredUsers
                .where((user) => user.hasAdvancedProfile)
                .length;
            final verifiedProfiles = filteredUsers
                .where((user) => user.profileVerified)
                .length;
            // canBeProfileVerifiedByAdmin alone doesn't check whether the
            // account is actually one the admin can act on (self-signup
            // joueur/fan accounts pass it too, but _verifyManagedAccountProfile
            // and the backend's assertManagedTarget both reject those) — use
            // the same _canManageProfileVerification gate as the action
            // itself so this count matches what "Certifier" can actually do.
            final readyForVerification = filteredUsers
                .where(
                  (user) =>
                      !user.profileVerified &&
                      _canManageProfileVerification(user) &&
                      user.canBeProfileVerifiedByAdmin,
                )
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
                      label: 'Comptes administrés',
                      value: '$managedUsers',
                      icon: Icons.manage_accounts_outlined,
                      accentColor: AdminTheme.accent,
                      subtitle: 'Dans la sélection',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Accès suspendus',
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
                      label: 'À revalider',
                      value: '$pendingReview',
                      icon: Icons.fact_check_outlined,
                      accentColor: AdminTheme.warning,
                      subtitle: 'Informations à revoir',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Prêts à vérifier',
                      value: '$readyForVerification',
                      icon: Icons.rule_folder_outlined,
                      accentColor: AdminTheme.cyan,
                      subtitle: 'Éligibles',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Droits actifs',
                      value:
                          '${filteredUsers.where((user) => user.membership.isActiveAt(DateTime.now())).length}',
                      icon: Icons.workspace_premium_outlined,
                      accentColor: AdminTheme.accent,
                      subtitle: 'Dossiers en cours',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Profils avancés',
                      value: '$advancedProfiles',
                      icon: Icons.verified_outlined,
                      accentColor: AdminTheme.success,
                      subtitle: 'Profils complets',
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
                if (compact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final user in displayedUsers) ...[
                        _buildUserCard(user),
                        const SizedBox(height: 12),
                      ],
                    ],
                  )
                else
                  AdminDataTableCard(
                    compact: compact,
                    child: DataTable(
                      columnSpacing: tableColumnSpacing,
                      horizontalMargin: compact ? 8 : 10,
                      columns: const [
                        DataColumn(
                          label: Text('Nom', textAlign: TextAlign.center),
                        ),
                        DataColumn(
                          label: Text('Email', textAlign: TextAlign.center),
                        ),
                        DataColumn(
                          label: Text('Rôle', textAlign: TextAlign.center),
                        ),
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
                              SizedBox(
                                width: compact ? 170 : 190,
                                child: Row(
                                  children: [
                                    Icon(
                                      _rowLeadingIcon,
                                      color: _rowLeadingColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        displayedUsers[index].nom,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: compact ? 200 : 240,
                                child: Text(
                                  displayedUsers[index].email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: compact ? 190 : 220,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayedUsers[index].role,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      displayedUsers[index].profileLevelLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                                        color:
                                            displayedUsers[index]
                                                .profileVerified
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
                                        'créé par l\'administration',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AdminTheme.accent,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(
                              AdminAccountStatusChips(
                                user: displayedUsers[index],
                              ),
                            ),
                            DataCell(_buildActionCell(displayedUsers[index])),
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
                      dataRowMinHeight: dataRowHeight,
                      dataRowMaxHeight: dataRowHeight,
                      headingRowHeight: headingRowHeight,
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

class _ManagedProfileEditDialog extends StatefulWidget {
  const _ManagedProfileEditDialog({required this.user});

  final AppUser user;

  @override
  State<_ManagedProfileEditDialog> createState() =>
      _ManagedProfileEditDialogState();
}

class _ManagedProfileEditDialogState extends State<_ManagedProfileEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomController;
  late List<FootballPosition> _positionCodes;
  late final TextEditingController _teamController;
  late final TextEditingController _ligueController;
  late final TextEditingController _entrepriseController;
  late final TextEditingController _licenseController;

  AppUser get _user => widget.user;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: _user.nom);
    _positionCodes = List<FootballPosition>.of(_user.football.positions);
    _teamController = TextEditingController(text: _user.team ?? '');
    _ligueController = TextEditingController(text: _user.ligue ?? '');
    _entrepriseController = TextEditingController(text: _user.entreprise ?? '');
    _licenseController = TextEditingController(
      text: _currentLicenseNumber() ?? '',
    );
  }

  @override
  void dispose() {
    _nomController.dispose();
    _teamController.dispose();
    _ligueController.dispose();
    _entrepriseController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  String? _currentLicenseNumber() {
    if (_user.isPlayer) {
      return _user.playerProfile?['licenseNumber']?.toString();
    }
    if (_user.isClub) {
      return _user.clubProfile?['licenseNumber']?.toString();
    }
    if (_user.isRecruiter) {
      return _user.agentProfile?['licenseNumber']?.toString();
    }
    return null;
  }

  String? _trimOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Map<String, dynamic> _buildPatch() {
    final patch = <String, dynamic>{};

    final nom = _nomController.text.trim();
    if (nom.isNotEmpty && nom != _user.nom) {
      patch['nom'] = nom;
    }

    if (_user.isPlayer) {
      // Des codes, pas du texte : `updateManagedAccountProfile` valide contre
      // la meme liste fermee et laisse tomber en silence ce qu'il ne reconnait
      // pas. Un poste tape a la main serait donc perdu sans erreur.
      final codes = _positionCodes.map((p) => p.code).toList();
      final currentCodes =
          _user.football.positions.map((p) => p.code).toList();
      if (!listEquals(codes, currentCodes)) {
        patch['positionCodes'] = codes;
      }
      final team = _trimOrNull(_teamController.text);
      if (team != _user.team) {
        patch['team'] = team;
      }
    } else if (_user.isClub) {
      final ligue = _trimOrNull(_ligueController.text);
      if (ligue != _user.ligue) {
        patch['ligue'] = ligue;
      }
      final license = _trimOrNull(_licenseController.text);
      if (license != _currentLicenseNumber()) {
        patch['clubFederationId'] = license;
      }
    } else if (_user.isRecruiter) {
      final entreprise = _trimOrNull(_entrepriseController.text);
      if (entreprise != _user.entreprise) {
        patch['entreprise'] = entreprise;
      }
      final license = _trimOrNull(_licenseController.text);
      if (license != _currentLicenseNumber()) {
        patch['agentProfile'] = {'licenseNumber': license};
      }
    }

    return patch;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(_buildPatch());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Modifier le profil - ${_user.nom}'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nomController,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Le nom est requis.'
                      : null,
                ),
                const SizedBox(height: 12),
                if (_user.isPlayer) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Postes',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: FootballPosition.values.map((position) {
                      final index = _positionCodes.indexOf(position);
                      final isSelected = index >= 0;
                      final atLimit = _positionCodes.length >=
                          FootballPosition.maxPerPlayer;

                      return FilterChip(
                        selected: isSelected,
                        label: Text(
                          isSelected
                              ? '${index + 1}. ${position.labelFr}'
                              : position.labelFr,
                        ),
                        onSelected: (!isSelected && atLimit)
                            ? null
                            : (_) => setState(() {
                                if (isSelected) {
                                  _positionCodes.remove(position);
                                } else {
                                  _positionCodes.add(position);
                                }
                              }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _teamController,
                    decoration: const InputDecoration(labelText: 'Équipe'),
                  ),
                ] else if (_user.isClub) ...[
                  TextFormField(
                    controller: _ligueController,
                    decoration: const InputDecoration(labelText: 'Ligue'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _licenseController,
                    decoration: const InputDecoration(
                      labelText: 'Numéro de licence du club (facultatif)',
                    ),
                  ),
                ] else if (_user.isRecruiter) ...[
                  TextFormField(
                    controller: _entrepriseController,
                    decoration: const InputDecoration(
                      labelText: 'Organisation',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _licenseController,
                    decoration: InputDecoration(
                      labelText: _user.isAgent
                          ? 'Numéro de licence'
                          : 'Référence de licence ou d’agrément',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Enregistrer')),
      ],
    );
  }
}

/// Ce que l'administrateur a décidé dans le dialogue des droits.
class _MembershipDecision {
  const _MembershipDecision({
    required this.tier,
    this.validUntil,
    this.reference,
  });

  final MembershipTier tier;
  final DateTime? validUntil;
  final String? reference;

  String get summaryLabel {
    if (tier == MembershipTier.none) {
      return 'aucun droit';
    }

    final until = validUntil;
    final label = Membership.tierLabelOf(tier);
    return until == null
        ? '$label, sans terme'
        : '$label, jusqu’au ${Membership.formatDate(until)}';
  }
}

class _ManagedMembershipDialog extends StatefulWidget {
  const _ManagedMembershipDialog({required this.user});

  final AppUser user;

  @override
  State<_ManagedMembershipDialog> createState() =>
      _ManagedMembershipDialogState();
}

class _ManagedMembershipDialogState extends State<_ManagedMembershipDialog> {
  late MembershipTier _tier;
  late DateTime? _validUntil;
  late final TextEditingController _referenceController;

  AppUser get _user => widget.user;

  @override
  void initState() {
    super.initState();
    _tier = _user.membership.tier;
    _validUntil = _user.membership.validUntil;
    _referenceController = TextEditingController(
      text: _user.membership.reference ?? '',
    );
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  bool get _isClearing => _tier == MembershipTier.none;

  Future<void> _pickValidUntil() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day + 1);
    // Deux jours de marge sur la limite du callable : la date choisie est
    // ramenée à 23h59, et une échéance au dernier jour exact serait refusée
    // pour quelques heures de trop.
    final lastDate = now.add(Membership.maxValidity - const Duration(days: 2));
    final current = _validUntil;
    final initialDate = (current != null && current.isAfter(firstDate))
        ? (current.isBefore(lastDate) ? current : lastDate)
        : firstDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Échéance des droits',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );

    if (picked == null) {
      return;
    }

    setState(() {
      // Fin de journée : des droits accordés « jusqu’au 12 » valent tout le 12.
      _validUntil = DateTime(picked.year, picked.month, picked.day, 23, 59);
    });
  }

  void _submit() {
    final reference = _referenceController.text.trim();

    Navigator.of(context).pop(
      _MembershipDecision(
        tier: _tier,
        validUntil: _isClearing ? null : _validUntil,
        reference: (_isClearing || reference.isEmpty) ? null : reference,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _user.membership;

    return AlertDialog(
      title: Text('Droits - ${_user.nom}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Compte cible : ${_user.nom} (${_user.email})'),
              const SizedBox(height: 6),
              Text(
                'État actuel : ${current.statusLabelAt(DateTime.now())}',
                style: const TextStyle(color: AdminTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MembershipTier>(
                initialValue: _tier,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
                ),
                items: Membership.selectableTiers
                    .map(
                      (tier) => DropdownMenuItem<MembershipTier>(
                        value: tier,
                        child: Text(Membership.tierLabelOf(tier)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _tier = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                Membership.tierDescriptionOf(_tier),
                style: const TextStyle(
                  color: AdminTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              if (!_isClearing) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _validUntil == null
                            ? 'Échéance : sans terme'
                            : 'Échéance : ${Membership.formatDate(_validUntil!)}',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pickValidUntil,
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: const Text('Choisir'),
                    ),
                    if (_validUntil != null)
                      TextButton(
                        onPressed: () => setState(() => _validUntil = null),
                        child: const Text('Sans terme'),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Un compte sous contrat avec l’agence n’a normalement pas de terme.',
                  style: TextStyle(
                    color: AdminTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _referenceController,
                  maxLength: Membership.referenceMaxLength,
                  decoration: const InputDecoration(
                    labelText: 'Référence interne (facultatif)',
                    hintText: 'Ex. contrat 2026-014 ou reçu agence 1287',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _isClearing
                    ? 'Le dossier sera effacé : le compte redeviendra un compte sans droits enregistrés.'
                    : 'Aucun montant n’est enregistré ici. Le règlement se fait à l’agence et cette fiche ne fait qu’en garder la trace.',
                style: const TextStyle(
                  color: AdminTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(_isClearing ? 'Retirer les droits' : 'Enregistrer'),
        ),
      ],
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
              color: user.profileVerified
                  ? AdminTheme.success
                  : AdminTheme.cyan,
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
              color: user.profilePublic
                  ? AdminTheme.success
                  : AdminTheme.warning,
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
                value: 'Revalidation Adfoot après modification utilisateur',
              ),
            if (user.profileVerificationInvalidatedAt != null)
              _ProfileReviewItem(
                label: 'À revalider depuis',
                value: user.profileVerificationInvalidatedAt!
                    .toLocal()
                    .toString(),
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
                    ? 'Certifié le'
                    : 'Dernière certification',
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
          title: 'Droits enregistrés',
          children: [
            _ProfileReviewItem(
              label: 'État',
              value: user.membership.statusLabelAt(DateTime.now()),
            ),
            _ProfileReviewItem(
              label: 'Catégorie',
              value: user.membership.tierLabel,
            ),
            if (user.membership.startedAt != null)
              _ProfileReviewItem(
                label: 'Enregistré le',
                value: Membership.formatDate(user.membership.startedAt!),
              ),
            _ProfileReviewItem(
              label: 'Échéance',
              value: user.membership.validUntil == null
                  ? (user.membership.isRecorded
                        ? 'Sans terme'
                        : 'Sans objet')
                  : Membership.formatDate(user.membership.validUntil!),
            ),
            _ProfileReviewItem(
              label: 'Référence interne',
              value: user.membership.reference ?? 'Non renseignée',
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
          label: 'Postes',
          value: user.football.positions.isEmpty
              ? 'Non renseigné'
              : user.football.positions.map((p) => p.labelFr).join(' · '),
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
          label: 'Numéro de licence',
          value:
              user.playerProfile?['licenseNumber']?.toString() ??
              'Non renseigné',
        ),
        _ProfileReviewItem(
          label: 'Profil joueur avancé',
          value: _formatMapSummary(user.playerProfile),
        ),
      ];
    }

    if (user.isClub) {
      return [
        _ProfileReviewItem(label: 'Club', value: user.nomClub ?? user.nom),
        _ProfileReviewItem(
          label: 'Ligue',
          value: user.ligue ?? 'Non renseignée',
        ),
        _ProfileReviewItem(
          label: 'Numéro de licence du club',
          value:
              user.clubProfile?['licenseNumber']?.toString() ?? 'Non renseigné',
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
          label: user.isAgent
              ? 'Numéro de licence'
              : 'Référence de licence ou d’agrément',
          value:
              user.agentProfile?['licenseNumber']?.toString() ??
              'Non renseigné',
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
  const _ProfileReviewSection({required this.title, required this.children});

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
  const _ProfileReviewItem({required this.label, required this.value})
    : success = null;

  const _ProfileReviewItem.boolean({required this.label, required bool value})
    : value = value ? 'Oui' : 'Non',
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
