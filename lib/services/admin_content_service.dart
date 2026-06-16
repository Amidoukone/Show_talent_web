import 'package:cloud_functions/cloud_functions.dart';

import '../config/app_environment.dart';
import '../models/admin_action_response.dart';

class AdminContentService {
  AdminContentService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(
              region: AppEnvironmentConfig.functionsRegion,
            ),
        _visualQaMode = false;

  AdminContentService.visualQa()
      : _functions = null,
        _visualQaMode = true;

  final FirebaseFunctions? _functions;
  final bool _visualQaMode;

  String _buildFailureMessage(
    FirebaseFunctionsException error, {
    required String fallbackMessage,
  }) {
    final rawMessage = error.message?.trim() ?? '';
    final hasActionableMessage = rawMessage.isNotEmpty &&
        rawMessage.toLowerCase() != 'internal' &&
        rawMessage.toUpperCase() != 'INTERNAL';

    if (hasActionableMessage) {
      return rawMessage;
    }

    switch (error.code) {
      case 'unauthenticated':
        return 'Session admin expirée. Reconnectez-vous.';
      case 'permission-denied':
        return "Action réservée à l’administration.";
      case 'not-found':
        return 'Élément introuvable ou déjà supprimé.';
      case 'unavailable':
        return '$fallbackMessage Réessayez dans un instant.';
      case 'internal':
        return '$fallbackMessage Vérifiez aussi le déploiement Functions partagé.';
      default:
        return fallbackMessage;
    }
  }

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
        message: _buildFailureMessage(
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

  Future<AdminActionResponse> deleteOffer({
    required String offerId,
  }) {
    return _callable(
      'adminDeleteOffer',
      payload: <String, dynamic>{
        'offerId': offerId.trim(),
      },
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

  Future<AdminActionResponse> deleteEvent({
    required String eventId,
  }) {
    return _callable(
      'adminDeleteEvent',
      payload: <String, dynamic>{
        'eventId': eventId.trim(),
      },
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
      fallbackMessage: 'Refus de la video impossible pour le moment.',
    );
  }

  Future<AdminActionResponse> deleteVideo({
    required String videoId,
  }) {
    return _callable(
      'adminDeleteVideo',
      payload: <String, dynamic>{
        'videoId': videoId.trim(),
      },
      fallbackMessage: 'Suppression de la vidéo impossible pour le moment.',
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
