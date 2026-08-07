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
  final List<String> uiSurfaces;
  final bool isAvailableInBackend;
  final bool isConnectedInUi;
}

const AdminCallableActionDescriptor provisionManagedAccountAction =
    AdminCallableActionDescriptor(
  id: 'provision_managed_account',
  label: 'Provisionner un compte',
  callableName: 'provisionManagedAccount',
  summary:
      "Création ou mise à jour d'un compte joueur, fan, club, recruteur ou agent.",
  uiSurfaces: ['Provisionnement des comptes'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor deleteManagedAccountAction =
    AdminCallableActionDescriptor(
  id: 'delete_managed_account',
  label: 'Supprimer un compte',
  callableName: 'deleteManagedAccount',
  summary: "Suppression traitée par le service sécurisé de l'administration.",
  uiSurfaces: ['Gestion des utilisateurs'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor changeManagedAccountRoleAction =
    AdminCallableActionDescriptor(
  id: 'change_managed_account_role',
  label: 'Changer le rôle',
  callableName: 'changeManagedAccountRole',
  summary: "Change le rôle d'un compte créé ou suivi par l'administration.",
  uiSurfaces: ['Gestion des utilisateurs'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor resendManagedAccountInviteAction =
    AdminCallableActionDescriptor(
  id: 'resend_managed_account_invite',
  label: "Renvoyer l'invitation",
  callableName: 'resendManagedAccountInvite',
  summary: "Régénérer ou renvoyer les liens d'onboarding d'un compte.",
  uiSurfaces: ['Gestion des utilisateurs'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor disableManagedAccountAuthAction =
    AdminCallableActionDescriptor(
  id: 'disable_managed_account_auth',
  label: 'Suspendre l’accès',
  callableName: 'disableManagedAccountAuth',
  summary: "Suspend l'accès au compte et bloque les prochaines connexions.",
  uiSurfaces: ['Gestion des utilisateurs'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor enableManagedAccountAuthAction =
    AdminCallableActionDescriptor(
  id: 'enable_managed_account_auth',
  label: 'Réactiver l’accès',
  callableName: 'enableManagedAccountAuth',
  summary: "Rétablit l'accès du compte aux prochaines connexions.",
  uiSurfaces: ['Gestion des utilisateurs'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor updateManagedAccountProfileAction =
    AdminCallableActionDescriptor(
  id: 'update_managed_account_profile',
  label: 'Gérer le profil',
  callableName: 'updateManagedAccountProfile',
  summary: "Met à jour les champs de confiance et la certification du profil.",
  uiSurfaces: ['Gestion des utilisateurs'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor setOfferStatusAction =
    AdminCallableActionDescriptor(
  id: 'admin_set_offer_status',
  label: "Changer le statut d'une offre",
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
  label: "Changer le statut d'un événement",
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
  summary: "Approuve, remet en attente ou republie une vidéo modérée.",
  uiSurfaces: ['VideoReviewWidget', 'VideoAddedWidget'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor rejectVideoAction =
    AdminCallableActionDescriptor(
  id: 'admin_reject_video',
  label: 'Rejeter une vidéo',
  callableName: 'adminRejectVideo',
  summary: "Rejette une vidéo signalée ou en revue, avec motif optionnel.",
  uiSurfaces: ['VideoReviewWidget', 'VideoReportedWidget'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor deleteVideoAction =
    AdminCallableActionDescriptor(
  id: 'admin_delete_video',
  label: 'Supprimer une vidéo',
  callableName: 'adminDeleteVideo',
  summary: "Supprime définitivement une vidéo et ses fichiers de stockage.",
  uiSurfaces: ['VideoReviewWidget', 'VideoReportedWidget', 'VideoAddedWidget'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor setContactIntakeFollowUpAction =
    AdminCallableActionDescriptor(
  id: 'admin_set_contact_intake_follow_up',
  label: 'Mettre à jour le suivi agence',
  callableName: 'adminSetContactIntakeFollowUp',
  summary: "Met à jour le statut de suivi agence d'une mise en relation.",
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

const AdminCallableActionDescriptor deleteContactIntakeConversationAction =
    AdminCallableActionDescriptor(
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
  setOfferStatusAction,
  deleteOfferAction,
  setEventStatusAction,
  deleteEventAction,
  setVideoStatusAction,
  rejectVideoAction,
  deleteVideoAction,
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
