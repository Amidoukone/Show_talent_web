import 'package:get/get.dart';

import '../dashboard/admin_dashboard_screen.dart';
import '../dashboard/admin_login.dart';
import '../dashboard/admin_signup.dart';
import '../dashboard/statistiques_screen.dart';
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
        previewMode: _resolveDashboardPreviewMode(),
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

  static bool _resolveDashboardPreviewMode() {
    final args = Get.arguments;
    if (args is Map) {
      final previewMode = args['previewMode'];
      if (previewMode is bool) {
        return previewMode;
      }
    }

    return false;
  }
}
