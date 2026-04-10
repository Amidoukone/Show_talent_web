import '../models/user.dart';
import 'account_role_policy.dart';

class AdminAccessMessages {
  static const String sessionExpired = 'Session admin expirée.';
  static const String userNotFound = 'Utilisateur introuvable dans /users.';
  static const String roleDenied =
      "Votre compte n'est pas autorisé sur le portail admin.";
  static const String temporaryBlocked =
      'Votre compte est suspendu temporairement.';
  static const String blocked = 'Votre compte est bloqué.';
  static const String authDisabled =
      'Firebase Auth est désactivé pour ce compte.';
  static const String missingClaims =
      "Les custom claims admin sont requis pour accéder au tableau de bord.";

  static String deniedForUser(
    AppUser? appUser, {
    required bool hasClaims,
  }) {
    if (appUser == null) {
      return userNotFound;
    }
    if (!isAdminPortalOnlyRole(appUser.role)) {
      return roleDenied;
    }
    if (appUser.hasTemporaryBlock) {
      return temporaryBlocked;
    }
    if (appUser.hasActiveAppBlock) {
      return blocked;
    }
    if (appUser.authDisabled) {
      return authDisabled;
    }
    if (!hasClaims) {
      return missingClaims;
    }
    return roleDenied;
  }
}
