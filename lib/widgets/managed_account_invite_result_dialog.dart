import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../models/managed_account_provision_result.dart';

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
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(subtitle),
              const SizedBox(height: 16),
              if (result.uid.isNotEmpty) Text('UID : ${result.uid}'),
              if (result.email.isNotEmpty) Text('E-mail : ${result.email}'),
              if (result.role.isNotEmpty) Text('Role : ${result.role}'),
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
        TextButton(
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (value == null)
            const Text('Aucun lien retourne.')
          else ...[
            SelectableText(value!),
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
