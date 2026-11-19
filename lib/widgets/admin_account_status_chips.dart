import 'package:flutter/material.dart';

import '../models/user.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';
import '../utils/admin_date_format.dart';
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
///
/// Les droits en second plan tiennent sur **une seule ligne**, même quand un
/// club cumule un abonnement et une habilitation. Ce n'est pas une
/// préférence : la ligne du tableau fait [AdminTheme.tableRowHeight], et un
/// troisième niveau de texte en déborderait sans rien signaler.
class AdminAccountStatusChips extends StatelessWidget {
  const AdminAccountStatusChips({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final primary = _primaryStatus(user);
    final secondary = _secondaryLabels(user);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminStatusDot(label: primary.label, color: primary.color),
        if (secondary.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                for (var index = 0; index < secondary.length; index += 1) ...[
                  if (index > 0)
                    const TextSpan(
                      text: ' · ',
                      style: TextStyle(color: AdminTheme.textMuted),
                    ),
                  TextSpan(
                    text: secondary[index].label,
                    style: TextStyle(color: secondary[index].color),
                  ),
                ],
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdminType.caption,
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

  /// Les droits enregistrés sur le compte, abonnement puis habilitation.
  ///
  /// Dans cet ordre parce que l'abonnement concerne tous les rôles alors que
  /// l'habilitation ne concerne que les clubs : la colonne garde la même
  /// grammaire d'une ligne à l'autre.
  List<_StatusItem> _secondaryLabels(AppUser user) {
    return <_StatusItem>[?_membershipLabel(user), ?_enrollmentLabel(user)];
  }

  _StatusItem? _membershipLabel(AppUser user) {
    if (!user.membership.isRecorded) return null;
    final active = user.membership.isActiveAt(DateTime.now());
    if (active) {
      return _StatusItem(
        label: user.membership.isAgencyPlayer
            ? 'Sous contrat'
            : 'Droits actifs',
        color: AdminTheme.textSecondary,
      );
    }
    return const _StatusItem(
      label: 'Droits échus',
      color: AdminTheme.textSecondary,
    );
  }

  /// L'habilitation à déclarer des joueurs, et son terme.
  ///
  /// Le terme est affiché, pas seulement l'état : repérer un club dont
  /// l'habilitation expire demandait d'ouvrir chaque ligne, alors que c'est
  /// précisément ce qu'une liste doit éviter. Une échéance proche passe en
  /// couleur d'avertissement — un renouvellement passe par un accord signé
  /// entre deux parties, donc il se prépare avant d'être urgent.
  ///
  /// Rien n'est affiché sur un club jamais habilité : la très grande majorité
  /// des comptes clubs sont dans ce cas, et le dire sur chaque ligne ne
  /// renseignerait personne. L'absence se lit dans l'action de la ligne, qui
  /// propose « Habiliter le club ».
  _StatusItem? _enrollmentLabel(AppUser user) {
    final enrollment = user.clubEnrollment;
    if (!enrollment.granted) return null;

    if (enrollment.expired) {
      return const _StatusItem(
        label: 'Habilitation échue',
        color: AdminTheme.warning,
      );
    }

    final validUntil = enrollment.validUntil;
    final label = validUntil == null
        ? 'Habilité'
        : 'Habilité jusqu’au ${formatAdminDate(validUntil)}';

    return _StatusItem(
      label: label,
      color: enrollment.expiresSoon()
          ? AdminTheme.warning
          : AdminTheme.textSecondary,
    );
  }
}

class _StatusItem {
  const _StatusItem({required this.label, required this.color});

  final String label;
  final Color color;
}
