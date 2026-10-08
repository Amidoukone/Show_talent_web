import 'package:cloud_functions/cloud_functions.dart';

/// Translates a [FirebaseFunctionsException] into a message an admin can
/// act on. Firebase often returns the literal string "INTERNAL" as
/// [FirebaseFunctionsException.message] when the callable throws without a
/// details message — showing that raw string to an admin is not actionable,
/// so it's treated the same as an absent message and replaced by
/// [fallbackMessage] or a code-specific explanation.
String describeFunctionsError(
  FirebaseFunctionsException error, {
  required String fallbackMessage,
}) {
  final rawMessage = error.message?.trim() ?? '';
  final hasActionableMessage =
      rawMessage.isNotEmpty &&
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
