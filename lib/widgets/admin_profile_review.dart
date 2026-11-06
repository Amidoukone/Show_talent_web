import 'package:flutter/material.dart';

import '../models/membership.dart';
import '../models/user.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';
import '../utils/season_record_label.dart';
import 'admin_detail_panel.dart';
import 'admin_ui.dart';

class ProfileReviewContent extends StatelessWidget {
  const ProfileReviewContent({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AdminPill(
              label: user.profileTrustLabel,
              icon: user.profileVerified
                  ? Icons.verified_rounded
                  : Icons.fact_check_outlined,
              color: user.profileVerified
                  ? AdminTheme.success
                  : AdminTheme.cyan,
            ),
            AdminPill(
              label: user.profileLevelLabel,
              icon: Icons.military_tech_outlined,
              color: user.hasAdvancedProfile
                  ? AdminTheme.accent
                  : AdminTheme.textMuted,
            ),
            AdminPill(
              label: user.profilePublic ? 'Profil public' : 'Profil restreint',
              icon: user.profilePublic
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: user.profilePublic
                  ? AdminTheme.success
                  : AdminTheme.warning,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ProfileReviewSection(
          title: 'Éligibilité confiance',
          children: [
            _ProfileReviewItem.boolean(
              label: 'Compte actif et e-mail vérifié',
              value: user.isEffectivelyActiveAccount,
            ),
            _ProfileReviewItem.boolean(
              label: 'Profil de base complet',
              value: user.isMvpProfileComplete,
            ),
            _ProfileReviewItem.boolean(
              label: 'Profil avancé mobile renseigné',
              value: user.hasAdvancedProfile,
            ),
            if (user.isPlayer)
              _ProfileReviewItem.boolean(
                label: 'Dossier scout exploitable',
                value: user.hasScoutReadyProfile,
              ),
            _ProfileReviewItem(
              label: 'Statut actuel',
              value: user.profileVerificationStatusLabel,
            ),
            if (user.profileVerificationNeedsReview)
              _ProfileReviewItem(
                label: 'Action requise',
                value: 'Revalidation Adfoot après modification utilisateur',
              ),
            if (user.profileVerificationInvalidatedAt != null)
              _ProfileReviewItem(
                label: 'À revalider depuis',
                value: user.profileVerificationInvalidatedAt!
                    .toLocal()
                    .toString(),
              ),
            if (user.profileVerificationInvalidatedBy != null)
              _ProfileReviewItem(
                label: 'Modification par',
                value: user.profileVerificationInvalidatedBy!,
              ),
            if (user.profileVerificationInvalidationReason != null)
              _ProfileReviewItem(
                label: 'Cause',
                value: user.profileVerificationInvalidationReason!,
              ),
            if (user.profileVerifiedAt != null)
              _ProfileReviewItem(
                label: user.profileVerified
                    ? 'Certifié le'
                    : 'Dernière certification',
                value: user.profileVerifiedAt!.toLocal().toString(),
              ),
            if (user.profileVerificationNote != null)
              _ProfileReviewItem(
                label: 'Note interne',
                value: user.profileVerificationNote!,
              ),
          ],
        ),
        const SizedBox(height: 14),
        _ProfileReviewSection(
          title: 'Droits enregistrés',
          children: [
            _ProfileReviewItem(
              label: 'État',
              value: user.membership.statusLabelAt(DateTime.now()),
            ),
            _ProfileReviewItem(
              label: 'Catégorie',
              value: user.membership.tierLabel,
            ),
            if (user.membership.startedAt != null)
              _ProfileReviewItem(
                label: 'Enregistré le',
                value: Membership.formatDate(user.membership.startedAt!),
              ),
            _ProfileReviewItem(
              label: 'Échéance',
              value: user.membership.validUntil == null
                  ? (user.membership.isRecorded ? 'Sans terme' : 'Sans objet')
                  : Membership.formatDate(user.membership.validUntil!),
            ),
            _ProfileReviewItem(
              label: 'Référence interne',
              value: user.membership.reference ?? 'Non renseignée',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ProfileReviewSection(
          title: 'Identité et contact',
          children: [
            _ProfileReviewItem(label: 'Nom', value: user.nom),
            _ProfileReviewItem(label: 'E-mail', value: user.email),
            _ProfileReviewItem(label: 'Rôle', value: user.role),
            _ProfileReviewItem(
              label: 'Téléphone',
              value: user.phone ?? 'Non renseigné',
            ),
            _ProfileReviewItem(
              label: 'Localisation',
              value: user.primaryLocation ?? 'Non renseignée',
            ),
            _ProfileReviewItem(
              label: 'Langues',
              value: user.languages?.join(', ') ?? 'Non renseignées',
            ),
            _ProfileReviewItem.boolean(
              label: 'Ouvert aux opportunités',
              value: user.openToOpportunities == true,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ProfileReviewSection(
          title: 'Profil métier mobile',
          children: _buildRoleProfileItems(user),
        ),
      ],
    );
  }

  static List<_ProfileReviewItem> _buildRoleProfileItems(AppUser user) {
    if (user.isPlayer) {
      return [
        _ProfileReviewItem(
          label: 'Postes',
          value: user.football.positions.isEmpty
              ? 'Non renseigné'
              : user.football.positions.map((p) => p.labelFr).join(' · '),
        ),
        _ProfileReviewItem(
          label: 'Club actuel',
          value: user.football.currentClubName ?? 'Non renseigné',
        ),
        // Le parcours : c'est sur lui qu'un recruteur juge une progression,
        // donc c'est lui qu'il signalera si une saison est fausse. Le voir
        // est la condition pour pouvoir le corriger.
        _ProfileReviewItem(
          label: 'Parcours',
          value: user.football.seasonHistory.isEmpty
              ? 'Aucune saison archivée'
              : user.football.seasonHistory.map(archivedSeasonLabel).join('\n'),
        ),
        _ProfileReviewItem(
          label: 'CV',
          value: user.cvUrl?.isNotEmpty == true ? 'Présent' : 'Absent',
        ),
        _ProfileReviewItem(
          label: 'Photo de passeport',
          value: user.passportPhotoUrl?.isNotEmpty == true
              ? 'Présent'
              : 'Absent',
        ),
        _ProfileReviewItem(
          label: 'Numéro de licence',
          value:
              user.playerProfile?['licenseNumber']?.toString() ??
              'Non renseigné',
        ),
        _ProfileReviewItem(
          label: 'Profil joueur avancé',
          value: _formatMapSummary(user.playerProfile),
        ),
      ];
    }

    if (user.isClub) {
      return [
        _ProfileReviewItem(label: 'Club', value: user.nomClub ?? user.nom),
        _ProfileReviewItem(
          label: 'Ligue',
          value: user.ligue ?? 'Non renseignée',
        ),
        _ProfileReviewItem(
          label: 'Numéro de licence du club',
          value:
              user.clubProfile?['licenseNumber']?.toString() ?? 'Non renseigné',
        ),
        _ProfileReviewItem(
          label: 'Profil club avancé',
          value: _formatMapSummary(user.clubProfile),
        ),
      ];
    }

    if (user.isRecruiter) {
      return [
        _ProfileReviewItem(
          label: 'Organisation',
          value: user.entreprise ?? 'Non renseignée',
        ),
        _ProfileReviewItem(
          label: 'Recrutements',
          value: user.nombreDeRecrutements?.toString() ?? 'Non renseigné',
        ),
        _ProfileReviewItem(
          label: user.isAgent
              ? 'Numéro de licence'
              : 'Référence de licence ou d’agrément',
          value:
              user.agentProfile?['licenseNumber']?.toString() ??
              'Non renseigné',
        ),
        _ProfileReviewItem(
          label: 'Profil agent/recruteur',
          value: _formatMapSummary(user.agentProfile),
        ),
      ];
    }

    return [
      _ProfileReviewItem(
        label: 'Profil',
        value: user.bio ?? 'Aucune donnée métier avancée pour ce rôle.',
      ),
    ];
  }

  static String _formatMapSummary(Map<String, dynamic>? value) {
    if (value == null || value.isEmpty) {
      return 'Non renseigné';
    }

    return value.entries
        .take(4)
        .map((entry) => '${entry.key}: ${_formatValue(entry.value)}')
        .join(' | ');
  }

  static String _formatValue(dynamic value) {
    if (value is List) {
      return value.join(', ');
    }
    if (value is Map) {
      return '${value.length} champs';
    }
    return value?.toString() ?? 'Non renseigné';
  }
}

class _ProfileReviewSection extends StatelessWidget {
  const _ProfileReviewSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  // Même grammaire que les autres fiches du portail (AdminDetailSection) :
  // un intitulé discret et une suite de champs, sans encadré. Le panneau
  // en empile six, ce qui faisait six cartes dans une carte.
  @override
  Widget build(BuildContext context) {
    return AdminDetailSection(title: title, children: children);
  }
}

class _ProfileReviewItem extends StatelessWidget {
  const _ProfileReviewItem({required this.label, required this.value})
    : success = null;

  const _ProfileReviewItem.boolean({required this.label, required bool value})
    : value = value ? 'Oui' : 'Non',
      success = value;

  final String label;
  final String value;
  final bool? success;

  @override
  Widget build(BuildContext context) {
    final successValue = success;

    return AdminDetailField(
      label: label,
      value: value,
      valueColor: successValue == null
          ? null
          : (successValue ? AdminTheme.success : AdminTheme.warning),
      child: successValue == null
          ? null
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  successValue
                      ? Icons.check_circle_outline_rounded
                      : Icons.error_outline_rounded,
                  size: 14,
                  color: successValue ? AdminTheme.success : AdminTheme.warning,
                ),
                const SizedBox(width: AdminTheme.space2 - 2),
                Expanded(
                  child: Text(
                    value,
                    style: AdminType.body.copyWith(
                      color: successValue
                          ? AdminTheme.success
                          : AdminTheme.warning,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
