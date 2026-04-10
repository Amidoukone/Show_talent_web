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

    if (user.hasTemporaryBlock) {
      statuses.add(
        _StatusItem(
          label: user.hasExpiredTemporaryBlock
              ? 'suspension expirée'
              : 'suspendu ${_formatBlockedUntil(user.blockedUntil)}',
          backgroundColor: user.hasExpiredTemporaryBlock
              ? const Color(0x334A655C)
              : const Color(0x33FF7E8A),
          textColor: user.hasExpiredTemporaryBlock
              ? AdminTheme.textMuted
              : AdminTheme.danger,
        ),
      );
    } else if (user.hasPermanentBlock) {
      statuses.add(const _StatusItem(
        label: 'bloqué',
        backgroundColor: Color(0x33FF7E8A),
        textColor: AdminTheme.danger,
      ));
    }

    if (user.authDisabled) {
      statuses.add(const _StatusItem(
        label: 'auth désactivée',
        backgroundColor: Color(0x33F4D27A),
        textColor: AdminTheme.warning,
      ));
    }

    if (!user.isEffectivelyActiveAccount) {
      statuses.add(const _StatusItem(
        label: 'inactif',
        backgroundColor: Color(0x334A655C),
        textColor: AdminTheme.textMuted,
      ));
    }

    if (statuses.isEmpty) {
      statuses.add(const _StatusItem(
        label: 'actif',
        backgroundColor: Color(0x3367F1AB),
        textColor: AdminTheme.success,
      ));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: statuses.map((status) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: status.backgroundColor,
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

  String _formatBlockedUntil(DateTime? value) {
    if (value == null) {
      return 'temporairement';
    }

    final normalized = value.toLocal();
    final day = normalized.day.toString().padLeft(2, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final year = normalized.year.toString();
    return 'jusqu’au $day/$month/$year';
  }
}

class _StatusItem {
  const _StatusItem({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
}
