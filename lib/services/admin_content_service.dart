import 'package:cloud_functions/cloud_functions.dart';

import '../config/app_environment.dart';
import '../models/admin_action_response.dart';
import '../models/contract_status_proof.dart';
import '../utils/firebase_functions_error.dart';

class AdminContentService {
  AdminContentService({FirebaseFunctions? functions})
    : _functions =
          functions ??
          FirebaseFunctions.instanceFor(
            region: AppEnvironmentConfig.functionsRegion,
          ),
      _visualQaMode = false;

  AdminContentService.visualQa() : _functions = null, _visualQaMode = true;

  final FirebaseFunctions? _functions;
  final bool _visualQaMode;

  Future<AdminActionResponse> _callable(
    String callableName, {
    required Map<String, dynamic> payload,
    required String fallbackMessage,
  }) async {
    if (_visualQaMode) {
      return AdminActionResponse.failure(
        message: 'Action indisponible pendant la QA visuelle locale.',
        retriable: false,
      );
    }

    try {
      final callable = _functions!.httpsCallable(callableName);
      final response = await callable.call(payload);
      final data = response.data;
      final map = data is Map<String, dynamic>
          ? data
          : data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      return AdminActionResponse.fromMap(map);
    } on FirebaseFunctionsException catch (error) {
      return AdminActionResponse.failure(
        code: error.code,
        message: describeFunctionsError(
          error,
          fallbackMessage: fallbackMessage,
        ),
        retriable: error.code == 'unavailable',
      );
    } catch (_) {
      return AdminActionResponse.failure(
        message: fallbackMessage,
        retriable: true,
      );
    }
  }

  Future<AdminActionResponse> setOfferStatus({
    required String offerId,
    required String status,
  }) {
    return _callable(
      'adminSetOfferStatus',
      payload: <String, dynamic>{
        'offerId': offerId.trim(),
        'status': status.trim(),
      },
      fallbackMessage:
          "Mise à jour du statut de l’offre impossible pour le moment.",
    );
  }

  Future<AdminActionResponse> deleteOffer({required String offerId}) {
    return _callable(
      'adminDeleteOffer',
      payload: <String, dynamic>{'offerId': offerId.trim()},
      fallbackMessage: "Suppression de l’offre impossible pour le moment.",
    );
  }

  Future<AdminActionResponse> setEventStatus({
    required String eventId,
    required String status,
  }) {
    return _callable(
      'adminSetEventStatus',
      payload: <String, dynamic>{
        'eventId': eventId.trim(),
        'status': status.trim(),
      },
      fallbackMessage:
          "Mise à jour du statut de l’événement impossible pour le moment.",
    );
  }

  Future<AdminActionResponse> deleteEvent({required String eventId}) {
    return _callable(
      'adminDeleteEvent',
      payload: <String, dynamic>{'eventId': eventId.trim()},
      fallbackMessage: "Suppression de l’événement impossible pour le moment.",
    );
  }

  Future<AdminActionResponse> setVideoStatus({
    required String videoId,
    required String status,
    String reason = '',
  }) {
    return _callable(
      'adminSetVideoStatus',
      payload: <String, dynamic>{
        'videoId': videoId.trim(),
        'status': status.trim(),
        if (reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
      fallbackMessage: 'Mise à jour du statut vidéo impossible pour le moment.',
    );
  }

  Future<AdminActionResponse> rejectVideo({
    required String videoId,
    String reason = '',
  }) {
    return _callable(
      'adminRejectVideo',
      payload: <String, dynamic>{
        'videoId': videoId.trim(),
        if (reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
      fallbackMessage: 'Refus de la vidéo impossible pour le moment.',
    );
  }

  Future<AdminActionResponse> deleteVideo({required String videoId}) {
    return _callable(
      'adminDeleteVideo',
      payload: <String, dynamic>{'videoId': videoId.trim()},
      fallbackMessage: 'Suppression de la vidéo impossible pour le moment.',
    );
  }

  /// Rend le verdict de l’administration sur une pièce de statut contractuel.
  ///
  /// Deux verdicts, et deux seulement : approuver ou écarter. Remettre une
  /// pièce en attente n’existe pas — le serveur le refuse — parce que ce
  /// n’est pas une décision mais son absence, et qu’une file dont on peut
  /// repousser indéfiniment les éléments n’est plus une file.
  ///
  /// Approuver demande de dire **quel** statut la pièce justifie, et la date
  /// de fin quand ce statut en attend une. Ce n’est pas une formalité : c’est
  /// cette valeur-là que la projection publique recompare au statut saisi par
  /// le joueur avant de publier quoi que ce soit. Une approbation sans statut,
  /// ou avec un statut hors de la liste fermée, est refusée par le callable.
  ///
  /// Les contrôles sont volontairement répétés ici alors que le serveur les
  /// refait : le SDK Admin ne voit pas `firestore.rules`, donc un appel mal
  /// formé coûte un aller-retour réseau et un message d’erreur technique là
  /// où l’opérateur attend une phrase. Le serveur reste l’autorité.
  Future<AdminActionResponse> reviewContractStatusProof({
    required String uid,
    String? expectedFileUrl,
    String expectedStatus = ContractStatusProof.statusPending,
    int? expectedReviewRevision,
    required String status,
    String? contractStatus,
    DateTime? contractEndDate,
    String? note,
  }) {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return Future.value(
        AdminActionResponse.failure(
          code: 'invalid_uid',
          message: 'Aucun joueur désigné pour cet examen.',
        ),
      );
    }

    final normalizedExpectedStatus = expectedStatus.trim().toLowerCase();
    if (!ContractStatusProof.allStatuses.contains(normalizedExpectedStatus)) {
      return Future.value(
        AdminActionResponse.failure(
          code: 'invalid_expected_status',
          message: 'État de réexamen invalide.',
        ),
      );
    }

    final normalizedStatus = status.trim().toLowerCase();
    if (!ContractStatusProof.verdicts.contains(normalizedStatus)) {
      return Future.value(
        AdminActionResponse.failure(
          code: 'invalid_status',
          message: 'Le verdict doit être une approbation ou un rejet.',
        ),
      );
    }

    final normalizedNote = note?.trim() ?? '';
    if (normalizedNote.length > ContractStatusProof.maxReviewNoteLength) {
      return Future.value(
        AdminActionResponse.failure(
          code: 'note_too_long',
          message:
              'Le motif dépasse '
              '${ContractStatusProof.maxReviewNoteLength} caractères.',
        ),
      );
    }

    final normalizedContractStatus = contractStatus?.trim() ?? '';
    if (normalizedStatus == ContractStatusProof.statusApproved &&
        normalizedContractStatus.isEmpty) {
      return Future.value(
        AdminActionResponse.failure(
          code: 'missing_contract_status',
          message:
              'Approuver une pièce demande de dire quel statut elle justifie.',
        ),
      );
    }

    if (expectedFileUrl == null || expectedFileUrl.trim().isEmpty) {
      return Future.value(
        AdminActionResponse.failure(
          code: 'missing_proof_identity',
          message: 'Ouvrez et examinez la pièce avant de rendre le verdict.',
        ),
      );
    }
    return _callable(
      'reviewContractStatusProof',
      payload: <String, dynamic>{
        'uid': normalizedUid,
        'expectedFileUrl': expectedFileUrl.trim(),
        'expectedStatus': normalizedExpectedStatus,
        'expectedReviewRevision': ?expectedReviewRevision,
        'status': normalizedStatus,
        if (normalizedStatus == ContractStatusProof.statusApproved)
          'contractStatus': normalizedContractStatus,
        // Envoyée seulement quand elle existe : le serveur retombe alors sur
        // la date déjà portée par la fiche du joueur, ce qui est le bon
        // comportement quand l’opérateur n’a rien à corriger. Normalisée au
        // jour calendaire UTC pour éviter un décalage d’un jour hors UTC+0.
        if (contractEndDate != null)
          'contractEndDate': ContractStatusProof.toUtcCalendarDateIso(
            contractEndDate,
          ),
        if (normalizedNote.isNotEmpty) 'note': normalizedNote,
      },
      fallbackMessage:
          'Examen de la pièce impossible pour le moment. Réessayez.',
    );
  }

  /// Clôt un rattachement joueur-club.
  ///
  /// **La seule issue dont le portail dispose pour trancher**, et c'est une
  /// contrainte du serveur, pas un manque d'interface : `confirmClubLink`
  /// exige `playerUid == uid`, donc aucun callable ne permet de confirmer à la
  /// place du joueur. Un doublon se résout en closant le rattachement de trop,
  /// jamais en validant l'autre d'office — valider pour quelqu'un reviendrait
  /// à signer son affiliation à sa place.
  ///
  /// Le rattachement passe en `ended`, `endedBy` enregistre l'opérateur, et la
  /// fiche du joueur perd `currentClubName` et `clubAffiliation`. Les faits
  /// sportifs lui restent : son poste et sa nationalité ne changent pas parce
  /// qu'il a quitté un club.
  ///
  /// Le serveur refuse un rattachement déjà clos.
  Future<AdminActionResponse> endClubLink({required String linkId}) {
    final normalizedId = linkId.trim();
    if (normalizedId.isEmpty) {
      return Future.value(
        AdminActionResponse.failure(
          code: 'invalid_link_id',
          message: 'Aucun rattachement désigné.',
        ),
      );
    }

    return _callable(
      'endClubLink',
      payload: <String, dynamic>{'linkId': normalizedId},
      fallbackMessage:
          'Clôture du rattachement impossible pour le moment. Réessayez.',
    );
  }

  Future<AdminActionResponse> setContactIntakeFollowUp({
    required String contactIntakeId,
    required String status,
    String note = '',
  }) {
    return _callable(
      'adminSetContactIntakeFollowUp',
      payload: <String, dynamic>{
        'contactIntakeId': contactIntakeId.trim(),
        'status': status.trim(),
        'note': note.trim(),
      },
      fallbackMessage: 'Mise à jour du suivi agence impossible pour le moment.',
    );
  }

  Future<AdminActionResponse> deleteContactIntake({
    required String contactIntakeId,
    String? conversationId,
  }) {
    return _callable(
      'adminDeleteContactIntake',
      payload: <String, dynamic>{
        'contactIntakeId': contactIntakeId.trim(),
        if (conversationId?.trim().isNotEmpty == true)
          'conversationId': conversationId!.trim(),
      },
      fallbackMessage:
          'Suppression de la mise en relation impossible pour le moment.',
    );
  }

  Future<AdminActionResponse> deleteContactIntakeConversation({
    required String contactIntakeId,
    String? conversationId,
  }) {
    return _callable(
      'adminDeleteContactIntakeConversation',
      payload: <String, dynamic>{
        'contactIntakeId': contactIntakeId.trim(),
        if (conversationId?.trim().isNotEmpty == true)
          'conversationId': conversationId!.trim(),
      },
      fallbackMessage:
          'Suppression de la conversation impossible pour le moment.',
    );
  }
}
