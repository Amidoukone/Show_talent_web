import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/user_controller.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_ui.dart';
import 'admin_dashboard_screen.dart';
import 'admin_signup.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final UserController userController = Get.find<UserController>();

  bool _obscurePassword = true;

  String _firebaseErrorMessage(FirebaseAuthException error) {
    final normalized = '${error.code} ${error.message ?? ''}'.toLowerCase();
    if (normalized.contains('403') ||
        normalized.contains('web-internal-error') ||
        normalized.contains('identity toolkit') ||
        normalized.contains('api key')) {
      return "Firebase Auth refuse la requête. Si le projet Google Cloud ou Firebase est suspendu, la connexion admin est bloquée même si l'interface fonctionne.";
    }

    return error.message ?? 'Erreur Firebase Auth : ${error.code}';
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
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final accessResult = await userController.evaluateAdminAccess(
        firebaseUser: userCredential.user!,
        forceRefresh: true,
      );

      if (!accessResult.isAuthorized) {
        Get.snackbar('Accès refusé', accessResult.message ?? 'Accès refusé.');
        await FirebaseAuth.instance.signOut();
        userController.clearSessionState();
        return;
      }

      Get.offAll(() => AdminDashboardScreen());
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
    return Scaffold(
      body: SafeArea(
        child: AdminAppBackground(
          padding: const EdgeInsets.all(24),
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
                            onOpenPreview: kDebugMode
                                ? () => Get.offAll(
                                      () => AdminDashboardScreen(
                                        previewMode: true,
                                      ),
                                    )
                                : null,
                          );

                          return isWide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    showcaseSection,
                                    const SizedBox(height: 24),
                                    formSection,
                                  ],
                                );
                        },
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
    final viewportHeight = MediaQuery.sizeOf(context).height;

    return AdminGlassPanel(
      padding: const EdgeInsets.all(28),
      highlight: true,
      accentColor: AdminTheme.accent,
      child: Stack(
        children: [
          Positioned(
            top: 18,
            right: 10,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AdminTheme.cyan.withValues(alpha: 0.08),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdminPill(
                label: 'Expérience admin',
                icon: Icons.shield_outlined,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AdminTheme.surfaceSoft.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AdminTheme.accent.withValues(alpha: 0.2),
                      ),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Image.asset('assets/logo.png'),
                  ),
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
                        'Portail de pilotage premium',
                        style: TextStyle(color: AdminTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Pilote la plateforme avec une interface plus nette, plus sobre et plus fiable.',
                style: textTheme.displaySmall,
              ),
              const SizedBox(height: 16),
              const Text(
                'La direction artistique reprend un univers sombre, lumineux et plus éditorial afin de donner une présence plus professionnelle au back-office.',
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
                      title: 'Comptes gérés',
                      subtitle:
                          'Provisionnement, claims et activation centralisés.',
                      accentColor: AdminTheme.accent,
                    ),
                    const _ShowcaseCard(
                      icon: Icons.play_circle_outline_rounded,
                      title: 'Modération vidéo',
                      subtitle:
                          'Lecture, suppression et suivi des signalements.',
                      accentColor: AdminTheme.cyan,
                    ),
                    const _ShowcaseCard(
                      icon: Icons.insights_rounded,
                      title: 'Vue d’ensemble',
                      subtitle:
                          'Des cartes KPI et une lecture rapide de l’activité.',
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

                  return SizedBox(
                    height: 360,
                    child: Column(
                      children: [
                        Expanded(
                          child: Transform.translate(
                            offset: const Offset(-18, 10),
                            child: cards[0],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Transform.translate(
                            offset: const Offset(24, 0),
                            child: cards[1],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Transform.translate(
                            offset: const Offset(-8, -8),
                            child: cards[2],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
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
    this.onOpenPreview,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscurePassword;
  final VoidCallback onSubmit;
  final VoidCallback? onOpenPreview;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      padding: const EdgeInsets.all(28),
      highlight: true,
      accentColor: AdminTheme.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminPill(
            label: 'Connexion sécurisée',
            icon: Icons.lock_outline_rounded,
            color: AdminTheme.cyan,
          ),
          const SizedBox(height: 22),
          const Text(
            'Connexion Admin',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AdminTheme.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Connectez-vous avec un compte admin autorisé. Les droits sont toujours contrôlés par les custom claims et le profil Firestore.',
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
            child: Column(
              children: [
                Container(
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
                const SizedBox(height: 18),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Adresse e-mail',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onSubmit,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Ouvrir le tableau de bord'),
                  ),
                ),
                if (onOpenPreview != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onOpenPreview,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Ouvrir un aperçu local'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          const AdminInfoBanner(
            title: 'Contrôle d’accès',
            message:
                'La création admin côté client reste désactivée. Le portail se concentre sur l’exploitation, pas sur l’élévation de privilège.',
            icon: Icons.verified_user_outlined,
            tone: AdminBannerTone.info,
          ),
          if (onOpenPreview != null) ...[
            const SizedBox(height: 14),
            const AdminInfoBanner(
              title: 'Mode debug',
              message:
                  'Si Firebase ou Google Cloud est suspendu, l’aperçu local permet de vérifier le design sans connexion réelle.',
              icon: Icons.design_services_outlined,
              tone: AdminBannerTone.warning,
            ),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () => Get.to(() => const AdminSignupScreen()),
              child: const Text('Accès admin géré par la plateforme'),
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
