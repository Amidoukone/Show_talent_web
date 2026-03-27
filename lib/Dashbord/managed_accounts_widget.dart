import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controller/user_controller.dart';
import '../firebase_options.dart';
import '../models/managed_account_provision_result.dart';
import '../services/managed_account_service.dart';
import '../utils/admin_callable_action_catalog.dart';
import '../utils/account_role_policy.dart';

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

  @override
  void initState() {
    super.initState();
    _userController.refreshAdminClaims(forceRefresh: true);
  }

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
      Get.snackbar(
        'Session expiree',
        'Reconnectez-vous avant de provisionner un compte gere.',
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
            'Aucun custom claim admin/platformAdmin/superAdmin detecte. '
            'Le provisionnement est bloque cote client.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
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
        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
      });

      Get.snackbar(
        'Provisionnement termine',
        result.existingUser
            ? 'Le compte gere existant a ete mis a jour.'
            : 'Le compte gere a ete cree.',
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            error.message ?? 'La Cloud Function a refuse le provisionnement.';
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

  Future<void> _copyToClipboard(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }

    Get.snackbar('Lien copie', '$label copie dans le presse-papiers.');
  }

  Widget _buildInfoBanner({
    required Color backgroundColor,
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.black87),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTile(String label, String? value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (value == null)
            const Text('Aucun lien retourne.')
          else ...[
            SelectableText(value),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _copyToClipboard(label, value),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copier'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionInventoryCard({
    required String title,
    required List<AdminCallableActionDescriptor> actions,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
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
                              ? const Color(0xFFDFF3E4)
                              : const Color(0xFFFFF3CD),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          action.isConnectedInUi ? 'Branchee' : 'Backend pret',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(action.summary),
                  const SizedBox(height: 2),
                  Text(
                    'Surfaces UI: $surfaceList',
                    style: TextStyle(color: Colors.grey.shade700),
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
    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          width: MediaQuery.of(context).size.width * 0.95,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                spreadRadius: 2,
                blurRadius: 8,
              ),
            ],
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Provisionnement des comptes geres',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Projet Firebase partage : '
                '${DefaultFirebaseOptions.currentPlatform.projectId}. '
                'Seuls les roles club, recruteur et agent passent ici.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              Obx(() {
                if (_userController.hasRequiredAdminClaims) {
                  return _buildInfoBanner(
                    backgroundColor: const Color(0xFFDFF3E4),
                    icon: Icons.verified_user,
                    title: 'Claims admin valides',
                    message:
                        'Claims detectes : ${_userController.grantedAdminClaims.join(', ')}',
                  );
                }

                return _buildInfoBanner(
                  backgroundColor: const Color(0xFFFFF3CD),
                  icon: Icons.warning_amber_rounded,
                  title: 'Claims admin manquants',
                  message:
                      'Cette UI verifie admin/platformAdmin/superAdmin avant '
                      'd appeler provisionManagedAccount.',
                );
              }),
              const SizedBox(height: 16),
              _buildInfoBanner(
                backgroundColor: const Color(0xFFEAF4FF),
                icon: Icons.security,
                title: 'Contrat backend',
                message: 'La creation des comptes geres ne passe plus par Auth '
                    'ou Firestore directement depuis le client admin.',
              ),
              const SizedBox(height: 16),
              _buildActionInventoryCard(
                title: 'Actions deja branchees dans l UI',
                actions: connectedAdminCallableActions,
              ),
              const SizedBox(height: 16),
              _buildActionInventoryCard(
                title: 'Actions backend presentes mais UI encore a raccorder',
                actions: backendReadyButPendingUiActions,
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Nom complet',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le nom est obligatoire.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Adresse e-mail',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'L e-mail est obligatoire.';
                        }
                        if (!trimmed.contains('@')) {
                          return 'Saisissez un e-mail valide.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Telephone (optionnel)',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Role gere',
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF214D4F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
                            : 'Provisionner le compte gere',
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 20),
                _buildInfoBanner(
                  backgroundColor: const Color(0xFFF8D7DA),
                  icon: Icons.error_outline,
                  title: 'Provisionnement refuse',
                  message: _errorMessage!,
                ),
              ],
              if (_lastResult != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resultat du provisionnement',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('UID : ${_lastResult!.uid}'),
                      Text('E-mail : ${_lastResult!.email}'),
                      Text('Role : ${_lastResult!.role}'),
                      Text(
                        _lastResult!.existingUser
                            ? 'Etat : utilisateur existant mis a jour'
                            : 'Etat : nouveau compte gere cree',
                      ),
                      _buildLinkTile(
                        'Password setup link',
                        _lastResult!.passwordSetupLink,
                      ),
                      _buildLinkTile(
                        'Email verification link',
                        _lastResult!.emailVerificationLink,
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
