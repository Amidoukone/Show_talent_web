import 'package:flutter/material.dart';

import '../models/user.dart';
import '../theme/admin_theme.dart';
import 'admin_ui.dart';

/// Un seul repère de statut par compte plutôt qu'une pile de chips : les
/// anciennes puces (certifié / droits / auth désactivée / inactif / actif)
/// pouvaient s'accumuler jusqu'à quatre par ligne, répétant parfois la même
/// information (ex. "inactif" et "accès limité" en même temps). Les droits
/// enregistrés restent affichés, mais en second plan — ils ne changent pas
/// l'accès au compte et ne doivent jamais se confondre avec lui.
class AdminAccountStatusChips extends StatelessWidget {
  const AdminAccountStatusChips({
    required this.user,
    super.key,
  });

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final primary = _primaryStatus(user);
    final membershipLabel = _membershipLabel(user);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminStatusDot(label: primary.label, color: primary.color),
        if (membershipLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            membershipLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AdminTheme.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  _StatusItem _primaryStatus(AppUser user) {
    if (user.authDisabled) {
      return const _StatusItem(label: 'Accès désactivé', color: AdminTheme.warning);
    }
    if (!user.isEffectivelyActiveAccount) {
      return const _StatusItem(label: 'Accès limité', color: AdminTheme.textMuted);
    }
    if (user.profileVerified) {
      return const _StatusItem(label: 'Vérifié', color: AdminTheme.success);
    }
    if (user.profileVerificationNeedsReview) {
      return const _StatusItem(label: 'À revalider', color: AdminTheme.warning);
    }
    return const _StatusItem(label: 'Actif', color: AdminTheme.success);
  }

  String? _membershipLabel(AppUser user) {
    if (!user.membership.isRecorded) return null;
    final active = user.membership.isActiveAt(DateTime.now());
    if (active) {
      return user.membership.isAgencyPlayer ? 'Sous contrat' : 'Droits actifs';
    }
    return 'Droits échus';
  }
}

class _StatusItem {
  const _StatusItem({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;
}
