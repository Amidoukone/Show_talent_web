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

  String _firebaseErrorMessage(FirebaseAuthException error) {
    final normalized = '${error.code} ${error.message ?? ''}'.toLowerCase();
    if (normalized.contains('403') ||
        normalized.contains('web-internal-error') ||
        normalized.contains('identity toolkit') ||
        normalized.contains('api key')) {
      return "Le service d'authentification refuse la requ\u00eate. V\u00e9rifiez que votre acc\u00e8s administrateur est actif avant de r\u00e9essayer.";
    }

    return error.message ?? "Erreur d'authentification : ${error.code}";
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginAdmin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      Get.snackbar(
        'Connexion impossible',
        'Saisissez votre e-mail et mot de passe.',
      );
      return;
    }

    try {
      final accessResult = await _authController.loginAdmin(
        email: email,
        password: password,
      );

      if (!accessResult.isAuthorized) {
        Get.snackbar('Acc\u00e8s refus\u00e9', accessResult.message ?? 'Acc\u00e8s refus\u00e9.');
        return;
      }

      Get.offAllNamed(AppRoutes.adminDashboard);
    } on FirebaseAuthException catch (error) {
      Get.snackbar(
        'Connexion impossible',
        _firebaseErrorMessage(error),
      );
    } catch (error) {
      Get.snackbar('Connexion impossible', error.toString());
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
    required this.onToggleObscurePassword,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscurePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final compact = viewportWidth < 600;

    return AdminGlassPanel(
      width: compact ? viewportWidth - 32 : 440,
      padding: EdgeInsets.all(compact ? 20 : 28),
      highlight: true,
      accentColor: AdminTheme.cyan,
      child: AdminFormColumn(
        maxWidth: 440,
        children: [
          const Align(
            alignment: Alignment.center,
            child: AdminBrandMark(size: 64),
          ),
          const Align(
            alignment: Alignment.center,
            child: Text(
              'Connexion admin',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AdminTheme.textPrimary,
                letterSpacing: 0,
              ),
            ),
          ),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Adresse e-mail',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: onToggleObscurePassword,
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Ouvrir le tableau de bord'),
            ),
          ),
        ],
      ),
    );
  }
}
