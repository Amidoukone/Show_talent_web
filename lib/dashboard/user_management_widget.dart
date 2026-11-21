import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/app_environment.dart';
import '../controller/user_controller.dart';
import '../models/contract_status_proof.dart';
import '../models/managed_account_provision_result.dart';
import '../models/admin_action_response.dart';
import '../models/membership.dart';
import '../models/user.dart';
import '../services/admin_content_service.dart';
import '../services/managed_account_service.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';
import '../utils/account_role_policy.dart';
import '../utils/admin_callable_action_catalog.dart';
import '../utils/admin_pagination.dart';
import '../utils/firebase_functions_error.dart';
import '../widgets/admin_account_status_chips.dart';
import '../widgets/admin_detail_panel.dart';
import '../widgets/admin_feedback.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_profile_review.dart';
import '../widgets/admin_table.dart';
import '../widgets/admin_ui.dart';
import '../widgets/managed_account_invite_result_dialog.dart';
import '../widgets/club_enrollment_dialog.dart';
import '../widgets/managed_membership_dialog.dart';
import '../widgets/managed_profile_edit_dialog.dart';

class UserManagementWidget extends StatefulWidget {
  const UserManagementWidget({
    required this.selectedRole,
    this.userController,
    this.managedAccountService,
    this.adminContentService,
    super.key,
  });

  final String selectedRole;
  final UserController? userController;
  final ManagedAccountService? managedAccountService;
  final AdminContentService? adminContentService;

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
  AdminContentService? _adminContentServiceInstance;

  AdminContentService get _adminContentService =>
      _adminContentServiceInstance ??=
          widget.adminContentService ??
          (AppEnvironmentConfig.visualQaMode
              ? AdminContentService.visualQa()
              : AdminContentService());
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

  /// Si ce compte peut porter une habilitation à déclarer des joueurs.
  ///
  /// Le rôle club et lui seul. Le droit ne vient jamais du rôle pour autant :
  /// un club sans habilitation ne déclare personne, et cette garde ne dit que
  /// devant quelles lignes la question se pose.
  bool _canManageClubEnrollment(AppUser user) {
    return _isMutableManagedAccount(user) &&
        normalizeUserRole(user.role) == 'club';
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
    Color confirmColor = AdminTheme.dangerText,
  }) {
    return confirmAdminDeletion(
      context: context,
      title: title,
      content: Text(message),
      confirmLabel: confirmLabel,
      confirmColor: confirmColor,
    );
  }

  Future<void> _runAccountAction({
    required AppUser user,
    required AdminCallableActionDescriptor action,
    required Future<dynamic> Function() request,
    required String successMessage,
  }) async {
    _setActionInFlight(user, action.label);

    try {
      final response = await request();
      if (!mounted) {
        return;
      }

      var message = successMessage;
      var tone = AdminBannerTone.success;
      if (response is AdminActionResponse) {
        if (response.message.trim().isNotEmpty) message = response.message;
        if (!response.success) {
          tone = AdminBannerTone.danger;
        } else if (response.data?['authDeleted'] == false ||
            response.data?['cascadePending'] == true) {
          tone = AdminBannerTone.info;
        }
      }
      showAdminFeedback(title: action.label, message: message, tone: tone);
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

    await _runAccountAction(
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
          'Cette action suspend immédiatement l’accès au compte ${user.email}. La session mobile sera fermée et les prochaines connexions seront refusées.',
      confirmLabel: 'Suspendre',
    );
    if (!confirmed) {
      return;
    }

    await _runAccountAction(
      user: user,
      action: disableManagedAccountAuthAction,
      request: () =>
          _managedAccountService.disableManagedAccountAuth(uid: user.uid),
      successMessage:
          'L’accès a été suspendu pour ${user.email}. Le compte ne pourra plus se reconnecter tant qu’il ne sera pas rétabli.',
    );
  }

  Future<void> _enableManagedAccountAuth(AppUser user) async {
    await _runAccountAction(
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
            'Le changement de rôle n’est proposé que pour les comptes administrés.',
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

    await _runAccountAction(
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
            'Le renvoi d’invitation n’est proposé que pour les comptes administrés.',
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
            'La modification du profil est réservée aux comptes administrés et exclut les comptes admin.',
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
      builder: (context) => ManagedProfileEditDialog(
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

    await _runAccountAction(
      user: user,
      action: updateManagedAccountProfileAction,
      request: () => _managedAccountService.updateManagedAccountProfile(
        uid: user.uid,
        patch: patch,
      ),
      successMessage: 'Le profil de ${user.nom} a été mis à jour.',
    );
  }

  bool _canRevokeContractProof(AppUser user) {
    return user.isPlayer &&
        !user.authDisabled &&
        user.contractStatusProof.isApproved &&
        user.contractStatusProof.hasFile;
  }

  Future<void> _revokeApprovedContractProof(AppUser user) async {
    final proof = user.contractStatusProof;
    if (!_canRevokeContractProof(user) || proof.fileUrl == null) {
      showAdminFeedback(
        title: 'Action indisponible',
        message:
            'Aucune pièce de statut contractuel approuvée à révoquer sur ce compte.',
        tone: AdminBannerTone.warning,
      );
      return;
    }

    final note = await showDialog<String?>(
      context: context,
      builder: (_) => _ContractProofRevokeReasonDialog(playerName: user.nom),
    );
    if (note == null || !mounted) {
      return;
    }

    await _runAccountAction(
      user: user,
      action: reviewContractStatusProofAction,
      request: () => _adminContentService.reviewContractStatusProof(
        uid: user.uid,
        expectedFileUrl: proof.fileUrl,
        expectedStatus: ContractStatusProof.statusApproved,
        expectedReviewRevision: proof.reviewRevision,
        status: ContractStatusProof.statusRejected,
        note: note,
      ),
      successMessage:
          'Le statut contractuel publié de ${user.nom} a été révoqué.',
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
          'La fiche sera masquée et les photos (y compris le passeport), CV et vidéos publiés seront supprimés.',
      confirmLabel: 'Retirer les autorisations',
    );
    if (!confirmed) return;
    await _runAccountAction(
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
            'La certification profil est réservée aux comptes administrés et exclut les comptes admin.',
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

    await _runAccountAction(
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
            'La certification profil est réservée aux comptes administrés et exclut les comptes admin.',
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

    await _runAccountAction(
      user: user,
      action: updateManagedAccountProfileAction,
      request: () => _managedAccountService.unverifyManagedAccountProfile(
        uid: user.uid,
        note: note,
      ),
      successMessage: 'La certification profil de ${user.nom} a été retirée.',
    );
  }

  /// Accorde ou retire l'habilitation à déclarer des joueurs.
  ///
  /// Deux appels distincts derrière un seul dialogue : accorder écrit un
  /// droit, retirer traite en plus tout ce que le club a déclaré pendant
  /// qu'il était habilité. Le backend refuse explicitement un retrait envoyé
  /// par le chemin d'octroi, pour qu'il n'existe qu'une porte de sortie.
  Future<void> _manageClubEnrollment(AppUser user) async {
    if (!_canManageClubEnrollment(user)) {
      showAdminFeedback(
        title: 'Action indisponible',
        message:
            'L’habilitation à déclarer des joueurs ne concerne que les comptes club suivis par l’administration.',
        tone: AdminBannerTone.warning,
      );
      return;
    }

    final decision = await showDialog<ClubEnrollmentDecision>(
      context: context,
      builder: (context) => ClubEnrollmentDialog(user: user),
    );

    if (decision == null) {
      return;
    }

    if (decision.revoke) {
      await _runAccountAction(
        user: user,
        action: revokeClubEnrollmentAction,
        request: () => _managedAccountService.revokeClubEnrollment(
          uid: user.uid,
          reason: decision.reason,
        ),
        successMessage:
            'L’habilitation de ${user.nom} a été retirée, et ses déclarations traitées.',
      );
      return;
    }

    await _runAccountAction(
      user: user,
      action: setClubEnrollmentRightAction,
      request: () => _managedAccountService.grantClubEnrollment(
        uid: user.uid,
        agreementRef: decision.agreementRef!,
        validUntil: decision.validUntil!,
      ),
      successMessage:
          '${user.nom} peut désormais déclarer ses joueurs, accord ${decision.agreementRef}.',
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

    final decision = await showDialog<MembershipDecision>(
      context: context,
      builder: (context) => ManagedMembershipDialog(user: user),
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

    await _runAccountAction(
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
          label: user.authDisabled
              ? (user.awaitsGuardianConsent
                    ? 'Enregistrez d’abord l’accord parental avant de réactiver l’accès'
                    : 'Réactiver l’accès')
              : 'Suspendre l’accès',
          color: user.authDisabled ? AdminTheme.success : AdminTheme.warning,
          onPressed: user.authDisabled && user.awaitsGuardianConsent
              ? null
              : () {
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
        if (_canManageClubEnrollment(user))
          AdminRowAction(
            icon: Icons.groups_outlined,
            label: user.clubEnrollmentRevocationPending
                ? 'Reprendre le retrait'
                : user.clubEnrollment.active
                ? 'Habilitation du club'
                : 'Habiliter le club',
            color: AdminTheme.cyan,
            onPressed: () => _manageClubEnrollment(user),
          ),
        if (_canRevokeContractProof(user))
          AdminRowAction(
            icon: Icons.gavel_rounded,
            label: 'Révoquer le statut contractuel',
            color: AdminTheme.warning,
            onPressed: () => _revokeApprovedContractProof(user),
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
      body = ProfileReviewContent(user: user);
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
        if (_canManageClubEnrollment(user))
          OutlinedButton(
            onPressed: busy ? null : () => _manageClubEnrollment(user),
            child: const Text('Habilitation'),
          ),
        if (_canRevokeContractProof(user))
          OutlinedButton(
            onPressed: busy ? null : () => _revokeApprovedContractProof(user),
            child: const Text('Révoquer le statut contractuel'),
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
      case _UserStatusFilter.awaitingGuardianConsent:
        return user.awaitsGuardianConsent;
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
      // Une fiche mineure sans accord parental est un état normal et
      // transitoire : un club peut déclarer un mineur avant que l'accord soit
      // recueilli, le compte existe et la fiche publique non. Normal ne veut
      // pas dire invisible — personne ne réclamera cet accord à la place de
      // l'enfant, et sans ce compteur la fiche attendait indéfiniment.
      final awaitingGuardianConsent = roleAndSearchMatches
          .where((user) => user.awaitsGuardianConsent)
          .length;

      final filteredUsers = roleAndSearchMatches
          .where(_matchesStatusFilter)
          .toList();

      final page = paginateAdminList(
        filtered: filteredUsers,
        currentPage: currentPage,
        rowsPerPage: rowsPerPage,
      );
      final totalPages = page.totalPages;
      final safePage = page.safePage;
      final startIndex = page.startIndex;
      final endIndex = page.endIndex;
      final displayedUsers = page.items;

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
          AdminStat(
            label: 'accord parental attendu',
            value: '$awaitingGuardianConsent',
            tone: awaitingGuardianConsent > 0 ? AdminTheme.cyan : null,
            selected:
                _statusFilter == _UserStatusFilter.awaitingGuardianConsent,
            onTap: () =>
                _toggleStatusFilter(_UserStatusFilter.awaitingGuardianConsent),
            tooltip:
                'Fiches mineures que la projection publique refuse de publier '
                'tant que l’accord d’un représentant légal n’est pas '
                'enregistré, par « Gérer le profil »',
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
          rowKey: (index) => ValueKey(displayedUsers[index].uid),
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
                searchLimited:
                    _userController.hasMoreUsers.value &&
                    searchQuery.trim().isNotEmpty,
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

/// Les cinq états sur lesquels la bande de synthèse peut restreindre la
/// liste.
enum _UserStatusFilter {
  managed,
  verified,
  needsReview,
  suspended,
  awaitingGuardianConsent,
}

class _ContractProofRevokeReasonDialog extends StatefulWidget {
  const _ContractProofRevokeReasonDialog({required this.playerName});

  final String playerName;

  @override
  State<_ContractProofRevokeReasonDialog> createState() =>
      _ContractProofRevokeReasonDialogState();
}

class _ContractProofRevokeReasonDialogState
    extends State<_ContractProofRevokeReasonDialog> {
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = _noteController.text.trim();
    final canSubmit =
        trimmed.isNotEmpty &&
        trimmed.length <= ContractStatusProof.maxReviewNoteLength;

    return AlertDialog(
      title: Text('Révoquer le statut contractuel - ${widget.playerName}'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'La fiche publique cessera d’afficher le statut contractuel '
              'approuvé. Cette révocation reste possible même si le fichier '
              'justificatif a déjà été purgé.',
              style: AdminType.caption.copyWith(color: AdminTheme.textSecondary),
            ),
            const SizedBox(height: AdminTheme.space3),
            TextField(
              controller: _noteController,
              maxLines: 3,
              maxLength: ContractStatusProof.maxReviewNoteLength,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Motif transmis au joueur',
                hintText: 'Contrat expiré, pièce invalidée…',
                border: const OutlineInputBorder(),
                errorText: trimmed.isEmpty
                    ? 'Un motif est requis pour révoquer une approbation.'
                    : null,
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
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.dangerText,
            foregroundColor: AdminTheme.background,
          ),
          onPressed: canSubmit ? () => Navigator.of(context).pop(trimmed) : null,
          icon: const Icon(Icons.gavel_rounded),
          label: const Text('Révoquer'),
        ),
      ],
    );
  }
}
