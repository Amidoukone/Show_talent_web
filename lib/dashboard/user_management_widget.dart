import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/user_controller.dart';
import '../models/managed_account_provision_result.dart';
import '../models/football_vocabulary.dart';
import '../models/membership.dart';
import '../models/player_football_profile.dart';
import '../models/user.dart';
import '../services/managed_account_service.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';
import '../utils/account_role_policy.dart';
import '../utils/admin_callable_action_catalog.dart';
import '../utils/firebase_functions_error.dart';
import '../utils/player_age.dart';
import '../widgets/admin_account_status_chips.dart';
import '../widgets/admin_detail_panel.dart';
import '../widgets/admin_feedback.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_table.dart';
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
  static const int rowsPerPage = 25;

  /// Largeur en deçà de laquelle le tableau défile horizontalement. Sert
  /// aussi à AdminWorkspace pour décider si la fiche tient à côté.
  static const double _tableMinWidth = 960;

  final TextEditingController _searchController = TextEditingController();

  late final UserController _userController;
  late final ManagedAccountService _managedAccountService;
  String searchQuery = '';
  String? selectedRole;
  int currentPage = 0;
  String? _actionInFlightUid;
  String? _actionInFlightLabel;

  /// Compte ouvert dans la fiche latérale.
  ///
  /// Seul l'identifiant est mémorisé : le contenu de la fiche est relu à
  /// chaque reconstruction depuis la liste vivante du contrôleur. Garder
  /// une copie figée afficherait l'état d'avant l'action — l'opérateur
  /// certifie un profil et la fiche continue d'annoncer « non certifié ».
  String? _selectedUid;

  /// La note de certification est le seul champ que la liste ne porte pas :
  /// elle vit dans users/{uid}/private/adminNotes et se lit à la demande
  /// (téléphone, e-mail et motif de suspension arrivent, eux, par le
  /// miroir users/{uid}/private/contact du contrôleur).
  String? _detailVerificationNote;
  bool _detailLoading = false;
  String? _detailError;

  /// Restriction appliquée par la bande de compteurs, en plus du rôle et
  /// de la recherche.
  _UserStatusFilter? _statusFilter;

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
    return AdminFilterDropdown<String>(
      label: 'Rôle',
      value: selectedRole ?? 'Tous',
      items: <String>['Tous', ...adminProvisionedRoles],
      labelBuilder: (role) => role,
      onChanged: (String newValue) {
        setState(() {
          selectedRole = newValue;
          currentPage = 0;
        });
      },
    );
  }

  void _clearFilters() {
    setState(() {
      searchQuery = '';
      selectedRole = 'Tous';
      _statusFilter = null;
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

  IconData get _rowLeadingIcon => Icons.person_rounded;

  Color get _rowLeadingColor => AdminTheme.cyan;

  /// Règle de gouvernance rappelée au survol de la colonne « Confiance ».
  /// Elle occupait un bandeau permanent de quatre lignes en haut de l'écran.
  String get _trustColumnHelp =>
      "La certification profil est un signal de confiance séparé de l’e-mail vérifié. Si l’utilisateur modifie une information de confiance côté mobile, le profil repasse à revalider avant d’afficher le badge Adfoot.";

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
        message: describeFunctionsError(
          error,
          fallbackMessage: 'Opération ${action.label} refusée.',
        ),
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
        message: describeFunctionsError(
          error,
          fallbackMessage:
              'Impossible de renvoyer les liens d’invitation pour ce compte.',
        ),
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

    // La date de naissance vit dans users/{uid}/private/contact, pas dans le
    // flux de la liste : sans cette lecture, le champ s'ouvrirait vide sur un
    // profil qui en porte une, et l'administration corrigerait une fiche en
    // croyant qu'il lui manque un fait qu'elle possède déjà.
    var editable = user;
    var contactLoaded = true;
    try {
      editable = await _userController.fetchUserWithPrivateFields(user);
    } catch (error) {
      // La modification n'est pas abandonnée pour autant : les postes, le club
      // et le parcours restent corrigeables sans ce document. Seul le champ
      // date disparaît — mieux vaut absent qu'affiché vide, ce qui se lirait
      // comme « ce joueur n'a pas de date de naissance ».
      contactLoaded = false;
      debugPrint('Lecture de private/contact impossible : $error');
    }

    if (!mounted) {
      return;
    }

    final patch = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => _ManagedProfileEditDialog(
        user: editable,
        contactLoaded: contactLoaded,
      ),
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

  Future<void> _withdrawMinorConsent(AppUser user) async {
    if (!user.isPlayer || !user.isMinorProfile) {
      showAdminFeedback(
        title: 'Action indisponible',
        message: 'Cette action concerne uniquement les joueurs mineurs.',
        tone: AdminBannerTone.warning,
      );
      return;
    }
    final confirmed = await _confirmAction(
      title: withdrawManagedMinorConsentAction.label,
      message:
          'Confirmez-vous que la demande du parent ou tuteur a été vérifiée ? '
          'La fiche sera masquée et les photos, CV et vidéos publiés seront supprimés.',
      confirmLabel: 'Retirer les autorisations',
    );
    if (!confirmed) return;
    await _runVoidAction(
      user: user,
      action: withdrawManagedMinorConsentAction,
      request: () =>
          _managedAccountService.withdrawManagedMinorConsent(uid: user.uid),
      successMessage:
          'Les autorisations de ${user.nom} ont été retirées et les médias purgés.',
    );
  }

  Future<void> _verifyManagedAccountProfile(AppUser user) async {
    if (!_canManageProfileVerification(user) || user.isMinorProfile) {
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

  /// Ouvre la fiche latérale sur un compte.
  ///
  /// Remplace la boîte de dialogue « Revue profil » : elle imposait de
  /// refermer pour passer au dossier suivant, alors que la revue de profils
  /// se fait en série. La lecture à la demande des champs privés
  /// (téléphone, e-mail, note de certification — sortis de l'instantané
  /// global vers users/{uid}/private) est inchangée, elle alimente
  /// maintenant le panneau au lieu de la modale.
  Future<void> _openDetail(AppUser user) async {
    setState(() {
      _selectedUid = user.uid;
      _detailVerificationNote = null;
      _detailLoading = true;
      _detailError = null;
    });

    try {
      final enriched = await _userController.fetchUserWithPrivateFields(user);
      if (!mounted || _selectedUid != user.uid) {
        return;
      }
      setState(() {
        _detailVerificationNote = enriched.profileVerificationNote;
        _detailLoading = false;
      });
    } catch (error) {
      debugPrint('Lecture des champs privés impossible : $error');
      if (!mounted || _selectedUid != user.uid) {
        return;
      }
      setState(() {
        _detailLoading = false;
        _detailError =
            'Impossible de charger les coordonnées de ${user.nom}. '
            'Vérifiez votre connexion puis réessayez.';
      });
    }
  }

  void _closeDetail() {
    setState(() {
      _selectedUid = null;
      _detailVerificationNote = null;
      _detailLoading = false;
      _detailError = null;
    });
  }

  /// Le compte à afficher dans la fiche, reconstruit à partir de la version
  /// vivante de la liste et de la note lue à la demande.
  ///
  /// Résolu sur la liste complète et non sur la liste filtrée : certifier
  /// un profil pendant qu'on filtre sur « à revalider » le fait sortir des
  /// résultats, et la fiche ne doit pas disparaître au moment précis où
  /// l'opérateur veut vérifier que son action a abouti.
  AppUser? get _detailUser {
    final uid = _selectedUid;
    if (uid == null) {
      return null;
    }

    for (final user in _userController.userList) {
      if (user.uid != uid) {
        continue;
      }
      if (_detailVerificationNote == null) {
        return user;
      }
      return AppUser.fromMap({
        ...user.toMap(),
        'profileVerificationNote': _detailVerificationNote,
      });
    }

    return null;
  }

  /// Actions d'une ligne.
  ///
  /// Les trois gestes du quotidien — ouvrir la fiche, certifier, suspendre
  /// — sont en clair. Tout passait auparavant par un menu, donc deux clics
  /// pour chacun. Le reste, moins fréquent ou destructeur, est sous « … ».
  Widget _buildActionCell(AppUser user) {
    final canVerify = _canManageProfileVerification(user);
    final canManage = _isMutableManagedAccount(user);
    final isManaged = _isAdminManagedAccount(user);

    return AdminRowActions(
      busy: _actionInFlightUid == user.uid,
      busyLabel: _actionInFlightLabel,
      primary: [
        AdminRowAction(
          icon: Icons.fact_check_outlined,
          label: 'Ouvrir la fiche',
          color: AdminTheme.cyan,
          onPressed: () => _openDetail(user),
        ),
        AdminRowAction(
          icon: user.profileVerified
              ? Icons.remove_moderator_outlined
              : Icons.verified_outlined,
          label: user.profileVerified
              ? 'Retirer la certification'
              : _verifyProfileActionLabel(user),
          color: user.profileVerified ? AdminTheme.warning : AdminTheme.success,
          onPressed: canVerify && (user.profileVerified || !user.isMinorProfile)
              ? () {
                  if (user.profileVerified) {
                    _unverifyManagedAccountProfile(user);
                  } else {
                    _verifyManagedAccountProfile(user);
                  }
                }
              : null,
        ),
        AdminRowAction(
          icon: user.authDisabled
              ? Icons.lock_open_rounded
              : Icons.lock_outline_rounded,
          label: user.authDisabled ? 'Réactiver l’accès' : 'Suspendre l’accès',
          color: user.authDisabled ? AdminTheme.success : AdminTheme.warning,
          onPressed: () {
            if (user.authDisabled) {
              _enableManagedAccountAuth(user);
            } else {
              _disableManagedAccountAuth(user);
            }
          },
        ),
      ],
      overflow: [
        // Une action structurellement impossible — compte du portail,
        // compte que l'administration ne suit pas — est retirée du menu
        // plutôt que grisée : même règle qu'avant la refonte, et elle évite
        // de promettre une opération que les callables refuseraient.
        if (canVerify)
          AdminRowAction(
            icon: Icons.edit_outlined,
            label: 'Modifier le profil',
            color: AdminTheme.cyan,
            onPressed: () => _editManagedAccountProfile(user),
          ),
        if (canManage)
          AdminRowAction(
            icon: Icons.workspace_premium_outlined,
            label: 'Gérer les droits',
            onPressed: () => _setManagedAccountMembership(user),
          ),
        if (isManaged) ...[
          AdminRowAction(
            icon: Icons.manage_accounts_outlined,
            label: 'Changer le rôle',
            onPressed: () => _changeManagedAccountRole(user),
          ),
          AdminRowAction(
            icon: Icons.mark_email_read_outlined,
            label: 'Renvoyer l’invitation',
            onPressed: () => _resendManagedAccountInvite(user),
          ),
        ],
        if (user.isPlayer && user.isMinorProfile)
          AdminRowAction(
            icon: Icons.shield_outlined,
            label: 'Retirer les autorisations parentales',
            color: AdminTheme.warning,
            onPressed: () => _withdrawMinorConsent(user),
          ),
        AdminRowAction(
          icon: Icons.delete_outline_rounded,
          label: 'Supprimer',
          color: AdminTheme.danger,
          onPressed: () => _deleteManagedAccount(user),
        ),
      ],
    );
  }

  /// Fiche latérale d'un compte : la revue de profil complète, avec les
  /// décisions épinglées en bas et la navigation dans la file en haut.
  Widget _buildDetailPanel(AppUser user, List<AppUser> queue) {
    final index = queue.indexWhere((item) => item.uid == user.uid);
    final canVerify = _canManageProfileVerification(user);
    final busy = _actionInFlightUid == user.uid;

    final Widget body;
    if (_detailLoading) {
      body = const AdminLoadingState(message: 'Chargement de la fiche…');
    } else if (_detailError != null) {
      body = AdminEmptyState(
        title: 'Chargement incomplet',
        message: _detailError!,
        icon: Icons.error_outline_rounded,
        actionLabel: 'Réessayer',
        actionIcon: Icons.refresh_rounded,
        onAction: () => _openDetail(user),
      );
    } else {
      body = _ProfileReviewContent(user: user);
    }

    return AdminDetailPanel(
      title: user.nom,
      subtitle: user.role,
      position: index < 0 ? null : '${index + 1} / ${queue.length}',
      onPrevious: index > 0 ? () => _openDetail(queue[index - 1]) : null,
      onNext: index >= 0 && index < queue.length - 1
          ? () => _openDetail(queue[index + 1])
          : null,
      onClose: _closeDetail,
      actions: [
        if (canVerify)
          OutlinedButton(
            onPressed: busy ? null : () => _editManagedAccountProfile(user),
            child: const Text('Modifier'),
          ),
        if (_isMutableManagedAccount(user))
          OutlinedButton(
            onPressed: busy ? null : () => _setManagedAccountMembership(user),
            child: const Text('Droits'),
          ),
        if (canVerify && (user.profileVerified || !user.isMinorProfile))
          ElevatedButton(
            onPressed: busy
                ? null
                : () {
                    if (user.profileVerified) {
                      _unverifyManagedAccountProfile(user);
                    } else {
                      _verifyManagedAccountProfile(user);
                    }
                  },
            child: Text(
              user.profileVerified
                  ? 'Retirer la certification'
                  : _verifyProfileActionLabel(user),
            ),
          ),
      ],
      child: body,
    );
  }

  Widget _buildUserCard(AppUser user) {
    return AdminDataCard(
      onTap: () => _openDetail(user),
      leading: Icon(_rowLeadingIcon, color: _rowLeadingColor, size: 18),
      title: Text(user.nom, style: AdminType.bodyStrong),
      subtitle: Text(user.email, style: AdminType.caption),
      fields: [
        AdminDataCardField(
          label: 'Rôle',
          value: Text('${user.role} · ${user.profileLevelLabel}'),
        ),
        AdminDataCardField(
          label: 'Confiance',
          value: Text(
            user.profileTrustLabel,
            style: TextStyle(
              color: user.profileVerified
                  ? AdminTheme.success
                  : user.profileVerificationNeedsReview
                  ? AdminTheme.warning
                  : AdminTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
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

  /// Applique le compteur sélectionné dans la bande de synthèse.
  ///
  /// Les tuiles de statistiques annonçaient « 3 accès suspendus » sans
  /// permettre de les voir : il fallait deviner lesquels à la lecture du
  /// tableau. Chaque compteur est maintenant un filtre.
  bool _matchesStatusFilter(AppUser user) {
    switch (_statusFilter) {
      case _UserStatusFilter.managed:
        return _isAdminManagedAccount(user);
      case _UserStatusFilter.suspended:
        return user.authDisabled;
      case _UserStatusFilter.verified:
        return user.profileVerified;
      case _UserStatusFilter.needsReview:
        return user.profileVerificationNeedsReview;
      case null:
        return true;
    }
  }

  void _toggleStatusFilter(_UserStatusFilter filter) {
    setState(() {
      _statusFilter = _statusFilter == filter ? null : filter;
      currentPage = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);
    final hasFilters =
        searchQuery.trim().isNotEmpty ||
        selectedRole != 'Tous' ||
        _statusFilter != null;

    final toolbar = AdminToolbar(
      flexes: const [3, 2],
      trailing: [
        IconButton(
          onPressed: hasFilters ? _clearFilters : null,
          icon: const Icon(Icons.filter_alt_off_rounded, size: 17),
          tooltip: 'Réinitialiser les filtres',
        ),
        IconButton(
          onPressed: _userController.retryUsers,
          icon: const Icon(Icons.refresh_rounded, size: 17),
          tooltip: 'Recharger la liste',
        ),
      ],
      filters: [
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
      ],
    );

    return Obx(() {
      final loadError =
          _userController.usersLoadError.value ??
          _userController.privateContactLoadError.value;
      if (loadError != null) {
        return AdminEmptyState(
          title: 'Chargement incomplet',
          message: loadError,
          icon: Icons.error_outline_rounded,
          actionLabel: 'Réessayer',
          actionIcon: Icons.refresh_rounded,
          onAction: _userController.retryUsers,
        );
      }

      if (_userController.isLoading.value) {
        return const AdminLoadingState(message: 'Chargement des utilisateurs…');
      }

      final roleAndSearchMatches = _userController.userList.where((user) {
        final matchesRole = selectedRole == 'Tous' || user.role == selectedRole;
        final normalizedQuery = searchQuery.toLowerCase();
        final matchesSearch =
            normalizedQuery.isEmpty ||
            // email/phone dropped: they no longer come back on the
            // bulk users snapshot (see UserController.fetchUsers),
            // only on the on-demand private-fields fetch used by the
            // profile review panel.
            [
              user.nom,
              user.city,
              user.region,
              user.country,
              user.football.currentClubName,
              user.nomClub,
              user.entreprise,
              user.profileTrustLabel,
              user.profileVerificationStatusLabel,
            ].whereType<String>().any(
              (value) => value.toLowerCase().contains(normalizedQuery),
            );

        return matchesRole && matchesSearch;
      }).toList();

      // Les compteurs portent sur la sélection rôle + recherche, pas sur le
      // filtre d'état lui-même : sinon cliquer « Accès suspendus » ferait
      // tomber tous les autres compteurs à zéro.
      final managedUsers = roleAndSearchMatches
          .where(_isAdminManagedAccount)
          .length;
      final verifiedProfiles = roleAndSearchMatches
          .where((user) => user.profileVerified)
          .length;
      final pendingReview = roleAndSearchMatches
          .where((user) => user.profileVerificationNeedsReview)
          .length;
      final suspendedAccess = roleAndSearchMatches
          .where((user) => user.authDisabled)
          .length;

      final filteredUsers = roleAndSearchMatches
          .where(_matchesStatusFilter)
          .toList();

      final totalPages = (filteredUsers.length / rowsPerPage).ceil();
      final safePage = totalPages == 0
          ? 0
          : currentPage.clamp(0, totalPages - 1);
      final startIndex = safePage * rowsPerPage;
      final endIndex = (startIndex + rowsPerPage).clamp(
        0,
        filteredUsers.length,
      );
      final displayedUsers = filteredUsers.sublist(startIndex, endIndex);

      final stats = AdminStatStrip(
        stats: [
          AdminStat(
            label: 'administrés',
            value: '$managedUsers',
            selected: _statusFilter == _UserStatusFilter.managed,
            onTap: () => _toggleStatusFilter(_UserStatusFilter.managed),
            tooltip: 'Comptes créés ou suivis par l’administration',
          ),
          AdminStat(
            label: 'certifiés',
            value: '$verifiedProfiles',
            selected: _statusFilter == _UserStatusFilter.verified,
            onTap: () => _toggleStatusFilter(_UserStatusFilter.verified),
            tooltip: 'Profils portant le badge de confiance',
          ),
          AdminStat(
            label: 'à revalider',
            value: '$pendingReview',
            tone: pendingReview > 0 ? AdminTheme.warning : null,
            selected: _statusFilter == _UserStatusFilter.needsReview,
            onTap: () => _toggleStatusFilter(_UserStatusFilter.needsReview),
            tooltip: 'Informations de confiance modifiées depuis la revue',
          ),
          AdminStat(
            label: 'accès suspendus',
            value: '$suspendedAccess',
            tone: suspendedAccess > 0 ? AdminTheme.warning : null,
            selected: _statusFilter == _UserStatusFilter.suspended,
            onTap: () => _toggleStatusFilter(_UserStatusFilter.suspended),
            tooltip: 'Comptes dont la connexion est bloquée',
          ),
        ],
      );

      final Widget body;
      if (filteredUsers.isEmpty) {
        body = AdminEmptyState(
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
              _userController.retryUsers();
            }
          },
        );
      } else if (compact) {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final user in displayedUsers) ...[
              _buildUserCard(user),
              const SizedBox(height: AdminTheme.space2),
            ],
          ],
        );
      } else {
        body = AdminTable(
          minWidth: _tableMinWidth,
          columns: [
            const AdminColumn(label: 'Compte', flex: 4),
            const AdminColumn(label: 'Rôle', flex: 2),
            AdminColumn(
              label: 'Confiance',
              width: 150,
              tooltip: _trustColumnHelp,
            ),
            const AdminColumn(label: 'Statut', width: 220),
            const AdminColumn(label: '', width: 128, alignRight: true),
          ],
          rowCount: displayedUsers.length,
          selectedRow: _selectedUid == null
              ? null
              : displayedUsers.indexWhere((user) => user.uid == _selectedUid),
          onRowTap: (index) => _openDetail(displayedUsers[index]),
          cellsBuilder: (index) {
            final user = displayedUsers[index];

            return [
              AdminCellIdentity(
                title: user.nom,
                subtitle: user.email,
                icon: _rowLeadingIcon,
                iconColor: _rowLeadingColor,
              ),
              AdminCellIdentity(
                title: user.role,
                subtitle: user.createdByAdmin
                    ? 'Compte administré'
                    : user.profileLevelLabel,
              ),
              Text(
                user.profileTrustLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminType.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: user.profileVerified
                      ? AdminTheme.success
                      : user.profileVerificationNeedsReview
                      ? AdminTheme.warning
                      : AdminTheme.textMuted,
                ),
              ),
              AdminAccountStatusChips(user: user),
              _buildActionCell(user),
            ];
          },
        );
      }

      final selected = _detailUser;

      return AdminWorkspace(
        compact: compact,
        bodyMinWidth: _tableMinWidth,
        toolbar: toolbar,
        stats: stats,
        body: body,
        // Le bandeau de gouvernance expliquait une règle métier en quatre
        // lignes, en haut de chaque visite. Il est devenu l'infobulle de la
        // colonne « Confiance », là où la question se pose vraiment.
        detail: selected == null
            ? null
            : _buildDetailPanel(selected, filteredUsers),
        footer: filteredUsers.isEmpty
            ? null
            : AdminListFooter(
                rangeStart: startIndex + 1,
                rangeEnd: endIndex,
                filteredCount: filteredUsers.length,
                currentPage: safePage,
                totalPages: totalPages,
                itemLabel: 'utilisateurs',
                hasMore: _userController.hasMoreUsers.value,
                onLoadMore: _userController.loadMoreUsers,
                onPrevious: safePage > 0
                    ? () => setState(() => currentPage = safePage - 1)
                    : null,
                onNext: safePage < totalPages - 1
                    ? () => setState(() => currentPage = safePage + 1)
                    : null,
              ),
      );
    });
  }
}

/// Les quatre états sur lesquels la bande de synthèse peut restreindre la
/// liste.
enum _UserStatusFilter { managed, verified, needsReview, suspended }

class _ManagedProfileEditDialog extends StatefulWidget {
  const _ManagedProfileEditDialog({
    required this.user,
    this.contactLoaded = true,
  });

  final AppUser user;

  /// Si `users/{uid}/private/contact` a pu être lu.
  ///
  /// Faux, le champ date de naissance n'est pas affiché du tout : il ne peut
  /// être ni prérempli ni comparé, et un champ vide dirait le contraire de la
  /// vérité sur une fiche qui porte une date.
  final bool contactLoaded;

  @override
  State<_ManagedProfileEditDialog> createState() =>
      _ManagedProfileEditDialogState();
}

class _ManagedProfileEditDialogState extends State<_ManagedProfileEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomController;
  late List<FootballPosition> _positionCodes;

  /// Le parcours tel que l'administration le laissera.
  ///
  /// Le portail retire, il n'ajoute pas : une saison s'archive depuis le
  /// téléphone, au moment où elle se termine, avec le club que le profil
  /// portait alors. Retaper une saison ici reviendrait à saisir de mémoire ce
  /// que l'application savait déjà — et c'est ainsi qu'on invente un fait dans
  /// une base qu'on présente comme qualifiée. Ce qu'un administrateur doit
  /// pouvoir faire, c'est effacer une ligne fausse ou dupliquée.
  late List<SeasonRecord> _seasonHistory;

  /// La date de naissance telle que l'administration la laissera.
  ///
  /// C'est le seul fait dont l'absence retire une fiche de toutes les
  /// recherches : `birthYear` en est dérivé par le serveur, et un dossier sans
  /// année n'est renvoyé à aucun recruteur. Jusqu'ici, seul le joueur pouvait
  /// le réparer, depuis son téléphone.
  DateTime? _birthDate;
  final _guardianNameController = TextEditingController();
  final _guardianEvidenceController = TextEditingController();
  String _guardianRelationship = 'parent';
  String _guardianConsentMethod = 'oral_confirmation';
  bool _guardianConsentConfirmed = false;
  bool _guardianMediaAllowed = false;
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
    _seasonHistory = List<SeasonRecord>.of(_user.football.seasonHistory);
    _birthDate = _user.birthDate;
    // Le club typé, pas `team`. Les deux existaient et personne ne les
    // écrivait ensemble : le portail posait `team`, le formulaire avancé du
    // mobile posait `currentClubName`, et la fiche affichait tantôt l'un
    // tantôt l'autre. Un club corrigé ici ressortait donc à côté de l'ancien
    // sur le téléphone.
    _teamController = TextEditingController(
      text: _user.football.currentClubName ?? '',
    );
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
    _guardianNameController.dispose();
    _guardianEvidenceController.dispose();
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

  bool get _isMinor {
    final date = _birthDate;
    if (date == null) {
      return false;
    }
    return isMinorPlayer(date);
  }

  bool get _requiresGuardianConsent =>
      _isMinor &&
      (!_user.isMinorProfile ||
          !_user.minorProfileApproved ||
          !_isSameDay(_birthDate, _user.birthDate));

  Map<String, dynamic> _guardianConsentPayload() => <String, dynamic>{
    'guardianName': _guardianNameController.text.trim(),
    'relationship': _guardianRelationship,
    'method': _guardianConsentMethod,
    'evidenceReference': _guardianEvidenceController.text.trim(),
    'mediaAllowed': _guardianMediaAllowed,
    'confirmed': _guardianConsentConfirmed,
  };

  bool _hasValidGuardianConsent() =>
      _guardianNameController.text.trim().length >= 2 &&
      _guardianConsentConfirmed;

  /// Deux dates désignent-elles le même jour ?
  ///
  /// Comparer les `DateTime` entiers enverrait un patch à chaque ouverture du
  /// dialogue : la valeur relue porte l'heure que le `Timestamp` a conservée,
  /// jamais celle que le sélecteur produit.
  static bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return a == null && b == null;
    }
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _pickBirthDate() async {
    final latestEligibleDate = latestEligibleBirthDate();
    final currentBirthDate = _birthDate;
    final initialDate =
        currentBirthDate == null || currentBirthDate.isAfter(latestEligibleDate)
        ? defaultBirthDatePickerDate()
        : currentBirthDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1930),
      lastDate: latestEligibleDate,
      helpText: 'Date de naissance',
    );

    if (picked == null || !mounted) {
      return;
    }
    setState(() => _birthDate = picked);
  }

  Widget _buildBirthDateField() {
    final value = _birthDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                value == null
                    ? 'Date de naissance : non renseignée'
                    : 'Date de naissance : ${_formatDate(value)}',
              ),
            ),
            TextButton.icon(
              onPressed: _pickBirthDate,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(value == null ? 'Renseigner' : 'Modifier'),
            ),
          ],
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Sans elle, le dossier n’apparaît dans aucune recherche de '
            'recruteur.',
            style: AdminType.caption,
          ),
        ),
        if (_user.profileVerified) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Modifier la date retire la certification jusqu’à un nouveau '
              'contrôle : l’âge est un fait que le recruteur croit sur parole.',
              style: AdminType.caption.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
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
      final currentCodes = _user.football.positions.map((p) => p.code).toList();
      if (!listEquals(codes, currentCodes)) {
        patch['positionCodes'] = codes;
      }
      final clubName = _trimOrNull(_teamController.text);
      if (clubName != _user.football.currentClubName) {
        patch['currentClubName'] = clubName;
      }
      // ISO-8601, jamais un DateTime : le callable accepte la chaîne, la
      // valide contre `toBirthYear` — celle-là même dont le trigger dérive
      // l'année — et la stocke en `Timestamp`, la forme que le mobile écrit
      // déjà. `null` efface, ce qui est le bon geste pour une date inventée.
      if (widget.contactLoaded && !_isSameDay(_birthDate, _user.birthDate)) {
        patch['birthDate'] = _birthDate?.toIso8601String();
      }
      if (_requiresGuardianConsent && _hasValidGuardianConsent()) {
        patch['guardianConsent'] = _guardianConsentPayload();
      }
      // La liste entière est renvoyée, pas la seule ligne retirée : le
      // callable réécrit `seasonHistory` d'un bloc, et lui envoyer un fragment
      // effacerait le reste du parcours.
      if (_seasonHistory.length != _user.football.seasonHistory.length) {
        patch['seasonHistory'] = _seasonHistory
            .map((season) => season.toMap())
            .toList();
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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final date = _birthDate;
    if (date != null) {
      final age = playerAgeOn(date);
      if (age < kMinimumPlayerAge) {
        showAdminFeedback(
          title: 'Date de naissance invalide',
          message: 'Adfoot accueille les joueurs à partir de 13 ans.',
          tone: AdminBannerTone.warning,
        );
        return;
      }
      final changed =
          widget.contactLoaded && !_isSameDay(date, _user.birthDate);
      if (changed && age < kAdultAge && !_hasValidGuardianConsent()) {
        showAdminFeedback(
          title: 'Accord parental requis',
          message:
              'Consignez l’accord du parent ou du tuteur avant cette correction.',
          tone: AdminBannerTone.warning,
        );
        return;
      }
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
                      final atLimit =
                          _positionCodes.length >=
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
                    decoration: const InputDecoration(labelText: 'Club actuel'),
                  ),
                  const SizedBox(height: 12),
                  if (widget.contactLoaded)
                    _buildBirthDateField()
                  else
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Date de naissance indisponible : le document de '
                        'contact n’a pas pu être lu.',
                        style: AdminType.caption,
                      ),
                    ),
                  if (_isMinor) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Sans accord parental enregistré, la fiche reste masquée. Avec accord, accès limité aux recruteurs vérifiés et contact médié par l’administration.',
                      style: AdminType.caption,
                    ),
                    if (_requiresGuardianConsent) ...[
                      TextFormField(
                        controller: _guardianNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom du parent ou tuteur',
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _guardianRelationship,
                        decoration: const InputDecoration(
                          labelText: 'Lien avec le joueur',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'parent',
                            child: Text('Parent'),
                          ),
                          DropdownMenuItem(
                            value: 'legal_guardian',
                            child: Text('Tuteur légal'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _guardianRelationship = value);
                          }
                        },
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _guardianConsentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Mode de consentement vérifié',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'oral_confirmation',
                            child: Text('Accord oral / téléphone'),
                          ),
                          DropdownMenuItem(
                            value: 'written_confirmation',
                            child: Text('Accord écrit'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _guardianConsentMethod = value);
                          }
                        },
                      ),
                      TextFormField(
                        controller: _guardianEvidenceController,
                        decoration: const InputDecoration(
                          labelText: 'Note de suivi (facultatif)',
                        ),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _guardianMediaAllowed,
                        title: const Text(
                          'Le parent autorise la publication des photos, vidéos et CV sur la fiche ; les vidéos restent soumises à modération.',
                        ),
                        onChanged: (value) => setState(
                          () => _guardianMediaAllowed = value ?? false,
                        ),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _guardianConsentConfirmed,
                        title: const Text(
                          'J’atteste avoir recueilli et consigné l’accord du parent/tuteur.',
                        ),
                        onChanged: (value) => setState(
                          () => _guardianConsentConfirmed = value ?? false,
                        ),
                      ),
                    ] else
                      const Text('Consentement parental déjà enregistré.'),
                  ],
                  if (_seasonHistory.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Parcours',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Retirez une saison fausse ou dupliquée. '
                        'Une saison s’archive depuis l’application.',
                        style: AdminType.caption,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final (index, season) in _seasonHistory.indexed)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _ProfileReviewContent.archivedSeasonLabel(season),
                              style: AdminType.body,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Retirer cette saison',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(
                              () => _seasonHistory = <SeasonRecord>[
                                ..._seasonHistory,
                              ]..removeAt(index),
                            ),
                          ),
                        ],
                      ),
                  ],
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
                style: AdminType.caption.copyWith(
                  color: AdminTheme.textSecondary,
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
                Text(
                  'Un compte sous contrat avec l’agence n’a normalement pas de terme.',
                  style: AdminType.caption.copyWith(
                    color: AdminTheme.textSecondary,
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
                style: AdminType.caption.copyWith(
                  color: AdminTheme.textSecondary,
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
                  ? (user.membership.isRecorded ? 'Sans terme' : 'Sans objet')
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

  /// « 2024-25 · Ligue 1 CIV · ASEC Mimosas (Académie) · 28 matchs, 11 buts »
  ///
  /// Le niveau du club y figure parce qu'il change la lecture des chiffres :
  /// vingt-huit matchs en académie et vingt-huit en première division ne
  /// disent pas la même chose du joueur.
  static String archivedSeasonLabel(SeasonRecord season) {
    final head = <String>[
      ?season.season,
      ?season.competition,
      if (season.clubName != null)
        season.clubLevel == null
            ? season.clubName!
            : '${season.clubName} (${season.clubLevel!.labelFr})',
    ].join(' · ');

    final figures = <String>[
      if (season.appearances != null) '${season.appearances} matchs',
      if (season.minutes != null) '${season.minutes} min',
      if (season.goals != null) '${season.goals} buts',
      if (season.assists != null) '${season.assists} passes',
    ].join(', ');

    if (head.isEmpty) return figures.isEmpty ? 'Saison archivée' : figures;
    return figures.isEmpty ? head : '$head · $figures';
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
          label: 'Club actuel',
          value: user.football.currentClubName ?? 'Non renseigné',
        ),
        // Le parcours : c'est sur lui qu'un recruteur juge une progression,
        // donc c'est lui qu'il signalera si une saison est fausse. Le voir
        // est la condition pour pouvoir le corriger.
        _ProfileReviewItem(
          label: 'Parcours',
          value: user.football.seasonHistory.isEmpty
              ? 'Aucune saison archivée'
              : user.football.seasonHistory.map(archivedSeasonLabel).join('\n'),
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

  // Même grammaire que les autres fiches du portail (AdminDetailSection) :
  // un intitulé discret et une suite de champs, sans encadré. Le panneau
  // en empile six, ce qui faisait six cartes dans une carte.
  @override
  Widget build(BuildContext context) {
    return AdminDetailSection(title: title, children: children);
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

    return AdminDetailField(
      label: label,
      value: value,
      valueColor: successValue == null
          ? null
          : (successValue ? AdminTheme.success : AdminTheme.warning),
      child: successValue == null
          ? null
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  successValue
                      ? Icons.check_circle_outline_rounded
                      : Icons.error_outline_rounded,
                  size: 14,
                  color: successValue ? AdminTheme.success : AdminTheme.warning,
                ),
                const SizedBox(width: AdminTheme.space2 - 2),
                Expanded(
                  child: Text(
                    value,
                    style: AdminType.body.copyWith(
                      color: successValue
                          ? AdminTheme.success
                          : AdminTheme.warning,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
