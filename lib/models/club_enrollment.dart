import 'package:cloud_firestore/cloud_firestore.dart';

/// L'habilitation d'un club à déclarer ses joueurs.
///
/// Deux habilitations existent sur un compte club, et elles ne se
/// conditionnent jamais l'une l'autre.
///
/// [ClubEnrollment] est le droit de déclarer des joueurs, et **il ne s'achète
/// pas** : un club qui enrôle quarante joueurs fait le travail de saisie à la
/// place d'Adfoot, et facturer ce service-là serait facturer un fournisseur.
/// Il est accordé par l'administration contre un accord signé, dont ce dossier
/// porte la référence, et il a un terme.
///
/// `Membership` est l'abonnement professionnel, qui achète autre chose :
/// publier des opportunités, chercher des profils, recevoir des mises en
/// relation. Un club peut donc déclarer son effectif gratuitement et pour
/// toujours, et payer le jour où il veut recruter.
///
/// Le droit ne vient jamais du rôle : un compte de rôle `club` sans
/// habilitation ne déclare personne. Le champ `clubEnrollment` n'est écrit que
/// par les callables `setClubEnrollmentRight` et `revokeClubEnrollment`, qui
/// tournent sous le SDK Admin ; ni le mobile ni ce portail n'y touchent
/// directement, et les règles Firestore refusent qu'un club se l'accorde.
///
/// Miroir de `readClubEnrollmentRight` dans
/// `functions/src/club_enrollment.ts`. Les deux doivent lire la même chose,
/// sinon le portail affiche un droit que le serveur refuse.
class ClubEnrollment {
  const ClubEnrollment({
    this.granted = false,
    this.grantedAt,
    this.validUntil,
    this.agreementRef,
  });

  /// Si une habilitation a été enregistrée un jour.
  final bool granted;

  final DateTime? grantedAt;

  /// Terme de l'habilitation.
  ///
  /// Toujours renseigné sur une habilitation accordée : le callable l'exige,
  /// contrairement à l'abonnement qui accepte un droit sans terme. Un droit
  /// que personne ne revisite finit par survivre à l'accord qu'il représente.
  final DateTime? validUntil;

  /// Référence de l'accord signé avec ce club.
  ///
  /// Tous les clubs n'ont pas le même accord, donc l'habilitation pointe vers
  /// celui qui a été signé. Le document lui-même vit dans
  /// `clubAgreements/{clubUid}` sur le stockage, en lecture administration
  /// seule.
  final String? agreementRef;

  static const ClubEnrollment absent = ClubEnrollment();

  /// Durée maximale accordable en un appel, alignée sur le callable.
  static const Duration maxValidity = Duration(days: 5 * 365);

  static bool isGrantDateValid(DateTime deadline) {
    final now = DateTime.now();
    return deadline.isAfter(now) && deadline.difference(now) <= maxValidity;
  }

  /// Si l'habilitation a dépassé son terme.
  ///
  /// Une habilitation sans terme lisible est traitée comme échue, exactement
  /// comme côté serveur : un document à moitié écrit ne doit pas valoir
  /// autorisation.
  bool get expired {
    if (!granted) return false;
    final deadline = validUntil;
    if (deadline == null) return true;
    return !deadline.isAfter(DateTime.now());
  }

  /// Si l'habilitation autorise un enrôlement maintenant.
  bool get active => granted && !expired;

  /// Délai au-delà duquel une échéance n'est pas encore une alerte.
  ///
  /// Trente jours : un renouvellement passe par un accord signé entre deux
  /// parties, ce qui prend des semaines. Prévenir l'avant-veille ne sert à
  /// rien, et prévenir six mois avant transforme l'alerte en décor.
  static const Duration renewalWarningWindow = Duration(days: 30);

  /// Si l'habilitation est encore valable mais arrive à son terme.
  ///
  /// Dérivé propre à ce portail, et absent du modèle mobile comme du serveur :
  /// l'application n'a rien à faire de cette nuance — une habilitation est
  /// active ou elle ne l'est pas — alors que l'administration a besoin de
  /// repérer un renouvellement à préparer sans ouvrir chaque ligne. Les champs
  /// lus restent exactement les mêmes des deux côtés.
  bool expiresSoon({DateTime? now}) {
    if (!active) return false;
    final deadline = validUntil;
    if (deadline == null) return false;
    final reference = now ?? DateTime.now();
    return deadline.isBefore(reference.add(renewalWarningWindow));
  }

  /// Ce que le portail affiche sur la ligne d'un club.
  ///
  /// La distinction entre « pas habilité » et « échue » compte : la première
  /// situation demande un accord signé, la seconde un renouvellement. Les
  /// confondre fait perdre du temps à l'administration comme au club.
  String get statusLabel {
    if (!granted) return 'Non habilité';
    if (expired) return 'Habilitation échue';
    return 'Habilité';
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  factory ClubEnrollment.fromMap(Object? raw) {
    if (raw is! Map) return absent;
    final map = Map<String, dynamic>.from(raw);
    final reference = map['agreementRef']?.toString().trim();
    return ClubEnrollment(
      granted: true,
      grantedAt: _readDate(map['grantedAt']),
      validUntil: _readDate(map['validUntil']),
      agreementRef: (reference == null || reference.isEmpty) ? null : reference,
    );
  }
}
