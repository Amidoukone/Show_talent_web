import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/user_controller.dart';
import '../models/managed_account_provision_result.dart';
import '../services/managed_account_service.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';
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
    final initialDate =
        currentBirthDate == null || currentBirthDate.isAfter(latestEligibleDate)
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
      setState(
        () => _errorMessage =
            'La date de naissance est requise pour vérifier l’âge du joueur.',
      );
      return;
    }
    if (_selectedRole == 'joueur' && isBelowMinimumPlayerAge(_birthDate!)) {
      setState(
        () =>
            _errorMessage = 'Adfoot accueille les joueurs à partir de 13 ans.',
      );
      return;
    }
    if (_isMinor &&
        _guardianConsentReceived &&
        _guardianNameController.text.trim().length < 2) {
      setState(
        () => _errorMessage =
            'Ajoutez le nom du parent ou tuteur dont l’accord a été recueilli.',
      );
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

  Widget _buildTitulaireFields() {
    return AdminFormColumn(
      maxWidth: 560,
      children: [
        TextFormField(
          controller: _nameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Nom complet',
            prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
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
            prefixIcon: Icon(Icons.mail_outline_rounded, size: 18),
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
            prefixIcon: Icon(Icons.call_outlined, size: 18),
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: _selectedRole,
          decoration: const InputDecoration(
            labelText: 'Rôle du compte',
            prefixIcon: Icon(Icons.badge_outlined, size: 18),
          ),
          items: adminProvisionedRoles
              .map(
                (role) =>
                    DropdownMenuItem<String>(value: role, child: Text(role)),
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
      ],
    );
  }

  /// Bloc « accord parental », affiché seulement pour un joueur mineur.
  ///
  /// Il reste replié tant que la date de naissance n'est pas saisie : six
  /// champs de consentement affichés à un administrateur qui crée un
  /// compte de club, c'est du bruit, et cela noyait la seule chose à
  /// faire — remplir le nom et l'e-mail.
  List<Widget> _buildGuardianFields() {
    if (_selectedRole != 'joueur' || !_isMinor) {
      return const <Widget>[];
    }

    return [
      const SizedBox(height: AdminTheme.space4),
      AdminInfoBanner(
        title: 'Joueur mineur',
        message:
            'Le compte et son invitation peuvent être créés maintenant. Tant '
            'que l’accord du parent ou tuteur n’est pas enregistré, la fiche '
            'et les médias du mineur restent masqués.',
        icon: Icons.shield_outlined,
        tone: AdminBannerTone.warning,
      ),
      const SizedBox(height: AdminTheme.space3),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        value: _guardianConsentReceived,
        title: const Text(
          'Accord du parent ou tuteur déjà recueilli (oralement ou par écrit)',
          style: AdminType.body,
        ),
        onChanged: (value) => setState(() {
          _guardianConsentReceived = value ?? false;
          if (!_guardianConsentReceived) {
            _guardianMediaAllowed = false;
          }
        }),
      ),
      if (!_guardianConsentReceived)
        const Text(
          'Vous pouvez créer le compte sans cette information et enregistrer '
          'l’accord plus tard depuis la gestion du compte.',
          style: AdminType.caption,
        )
      else ...[
        const SizedBox(height: AdminTheme.space3),
        AdminFormColumn(
          maxWidth: 560,
          children: [
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
                labelText: 'Accord recueilli par',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'oral_confirmation',
                  child: Text('Échange oral / téléphone'),
                ),
                DropdownMenuItem(
                  value: 'written_confirmation',
                  child: Text('Écrit / document'),
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
          ],
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _guardianMediaAllowed,
          title: const Text(
            'Le parent autorise la publication des photos, vidéos et CV sur '
            'la fiche ; les vidéos restent soumises à modération.',
            style: AdminType.body,
          ),
          onChanged: (value) =>
              setState(() => _guardianMediaAllowed = value ?? false),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);

    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Le bandeau vert « droits vérifiés » a disparu : un message
              // permanent qui confirme que tout va bien n'est plus lu au
              // bout de deux jours, et il masquait le seul cas qui compte.
              Obx(() {
                if (_userController.hasRequiredAdminClaims) {
                  return const SizedBox.shrink();
                }

                return const Padding(
                  padding: EdgeInsets.only(bottom: AdminTheme.space4),
                  child: AdminInfoBanner(
                    title: 'Droits administrateur manquants',
                    message:
                        'Reconnectez-vous avec un compte autorisé avant de '
                        'provisionner.',
                    icon: Icons.warning_amber_rounded,
                    tone: AdminBannerTone.danger,
                  ),
                );
              }),
              AdminPanel(
                padding: EdgeInsets.all(
                  compact ? AdminTheme.space4 : AdminTheme.space5,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AdminSectionHeader(
                      title: 'Créer ou mettre à jour un compte',
                      subtitle:
                          'Renseignez le titulaire, choisissez son rôle, puis '
                          'transmettez les liens d’activation générés.',
                    ),
                    const SizedBox(height: AdminTheme.space5),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTitulaireFields(),
                          if (_selectedRole == 'joueur') ...[
                            const SizedBox(height: AdminTheme.space3),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : _pickBirthDate,
                                icon: const Icon(
                                  Icons.event_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  _birthDate == null
                                      ? 'Date de naissance requise'
                                      : 'Né le ${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}',
                                ),
                              ),
                            ),
                          ],
                          ..._buildGuardianFields(),
                          const SizedBox(height: AdminTheme.space5),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton.icon(
                              onPressed: _isSubmitting ? null : _submit,
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AdminTheme.background,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_add_alt_1,
                                      size: 16,
                                    ),
                              label: Text(
                                _isSubmitting
                                    ? 'Provisionnement en cours…'
                                    : 'Provisionner le compte',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: AdminTheme.space4),
                      AdminInfoBanner(
                        title: 'Provisionnement refusé',
                        message: _errorMessage!,
                        icon: Icons.error_outline,
                        tone: AdminBannerTone.danger,
                      ),
                    ],
                  ],
                ),
              ),
              if (_lastResult != null) ...[
                const SizedBox(height: AdminTheme.space3),
                AdminPanel(
                  padding: EdgeInsets.all(
                    compact ? AdminTheme.space4 : AdminTheme.space5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AdminSectionHeader(
                        title: 'Liens à transmettre',
                        subtitle:
                            'Le message est déjà ordonné pour le titulaire. '
                            'Copiez-le tel quel ou réutilisez les liens un '
                            'par un.',
                        trailing: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _lastResult = null;
                              _lastRecipientName = null;
                              _errorMessage = null;
                            });
                          },
                          icon: const Icon(Icons.restart_alt_rounded, size: 16),
                          label: const Text('Nouvelle opération'),
                        ),
                      ),
                      const SizedBox(height: AdminTheme.space4),
                      ManagedAccountInviteSummary(
                        result: _lastResult!,
                        recipientName: _lastRecipientName,
                        copyPosition: SnackPosition.BOTTOM,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
