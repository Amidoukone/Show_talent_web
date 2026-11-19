/// Une action d'administration, et l'endroit du portail qui l'appelle.
///
/// Cette liste n'est pas de la documentation : `contract:mobile` la compare au
/// dépôt mobile, et `admin_callable_catalog_test.dart` la compare à ce dépôt.
/// Une entrée fausse fait donc échouer la chaîne de livraison.
///
/// [uiSurfaces] porte des **noms de classes Dart existantes**, et non des
/// libellés. Trois entrées de la famille vidéo avaient dérivé — elles
/// nommaient des écrans qui n'appellent pas l'action — et rien ne pouvait le
/// signaler tant que ce champ restait du texte libre.
class AdminCallableActionDescriptor {
  const AdminCallableActionDescriptor({
    required this.id,
    required this.label,
    required this.callableName,
    required this.summary,
    required this.uiSurfaces,
    required this.isAvailableInBackend,
    required this.isConnectedInUi,
  });

  final String id;
  final String label;
  final String callableName;
  final String summary;

  /// Les écrans qui appellent cette action, par nom de classe.
  ///
  /// Vérifié : chaque nom doit être une classe déclarée sous `lib/dashboard`
  /// ou `lib/widgets`, et une action raccordée doit en nommer au moins une.
  final List<String> uiSurfaces;
  final bool isAvailableInBackend;
  final bool isConnectedInUi;
}

const AdminCallableActionDescriptor
provisionManagedAccountAction = AdminCallableActionDescriptor(
  id: 'provision_managed_account',
  label: 'Provisionner un compte',
  callableName: 'provisionManagedAccount',
  summary:
      "Création ou mise à jour d’un compte joueur, fan, club, recruteur ou agent.",
  uiSurfaces: ['ManagedAccountsWidget'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor deleteManagedAccountAction =
    AdminCallableActionDescriptor(
      id: 'delete_managed_account',
      label: 'Supprimer un compte',
      callableName: 'deleteManagedAccount',
      summary:
          "Suppression traitée par le service sécurisé de l’administration.",
      uiSurfaces: ['UserManagementWidget'],
      isAvailableInBackend: true,
      isConnectedInUi: true,
    );

const AdminCallableActionDescriptor changeManagedAccountRoleAction =
    AdminCallableActionDescriptor(
      id: 'change_managed_account_role',
      label: 'Changer le rôle',
      callableName: 'changeManagedAccountRole',
      summary: "Change le rôle d’un compte créé ou suivi par l’administration.",
      uiSurfaces: ['UserManagementWidget'],
      isAvailableInBackend: true,
      isConnectedInUi: true,
    );

const AdminCallableActionDescriptor resendManagedAccountInviteAction =
    AdminCallableActionDescriptor(
      id: 'resend_managed_account_invite',
      label: "Renvoyer l’invitation",
      callableName: 'resendManagedAccountInvite',
      summary: "Régénérer ou renvoyer les liens d’onboarding d’un compte.",
      uiSurfaces: ['UserManagementWidget'],
      isAvailableInBackend: true,
      isConnectedInUi: true,
    );

const AdminCallableActionDescriptor disableManagedAccountAuthAction =
    AdminCallableActionDescriptor(
      id: 'disable_managed_account_auth',
      label: 'Suspendre l’accès',
      callableName: 'disableManagedAccountAuth',
      summary: "Suspend l’accès au compte et bloque les prochaines connexions.",
      uiSurfaces: ['UserManagementWidget'],
      isAvailableInBackend: true,
      isConnectedInUi: true,
    );

const AdminCallableActionDescriptor enableManagedAccountAuthAction =
    AdminCallableActionDescriptor(
      id: 'enable_managed_account_auth',
      label: 'Réactiver l’accès',
      callableName: 'enableManagedAccountAuth',
      summary: "Rétablit l’accès du compte aux prochaines connexions.",
      uiSurfaces: ['UserManagementWidget'],
      isAvailableInBackend: true,
      isConnectedInUi: true,
    );

const AdminCallableActionDescriptor updateManagedAccountProfileAction =
    AdminCallableActionDescriptor(
      id: 'update_managed_account_profile',
      label: 'Gérer le profil',
      callableName: 'updateManagedAccountProfile',
      summary:
          "Met à jour les champs de confiance et la certification du profil.",
      uiSurfaces: ['UserManagementWidget'],
      isAvailableInBackend: true,
      isConnectedInUi: true,
    );

const AdminCallableActionDescriptor
withdrawManagedMinorConsentAction = AdminCallableActionDescriptor(
  id: 'withdraw_managed_minor_consent',
  label: 'Retirer les autorisations parentales',
  callableName: 'withdrawManagedMinorConsent',
  summary:
      'Masque la fiche mineure et purge les médias publiés après une demande parentale vérifiée.',
  uiSurfaces: ['UserManagementWidget'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor
setManagedAccountMembershipAction = AdminCallableActionDescriptor(
  id: 'set_managed_account_membership',
  label: 'Gérer les droits',
  callableName: 'setManagedAccountMembership',
  summary:
      "Enregistre ou retire les droits d’un compte suivi par l’agence, sans aucun montant.",
  uiSurfaces: ['UserManagementWidget'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor
setClubEnrollmentRightAction = AdminCallableActionDescriptor(
  id: 'set_club_enrollment_right',
  label: 'Habiliter un club',
  callableName: 'setClubEnrollmentRight',
  summary:
      "Autorise un club à déclarer ses joueurs, contre un accord signé et pour une durée. Distinct de l’abonnement : l’enrôlement ne s’achète pas.",
  uiSurfaces: ['UserManagementWidget'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor
revokeClubEnrollmentAction = AdminCallableActionDescriptor(
  id: 'revoke_club_enrollment',
  label: 'Retirer l’habilitation',
  callableName: 'revokeClubEnrollment',
  summary:
      "Retire l’habilitation d’un club et traite ce qu’il a déjà déclaré : déclarations non confirmées annulées, affiliations confirmées signalées pour réexamen.",
  uiSurfaces: ['UserManagementWidget'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor setOfferStatusAction =
    AdminCallableActionDescriptor(
      id: 'admin_set_offer_status',
      label: "Changer le statut d’une offre",
      callableName: 'adminSetOfferStatus',
      summary: "Publie, suspend ou archive une offre.",
      uiSurfaces: ['OfferManagementWidget'],
      isAvailableInBackend: true,
      isConnectedInUi: true,
    );

const AdminCallableActionDescriptor deleteOfferAction =
    AdminCallableActionDescriptor(
      id: 'admin_delete_offer',
      label: 'Supprimer une offre',
      callableName: 'adminDeleteOffer',
      summary: "Supprime définitivement une offre.",
      uiSurfaces: ['OfferManagementWidget'],
      isAvailableInBackend: true,
      isConnectedInUi: true,
    );

const AdminCallableActionDescriptor setEventStatusAction =
    AdminCallableActionDescriptor(
      id: 'admin_set_event_status',
      label: "Changer le statut d’un événement",
      callableName: 'adminSetEventStatus',
      summary: "Publie, suspend ou archive un événement.",
      uiSurfaces: ['EventManagementWidget'],
      isAvailableInBackend: true,
      isConnectedInUi: true,
    );

const AdminCallableActionDescriptor deleteEventAction =
    AdminCallableActionDescriptor(
      id: 'admin_delete_event',
      label: 'Supprimer un événement',
      callableName: 'adminDeleteEvent',
      summary: "Supprime définitivement un événement.",
      uiSurfaces: ['EventManagementWidget'],
      isAvailableInBackend: true,
      isConnectedInUi: true,
    );

const AdminCallableActionDescriptor setVideoStatusAction =
    AdminCallableActionDescriptor(
      id: 'admin_set_video_status',
      label: 'Changer le statut d’une vidéo',
      callableName: 'adminSetVideoStatus',
      summary: "Approuve une vidéo en attente de validation.",
      // « Vidéos ajoutées » ne propose aucune approbation : l'écran ne sait
      // que lire et supprimer. L'entrée la nommait depuis le début.
      uiSurfaces: ['VideoReviewWidget'],
      isAvailableInBackend: true,
      isConnectedInUi: true,
    );

const AdminCallableActionDescriptor rejectVideoAction =
    AdminCallableActionDescriptor(
      id: 'admin_reject_video',
      label: 'Rejeter une vidéo',
      callableName: 'adminRejectVideo',
      summary: "Rejette une vidéo en revue, motif obligatoire.",
      // « Vidéos signalées » ne rejette pas, elle supprime : le motif n'y est
      // donc pas transmis au joueur, contrairement à ce que cette entrée
      // laissait croire.
      uiSurfaces: ['VideoReviewWidget'],
      isAvailableInBackend: true,
      isConnectedInUi: true,
    );

const AdminCallableActionDescriptor deleteVideoAction =
    AdminCallableActionDescriptor(
      id: 'admin_delete_video',
      label: 'Supprimer une vidéo',
      callableName: 'adminDeleteVideo',
      summary: "Supprime définitivement une vidéo et ses fichiers de stockage.",
      // Pas « Vidéos à valider » : cet écran approuve ou refuse, et un refus
      // passe par `adminRejectVideo`, qui notifie le joueur. Supprimer sans
      // motif n'y est pas proposé, et c'est voulu.
      uiSurfaces: ['VideoAddedWidget', 'VideoReportedWidget'],
      isAvailableInBackend: true,
      isConnectedInUi: true,
    );

const AdminCallableActionDescriptor
reviewContractStatusProofAction = AdminCallableActionDescriptor(
  id: 'review_contract_status_proof',
  label: "Examiner une pièce de statut contractuel",
  callableName: 'reviewContractStatusProof',
  summary:
      "Approuve ou écarte la pièce déposée par un joueur. Une approbation dit quel statut la pièce justifie : la fiche publique n’affiche ce statut que si le joueur déclare exactement le même.",
  uiSurfaces: ['ContractProofReviewWidget'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor
endClubLinkAction = AdminCallableActionDescriptor(
  id: 'end_club_link',
  label: 'Clore un rattachement',
  callableName: 'endClubLink',
  summary:
      "Clôt un rattachement joueur-club et retire le club courant de la fiche du joueur. Seule issue d’arbitrage : aucun callable ne permet de confirmer à la place du joueur.",
  uiSurfaces: ['ClubLinkExceptionsWidget'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor setContactIntakeFollowUpAction =
    AdminCallableActionDescriptor(
      id: 'admin_set_contact_intake_follow_up',
      label: 'Mettre à jour le suivi agence',
      callableName: 'adminSetContactIntakeFollowUp',
      summary: "Met à jour le statut de suivi agence d’une mise en relation.",
      uiSurfaces: ['ContactIntakeManagementWidget'],
      isAvailableInBackend: true,
      isConnectedInUi: true,
    );

const AdminCallableActionDescriptor deleteContactIntakeAction =
    AdminCallableActionDescriptor(
      id: 'admin_delete_contact_intake',
      label: 'Supprimer une mise en relation',
      callableName: 'adminDeleteContactIntake',
      summary: "Supprime définitivement une demande de mise en relation.",
      uiSurfaces: ['ContactIntakeManagementWidget'],
      isAvailableInBackend: true,
      isConnectedInUi: true,
    );

const AdminCallableActionDescriptor
deleteContactIntakeConversationAction = AdminCallableActionDescriptor(
  id: 'admin_delete_contact_intake_conversation',
  label: 'Supprimer la conversation associée',
  callableName: 'adminDeleteContactIntakeConversation',
  summary:
      "Supprime la conversation liée à une mise en relation, sans supprimer la demande.",
  uiSurfaces: ['ContactIntakeManagementWidget'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const List<AdminCallableActionDescriptor> adminCallableActions = [
  provisionManagedAccountAction,
  deleteManagedAccountAction,
  changeManagedAccountRoleAction,
  resendManagedAccountInviteAction,
  disableManagedAccountAuthAction,
  enableManagedAccountAuthAction,
  updateManagedAccountProfileAction,
  withdrawManagedMinorConsentAction,
  setManagedAccountMembershipAction,
  setClubEnrollmentRightAction,
  revokeClubEnrollmentAction,
  setOfferStatusAction,
  deleteOfferAction,
  setEventStatusAction,
  deleteEventAction,
  setVideoStatusAction,
  rejectVideoAction,
  deleteVideoAction,
  reviewContractStatusProofAction,
  endClubLinkAction,
  setContactIntakeFollowUpAction,
  deleteContactIntakeAction,
  deleteContactIntakeConversationAction,
];

List<AdminCallableActionDescriptor> get connectedAdminCallableActions {
  return adminCallableActions
      .where((action) => action.isConnectedInUi)
      .toList(growable: false);
}

List<AdminCallableActionDescriptor> get backendReadyButPendingUiActions {
  return adminCallableActions
      .where((action) => action.isAvailableInBackend && !action.isConnectedInUi)
      .toList(growable: false);
}
