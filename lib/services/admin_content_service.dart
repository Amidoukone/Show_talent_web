import 'package:cloud_functions/cloud_functions.dart';

import '../models/admin_action_response.dart';

class AdminContentService {
  AdminContentService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: _functionsRegion);

  final FirebaseFunctions _functions;
  static const String _functionsRegion = 'europe-west1';

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
        return 'Session admin expiree. Reconnectez-vous.';
      case 'permission-denied':
        return 'Action reservee a l administration.';
      case 'not-found':
        return 'Element introuvable ou deja supprime.';
      case 'unavailable':
        return '$fallbackMessage Reessayez dans un instant.';
      case 'internal':
        return '$fallbackMessage Verifiez aussi le deploiement Functions partage.';
      default:
        return fallbackMessage;
    }
  }

  Future<AdminActionResponse> _callable(
    String callableName, {
    required Map<String, dynamic> payload,
    required String fallbackMessage,
  }) async {
    try {
      final callable = _functions.httpsCallable(callableName);
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
      fallbackMessage: 'Mise a jour du statut offre impossible pour le moment.',
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
      fallbackMessage: 'Suppression offre impossible pour le moment.',
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
          'Mise a jour du statut evenement impossible pour le moment.',
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
      fallbackMessage: 'Suppression evenement impossible pour le moment.',
    );
  }
}
