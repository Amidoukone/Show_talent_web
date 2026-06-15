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

const List<AdminCallableActionDescriptor> adminCallableActions = [
  provisionManagedAccountAction,
  deleteManagedAccountAction,
  changeManagedAccountRoleAction,
  resendManagedAccountInviteAction,
  disableManagedAccountAuthAction,
  enableManagedAccountAuthAction,
  updateManagedAccountProfileAction,
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
