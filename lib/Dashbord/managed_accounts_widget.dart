import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/user_controller.dart';
import '../firebase_options.dart';
import '../models/managed_account_provision_result.dart';
import '../services/managed_account_service.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_callable_action_catalog.dart';
import '../utils/account_role_policy.dart';
import '../widgets/admin_feedback.dart';
import '../widgets/admin_ui.dart';
import '../widgets/managed_account_invite_result_dialog.dart';

class ManagedAccountsWidget extends StatefulWidget {
  const ManagedAccountsWidget({super.key});

  @override
  State<ManagedAccountsWidget> createState() => _ManagedAccountsWidgetState();
}

class _ManagedAccountsWidgetState extends State<ManagedAccountsWidget> {
  final UserController _userController = Get.find<UserController>();
  final ManagedAccountService _managedAccountService = ManagedAccountService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _selectedRole = managedAccountRoles.first;
  bool _isSubmitting = false;
  String? _errorMessage;
  ManagedAccountProvisionResult? _lastResult;
  String? _lastRecipientName;

  @override
  void initState() {
    super.initState();
    _userController.refreshAdminClaims(forceRefresh: true);
  }

  bool _isCompactLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 1120;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      showAdminFeedback(
        title: 'Session expirée',
        message: 'Reconnectez-vous avant de provisionner un compte géré.',
        tone: AdminBannerTone.warning,
      );
      return;
    }

    final grantedClaims = await _userController.refreshAdminClaims(
      firebaseUser: firebaseUser,
      forceRefresh: true,
    );
    if (grantedClaims.isEmpty) {
      setState(() {
        _errorMessage =
            'Aucun custom claim admin/platformAdmin/superAdmin détecté. '
            'Le provisionnement est bloqué côté client.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final recipientName = _nameController.text.trim();
      final result = await _managedAccountService.provisionManagedAccount(
        email: _emailController.text,
        nom: _nameController.text,
        role: _selectedRole,
        phone: _phoneController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastResult = result;
        _lastRecipientName = recipientName;
        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
      });

      showAdminFeedback(
        title: 'Provisionnement terminé',
        message: result.existingUser
            ? 'Le compte géré existant a été mis à jour.'
            : 'Le compte géré a été créé.',
        tone: AdminBannerTone.success,
      );

      await _showInviteResultDialog(
        result,
        recipientName: recipientName,
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            error.message ?? 'La Cloud Function a refusé le provisionnement.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Provisionnement impossible : $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _showInviteResultDialog(
    ManagedAccountProvisionResult result, {
    String? recipientName,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return ManagedAccountInviteResultDialog(
          result: result,
          recipientName: recipientName,
          title: 'Liens et consignes à transmettre',
          subtitle:
              'Le message ci-dessous est déjà ordonné pour le titulaire. Copiez-le tel quel ou réutilisez les liens individuellement.',
        );
      },
    );
  }

  Widget _buildInfoBanner({
    required Color backgroundColor,
    required IconData icon,
    required String title,
    required String message,
  }) {
    final tone = backgroundColor == const Color(0xFFDFF3E4)
        ? AdminBannerTone.success
        : backgroundColor == const Color(0xFFFFF3CD)
            ? AdminBannerTone.warning
            : backgroundColor == const Color(0xFFF8D7DA)
                ? AdminBannerTone.danger
                : AdminBannerTone.info;

    return AdminInfoBanner(
      title: title,
      message: message,
      icon: icon,
      tone: tone,
    );
  }

  Widget _buildActionInventoryCard({
    required String title,
    required List<AdminCallableActionDescriptor> actions,
  }) {
    return AdminGlassPanel(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AdminTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...actions.map((action) {
            final surfaceList = action.uiSurfaces.join(', ');
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '${action.label} (${action.callableName})',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: action.isConnectedInUi
                              ? AdminTheme.success.withValues(alpha: 0.14)
                              : AdminTheme.warning.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: action.isConnectedInUi
                                ? AdminTheme.success.withValues(alpha: 0.18)
                                : AdminTheme.warning.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          action.isConnectedInUi ? 'Branchée' : 'Backend prêt',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: action.isConnectedInUi
                                ? AdminTheme.success
                                : AdminTheme.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    action.summary,
                    style: const TextStyle(color: AdminTheme.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Surfaces UI: $surfaceList',
                    style: const TextStyle(color: AdminTheme.textMuted),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);
    final panelPadding = compact ? 16.0 : 22.0;
    final spacing = compact ? 12.0 : 16.0;

    return AdminGlassPanel(
      padding: EdgeInsets.all(panelPadding),
      highlight: true,
      accentColor: AdminTheme.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminSectionHeader(
            badge: 'Provisionnement',
            title: 'Provisionnement des comptes gérés',
            subtitle:
                "Création, mise à jour et restitution des liens d'activation via le backend partagé.",
          ),
          SizedBox(height: compact ? 10 : 12),
          Text(
            'Projet Firebase partagé : '
            '${DefaultFirebaseOptions.currentPlatform.projectId}. '
            'Seuls les rôles club, recruteur et agent passent ici.',
            style: const TextStyle(color: AdminTheme.textSecondary),
          ),
          SizedBox(height: spacing),
          Obx(() {
            return Wrap(
              spacing: compact ? 10 : 12,
              runSpacing: compact ? 10 : 12,
              children: [
                AdminMiniStat(
                  label: 'Claims admin',
                  value: '${_userController.grantedAdminClaims.length}',
                  icon: Icons.verified_user_outlined,
                  accentColor: AdminTheme.cyan,
                  subtitle: _userController.hasRequiredAdminClaims
                      ? 'Session valide'
                      : 'À vérifier',
                  minWidth: compact ? 180 : 220,
                ),
                AdminMiniStat(
                  label: 'Actions branchées',
                  value: '${connectedAdminCallableActions.length}',
                  icon: Icons.hub_outlined,
                  accentColor: AdminTheme.accent,
                  subtitle: 'Disponibles dans cette vue',
                  minWidth: compact ? 180 : 220,
                ),
                AdminMiniStat(
                  label: 'Actions en attente',
                  value: '${backendReadyButPendingUiActions.length}',
                  icon: Icons.extension_outlined,
                  accentColor: AdminTheme.warning,
                  subtitle: 'Backend déjà prêt',
                  minWidth: compact ? 180 : 220,
                ),
              ],
            );
          }),
          SizedBox(height: spacing),
          Obx(() {
            if (_userController.hasRequiredAdminClaims) {
              return _buildInfoBanner(
                backgroundColor: const Color(0xFFDFF3E4),
                icon: Icons.verified_user,
                title: 'Claims admin valides',
                message:
                    'Claims détectés : ${_userController.grantedAdminClaims.join(', ')}',
              );
            }

            return _buildInfoBanner(
              backgroundColor: const Color(0xFFFFF3CD),
              icon: Icons.warning_amber_rounded,
              title: 'Claims admin manquants',
              message: 'Cette UI vérifie admin/platformAdmin/superAdmin avant '
                  'd appeler provisionManagedAccount.',
            );
          }),
          SizedBox(height: spacing),
          _buildInfoBanner(
            backgroundColor: const Color(0xFFEAF4FF),
            icon: Icons.security,
            title: 'Contrat backend',
            message: 'La création des comptes gérés ne passe plus par Auth '
                'ou Firestore directement depuis le client admin.',
          ),
          SizedBox(height: spacing),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1180 && !compact;

              final inventorySection = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildActionInventoryCard(
                    title: 'Actions déjà branchées dans l’UI',
                    actions: connectedAdminCallableActions,
                  ),
                  SizedBox(height: spacing),
                  _buildActionInventoryCard(
                    title:
                        'Actions backend présentes mais UI encore à raccorder',
                    actions: backendReadyButPendingUiActions,
                  ),
                ],
              );

              final formSection = AdminSubsectionCard(
                title: 'Créer ou mettre à jour un compte',
                subtitle:
                    'Le formulaire client appelle provisionManagedAccount et restitue ensuite les liens retournés par le backend partagé.',
                accentColor: AdminTheme.cyan,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Nom complet',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Le nom est obligatoire.';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: compact ? 12 : 16),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Adresse e-mail',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                            validator: (value) {
                              final trimmed = value?.trim() ?? '';
                              if (trimmed.isEmpty) {
                                return 'L’e-mail est obligatoire.';
                              }
                              if (!trimmed.contains('@')) {
                                return 'Saisissez un e-mail valide.';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: compact ? 12 : 16),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Téléphone (optionnel)',
                              prefixIcon: Icon(Icons.call_outlined),
                            ),
                          ),
                          SizedBox(height: compact ? 12 : 16),
                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            decoration: const InputDecoration(
                              labelText: 'Rôle géré',
                              prefixIcon: Icon(Icons.badge_outlined),
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

                              setState(() {
                                _selectedRole = value;
                              });
                            },
                          ),
                          SizedBox(height: compact ? 16 : 20),
                          ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submit,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.person_add_alt_1),
                            label: Text(
                              _isSubmitting
                                  ? 'Provisionnement en cours...'
                                  : 'Provisionner le compte géré',
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      SizedBox(height: compact ? 14 : 20),
                      _buildInfoBanner(
                        backgroundColor: const Color(0xFFF8D7DA),
                        icon: Icons.error_outline,
                        title: 'Provisionnement refusé',
                        message: _errorMessage!,
                      ),
                    ],
                    if (_lastResult != null) ...[
                      SizedBox(height: compact ? 14 : 20),
                      AdminSubsectionCard(
                        title: 'Résultat du provisionnement',
                        subtitle:
                            'Le message prêt à envoyer et les liens individuels restent disponibles dans cette section.',
                        accentColor: AdminTheme.accent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ManagedAccountInviteSummary(
                              result: _lastResult!,
                              recipientName: _lastRecipientName,
                              copyPosition: SnackPosition.BOTTOM,
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _lastResult = null;
                                    _lastRecipientName = null;
                                    _errorMessage = null;
                                  });
                                },
                                icon: const Icon(Icons.restart_alt_rounded),
                                label: const Text('Nouvelle opération'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: formSection),
                    SizedBox(width: spacing),
                    Expanded(flex: 5, child: inventorySection),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  inventorySection,
                  SizedBox(height: spacing),
                  formSection,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
