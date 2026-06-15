import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/app_routes.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_ui.dart';

class AdminSignupScreen extends StatefulWidget {
  const AdminSignupScreen({super.key});

  @override
  State<AdminSignupScreen> createState() => _AdminSignupScreenState();
}

class _AdminSignupScreenState extends State<AdminSignupScreen> {
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
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: AdminGlassPanel(
                        padding: const EdgeInsets.all(30),
                        highlight: true,
                        accentColor: AdminTheme.warning,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final stacked = constraints.maxWidth < 760;

                            final intro = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AdminPill(
                                  label: 'Accès sécurisé',
                                  icon: Icons.rule_rounded,
                                  color: AdminTheme.warning,
                                ),
                                const SizedBox(height: 22),
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AdminTheme.warning.withValues(
                                      alpha: 0.14,
                                    ),
                                    border: Border.all(
                                      color: AdminTheme.warning.withValues(
                                        alpha: 0.26,
                                      ),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.admin_panel_settings_rounded,
                                    size: 36,
                                    color: AdminTheme.warning,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                const Text(
                                  'Accès administrateur géré',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: AdminTheme.textPrimary,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  "Pour protéger la production, les comptes administrateur sont créés et validés par l'équipe habilitée.",
                                  style: TextStyle(
                                    color: AdminTheme.textSecondary,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            );

                            final body = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AdminInfoBanner(
                                  title: "Droits d'accès",
                                  message:
                                      "Les droits admin sont attribués par l'équipe habilitée puis vérifiés à chaque connexion.",
                                  icon: Icons.security_rounded,
                                  tone: AdminBannerTone.warning,
                                ),
                                const SizedBox(height: 16),
                                const AdminInfoBanner(
                                  title: 'Comptes métier',
                                  message:
                                      'Les comptes joueurs, clubs, agents et recruteurs se créent depuis le dashboard avec un parcours contrôlé.',
                                  icon: Icons.hub_outlined,
                                  tone: AdminBannerTone.info,
                                ),
                                const SizedBox(height: 24),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          Get.offAllNamed(AppRoutes.adminLogin),
                                      icon: const Icon(
                                        Icons.arrow_back_rounded,
                                      ),
                                      label: const Text(
                                        'Retour à la connexion',
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          Get.offAllNamed(AppRoutes.adminLogin),
                                      icon: const Icon(Icons.login_rounded),
                                      label: const Text('Ouvrir le portail'),
                                    ),
                                  ],
                                ),
                              ],
                            );

                            if (stacked) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  intro,
                                  const SizedBox(height: 24),
                                  body,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 9, child: intro),
                                const SizedBox(width: 28),
                                Expanded(flex: 11, child: body),
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
