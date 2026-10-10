import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/error_reporting_service.dart';
import 'app_bindings.dart';
import 'app_environment.dart';
import 'firebase_bootstrap.dart';

class AppBootstrap {
  AppBootstrap._();

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    _configureSystemUi();

    if (!AppEnvironmentConfig.visualQaMode) {
      await ErrorReportingService.initialize();
      await FirebaseBootstrap.initialize();
      await FirebaseAuth.instance.setLanguageCode('fr');
    }

    AppBindings.registerPermanentDependencies();
    _configureFlutterErrors();
  }

  static void reportZoneError(Object error, StackTrace stack) {
    // Volontairement visible en release (pas seulement en debug) : avant
    // ErrorReportingService, c'était le seul filet de sécurité pour détecter
    // une erreur non interceptée en production (consultable via les
    // devtools navigateur). Reste en place en complément : la console
    // navigateur n'exige aucune configuration et aide au débogage local.
    debugPrint('Uncaught zone error: $error\n$stack');
    ErrorReportingService.captureError(error, stack);
  }

  static void _configureSystemUi() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
  }

  static void _configureFlutterErrors() {
    FlutterError.onError = (FlutterErrorDetails details) {
      // Volontairement sans garde kDebugMode : en release, c'est le seul
      // moyen de voir une erreur de build/widget via la console navigateur.
      FlutterError.dumpErrorToConsole(details);
      ErrorReportingService.captureError(
        details.exception,
        details.stack ?? StackTrace.current,
      );
    };
  }
}
