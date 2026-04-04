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
