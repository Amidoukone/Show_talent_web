import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/user_controller.dart';
import '../models/managed_account_provision_result.dart';
import '../services/managed_account_service.dart';
import '../theme/admin_theme.dart';
import '../utils/account_role_policy.dart';
import '../utils/firebase_functions_error.dart';
import '../utils/player_age.dart';
import '../widgets/admin_feedback.dart';
import '../widgets/admin_ui.dart';
import '../widgets/managed_account_invite_result_dialog.dart';

class ManagedAccountsWidget extends StatefulWidget {
  const ManagedAccountsWidget({
    this.userController,
    this.managedAccountService,
    super.key,
  });

  final UserController? userController;
  final ManagedAccountService? managedAccountService;

  @override
  State<ManagedAccountsWidget> createState() => _ManagedAccountsWidgetState();
}

class _ManagedAccountsWidgetState extends State<ManagedAccountsWidget> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _guardianNameController = TextEditingController();
  final TextEditingController _guardianEvidenceController =
      TextEditingController();

  late final UserController _userController;
  late final ManagedAccountService _managedAccountService;
  String _selectedRole = adminProvisionedRoles.first;
  String _guardianRelationship = 'parent';
  String _guardianConsentMethod = 'oral_confirmation';
  DateTime? _birthDate;
  bool _guardianConsentReceived = false;
  bool _guardianMediaAllowed = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  ManagedAccountProvisionResult? _lastResult;
  String? _lastRecipientName;

  @override
  void initState() {
    super.initState();
    _userController = widget.userController ?? Get.find<UserController>();
    _managedAccountService =
        widget.managedAccountService ?? ManagedAccountService();
    _userController.refreshAdminClaims(forceRefresh: true);
  }

  bool _isCompactLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AdminTheme.breakpointCompact;

  bool get _isMinor {
    final date = _birthDate;
    return date != null && isMinorPlayer(date);
  }

  Future<void> _pickBirthDate() async {
    final latestEligibleDate = latestEligibleBirthDate();
    final currentBirthDate = _birthDate;
    final initialDate = currentBirthDate == null ||
            currentBirthDate.isAfter(latestEligibleDate)
        ? defaultBirthDatePickerDate()
        : currentBirthDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1930),
      lastDate: latestEligibleDate,
      helpText: 'Date de naissance du joueur',
    );
    if (picked != null && mounted) setState(() => _birthDate = picked);
  }

  Map<String, dynamic>? _guardianConsentPayload() {
    if (!_isMinor || !_guardianConsentReceived) return null;
    return <String, dynamic>{
      'guardianName': _guardianNameController.text.trim(),
      'relationship': _guardianRelationship,
      'method': _guardianConsentMethod,
      'evidenceReference': _guardianEvidenceController.text.trim(),
      'mediaAllowed': _guardianMediaAllowed,
      'confirmed': true,
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _guardianNameController.dispose();
    _guardianEvidenceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedRole == 'joueur' && _birthDate == null) {
      setState(() => _errorMessage =
          'La date de naissance est requise pour vérifier l’âge du joueur.');
      return;
    }
    if (_selectedRole == 'joueur' && isBelowMinimumPlayerAge(_birthDate!)) {
      setState(() => _errorMessage =
          'Adfoot accueille les joueurs à partir de 13 ans.');
      return;
    }
    if (_isMinor && _guardianConsentReceived &&
        _guardianNameController.text.trim().length < 2) {
      setState(() => _errorMessage =
          'Ajoutez le nom du parent ou tuteur dont l’accord a été recueilli.');
      return;
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      showAdminFeedback(
        title: 'Session expirée',
        message: 'Reconnectez-vous avant de provisionner un compte.',
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
            "Votre session ne dispose pas des droits nécessaires pour provisionner un compte.";
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
        birthDate: _birthDate,
        guardianConsent: _guardianConsentPayload(),
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
        _birthDate = null;
        _guardianNameController.clear();
        _guardianEvidenceController.clear();
        _guardianConsentMethod = 'oral_confirmation';
        _guardianConsentReceived = false;
        _guardianMediaAllowed = false;
      });

      showAdminFeedback(
        title: 'Provisionnement terminé',
        message: result.existingUser
            ? 'Le compte existant a été mis à jour.'
            : 'Le compte a été créé.',
        tone: AdminBannerTone.success,
      );

      await _showInviteResultDialog(result, recipientName: recipientName);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = describeFunctionsError(
          error,
          fallbackMessage: 'Le service sécurisé a refusé le provisionnement.',
        );
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
    required AdminBannerTone tone,
    required IconData icon,
    required String title,
    required String message,
  }) {
    return AdminInfoBanner(
      title: title,
      message: message,
      icon: icon,
      tone: tone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);
    final panelPadding = compact ? 16.0 : 20.0;
    final spacing = compact ? 12.0 : 18.0;

    return AdminGlassPanel(
      padding: EdgeInsets.all(panelPadding),
      highlight: true,
      accentColor: AdminTheme.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(() {
            if (_userController.isLoading.value) {
              return const AdminLoadingState(
                message: 'Chargement des comptes...',
              );
            }

            final managedAccounts = _userController.userList
                .where(
                  (user) =>
                      user.createdByAdmin || isManagedAccountRole(user.role),
                )
                .length;

            return Wrap(
              spacing: compact ? 10 : 12,
              runSpacing: compact ? 10 : 12,
              children: [
                AdminMiniStat(
                  label: 'Droits admin',
                  value: '${_userController.grantedAdminClaims.length}',
                  icon: Icons.verified_user_outlined,
                  accentColor: AdminTheme.cyan,
                  subtitle: _userController.hasRequiredAdminClaims
                      ? 'Session valide'
                      : 'À vérifier',
                  minWidth: compact ? 180 : 220,
                ),
                AdminMiniStat(
                  label: 'Comptes gérés',
                  value: '$managedAccounts',
                  icon: Icons.manage_accounts_outlined,
                  accentColor: AdminTheme.success,
                  subtitle: "Créés ou suivis par l'administration",
                  minWidth: compact ? 180 : 220,
                ),
                AdminMiniStat(
                  label: 'Rôles disponibles',
                  value: '${adminProvisionedRoles.length}',
                  icon: Icons.badge_outlined,
                  accentColor: AdminTheme.accent,
                  subtitle: 'Profils métier',
                  minWidth: compact ? 180 : 220,
                ),
              ],
            );
          }),
          SizedBox(height: spacing),
          Obx(() {
            if (_userController.hasRequiredAdminClaims) {
              return _buildInfoBanner(
                tone: AdminBannerTone.success,
                icon: Icons.verified_user,
                title: 'Droits administrateur vérifiés',
                message:
                    'Votre session peut provisionner et mettre à jour les comptes métier.',
              );
            }

            return _buildInfoBanner(
              tone: AdminBannerTone.warning,
              icon: Icons.warning_amber_rounded,
              title: 'Droits administrateur manquants',
              message:
                  'Reconnectez-vous avec un compte autorisé avant de provisionner.',
            );
          }),
          SizedBox(height: spacing),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1180 && !compact;

              final formSection = AdminSubsectionCard(
                title: 'Créer ou mettre à jour un compte',
                subtitle:
                    "Renseignez le titulaire, choisissez son rôle et transmettez les liens d'activation générés.",
                accentColor: AdminTheme.cyan,
                child: AdminFormColumn(
                  maxWidth: 560,
                  spacing: compact ? 12 : 16,
                  children: [
                    Form(
                      key: _formKey,
                      child: AdminFormColumn(
                        maxWidth: 560,
                        spacing: compact ? 12 : 16,
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
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Téléphone (optionnel)',
                              prefixIcon: Icon(Icons.call_outlined),
                            ),
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedRole,
                            decoration: const InputDecoration(
                              labelText: 'Rôle du compte',
                              prefixIcon: Icon(Icons.badge_outlined),
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

                              setState(() {
                                _selectedRole = value;
                              });
                            },
                          ),
                          if (_selectedRole == 'joueur') ...[
                            OutlinedButton.icon(
                              onPressed: _isSubmitting ? null : _pickBirthDate,
                              icon: const Icon(Icons.event_outlined),
                              label: Text(_birthDate == null
                                  ? 'Date de naissance requise'
                                  : 'Date de naissance : ${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}'),
                            ),
                            if (_isMinor) ...[
                              const Text(
                                'Le compte et son invitation peuvent être créés maintenant. Tant que l’accord du parent ou tuteur n’est pas enregistré, la fiche et les médias du mineur restent masqués.',
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _guardianConsentReceived,
                                title: const Text(
                                  'Accord du parent ou tuteur déjà recueilli (oralement ou par écrit)',
                                ),
                                onChanged: (value) => setState(() {
                                  _guardianConsentReceived = value ?? false;
                                  if (!_guardianConsentReceived) {
                                    _guardianMediaAllowed = false;
                                  }
                                }),
                              ),
                              if (_guardianConsentReceived) ...[
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
                                    DropdownMenuItem(value: 'parent', child: Text('Parent')),
                                    DropdownMenuItem(value: 'legal_guardian', child: Text('Tuteur légal')),
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
                                    labelText: 'Accord recueilli par',
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'oral_confirmation', child: Text('Échange oral / téléphone')),
                                    DropdownMenuItem(value: 'written_confirmation', child: Text('Écrit / document')),
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
                                  title: const Text('Le parent autorise la publication des photos, vidéos et CV sur la fiche ; les vidéos restent soumises à modération.'),
                                  onChanged: (value) => setState(
                                    () => _guardianMediaAllowed = value ?? false,
                                  ),
                                ),
                              ] else
                                const Text(
                                  'Vous pouvez créer le compte sans cette information et enregistrer l’accord plus tard depuis la gestion du compte.',
                                ),
                            ],
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
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
                                    : 'Provisionner le compte',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      _buildInfoBanner(
                        tone: AdminBannerTone.danger,
                        icon: Icons.error_outline,
                        title: 'Provisionnement refusé',
                        message: _errorMessage!,
                      ),
                    ],
                    if (_lastResult != null) ...[
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

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: wide ? 860 : constraints.maxWidth,
                  ),
                  child: formSection,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
