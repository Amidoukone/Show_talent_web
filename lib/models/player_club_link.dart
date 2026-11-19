import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/country_codes.dart';
import 'football_vocabulary.dart';

/// Le rattachement d'un joueur à un club, de la déclaration à la clôture.
///
/// Le club déclare, le joueur confirme, et la fiche se publie sans qu'Adfoot
/// intervienne. C'est ce qui fait passer la charge de vérification du nombre
/// de joueurs au nombre de clubs.
///
/// **La collection est une zone de quarantaine.** Rien de ce qu'un club saisit
/// ne touche le profil public avant confirmation du joueur, et `firestore.rules`
/// n'autorise **aucune écriture cliente** : tout passe par les callables du
/// dépôt mobile, seuls à connaître les transitions permises. Ce portail est un
/// client de ce point de vue, donc il lit, et agit par `endClubLink`.
///
/// Miroir en lecture de `functions/src/club_links.ts` et des états de
/// `functions/src/club_enrollment.ts`.
class PlayerClubLink {
  const PlayerClubLink({
    required this.id,
    required this.clubUid,
    required this.clubName,
    required this.playerUid,
    required this.status,
    this.declaredFacts = const <String, dynamic>{},
    this.confirmedFacts = const <String, dynamic>{},
    this.corrections = const <String, dynamic>{},
    this.declaredUnderAgreementRef,
    this.declaredAt,
    this.confirmedAt,
    this.contestedAt,
    this.endedAt,
    this.updatedAt,
    this.declaredBy,
    this.endedBy,
    this.endedReason,
    this.contestReason,
    this.reviewRequired = false,
    this.reviewReason,
    this.reviewRequestedAt,
    this.reviewRequestedBy,
    this.revocationReason,
  });

  /// Le club a déclaré le joueur, le joueur n'a pas encore répondu.
  static const String statusDeclared = 'declared';

  /// Le joueur a confirmé : l'affiliation est active.
  static const String statusConfirmed = 'confirmed';

  /// Le joueur conteste : l'état public est gelé, l'administration tranche.
  static const String statusContested = 'contested';

  /// Le rattachement est terminé et conservé en historique.
  static const String statusEnded = 'ended';

  /// Les états dans lesquels un rattachement est encore en cours.
  ///
  /// Miroir de `OPEN_LINK_STATUSES`. C'est aussi l'ensemble sur lequel la file
  /// des exceptions interroge la collection : un rattachement clos n'attend
  /// plus personne.
  static const List<String> openStatuses = <String>[
    statusDeclared,
    statusConfirmed,
    statusContested,
  ];

  /// Motif inscrit par la cascade de révocation d'habilitation.
  ///
  /// Miroir de `REVOCATION_REASON`. Le reconnaître permet de dire *pourquoi*
  /// un réexamen est demandé plutôt que d'afficher un code.
  static const String reasonEnrollmentRevoked = 'club_enrollment_revoked';

  final String id;
  final String clubUid;

  /// Nom du club au moment de la déclaration, tel que le callable l'a figé.
  final String clubName;

  final String playerUid;

  /// `declared`, `confirmed`, `contested` ou `ended`.
  final String status;

  /// Ce que le club a saisi, en quarantaine tant que le joueur n'a pas répondu.
  final Map<String, dynamic> declaredFacts;

  /// Ce que le joueur a accepté, et qui est entré dans son profil.
  final Map<String, dynamic> confirmedFacts;

  /// Ce que le joueur a corrigé en confirmant.
  ///
  /// Une correction n'est pas un litige : le joueur reste le dernier mot sur
  /// ce qui le concerne, et contester le rattachement lui-même est une autre
  /// action. La distinction compte pour qui arbitre.
  final Map<String, dynamic> corrections;

  /// Référence de l'accord sous lequel la déclaration a été faite.
  ///
  /// C'est elle qui rend la cascade de révocation possible : retirer
  /// l'habilitation d'un club doit pouvoir retrouver ce qu'il a déclaré.
  final String? declaredUnderAgreementRef;

  final DateTime? declaredAt;
  final DateTime? confirmedAt;
  final DateTime? contestedAt;
  final DateTime? endedAt;
  final DateTime? updatedAt;

  final String? declaredBy;
  final String? endedBy;

  /// Pourquoi le rattachement a été clos, quand ce n'est pas un geste humain.
  final String? endedReason;

  /// Motif écrit par le joueur en contestant.
  final String? contestReason;

  /// Posé par la cascade de révocation sur une affiliation confirmée.
  ///
  /// Le joueur a lu ce que son club déclarait et l'a accepté ; sa confirmation
  /// ne devient pas fausse parce que l'accord de son club a été retiré. Ce que
  /// la révocation retire, c'est la caution d'Adfoot sur cette provenance, pas
  /// le fait lui-même — d'où un signalement, et non une annulation.
  final bool reviewRequired;

  final String? reviewReason;
  final DateTime? reviewRequestedAt;
  final String? reviewRequestedBy;

  /// Motif saisi par l'administration en retirant l'habilitation.
  final String? revocationReason;

  bool get isDeclared => status == statusDeclared;
  bool get isConfirmed => status == statusConfirmed;
  bool get isContested => status == statusContested;
  bool get isEnded => status == statusEnded;
  bool get isOpen => openStatuses.contains(status);

  /// Si la révocation d'une habilitation est à l'origine du réexamen.
  bool get reviewFollowsRevocation =>
      reviewRequired && reviewReason == reasonEnrollmentRevoked;

  /// L'instant qui compte pour dater l'exception, et non la dernière écriture.
  ///
  /// `updatedAt` bouge à chaque passage de la cascade de révocation, y compris
  /// sur des rattachements que personne n'a touchés depuis des mois : trier
  /// une file d'arbitrage dessus ferait remonter des dossiers anciens comme
  /// s'ils venaient d'arriver. L'horodatage de l'événement qui a créé
  /// l'exception est le bon.
  DateTime? get exceptionRaisedAt {
    if (isContested) return contestedAt ?? updatedAt;
    if (reviewRequired) return reviewRequestedAt ?? updatedAt;
    return declaredAt ?? updatedAt;
  }

  /// Ce que le portail affiche comme état.
  String get statusLabel {
    switch (status) {
      case statusDeclared:
        return 'Déclaré, en attente du joueur';
      case statusConfirmed:
        return 'Confirmé par le joueur';
      case statusContested:
        return 'Contesté';
      case statusEnded:
        return 'Clos';
      default:
        // Un état inconnu vient d'une écriture que ce portail ne connaît pas
        // encore. Le montrer tel quel vaut mieux que de le traduire au
        // hasard : l'opérateur saura qu'il doit lire le dépôt mobile.
        return status.isEmpty ? 'État inconnu' : status;
    }
  }

  /// Les faits qui font foi aujourd'hui : les confirmés, sinon les déclarés.
  Map<String, dynamic> get effectiveFacts =>
      confirmedFacts.isNotEmpty ? confirmedFacts : declaredFacts;

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  static String? _readString(Object? value) {
    final normalized = value?.toString().trim();
    return (normalized == null || normalized.isEmpty) ? null : normalized;
  }

  static Map<String, dynamic> _readMap(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.unmodifiable(
        value.map((key, entry) => MapEntry(key.toString(), entry)),
      );
    }
    return const <String, dynamic>{};
  }

  factory PlayerClubLink.fromMap(Map<String, dynamic> map, {String? docId}) {
    final id = _readString(map['id']) ?? docId ?? '';

    return PlayerClubLink(
      id: id,
      clubUid: _readString(map['clubUid']) ?? '',
      clubName: _readString(map['clubName']) ?? '',
      playerUid: _readString(map['playerUid']) ?? '',
      status: map['status']?.toString().trim().toLowerCase() ?? '',
      declaredFacts: _readMap(map['declaredFacts']),
      confirmedFacts: _readMap(map['confirmedFacts']),
      corrections: _readMap(map['corrections']),
      declaredUnderAgreementRef: _readString(map['declaredUnderAgreementRef']),
      declaredAt: _readDate(map['declaredAt']),
      confirmedAt: _readDate(map['confirmedAt']),
      contestedAt: _readDate(map['contestedAt']),
      endedAt: _readDate(map['endedAt']),
      updatedAt: _readDate(map['updatedAt']),
      declaredBy: _readString(map['declaredBy']),
      endedBy: _readString(map['endedBy']),
      endedReason: _readString(map['endedReason']),
      contestReason: _readString(map['contestReason']),
      reviewRequired: map['reviewRequired'] == true,
      reviewReason: _readString(map['reviewReason']),
      reviewRequestedAt: _readDate(map['reviewRequestedAt']),
      reviewRequestedBy: _readString(map['reviewRequestedBy']),
      revocationReason: _readString(map['revocationReason']),
    );
  }

  factory PlayerClubLink.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return PlayerClubLink.fromMap(
      doc.data() ?? <String, dynamic>{},
      docId: doc.id,
    );
  }
}

/// Les faits sportifs d'un rattachement, en français lisible.
///
/// La carte est stockée avec les codes du vocabulaire partagé
/// (`positionCodes`, `strongFoot`, `currentClubLevel`, nationalités en ISO
/// 3166-1 alpha-2). Les afficher bruts obligerait un opérateur à connaître
/// « ST », « CIV » et « semi_pro » pour arbitrer un litige.
///
/// Les six clés sont exactement celles que `sanitizeDeclaredFacts` retient :
/// une clé inconnue est donc une écriture qui a contourné le callable, et elle
/// s'affiche telle quelle plutôt que d'être passée sous silence.
String describeClubLinkFacts(Map<String, dynamic> facts) {
  if (facts.isEmpty) return '';

  final parts = <String>[];

  final positions = FootballVocabulary.positions(facts['positionCodes']);
  if (positions.isNotEmpty) {
    parts.add(
      'Postes : ${positions.map((position) => position.labelFr).join(', ')}',
    );
  }

  final nationalities = facts['nationalities'];
  if (nationalities is List && nationalities.isNotEmpty) {
    final labels = nationalities
        .map(countryLabel)
        .where((label) => label.isNotEmpty)
        .join(', ');
    if (labels.isNotEmpty) parts.add('Nationalités : $labels');
  }

  final strongFoot = FootballVocabulary.strongFoot(facts['strongFoot']);
  if (strongFoot != null) parts.add('Pied fort : ${strongFoot.labelFr}');

  final clubLevel = FootballVocabulary.clubLevel(facts['currentClubLevel']);
  if (clubLevel != null) parts.add('Niveau : ${clubLevel.labelFr}');

  final heightCm = facts['heightCm'];
  if (heightCm is num) parts.add('Taille : ${heightCm.toInt()} cm');

  final weightKg = facts['weightKg'];
  if (weightKg is num) parts.add('Poids : ${weightKg.toInt()} kg');

  const known = <String>{
    'positionCodes',
    'nationalities',
    'strongFoot',
    'currentClubLevel',
    'heightCm',
    'weightKg',
  };
  for (final key in facts.keys) {
    if (known.contains(key)) continue;
    parts.add('$key : ${facts[key]}');
  }

  return parts.join('\n');
}
