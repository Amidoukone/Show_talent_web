import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../models/managed_account_provision_result.dart';
import '../theme/admin_theme.dart';
import 'admin_ui.dart';

class ManagedAccountInviteResultDialog extends StatelessWidget {
  const ManagedAccountInviteResultDialog({
    required this.result,
    required this.title,
    required this.subtitle,
    super.key,
  });

  final ManagedAccountProvisionResult result;
  final String title;
  final String subtitle;

  Future<void> _copyValue(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    Get.snackbar('Lien copie', '$label copie dans le presse-papiers.');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      title: Text(
        title,
        style: const TextStyle(
          color: AdminTheme.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                subtitle,
                style: const TextStyle(
                  color: AdminTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              if (result.uid.isNotEmpty)
                Text(
                  'UID : ${result.uid}',
                  style: const TextStyle(color: AdminTheme.textPrimary),
                ),
              if (result.email.isNotEmpty)
                Text(
                  'E-mail : ${result.email}',
                  style: const TextStyle(color: AdminTheme.textPrimary),
                ),
              if (result.role.isNotEmpty)
                Text(
                  'Role : ${result.role}',
                  style: const TextStyle(color: AdminTheme.textPrimary),
                ),
              const SizedBox(height: 16),
              const AdminInfoBanner(
                title: 'Liens renvoyes par le backend',
                message:
                    'Tu peux copier les liens ci-dessous pour les reutiliser dans ton flux admin sans regenirer les actions.',
                icon: Icons.link_rounded,
                tone: AdminBannerTone.info,
              ),
              _LinkTile(
                label: 'Password setup link',
                value: result.passwordSetupLink,
                onCopy: _copyValue,
              ),
              _LinkTile(
                label: 'Email verification link',
                value: result.emailVerificationLink,
                onCopy: _copyValue,
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String? value;
  final Future<void> Function(String label, String value) onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceSoft.withValues(alpha: 0.38),
        border: Border.all(color: AdminTheme.border.withValues(alpha: 0.9)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AdminTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (value == null)
            const Text(
              'Aucun lien retourne.',
              style: TextStyle(color: AdminTheme.textMuted),
            )
          else ...[
            SelectableText(
              value!,
              style: const TextStyle(color: AdminTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => onCopy(label, value!),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copier'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
