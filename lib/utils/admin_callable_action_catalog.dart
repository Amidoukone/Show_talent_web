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
  label: 'Provisionner un compte géré',
  callableName: 'provisionManagedAccount',
  summary: 'Création ou mise à jour d’un compte club/recruteur/agent.',
  uiSurfaces: ['Comptes gérés'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor blockManagedAccountAction =
    AdminCallableActionDescriptor(
  id: 'block_managed_account',
  label: 'Suspendre ou bloquer un compte',
  callableName: 'blockManagedAccount',
  summary:
      'Suspend temporairement ou bloque durablement un compte sans écriture Firestore cross-user côté client.',
  uiSurfaces: ['Gestion des utilisateurs'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor unblockManagedAccountAction =
    AdminCallableActionDescriptor(
  id: 'unblock_managed_account',
  label: 'Débloquer un compte',
  callableName: 'unblockManagedAccount',
  summary: 'Retire seulement le blocage applicatif d’un compte géré.',
  uiSurfaces: ['Utilisateurs bloqués'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor deleteManagedAccountAction =
    AdminCallableActionDescriptor(
  id: 'delete_managed_account',
  label: 'Supprimer un compte',
  callableName: 'deleteManagedAccount',
  summary:
      'Suppression admin effectuée via backend partagé, sans mutation client de /users.',
  uiSurfaces: ['Gestion des utilisateurs', 'Utilisateurs bloqués'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor changeManagedAccountRoleAction =
    AdminCallableActionDescriptor(
  id: 'change_managed_account_role',
  label: 'Changer le rôle',
  callableName: 'changeManagedAccountRole',
  summary:
      'Change le rôle d’un compte géré via backend, sans modification client directe de /users.',
  uiSurfaces: ['Gestion des utilisateurs', 'Utilisateurs bloqués'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor resendManagedAccountInviteAction =
    AdminCallableActionDescriptor(
  id: 'resend_managed_account_invite',
  label: 'Renvoyer l’invitation',
  callableName: 'resendManagedAccountInvite',
  summary: 'Régénérer ou renvoyer les liens d’onboarding d’un compte géré.',
  uiSurfaces: ['Gestion des utilisateurs', 'Utilisateurs bloqués'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor disableManagedAccountAuthAction =
    AdminCallableActionDescriptor(
  id: 'disable_managed_account_auth',
  label: 'Désactiver Auth',
  callableName: 'disableManagedAccountAuth',
  summary:
      'Désactive seulement Firebase Auth sans changer le blocage applicatif.',
  uiSurfaces: ['Gestion des utilisateurs', 'Utilisateurs bloqués'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor enableManagedAccountAuthAction =
    AdminCallableActionDescriptor(
  id: 'enable_managed_account_auth',
  label: 'Réactiver Auth',
  callableName: 'enableManagedAccountAuth',
  summary:
      'Réactive seulement Firebase Auth sans modifier le blocage applicatif.',
  uiSurfaces: ['Gestion des utilisateurs', 'Utilisateurs bloqués'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor updateManagedAccountProfileAction =
    AdminCallableActionDescriptor(
  id: 'update_managed_account_profile',
  label: 'Mettre à jour le profil géré',
  callableName: 'updateManagedAccountProfile',
  summary:
      'Mise à jour admin de champs profil sensibles via Cloud Function dédiée.',
  uiSurfaces: ['UI à ajouter'],
  isAvailableInBackend: true,
  isConnectedInUi: false,
);

const List<AdminCallableActionDescriptor> adminCallableActions = [
  provisionManagedAccountAction,
  blockManagedAccountAction,
  unblockManagedAccountAction,
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
