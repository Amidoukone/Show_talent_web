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
  label: 'Provisionner un compte gere',
  callableName: 'provisionManagedAccount',
  summary: 'Creation ou mise a jour d un compte club/recruteur/agent.',
  uiSurfaces: ['Comptes geres'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor blockManagedAccountAction =
    AdminCallableActionDescriptor(
  id: 'block_managed_account',
  label: 'Bloquer un compte',
  callableName: 'blockManagedAccount',
  summary:
      'Bloque un compte gere sans ecriture Firestore cross-user cote client.',
  uiSurfaces: ['Gestion des utilisateurs'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor unblockManagedAccountAction =
    AdminCallableActionDescriptor(
  id: 'unblock_managed_account',
  label: 'Debloquer un compte',
  callableName: 'unblockManagedAccount',
  summary: 'Retire seulement le blocage applicatif d un compte gere.',
  uiSurfaces: ['Utilisateurs bloques'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor deleteManagedAccountAction =
    AdminCallableActionDescriptor(
  id: 'delete_managed_account',
  label: 'Supprimer un compte',
  callableName: 'deleteManagedAccount',
  summary:
      'Suppression admin effectuee via backend partage, sans mutation client de /users.',
  uiSurfaces: ['Gestion des utilisateurs', 'Utilisateurs bloques'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor changeManagedAccountRoleAction =
    AdminCallableActionDescriptor(
  id: 'change_managed_account_role',
  label: 'Changer le role',
  callableName: 'changeManagedAccountRole',
  summary:
      'Change le role d un compte gere via backend, sans modification client directe de /users.',
  uiSurfaces: ['Gestion des utilisateurs', 'Utilisateurs bloques'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor resendManagedAccountInviteAction =
    AdminCallableActionDescriptor(
  id: 'resend_managed_account_invite',
  label: 'Renvoyer l invitation',
  callableName: 'resendManagedAccountInvite',
  summary: 'Regenerer ou renvoyer les liens d onboarding d un compte gere.',
  uiSurfaces: ['Gestion des utilisateurs', 'Utilisateurs bloques'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor disableManagedAccountAuthAction =
    AdminCallableActionDescriptor(
  id: 'disable_managed_account_auth',
  label: 'Desactiver Auth',
  callableName: 'disableManagedAccountAuth',
  summary:
      'Desactive seulement Firebase Auth sans changer le blocage applicatif.',
  uiSurfaces: ['Gestion des utilisateurs', 'Utilisateurs bloques'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor enableManagedAccountAuthAction =
    AdminCallableActionDescriptor(
  id: 'enable_managed_account_auth',
  label: 'Reactiver Auth',
  callableName: 'enableManagedAccountAuth',
  summary:
      'Reactive seulement Firebase Auth sans modifier le blocage applicatif.',
  uiSurfaces: ['Gestion des utilisateurs', 'Utilisateurs bloques'],
  isAvailableInBackend: true,
  isConnectedInUi: true,
);

const AdminCallableActionDescriptor updateManagedAccountProfileAction =
    AdminCallableActionDescriptor(
  id: 'update_managed_account_profile',
  label: 'Mettre a jour le profil gere',
  callableName: 'updateManagedAccountProfile',
  summary:
      'Mise a jour admin de champs profil sensibles via Cloud Function dediee.',
  uiSurfaces: ['UI a ajouter'],
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
