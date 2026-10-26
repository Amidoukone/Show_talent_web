import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/app_routes.dart';
import '../controller/auth_controller.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_ui.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthController _authController = Get.find<AuthController>();

  bool _obscurePassword = true;
  bool _isSubmitting = false;

  static const Duration _loginTimeout = Duration(seconds: 20);

  String _firebaseErrorMessage(FirebaseAuthException error) {
    final normalized = '${error.code} ${error.message ?? ''}'.toLowerCase();
    if (normalized.contains('403') ||
        normalized.contains('web-internal-error') ||
        normalized.contains('identity toolkit') ||
        normalized.contains('api key')) {
      return "Le service d’authentification refuse la requ\u00eate. V\u00e9rifiez que votre acc\u00e8s administrateur est actif avant de r\u00e9essayer.";
    }

    return error.message ?? "Erreur d’authentification : ${error.code}";
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginAdmin() async {
    if (_isSubmitting) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      Get.snackbar(
        'Connexion impossible',
        'Saisissez votre e-mail et mot de passe.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final accessResult = await _authController
          .loginAdmin(email: email, password: password)
          .timeout(_loginTimeout);

      if (!accessResult.isAuthorized) {
        Get.snackbar(
          'Acc\u00e8s refus\u00e9',
          accessResult.message ?? 'Acc\u00e8s refus\u00e9.',
        );
        return;
      }

      Get.offAllNamed(AppRoutes.adminDashboard);
    } on FirebaseAuthException catch (error) {
      Get.snackbar('Connexion impossible', _firebaseErrorMessage(error));
    } on TimeoutException {
      Get.snackbar(
        'Connexion impossible',
        'Le service d\u2019authentification ne r\u00e9pond pas. V\u00e9rifiez votre connexion puis r\u00e9essayez.',
      );
    } catch (error) {
      debugPrint('Connexion admin \u00e9chou\u00e9e : $error');
      Get.snackbar(
        'Connexion impossible',
        'Une erreur inattendue est survenue. R\u00e9essayez.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final compactViewport = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      body: SafeArea(
        child: AdminAppBackground(
          padding: EdgeInsets.all(compactViewport ? 16 : 24),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _LoginFormPanel(
                emailController: _emailController,
                passwordController: _passwordController,
                obscurePassword: _obscurePassword,
                isSubmitting: _isSubmitting,
                onToggleObscurePassword: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                onSubmit: _loginAdmin,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginFormPanel extends StatelessWidget {
  const _LoginFormPanel({
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isSubmitting,
    required this.onToggleObscurePassword,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isSubmitting;
  final VoidCallback onToggleObscurePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final compact = viewportWidth < 600;

    return AdminPanel(
      width: compact ? viewportWidth - 32 : 420,
      padding: EdgeInsets.all(compact ? AdminTheme.space5 : AdminTheme.space6),
      child: AdminFormColumn(
        maxWidth: 420,
        spacing: AdminTheme.space4,
        children: [
          // Le logo complet, comme sur l'écran de connexion du mobile et
          // dans l'en-tête du site public. C'est la seule surface du
          // portail où le mot-marque n'est écrit nulle part ailleurs.
          const Align(
            alignment: Alignment.centerLeft,
            child: AdminBrandLockup(height: 64),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Connexion admin',
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !isSubmitting,
            decoration: const InputDecoration(
              labelText: 'Adresse e-mail',
              prefixIcon: Icon(Icons.mail_outline_rounded, size: 18),
            ),
          ),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            enabled: !isSubmitting,
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                ),
                onPressed: onToggleObscurePassword,
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSubmitting ? null : onSubmit,
              icon: isSubmitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AdminTheme.background,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(
                isSubmitting ? 'Connexion…' : 'Ouvrir le tableau de bord',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
