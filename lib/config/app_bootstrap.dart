import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_bindings.dart';
import 'app_environment.dart';
import 'firebase_bootstrap.dart';

class AppBootstrap {
  AppBootstrap._();

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    _configureSystemUi();

    if (!AppEnvironmentConfig.visualQaMode) {
      await FirebaseBootstrap.initialize();
      await FirebaseAuth.instance.setLanguageCode('fr');
    }

    AppBindings.registerPermanentDependencies();
    _configureFlutterErrors();
  }

  static void reportZoneError(Object error, StackTrace stack) {
    if (!kDebugMode) {
      return;
    }

    debugPrint('Uncaught zone error: $error\n$stack');
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
      if (kDebugMode) {
        FlutterError.dumpErrorToConsole(details);
      }
    };
  }
}
