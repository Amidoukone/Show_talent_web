import 'package:cloud_firestore/cloud_firestore.dart';

import 'football_vocabulary.dart';
import 'player_football_profile.dart';

/// La pièce qui justifie un statut contractuel, et son examen.
///
/// Le principe vient du document de conception : **sans club déclaré ne veut
/// pas dire libre de tout engagement**. Un joueur peut écrire « libre » dans
/// sa fiche sans que personne n'ait rien vérifié, et c'est précisément la
/// déclaration qu'un club lit avant d'engager des frais de déplacement et
/// d'essai.
///
/// La fiche publique n'affiche donc un statut contractuel que sur pièce
/// approuvée, et n'affiche rien sinon — pas « non vérifié », pas d'étiquette
/// de prudence : un champ absent ne ment pas, là où une mention de prudence
/// inquiète le recruteur et dévalorise le joueur. Le document interne garde la
/// valeur saisie, donc le joueur voit toujours la sienne, et ce portail aussi.
///
/// Miroir en lecture de `readContractStatusProof()` dans
/// `functions/src/contract_status_proof.ts`. Les deux doivent lire la même
/// chose, sinon le portail annonce un statut publié que la fiche n'affiche
/// pas. Rien ici ne s'écrit : le champ `contractStatusProof` est refusé au
/// client par `firestore.rules`, et seul le callable
/// `reviewContractStatusProof` y touche.
class ContractStatusProof {
  const ContractStatusProof({
    this.submitted = false,
    this.status = '',
    this.fileUrl,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewNote,
    this.approvedContractStatus,
    this.approvedContractEndDate,
    this.reviewRevision = 0,
  });

  /// L'état d'un joueur qui n'a jamais rien déposé.
  static const ContractStatusProof absent = ContractStatusProof();

  /// Déposée, en attente d'examen.
  static const String statusPending = 'pending';

  /// Examinée et retenue : le statut peut être publié.
  static const String statusApproved = 'approved';

  /// Examinée et écartée : rien n'est publié.
  static const String statusRejected = 'rejected';

  /// Les deux seuls verdicts que le callable accepte.
  ///
  /// `pending` n'en fait pas partie : il est posé par le dépôt, et le serveur
  /// refuse qu'un examen y ramène une pièce. Remettre une pièce en attente
  /// n'est pas une décision, c'est l'absence de décision.
  static const List<String> verdicts = <String>[statusApproved, statusRejected];

  /// Tous les états connus d'une pièce, utilisés comme précondition d'examen.
  static const List<String> allStatuses = <String>[
    statusPending,
    statusApproved,
    statusRejected,
  ];

  /// Longueur maximale d'un motif d'examen, alignée sur le callable
  /// (`MAX_REVIEW_NOTE_LENGTH`).
  static const int maxReviewNoteLength = 400;

  /// Si une pièce a été déposée un jour.
  final bool submitted;

  /// État de la dernière pièce déposée.
  final String status;

  /// Référence `gs://` du fichier, telle que le dépôt l'a écrite.
  final String? fileUrl;

  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  /// Identifiant de l'opérateur qui a rendu le verdict.
  final String? reviewedBy;

  /// Motif de l'examen, lisible par le titulaire.
  final String? reviewNote;

  /// Statut contractuel couvert par l'examen, quand il est favorable.
  final ContractStatus? approvedContractStatus;

  /// Fin de contrat couverte par l'examen, quand le statut en attend une.
  final DateTime? approvedContractEndDate;

  /// Révision d'examen incrémentée par le backend à chaque verdict.
  ///
  /// Sert de précondition optimiste pour révoquer une pièce déjà approuvée
  /// sans écraser une décision concurrente.
  final int reviewRevision;

  bool get isPending => submitted && status == statusPending;
  bool get isApproved => submitted && status == statusApproved;
  bool get isRejected => submitted && status == statusRejected;

  /// Compare deux dates au jour calendaire UTC (sans exiger l'égalité à la
  /// milliseconde, qui varie selon le fuseau horaire du navigateur).
  static bool isSameUtcCalendarDate(DateTime left, DateTime right) {
    final a = left.toUtc();
    final b = right.toUtc();
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Sérialise une date calendaire (ex. issue d'un sélecteur) à minuit UTC
  /// sans subir de décalage de fuseau horaire.
  static String toUtcCalendarDateIso(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day).toIso8601String();
  }

  /// Si une pièce est lisible, c'est-à-dire ouvrable par le portail.
  bool get hasFile => (fileUrl?.trim().isNotEmpty ?? false);

  /// Ce que le portail affiche sur la ligne d'un joueur.
  String get statusLabel {
    if (!submitted) return 'Aucune pièce';
    switch (status) {
      case statusPending:
        return 'En attente d’examen';
      case statusApproved:
        return 'Approuvée';
      case statusRejected:
        return 'Écartée';
      default:
        // Un état inconnu vient forcément d'une écriture serveur que ce
        // portail ne connaît pas encore. Le montrer tel quel vaut mieux que
        // de le traduire au hasard : l'opérateur saura qu'il doit lire le
        // dépôt mobile plutôt que de décider.
        return status.isEmpty ? 'État inconnu' : status;
    }
  }

  /// Le statut contractuel publié aujourd'hui sur la fiche, ou `null`.
  ///
  /// Miroir de `publishedContractStatus()` côté serveur, seule autorité sur la
  /// question. Trois conditions, et chacune ferme un cas concret :
  ///
  /// - une pièce approuvée, sinon rien n'est publié ;
  /// - le statut saisi aujourd'hui est celui que l'examen a couvert. Sans
  ///   cette comparaison, un joueur ferait approuver une lettre de libération
  ///   puis écrirait ce qu'il veut dans le champ, l'approbation servant de
  ///   caution à une déclaration que personne n'a lue ;
  /// - la date de fin saisie est celle que l'examen a couverte, quand le
  ///   statut en attend une. Une fin de contrat repoussée de deux ans change
  ///   ce qu'un club lit, autant que le statut lui-même.
  ///
  /// Le portail en a besoin pour une raison que le serveur n'a pas : montrer
  /// à l'opérateur qu'une pièce **approuvée** peut ne rien publier du tout,
  /// parce que le joueur a changé son statut depuis l'examen. Sans cette
  /// lecture, l'écran annoncerait « approuvée » devant une fiche muette.
  ContractStatus? publishedStatusFor(PlayerFootballProfile football) {
    if (!isApproved) return null;

    final approved = approvedContractStatus;
    if (approved == null) return null;

    final declared = football.contractStatus;
    if (declared == null || declared != approved) return null;

    if (!approved.expectsEndDate) return approved;

    final declaredEnd = football.contractEndDate;
    final approvedEnd = approvedContractEndDate;
    if (declaredEnd == null || approvedEnd == null) return null;
    return isSameUtcCalendarDate(declaredEnd, approvedEnd) ? approved : null;
  }

  /// Si une pièce approuvée ne publie rien, le joueur ayant changé d'avis.
  ///
  /// L'état le plus trompeur des trois : tout est en ordre côté examen, et la
  /// fiche n'affiche rien. Le nommer évite qu'un opérateur réexamine une
  /// pièce qui n'a aucun problème.
  bool isApprovedButSupersededFor(PlayerFootballProfile football) =>
      isApproved && publishedStatusFor(football) == null;

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

  static int _readNonNegativeInt(Object? value) {
    if (value is int && value >= 0) return value;
    if (value is num && value >= 0) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    return (parsed != null && parsed >= 0) ? parsed : 0;
  }

  factory ContractStatusProof.fromMap(Object? raw) {
    if (raw is! Map) return absent;
    final map = Map<String, dynamic>.from(raw);

    return ContractStatusProof(
      submitted: true,
      status: map['status']?.toString().trim().toLowerCase() ?? '',
      fileUrl: _readString(map['fileUrl']),
      submittedAt: _readDate(map['submittedAt']),
      reviewedAt: _readDate(map['reviewedAt']),
      reviewedBy: _readString(map['reviewedBy']),
      reviewNote: _readString(map['reviewNote']),
      approvedContractStatus: FootballVocabulary.contractStatus(
        map['approvedContractStatus'],
      ),
      approvedContractEndDate: _readDate(map['approvedContractEndDate']),
      reviewRevision: _readNonNegativeInt(map['reviewRevision']),
    );
  }

  /// Ce que la relecture d'un compte enrichi doit réécrire sur le document.
  ///
  /// `AppUser.toMap()` sert à reconstruire un compte après la lecture de ses
  /// champs privés (`fetchUserWithPrivateFields`). Sans cette map, la pièce
  /// disparaîtrait de l'objet reconstruit et la fiche de revue annoncerait
  /// « aucune pièce » juste après en avoir affiché une.
  Map<String, dynamic>? toMap() {
    if (!submitted) return null;

    return <String, dynamic>{
      'status': status,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (submittedAt != null) 'submittedAt': Timestamp.fromDate(submittedAt!),
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewNote != null) 'reviewNote': reviewNote,
      if (approvedContractStatus != null)
        'approvedContractStatus': approvedContractStatus!.code,
      if (approvedContractEndDate != null)
        'approvedContractEndDate': Timestamp.fromDate(approvedContractEndDate!),
      if (reviewRevision > 0) 'reviewRevision': reviewRevision,
    };
  }
}
