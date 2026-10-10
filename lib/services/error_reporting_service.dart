import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/app_environment.dart';

/// Télémétrie d'erreur pour le portail admin web.
///
/// Avant ce service, les erreurs non interceptées en production
/// (`AppBootstrap.reportZoneError` / `FlutterError.onError`) n'allaient nulle
/// part d'autre que la console du navigateur — personne n'était notifié,
/// aucun historique n'existait.
///
/// Inactif par défaut, à l'image d'[AppCheckService] : il faut à la fois
/// `SENTRY_ENABLED=true` et un `SENTRY_DSN` non vide pour qu'il s'active. Un
/// build sans ces dart-defines se comporte exactement comme avant son
/// introduction.
class ErrorReportingService {
  ErrorReportingService._();

  static const bool _enabled = bool.fromEnvironment(
    'SENTRY_ENABLED',
    defaultValue: false,
  );
  static const String _dsn = String.fromEnvironment('SENTRY_DSN');

  static bool get isEnabled => _enabled && _dsn.isNotEmpty;

  static Future<void> initialize() async {
    if (!isEnabled) {
      if (kDebugMode) {
        debugPrint(
          '[ErrorReportingService] disabled '
          '(SENTRY_ENABLED=$_enabled, dsnConfigured=${_dsn.isNotEmpty})',
        );
      }
      return;
    }

    try {
      await SentryFlutter.init((options) {
        options.dsn = _dsn;
        options.environment = AppEnvironmentConfig.environmentName;
        // Pas de traces de performance ni de PII : ce service ne sert qu'à
        // savoir qu'une erreur a eu lieu et à en lire la pile d'appels, pas à
        // profiler le portail ni à faire remonter des données utilisateur
        // (comptes mineurs notamment).
        options.tracesSampleRate = 0.0;
        options.sendDefaultPii = false;
      });

      if (kDebugMode) {
        debugPrint(
          '[ErrorReportingService] activated for '
          'env=${AppEnvironmentConfig.environmentName}',
        );
      }
    } catch (e) {
      // Non-bloquant : un échec d'activation de la télémétrie ne doit jamais
      // empêcher le démarrage du portail (même filet que AppCheckService).
      if (kDebugMode) {
        debugPrint('[ErrorReportingService] activation failed (non-blocking): $e');
      }
    }
  }

  /// Signale une erreur déjà capturée (zone non interceptée ou erreur de
  /// build de widget). Fire-and-forget : les deux appelants sont des
  /// callbacks synchrones (`FlutterError.onError`, le handler de
  /// `runZonedGuarded`) qui ne peuvent pas attendre un aller-retour réseau.
  static void captureError(Object error, StackTrace stackTrace) {
    if (!isEnabled) {
      return;
    }

    // ignore: discarded_futures
    Sentry.captureException(error, stackTrace: stackTrace);
  }
}
