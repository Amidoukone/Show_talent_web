import 'package:flutter/material.dart';

import '../models/user.dart';
import '../theme/admin_theme.dart';

class AdminAccountStatusChips extends StatelessWidget {
  const AdminAccountStatusChips({
    required this.user,
    super.key,
  });

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final statuses = <_StatusItem>[];

    if (user.profileVerified) {
      statuses.add(const _StatusItem(
        label: 'profil certifié',
        textColor: AdminTheme.success,
      ));
    } else if (user.profileVerificationNeedsReview) {
      statuses.add(const _StatusItem(
        label: 'à revalider',
        textColor: AdminTheme.warning,
      ));
    }

    if (user.authDisabled) {
      statuses.add(const _StatusItem(
        label: 'auth désactivée',
        textColor: AdminTheme.warning,
      ));
    }

    if (!user.isEffectivelyActiveAccount) {
      statuses.add(const _StatusItem(
        label: 'inactif',
        textColor: AdminTheme.textMuted,
      ));
    }

    statuses.add(_StatusItem(
      label: user.isEffectivelyActiveAccount ? 'actif' : 'accès limité',
      textColor: user.isEffectivelyActiveAccount
          ? AdminTheme.success
          : AdminTheme.textMuted,
    ));

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: statuses.map((status) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: status.textColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: status.textColor.withValues(alpha: 0.18),
            ),
          ),
          child: Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              color: status.textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatusItem {
  const _StatusItem({
    required this.label,
    required this.textColor,
  });

  final String label;
  final Color textColor;
}
