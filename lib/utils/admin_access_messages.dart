import '../models/user.dart';
import 'account_role_policy.dart';

class AdminAccessMessages {
  static const String sessionExpired = 'Session admin expirée.';
  static const String userNotFound =
      "Profil administrateur introuvable pour cette session.";
  static const String roleDenied =
      "Votre compte n'est pas autorisé sur le portail admin.";
  static const String authDisabled = "L'accès de ce compte est suspendu.";
  static const String missingClaims =
      "Les droits administrateur requis ne sont pas actifs pour cette session.";

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
    if (appUser.authDisabled) {
      return authDisabled;
    }
    if (!hasClaims) {
      return missingClaims;
    }
    return roleDenied;
  }
}
