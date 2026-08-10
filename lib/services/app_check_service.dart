import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;

import '../config/app_environment.dart';

/// App Check bootstrap for the admin web portal.
///
/// Inactive by default: activation requires both `APP_CHECK_ENABLED=true`
/// and a non-empty `APP_CHECK_WEB_RECAPTCHA_SITE_KEY`, so builds without
/// these dart-defines behave exactly as before this was introduced.
class AppCheckService {
  AppCheckService._();

  static const bool _enabled = bool.fromEnvironment(
    'APP_CHECK_ENABLED',
    defaultValue: false,
  );
  static const String _webRecaptchaSiteKey = String.fromEnvironment(
    'APP_CHECK_WEB_RECAPTCHA_SITE_KEY',
  );

  static Future<void> initialize() async {
    if (!kIsWeb || !_enabled || _webRecaptchaSiteKey.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[AppCheckService] disabled '
          '(APP_CHECK_ENABLED=$_enabled, siteKeyConfigured=${_webRecaptchaSiteKey.isNotEmpty})',
        );
      }
      return;
    }

    try {
      await FirebaseAppCheck.instance
          .activate(providerWeb: ReCaptchaV3Provider(_webRecaptchaSiteKey))
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        debugPrint(
          '[AppCheckService] activated for env=${AppEnvironmentConfig.environmentName}',
        );
      }
    } catch (e) {
      // Non-blocking: an App Check activation failure must never prevent
      // the admin portal from starting.
      if (kDebugMode) {
        debugPrint('[AppCheckService] activation failed (non-blocking): $e');
      }
    }
  }
}
