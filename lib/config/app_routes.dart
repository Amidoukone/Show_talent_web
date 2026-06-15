import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../dashboard/admin_dashboard_screen.dart';
import '../dashboard/admin_login.dart';
import '../dashboard/admin_signup.dart';
import '../dashboard/statistiques_screen.dart';
import 'app_environment.dart';
import 'app_page_bindings.dart';

class AppRoutes {
  AppRoutes._();

  static const String adminLogin = '/admin-login';
  static const String adminDashboard = '/admin-dashboard';
  static const String adminSignup = '/admin-signup';
  static const String statistics = '/statistics';

  static final List<GetPage<dynamic>> pages = <GetPage<dynamic>>[
    GetPage(name: adminLogin, page: () => const AdminLoginScreen()),
    GetPage(
      name: adminDashboard,
      page: () => AdminDashboardScreen(
        previewMode: resolveDashboardPreviewMode(),
        initialIndex: resolveDashboardInitialIndex(),
      ),
      binding: AdminDashboardBinding(),
    ),
    GetPage(name: adminSignup, page: () => const AdminSignupScreen()),
    GetPage(
      name: statistics,
      page: () => StatisticsScreen(),
      binding: AdminDashboardBinding(),
    ),
  ];

  static const int _lastDashboardIndex = 7;

  static const Map<String, int> _localDashboardTabs = <String, int>{
    'users': 0,
    'utilisateurs': 0,
    'managed': 1,
    'managed-accounts': 1,
    'comptes-administres': 1,
  };

  @visibleForTesting
  static bool resolveDashboardPreviewMode({
    Object? arguments,
    AppEnvironment? environment,
    Uri? uri,
  }) {
    final args = arguments ?? Get.arguments;
    if (args is Map) {
      final previewMode = args['previewMode'];
      if (previewMode is bool) {
        return previewMode;
      }
    }

    final resolvedEnvironment = environment ?? AppEnvironmentConfig.environment;
    if (resolvedEnvironment == AppEnvironment.production) {
      return false;
    }

    final queryParameters = _dashboardQueryParameters(uri ?? Uri.base);
    final previewValue =
        queryParameters['adminPreview'] ?? queryParameters['previewMode'];
    if (previewValue != null) {
      return _isTruthy(previewValue);
    }

    return false;
  }

  @visibleForTesting
  static int resolveDashboardInitialIndex({
    Object? arguments,
    AppEnvironment? environment,
    Uri? uri,
  }) {
    final args = arguments ?? Get.arguments;
    if (args is Map) {
      final initialIndex = args['initialIndex'];
      if (initialIndex is int) {
        return initialIndex.clamp(0, _lastDashboardIndex);
      }

      final tab = args['tab'];
      if (tab is String) {
        return _localDashboardTabs[tab.trim().toLowerCase()] ?? 0;
      }
    }

    final resolvedEnvironment = environment ?? AppEnvironmentConfig.environment;
    if (resolvedEnvironment == AppEnvironment.production) {
      return 0;
    }

    final queryParameters = _dashboardQueryParameters(uri ?? Uri.base);
    final tab = queryParameters['adminTab'] ?? queryParameters['tab'];
    if (tab == null) {
      return 0;
    }

    return _localDashboardTabs[tab.trim().toLowerCase()] ?? 0;
  }

  static Map<String, String> _dashboardQueryParameters(Uri uri) {
    final parameters = <String, String>{...uri.queryParameters};
    if (uri.fragment.isEmpty) {
      return parameters;
    }

    final fragmentUri = Uri.tryParse(
      uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}',
    );
    if (fragmentUri != null) {
      parameters.addAll(fragmentUri.queryParameters);
    }

    return parameters;
  }

  static bool _isTruthy(String value) {
    switch (value.trim().toLowerCase()) {
      case '1':
      case 'true':
      case 'yes':
      case 'oui':
        return true;
      default:
        return false;
    }
  }
}
