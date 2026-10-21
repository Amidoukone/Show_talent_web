import 'package:flutter/material.dart';

import '../models/user.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';
import 'admin_ui.dart';

/// Un seul repère de statut par compte plutôt qu'une pile de chips : les
/// anciennes puces (certifié / droits / auth désactivée / inactif / actif)
/// pouvaient s'accumuler jusqu'à quatre par ligne, répétant parfois la même
/// information (ex. "inactif" et "accès limité" en même temps). Les droits
/// enregistrés restent affichés, mais en second plan — ils ne changent pas
/// l'accès au compte et ne doivent jamais se confondre avec lui.
///
/// Ce repère ne parle que d'**accès**. La certification est l'affaire de
/// `AppUser.profileTrustLabel`, montré dans la colonne « Confiance ». Les
/// deux ont longtemps dit la même chose avec des mots différents —
/// « Vérifié » ici, « Profil certifié » là — ce qui donnait deux colonnes
/// redondantes sur la moitié des lignes.
class AdminAccountStatusChips extends StatelessWidget {
  const AdminAccountStatusChips({required this.user, super.key});

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
            style: AdminType.caption.copyWith(color: AdminTheme.textSecondary),
          ),
        ],
      ],
    );
  }

  _StatusItem _primaryStatus(AppUser user) {
    if (user.authDisabled) {
      return const _StatusItem(
        label: 'Accès suspendu',
        color: AdminTheme.warning,
      );
    }
    if (!user.isEffectivelyActiveAccount) {
      return const _StatusItem(
        label: 'Accès limité',
        color: AdminTheme.textMuted,
      );
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
  const _StatusItem({required this.label, required this.color});

  final String label;
  final Color color;
}
