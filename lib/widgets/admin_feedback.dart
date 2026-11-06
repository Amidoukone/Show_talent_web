import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/admin_theme.dart';
import 'admin_ui.dart';

void showAdminFeedback({
  required String title,
  required String message,
  AdminBannerTone tone = AdminBannerTone.neutral,
  SnackPosition position = SnackPosition.TOP,
  Duration duration = const Duration(seconds: 3),
}) {
  final Color accentColor = switch (tone) {
    AdminBannerTone.success => AdminTheme.success,
    AdminBannerTone.warning => AdminTheme.warning,
    AdminBannerTone.danger => AdminTheme.danger,
    AdminBannerTone.info => AdminTheme.cyan,
    AdminBannerTone.neutral => AdminTheme.accent,
  };

  final IconData icon = switch (tone) {
    AdminBannerTone.success => Icons.check_circle_outline_rounded,
    AdminBannerTone.warning => Icons.warning_amber_rounded,
    AdminBannerTone.danger => Icons.error_outline_rounded,
    AdminBannerTone.info => Icons.info_outline_rounded,
    AdminBannerTone.neutral => Icons.notifications_none_rounded,
  };

  Get.snackbar(
    title,
    message,
    snackPosition: position,
    duration: duration,
    margin: const EdgeInsets.all(14),
    borderRadius: 16,
    backgroundColor: AdminTheme.surfaceRaised.withValues(alpha: 0.96),
    borderWidth: 1,
    borderColor: accentColor.withValues(alpha: 0.35),
    colorText: AdminTheme.textPrimary,
    icon: Icon(icon, color: accentColor),
    titleText: Text(
      title,
      style: const TextStyle(
        color: AdminTheme.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    ),
    messageText: Text(
      message,
      style: const TextStyle(
        color: AdminTheme.textSecondary,
        height: 1.4,
      ),
    ),
  );
}

/// Boîte de dialogue de confirmation partagée par les actions destructives
/// des écrans de gestion (suppression, suspension...). Le même
/// `AlertDialog` à deux boutons ("Annuler" + action pleine sur
/// [confirmColor]) était recopié à l'identique dans plusieurs écrans.
///
/// [content] reste un `Widget` plutôt qu'une simple chaîne : certains
/// appelants (mise en relation) ont besoin d'un corps à plusieurs lignes
/// avec une mise en forme propre, pas seulement d'un message brut.
Future<bool> confirmAdminDeletion({
  required BuildContext context,
  required String title,
  required Widget content,
  String confirmLabel = 'Supprimer',
  IconData? confirmIcon,
  Color confirmColor = AdminTheme.dangerText,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final confirmStyle = ElevatedButton.styleFrom(
        backgroundColor: confirmColor,
        foregroundColor: AdminTheme.background,
      );

      return AlertDialog(
        title: Text(title),
        content: content,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          confirmIcon == null
              ? ElevatedButton(
                  style: confirmStyle,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(confirmLabel),
                )
              : ElevatedButton.icon(
                  style: confirmStyle,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  icon: Icon(confirmIcon),
                  label: Text(confirmLabel),
                ),
        ],
      );
    },
  );

  return confirmed ?? false;
}
