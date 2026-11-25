import 'package:flutter/material.dart';

import '../models/contact_leak_report.dart';
import '../models/membership.dart';
import '../models/user.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';
import '../utils/admin_date_format.dart';
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
        if (user.isPlayer) ...[
          const SizedBox(height: 14),
          _ProfileReviewSection(
            title: 'Statut contractuel',
            children: _buildContractStatusItems(user),
          ),
        ],
        if (user.isMinorProfile) ...[
          const SizedBox(height: 14),
          _ProfileReviewSection(
            title: 'Accord du représentant légal',
            children: _buildGuardianConsentItems(user),
          ),
        ],
        if (user.contactLeakFlagged) ...[
          const SizedBox(height: 14),
          _ProfileReviewSection(
            title: 'Coordonnées retirées',
            children: _buildContactLeakItems(user),
          ),
        ],
        if (user.isClub) ...[
          const SizedBox(height: 14),
          _ProfileReviewSection(
            title: 'Habilitation à déclarer',
            children: _buildClubEnrollmentItems(user),
          ),
        ],
        const SizedBox(height: 14),
        _ProfileReviewSection(
          title: 'Profil métier mobile',
          children: _buildRoleProfileItems(user),
        ),
      ],
    );
  }

  /// L'accord parental d'une fiche mineure, et ce qu'il couvre.
  ///
  /// Deux autorisations distinctes, et les confondre se paierait : un
  /// représentant peut accepter que la fiche existe sans accepter qu'on y
  /// publie des vidéos de l'enfant. La première conditionne la publication de
  /// la fiche, la seconde celle des médias.
  ///
  /// L'accord s'enregistre par « Gérer le profil », qui envoie
  /// `guardianConsent` au callable — y compris sur un compte déjà créé, ce qui
  /// est exactement ce qu'il faut quand un club déclare un mineur avant
  /// d'avoir recueilli l'accord.
  static List<_ProfileReviewItem> _buildGuardianConsentItems(AppUser user) {
    return [
      _ProfileReviewItem.boolean(
        label: 'Fiche publiable',
        value: user.minorProfileApproved,
      ),
      _ProfileReviewItem.boolean(
        label: 'Publication de médias autorisée',
        value: user.minorMediaConsentApproved,
      ),
      if (user.awaitsGuardianConsent)
        _ProfileReviewItem(
          label: 'Ce qui bloque',
          value:
              'La projection publique refuse de publier une fiche mineure '
              'sans accord enregistré. Le compte fonctionne, la fiche '
              'n’apparaît nulle part. Enregistrez l’accord par « Gérer le '
              'profil ».',
        ),
      if (user.minorProfileApproved && !user.minorMediaConsentApproved)
        _ProfileReviewItem(
          label: 'Portée de l’accord',
          value:
              'La fiche est publiable, les médias ne le sont pas : l’accord '
              'recueilli ne couvre pas la publication de vidéos.',
        ),
    ];
  }

  /// Les champs libres dont le serveur a retiré des coordonnées.
  ///
  /// Montré sur la fiche en plus de l'écran dédié, et pour une autre
  /// question : l'écran dédié sert à traiter la file, la fiche répond à
  /// « ce compte a-t-il déjà tenté de contourner ? » au moment où on décide
  /// de le certifier ou de le suspendre.
  ///
  /// Seuls les noms de champs sont listés ici. Les valeurs vivent sur l'écran
  /// des signalements, qui les montre en entier : la fiche de revue est lue
  /// pour arbitrer un compte, pas pour relire un texte retiré.
  static List<_ProfileReviewItem> _buildContactLeakItems(AppUser user) {
    return [
      _ProfileReviewItem(
        label: 'Champs concernés',
        value: user.contactLeakFields.isEmpty
            ? 'Signalé sans détail de champ'
            : user.contactLeakFields.map(describeLeakField).join(', '),
      ),
      _ProfileReviewItem(
        label: 'Ce que cela veut dire',
        value:
            'La fiche publique a été nettoyée avant publication. La valeur '
            'saisie reste sur le compte, et se relit depuis l’écran des '
            'coordonnées retirées.',
      ),
    ];
  }

  /// L'habilitation du club à déclarer ses joueurs, et son terme.
  ///
  /// Distincte des droits enregistrés juste au-dessus, et la fiche doit le
  /// montrer : l'enrôlement ne s'achète pas. Un club peut déclarer son
  /// effectif sans rien payer, et payer le jour où il veut recruter — les
  /// confondre ferait réclamer un abonnement pour un service gratuit.
  static List<_ProfileReviewItem> _buildClubEnrollmentItems(AppUser user) {
    final enrollment = user.clubEnrollment;

    return [
      _ProfileReviewItem(label: 'État', value: enrollment.statusLabel),
      _ProfileReviewItem(
        label: 'Terme',
        value: enrollment.validUntil == null
            ? (enrollment.granted ? 'Terme illisible' : 'Sans objet')
            : formatAdminDate(enrollment.validUntil!),
      ),
      if (enrollment.grantedAt != null)
        _ProfileReviewItem(
          label: 'Accordée le',
          value: formatAdminDate(enrollment.grantedAt!),
        ),
      _ProfileReviewItem(
        label: 'Accord signé',
        value: enrollment.agreementRef ?? 'Aucune référence',
      ),
      if (enrollment.expiresSoon())
        _ProfileReviewItem(
          label: 'À préparer',
          value:
              'L’habilitation arrive à son terme : un renouvellement passe '
              'par un accord signé, qui prend des semaines.',
        ),
      _ProfileReviewItem.boolean(
        label: 'Peut déclarer des joueurs aujourd’hui',
        value: enrollment.active,
      ),
    ];
  }

  /// L'état de la pièce de statut contractuel, et ce que la fiche publie.
  ///
  /// La file d'examen vit dans son propre onglet — elle se traite en lot, pas
  /// profil par profil. Ce bloc répond à l'autre question, celle qu'on se pose
  /// devant une fiche : « ce statut est-il adossé à quelque chose ? ».
  ///
  /// Les deux lignes qui comptent sont les deux dernières. « Approuvée » ne
  /// veut pas dire « publiée » : la projection publique ne publie le statut que
  /// si le joueur déclare encore celui que l'examen a couvert, date de fin
  /// comprise. Un joueur qui change de statut après coup perd l'affichage, ce
  /// qui est voulu — une approbation ne sert pas de caution à une déclaration
  /// que personne n'a lue — mais sans ces deux lignes l'opérateur conclurait à
  /// une panne.
  static List<_ProfileReviewItem> _buildContractStatusItems(AppUser user) {
    final proof = user.contractStatusProof;
    final declared = user.football.contractStatus;
    final declaredEnd = user.football.contractEndDate;
    final published = proof.publishedStatusFor(user.football);

    return [
      _ProfileReviewItem(
        label: 'Déclaré par le joueur',
        value: declared == null
            ? 'Aucun statut déclaré'
            : '${declared.labelFr}'
                  '${declaredEnd == null ? '' : ', jusqu’au ${formatAdminDate(declaredEnd)}'}',
      ),
      _ProfileReviewItem(
        label: 'Pièce justificative',
        value: proof.statusLabel,
      ),
      if (proof.submittedAt != null)
        _ProfileReviewItem(
          label: 'Déposée le',
          value: formatAdminDate(proof.submittedAt!),
        ),
      if (proof.reviewedAt != null)
        _ProfileReviewItem(
          label: 'Examinée le',
          value: formatAdminDate(proof.reviewedAt!),
        ),
      if (proof.approvedContractStatus != null)
        _ProfileReviewItem(
          label: 'Statut couvert par l’examen',
          value:
              '${proof.approvedContractStatus!.labelFr}'
              '${proof.approvedContractEndDate == null ? '' : ', jusqu’au ${formatAdminDate(proof.approvedContractEndDate!)}'}',
        ),
      if (proof.reviewNote != null)
        _ProfileReviewItem(
          label: 'Motif de l’examen',
          value: proof.reviewNote!,
        ),
      _ProfileReviewItem.boolean(
        label: 'Statut affiché sur la fiche publique',
        value: published != null,
      ),
      if (proof.isApprovedButSupersededFor(user.football))
        _ProfileReviewItem(
          label: 'Pourquoi rien n’est publié',
          value:
              'La pièce est approuvée, mais le statut saisi aujourd’hui n’est '
              'plus celui que l’examen a couvert. Le joueur doit remettre sa '
              'fiche en accord avec sa pièce, ou déposer une nouvelle pièce.',
        ),
    ];
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
              user.club.federationId ??
              user.clubProfile?['licenseNumber']?.toString() ??
              'Non renseigné',
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
              user.agent.licenceNumber ??
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

  // Recursif plutot que figé sur les champs d'un seul role : ce resume sert
  // aux profils joueur, club et agent/recruteur a la fois, avec chacun ses
  // propres champs legues. Une liste de maps (ex. `clubProfile.needs`)
  // appelait auparavant le toString() brut de chaque Map Dart ("{priority:
  // null, position: Défenseurs}"), illisible pour un operateur.
  static String _formatValue(dynamic value) {
    if (value is List) {
      return value.map(_formatValue).join(', ');
    }
    if (value is Map) {
      if (value.isEmpty) return 'Non renseigné';
      return value.entries
          .map((entry) => '${entry.key}: ${_formatValue(entry.value)}')
          .join(', ');
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
