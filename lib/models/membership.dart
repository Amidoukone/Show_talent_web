import 'package:cloud_firestore/cloud_firestore.dart';

/// Les deux populations que l'agence distingue, plus l'absence de dossier.
///
/// - [adfoot] : sous contrat avec l'agence. Ne paie rien, jamais : ni
///   inscription ni accompagnement. L'agence forme et cherche des
///   opportunités.
/// - [external] : libre de tout lien avec l'agence, paie les services
///   qu'il utilise.
/// - [none] : ce que porte aujourd'hui chaque compte, et ce qu'un compte
///   porte tant que l'administration n'a rien enregistré. Ce n'est
///   volontairement **pas** un synonyme d'[external] : un compte sans dossier
///   doit continuer à se comporter exactement comme aujourd'hui.
enum MembershipTier { none, adfoot, external }

/// Ce que l'administration a enregistré sur les droits d'un compte.
///
/// C'est un *reflet*, jamais une source de vérité sur l'argent. Le paiement a
/// lieu hors de la plateforme — mobile money, virement, espèces à l'agence —
/// et l'administration en enregistre le résultat depuis ce portail.
/// L'application mobile n'affiche aucun prix, n'offre aucun moyen de payer et
/// ne renvoie vers aucun : c'est ce qui maintient vraie la déclaration Play
/// Console « aucun achat intégré ». Aucun montant ne doit entrer ici.
///
/// Le champ `membership` n'est écrit que par le callable
/// `setManagedAccountMembership`, qui tourne sous le SDK Admin : ni le mobile
/// ni ce portail n'y touchent directement.
class Membership {
  const Membership({
    this.tier = MembershipTier.none,
    this.startedAt,
    this.validUntil,
    this.reference,
  });

  final MembershipTier tier;
  final DateTime? startedAt;

  /// Échéance des droits, ou null quand ils n'en ont pas.
  ///
  /// Null est le cas normal d'un joueur [MembershipTier.adfoot] : il est lié à
  /// l'agence par un contrat, pas par une période d'abonnement.
  final DateTime? validUntil;

  /// La référence interne du paiement ou du contrat.
  ///
  /// Texte libre, conservé pour répondre à une question sur un compte sans
  /// sortir du portail. Jamais affiché dans l'application mobile.
  final String? reference;

  static const Membership none = Membership();

  /// Les valeurs acceptées par le callable, dans l'ordre d'affichage.
  static const List<MembershipTier> selectableTiers = <MembershipTier>[
    MembershipTier.none,
    MembershipTier.adfoot,
    MembershipTier.external,
  ];

  /// Durée maximale accordable en un appel, alignée sur le callable.
  static const Duration maxValidity = Duration(days: 5 * 365);

  /// Longueur maximale conservée par le callable pour [reference].
  static const int referenceMaxLength = 120;

  bool get isRecorded => tier != MembershipTier.none;

  /// Vrai pour un joueur que l'agence porte à ses frais.
  bool get isAgencyPlayer => tier == MembershipTier.adfoot;

  /// Vrai tant que les droits sont enregistrés et non échus.
  ///
  /// Un compte sans dossier n'est pas « expiré », il est non enregistré — voir
  /// [MembershipTier.none]. Un appelant qui conditionne quelque chose doit
  /// décider explicitement du sort d'un compte non enregistré plutôt que de le
  /// laisser tomber dans la même branche qu'un compte échu.
  bool isActiveAt(DateTime now) {
    if (!isRecorded) return false;
    final until = validUntil;
    return until == null || until.isAfter(now);
  }

  bool isLapsedAt(DateTime now) => isRecorded && !isActiveAt(now);

  static MembershipTier parseTier(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'adfoot':
        return MembershipTier.adfoot;
      case 'external':
      case 'externe':
        return MembershipTier.external;
      default:
        return MembershipTier.none;
    }
  }

  static String tierToString(MembershipTier tier) {
    switch (tier) {
      case MembershipTier.adfoot:
        return 'adfoot';
      case MembershipTier.external:
        return 'external';
      case MembershipTier.none:
        return 'none';
    }
  }

  static String tierLabelOf(MembershipTier tier) {
    switch (tier) {
      case MembershipTier.adfoot:
        return 'Adfoot (sous contrat)';
      case MembershipTier.external:
        return 'Externe (services payés)';
      case MembershipTier.none:
        return 'Aucun droit enregistré';
    }
  }

  static String tierDescriptionOf(MembershipTier tier) {
    switch (tier) {
      case MembershipTier.adfoot:
        return "Le compte est suivi par l'agence et ne paie rien.";
      case MembershipTier.external:
        return 'Le compte règle les services utilisés, hors de la plateforme.';
      case MembershipTier.none:
        return "Aucun dossier : le compte se comporte comme avant tout enregistrement.";
    }
  }

  String get tierLabel => tierLabelOf(tier);

  /// Résumé lisible de l'état des droits à l'instant [now].
  String statusLabelAt(DateTime now) {
    if (!isRecorded) return 'Aucun droit enregistré';

    final until = validUntil;
    if (until == null) return '$tierLabel, sans terme';
    if (until.isAfter(now)) {
      return "$tierLabel, jusqu'au ${formatDate(until)}";
    }
    return '$tierLabel, échu le ${formatDate(until)}';
  }

  /// Lit la map `membership` d'un document utilisateur.
  ///
  /// Toute forme inattendue donne [none] plutôt qu'une exception : cette map
  /// est écrite par un outil qui évoluera, et un profil ne doit jamais
  /// échouer à se charger parce qu'un champ de droits est arrivé sous une
  /// forme que cette version ne connaît pas.
  factory Membership.fromMap(Object? raw) {
    if (raw is! Map) return none;
    final map = Map<String, dynamic>.from(raw);
    final reference = map['reference']?.toString().trim();

    return Membership(
      tier: parseTier(map['tier']),
      startedAt: _parseDate(map['startedAt']),
      validUntil: _parseDate(map['validUntil']),
      reference: (reference == null || reference.isEmpty) ? null : reference,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tier': tierToString(tier),
      'startedAt': startedAt == null ? null : Timestamp.fromDate(startedAt!),
      'validUntil': validUntil == null ? null : Timestamp.fromDate(validUntil!),
      'reference': reference,
    };
  }

  static DateTime? _parseDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  static String formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}
