import 'package:cloud_firestore/cloud_firestore.dart';

/// Un signalement de coordonnées retirées avant publication.
///
/// Le serveur retire les numéros et les adresses des champs libres avant
/// qu'un tiers ne les lise, et consigne ce qu'il a retiré. Jusqu'ici personne
/// ne lisait ces traces : la capacité existait et n'atteignait aucune
/// audience.
///
/// **Un signalement par document, et non par écriture.** Une offre corrigée
/// trois fois produit une ligne mise à jour, pas trois lignes à trier :
/// l'administration traite un document, pas un historique. L'identifiant est
/// `{collection}__{docId}`, ce qui rend l'écriture idempotente.
///
/// Fermé à tout client en écriture, et en lecture à tout le monde sauf
/// l'administration — d'abord à l'auteur du signalement, qui est précisément
/// celui qu'il concerne : la ligne porte le texte d'origine, donc la rendre
/// lisible par lui rendrait le nettoyage inutile.
///
/// Miroir en lecture de `cleanOpportunityDocument()` dans
/// `functions/src/opportunity_moderation.ts`.
class ContactLeakReport {
  const ContactLeakReport({
    required this.id,
    required this.collection,
    required this.docId,
    required this.ownerUid,
    this.fields = const <String>[],
    this.originals = const <String, dynamic>{},
    this.flaggedAt,
  });

  /// Collection des offres nettoyées.
  static const String collectionOffers = 'offres';

  /// Collection des événements nettoyés.
  static const String collectionEvents = 'events';

  /// Identifiant du signalement, `{collection}__{docId}`.
  final String id;

  /// `offres` ou `events`.
  final String collection;

  /// Identifiant du document nettoyé.
  final String docId;

  /// Auteur de l'annonce.
  final String ownerUid;

  /// Champs concernés, triés.
  ///
  /// Y compris les clés du bloc d'auteur recopié, sous la forme
  /// `recruteur.email` ou `organisateur.phone` : ces clés-là ne viennent pas
  /// d'une saisie mais d'un document ancien écrit avant que les coordonnées
  /// ne déménagent dans `users/{uid}/private/contact`. La distinction compte
  /// pour qui modère — l'un est une tentative, l'autre un reliquat.
  final List<String> fields;

  /// Le texte d'origine, c'est-à-dire exactement ce qui a été retiré.
  final Map<String, dynamic> originals;

  final DateTime? flaggedAt;

  bool get isOffer => collection == collectionOffers;
  bool get isEvent => collection == collectionEvents;

  /// Ce que le portail affiche comme origine.
  String get collectionLabel {
    switch (collection) {
      case collectionOffers:
        return 'Offre';
      case collectionEvents:
        return 'Événement';
      default:
        return collection.isEmpty ? 'Origine inconnue' : collection;
    }
  }

  /// Si le signalement ne porte que des reliquats du bloc d'auteur.
  ///
  /// Un document écrit avant le déménagement des coordonnées porte encore
  /// `recruteur.email` : le nettoyage l'a retiré, et son auteur n'a rien tenté.
  /// Confondre ce cas avec une tentative de publication ferait sanctionner
  /// quelqu'un pour une migration.
  bool get isLegacyOwnerBlockOnly =>
      fields.isNotEmpty && fields.every((field) => field.contains('.'));

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  static String _readString(Object? value) => value?.toString().trim() ?? '';

  factory ContactLeakReport.fromMap(
    Map<String, dynamic> map, {
    String? docIdFallback,
  }) {
    final rawFields = map['fields'];
    final rawOriginals = map['originals'];

    return ContactLeakReport(
      id: docIdFallback ?? '',
      collection: _readString(map['collection']).toLowerCase(),
      docId: _readString(map['docId']),
      ownerUid: _readString(map['ownerUid']),
      fields: rawFields is List
          ? List<String>.unmodifiable(
              rawFields.map(_readString).where((value) => value.isNotEmpty),
            )
          : const <String>[],
      originals: rawOriginals is Map
          ? Map<String, dynamic>.unmodifiable(
              rawOriginals.map((key, value) => MapEntry(key.toString(), value)),
            )
          : const <String, dynamic>{},
      flaggedAt: _readDate(map['flaggedAt']),
    );
  }

  factory ContactLeakReport.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ContactLeakReport.fromMap(
      doc.data() ?? <String, dynamic>{},
      docIdFallback: doc.id,
    );
  }
}

/// Un profil dont des champs libres ont été nettoyés avant publication.
///
/// Pas de collection dédiée ici, contrairement aux offres : un profil a une
/// projection publique, seule écrivain du document que le monde lit, donc le
/// verdict vit sur `users/{uid}` — en lecture propriétaire et administration,
/// ce qui est exactement la bonne audience. Le document interne garde la
/// valeur saisie, et c'est elle que [currentValues] rapporte : l'opérateur
/// voit ce que l'utilisateur a voulu publier en lisant le champ lui-même.
class ContactLeakProfile {
  const ContactLeakProfile({
    required this.uid,
    required this.nom,
    required this.role,
    this.fields = const <String>[],
    this.currentValues = const <String, dynamic>{},
  });

  /// Les champs libres du profil que le serveur contrôle.
  ///
  /// Miroir de `CONTACT_SCANNED_FIELDS` dans
  /// `functions/src/contact_redaction.ts`. Sert à relire la valeur saisie du
  /// champ signalé, donc la liste doit rester alignée : un champ ajouté là-bas
  /// et absent ici se signalerait sans que sa valeur soit lisible.
  static const List<String> scannedFields = <String>[
    'nom',
    'bio',
    'position',
    'performances',
    'clubActuel',
    'currentClubName',
    'nomClub',
    'ligue',
    'entreprise',
    'team',
    'city',
    'region',
  ];

  final String uid;
  final String nom;
  final String role;

  /// Champs concernés, tels que le serveur les a consignés.
  final List<String> fields;

  /// La valeur saisie des champs signalés, telle qu'elle vit sur le document.
  final Map<String, dynamic> currentValues;

  factory ContactLeakProfile.fromMap(
    Map<String, dynamic> map, {
    String? docIdFallback,
  }) {
    final rawFields = map['contactLeakFields'];
    final fields = rawFields is List
        ? rawFields
              .map((value) => value?.toString().trim() ?? '')
              .where((value) => value.isNotEmpty)
              .toList()
        : <String>[];

    final values = <String, dynamic>{};
    for (final field in fields) {
      if (!map.containsKey(field)) continue;
      values[field] = map[field];
    }

    final uid = map['uid']?.toString().trim() ?? '';

    return ContactLeakProfile(
      uid: uid.isEmpty ? (docIdFallback ?? '') : uid,
      nom: map['nom']?.toString().trim() ?? '',
      role: map['role']?.toString().trim() ?? '',
      fields: List<String>.unmodifiable(fields),
      currentValues: Map<String, dynamic>.unmodifiable(values),
    );
  }

  factory ContactLeakProfile.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ContactLeakProfile.fromMap(
      doc.data() ?? <String, dynamic>{},
      docIdFallback: doc.id,
    );
  }
}

/// Le nom d'un champ signalé, en français.
///
/// Les clés sont celles du document, en anglais pour certaines et en français
/// pour d'autres — l'historique du modèle. Les afficher brutes obligerait un
/// opérateur à savoir que `team` et `clubActuel` désignent deux champs
/// différents du même concept.
///
/// Une clé pointée (`recruteur.email`) est rendue telle quelle après
/// traduction de son préfixe : elle désigne le bloc d'auteur recopié dans le
/// document, et nommer la clé exacte est ce qui permet de comprendre d'où elle
/// vient.
String describeLeakField(String field) {
  if (field.contains('.')) {
    final parts = field.split('.');
    final owner = parts.first == 'recruteur' ? 'Recruteur' : 'Organisateur';
    return '$owner (bloc recopié) · ${parts.sublist(1).join('.')}';
  }

  switch (field) {
    case 'nom':
      return 'Nom';
    case 'bio':
      return 'Présentation';
    case 'position':
      return 'Poste (texte libre)';
    case 'performances':
      return 'Performances';
    case 'clubActuel':
      return 'Club actuel (ancien champ)';
    case 'currentClubName':
      return 'Club actuel';
    case 'nomClub':
      return 'Nom du club';
    case 'ligue':
      return 'Ligue';
    case 'entreprise':
      return 'Organisation';
    case 'team':
      return 'Équipe';
    case 'city':
      return 'Ville';
    case 'region':
      return 'Région';
    case 'titre':
      return 'Titre';
    case 'description':
      return 'Description';
    case 'localisation':
      return 'Localisation';
    case 'remuneration':
      return 'Rémunération';
    case 'lieu':
      return 'Lieu';
    default:
      // Un champ ajouté dans le dépôt mobile et pas encore connu ici doit
      // s'afficher tel quel plutôt que de laisser un trou dans le dossier.
      return field;
  }
}
