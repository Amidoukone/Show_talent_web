import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/messaging_config_controller.dart';
import '../controller/user_controller.dart';
import '../models/messaging_config.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';
import 'admin_detail_panel.dart';
import 'admin_ui.dart';

/// L'état de la messagerie médiatisée, et les comptes qui la tiennent.
///
/// **Panneau de lecture seule, par construction et non par manque.**
/// `config/messaging` est fermé en écriture à tout client, et aucune Cloud
/// Function ne l'écrit : il se modifie par la console Firebase, ce qui est
/// délibéré — refermer un mode qui aurait mal tourné ne doit pas demander de
/// publier un build. La procédure est dans
/// `docs/runbook-production-admin-mobile.md`.
///
/// Ce que ce panneau apporte, c'est de rendre l'état **visible avant la
/// bascule**. Activer le mode sans nommer de compte de support ferme toute la
/// messagerie de la plateforme : c'est le bon échec, fermé plutôt qu'ouvert,
/// mais ce n'est pas un état utilisable, et rien nulle part ne l'annonçait.
class MessagingConfigPanel extends StatelessWidget {
  const MessagingConfigPanel({super.key, this.controller, this.userController});

  /// Injectables pour les tests, résolus depuis GetX en production.
  final MessagingConfigController? controller;
  final UserController? userController;

  @override
  Widget build(BuildContext context) {
    final messaging = controller ?? Get.find<MessagingConfigController>();
    final users = userController ?? Get.find<UserController>();

    return Obx(() {
      final config = messaging.config.value;
      final error = messaging.lastError.value;

      return AdminPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminSectionHeader(
              title: 'Messagerie',
              subtitle:
                  'Réglage de plateforme, modifiable par la console seule.',
              trailing: AdminPill(
                label: config.statusLabel,
                color: _statusColor(config),
              ),
            ),
            const SizedBox(height: AdminTheme.space3),
            if (messaging.isLoading.value)
              const AdminLoadingState(message: 'Lecture du réglage…')
            else if (error.isNotEmpty)
              Text(
                error,
                style: AdminType.body.copyWith(color: AdminTheme.warning),
              )
            else ...[
              if (config.closesAllMessaging) ...[
                const AdminInfoBanner(
                  title: 'La messagerie est fermée à tout le monde',
                  message:
                      'Le mode médiatisé est actif et aucun compte de support '
                      'n’est nommé : les règles exigent qu’une conversation '
                      'ait un compte Adfoot d’un côté, donc plus aucune ne '
                      'peut s’ouvrir. Nommez un compte, ou désactivez le mode.',
                  icon: Icons.error_outline_rounded,
                  tone: AdminBannerTone.danger,
                ),
                const SizedBox(height: AdminTheme.space3),
              ],
              AdminDetailField(
                label: 'Mode médiatisé',
                value: config.mediatedOnly ? 'Actif' : 'Inactif',
                valueColor: config.mediatedOnly ? AdminTheme.warning : null,
              ),
              AdminDetailField(
                label: 'Document',
                value: config.exists
                    ? 'config/messaging'
                    : 'config/messaging — jamais créé',
              ),
              AdminDetailField(
                label: 'Comptes de support',
                value: config.supportUids.isEmpty
                    ? 'Aucun'
                    : config.supportUids
                          .map((uid) => _accountLabel(users, uid))
                          .join('\n'),
                valueColor: config.closesAllMessaging
                    ? AdminTheme.dangerText
                    : null,
              ),
              const SizedBox(height: AdminTheme.space2),
              Text(
                'Hors mode médiatisé, rien ne change : les mises en relation '
                'se font directement. En mode médiatisé, toute conversation '
                'passe par un compte nommé ci-dessus — nommé dans le '
                'document, et non reconnu à son rôle, qu’une console ou une '
                'mauvaise fusion peut changer.\n\n'
                'Ce réglage ne se modifie pas depuis le portail : la '
                'procédure est décrite dans le runbook de production, section '
                '« Messagerie médiatisée ».',
                style: AdminType.prose.copyWith(
                  color: AdminTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Color _statusColor(MessagingConfig config) {
    if (config.closesAllMessaging) return AdminTheme.dangerText;
    if (config.mediatedOnly) return AdminTheme.warning;
    if (!config.exists) return AdminTheme.textMuted;
    return AdminTheme.success;
  }

  /// Le nom d'un compte de support, avec son identifiant.
  ///
  /// Les deux, et pas seulement le nom : c'est l'identifiant qui figure dans
  /// le document, donc c'est lui qu'un opérateur recopie dans la console. Un
  /// compte hors de la fenêtre chargée s'affiche sous son seul identifiant,
  /// ce qui reste exploitable.
  String _accountLabel(UserController users, String uid) {
    for (final user in users.userList) {
      if (user.uid == uid) {
        final name = user.nom.trim();
        if (name.isNotEmpty && name != 'Nom inconnu') return '$name · $uid';
        break;
      }
    }
    return uid;
  }
}
