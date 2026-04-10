import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../models/managed_account_provision_result.dart';
import '../theme/admin_theme.dart';
import 'admin_feedback.dart';
import 'admin_ui.dart';

class ManagedAccountInviteResultDialog extends StatelessWidget {
  const ManagedAccountInviteResultDialog({
    required this.result,
    required this.title,
    required this.subtitle,
    this.recipientName,
    super.key,
  });

  final ManagedAccountProvisionResult result;
  final String title;
  final String subtitle;
  final String? recipientName;

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
        width: 640,
        child: SingleChildScrollView(
          child: ManagedAccountInviteSummary(
            result: result,
            subtitle: subtitle,
            recipientName: recipientName,
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

class ManagedAccountInviteSummary extends StatelessWidget {
  const ManagedAccountInviteSummary({
    required this.result,
    this.subtitle,
    this.recipientName,
    this.copyPosition = SnackPosition.BOTTOM,
    super.key,
  });

  final ManagedAccountProvisionResult result;
  final String? subtitle;
  final String? recipientName;
  final SnackPosition copyPosition;

  Future<void> _copyValue(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    showAdminFeedback(
      title: 'Copie terminée',
      message: '$label copié dans le presse-papiers.',
      tone: AdminBannerTone.info,
      position: copyPosition,
    );
  }

  @override
  Widget build(BuildContext context) {
    final whatsappMessage = result.buildWhatsappMessage(
      recipientName: recipientName,
    );
    final emailMessage = [
      'Objet : ${result.buildEmailSubject()}',
      '',
      result.buildEmailMessage(
        recipientName: recipientName,
      ),
    ].join('\n');
    final steps = result.buildRecommendedSteps();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (subtitle != null) ...[
          Text(
            subtitle!,
            style: const TextStyle(
              color: AdminTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
        ],
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
            'Rôle : ${result.role}',
            style: const TextStyle(color: AdminTheme.textPrimary),
          ),
        Text(
          'État : ${result.lifecycleLabel}',
          style: const TextStyle(color: AdminTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        AdminInfoBanner(
          title: 'Ordre conseillé',
          message: result.requiresEmailVerification
              ? 'Le titulaire doit d’abord définir son mot de passe, puis valider son e-mail, puis se connecter.'
              : 'Le titulaire doit d’abord définir son mot de passe, puis se connecter. Aucune validation e-mail supplémentaire n’est requise.',
          icon: Icons.rule_rounded,
          tone: AdminBannerTone.info,
        ),
        const SizedBox(height: 12),
        _ChecklistCard(steps: steps),
        const SizedBox(height: 12),
        _MessageCard(
          title: 'Version WhatsApp',
          description:
              'Format court, adapté à WhatsApp ou SMS. Le texte est déjà ordonné pour le titulaire.',
          copyLabel: 'Copier version WhatsApp',
          message: whatsappMessage,
          onCopy: () => _copyValue('Version WhatsApp', whatsappMessage),
        ),
        const SizedBox(height: 12),
        _MessageCard(
          title: 'Version e-mail',
          description:
              'Format plus formel, avec objet et message complet, adapté à un envoi par e-mail.',
          copyLabel: 'Copier version e-mail',
          message: emailMessage,
          onCopy: () => _copyValue('Version e-mail', emailMessage),
        ),
        _LinkTile(
          label: 'Lien mot de passe',
          value: result.passwordSetupLink,
          onCopy: _copyValue,
        ),
        if (result.emailVerificationLink != null)
          _LinkTile(
            label: 'Lien validation e-mail',
            value: result.emailVerificationLink,
            onCopy: _copyValue,
          )
        else
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            child: const AdminInfoBanner(
              title: 'Verification deja validee',
              message:
                  'Aucun lien de validation e-mail n’a été retourné. Le titulaire peut passer directement à la connexion après le mot de passe.',
              icon: Icons.verified_rounded,
              tone: AdminBannerTone.success,
            ),
          ),
      ],
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceSoft.withValues(alpha: 0.38),
        border: Border.all(color: AdminTheme.border.withValues(alpha: 0.9)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Parcours utilisateur recommandé',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AdminTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...List<Widget>.generate(steps.length, (index) {
            return Padding(
              padding:
                  EdgeInsets.only(bottom: index == steps.length - 1 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AdminTheme.cyan.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: AdminTheme.cyan,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      steps[index],
                      style: const TextStyle(
                        color: AdminTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.title,
    required this.description,
    required this.copyLabel,
    required this.message,
    required this.onCopy,
  });

  final String title;
  final String description;
  final String copyLabel;
  final String message;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceSoft.withValues(alpha: 0.38),
        border: Border.all(color: AdminTheme.border.withValues(alpha: 0.9)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AdminTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AdminTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy, size: 18),
                label: Text(copyLabel),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            message,
            style: const TextStyle(
              color: AdminTheme.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
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
              'Aucun lien retourné.',
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
