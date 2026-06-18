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
          child: LayoutBuilder(
            builder: (context, viewportConstraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (viewportConstraints.maxHeight - 16).clamp(
                      0.0,
                      double.infinity,
                    ),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: double.infinity,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1220),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 980 &&
                                viewportConstraints.maxHeight >= 760;

                            final showcaseSection = const _LoginShowcasePanel();
                            final formSection = _LoginFormPanel(
                              emailController: _emailController,
                              passwordController: _passwordController,
                              obscurePassword: _obscurePassword,
                              onToggleObscurePassword: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              onSubmit: _loginAdmin,
                            );

                            return isWide
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Expanded(
                                        flex: 12,
                                        child: _LoginShowcasePanel(),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(flex: 10, child: formSection),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      formSection,
                                      const SizedBox(height: 24),
                                      showcaseSection,
                                    ],
                                  );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginShowcasePanel extends StatelessWidget {
  const _LoginShowcasePanel();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final viewportSize = MediaQuery.sizeOf(context);
    final compact = viewportSize.width < 600;
    final viewportHeight = viewportSize.height;

    return AdminGlassPanel(
      width: compact ? viewportSize.width - 32 : double.infinity,
      padding: const EdgeInsets.all(28),
      highlight: true,
      accentColor: AdminTheme.accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminPill(
            label: 'Exp\u00e9rience admin',
            icon: Icons.shield_outlined,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const AdminBrandMark(),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Adfoot',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Portail d'administration",
                    style: TextStyle(color: AdminTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Pilotez la plateforme avec une interface claire, sobre et fiable.',
            style: textTheme.displaySmall,
          ),
          const SizedBox(height: 16),
          const Text(
            "Un espace centralis\u00e9 pour suivre les comptes, les contenus, les offres, les \u00e9v\u00e9nements et les mises en relation.",
            style: TextStyle(
              color: AdminTheme.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 30),
          LayoutBuilder(
            builder: (context, constraints) {
              final useCompactCards =
                  constraints.maxWidth < 560 || viewportHeight < 820;

              final cards = [
                const _ShowcaseCard(
                  icon: Icons.people_alt_rounded,
                  title: 'Comptes administr\u00e9s',
                  subtitle: 'Provisionnement et activation centralis\u00e9s.',
                  accentColor: AdminTheme.accent,
                ),
                const _ShowcaseCard(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'Mod\u00e9ration vid\u00e9o',
                  subtitle: 'Lecture, suppression et suivi des signalements.',
                  accentColor: AdminTheme.cyan,
                ),
                const _ShowcaseCard(
                  icon: Icons.insights_rounded,
                  title: "Vue d'ensemble",
                  subtitle:
                      "Des cartes KPI et une lecture rapide de l'activit\u00e9.",
                  accentColor: AdminTheme.warning,
                ),
              ];

              if (useCompactCards) {
                return Column(
                  children: [
                    cards[0],
                    const SizedBox(height: 14),
                    cards[1],
                    const SizedBox(height: 14),
                    cards[2],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 14),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 14),
                  Expanded(child: cards[2]),
                ],
              );
            },
          ),
        ],
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
      width: compact ? viewportWidth - 32 : double.infinity,
      padding: EdgeInsets.all(compact ? 20 : 28),
      highlight: true,
      accentColor: AdminTheme.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminPill(
            label: 'Connexion s\u00e9curis\u00e9e',
            icon: Icons.lock_outline_rounded,
            color: AdminTheme.cyan,
          ),
          const SizedBox(height: 22),
          const Text(
            'Connexion admin',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AdminTheme.textPrimary,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Connectez-vous avec un compte autoris\u00e9. Les droits sont v\u00e9rifi\u00e9s avant l'ouverture du tableau de bord.",
            style: TextStyle(
              color: AdminTheme.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 26),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AdminTheme.surfaceSoft.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AdminTheme.border.withValues(alpha: 0.85),
              ),
            ),
            child: AdminFormColumn(
              maxWidth: 440,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AdminTheme.accent.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AdminTheme.accent.withValues(alpha: 0.24),
                      ),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: AdminTheme.accent,
                      size: 34,
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
          ),
          const SizedBox(height: 18),
          const AdminInfoBanner(
            title: "Contr\u00f4le d'acc\u00e8s",
            message:
                "Les acc\u00e8s administrateur sont attribu\u00e9s par l'\u00e9quipe habilit\u00e9e. Le portail se concentre sur le pilotage op\u00e9rationnel.",
            icon: Icons.verified_user_outlined,
            tone: AdminBannerTone.info,
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () => Get.toNamed(AppRoutes.adminSignup),
              child: const Text('Acc\u00e8s admin g\u00e9r\u00e9 par la plateforme'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowcaseCard extends StatelessWidget {
  const _ShowcaseCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      padding: const EdgeInsets.all(20),
      accentColor: accentColor,
      highlight: true,
      radius: 26,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: accentColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AdminTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AdminTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
