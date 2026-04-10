import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:show_talent/Dashbord/admin_dashboard_screen.dart';
import 'package:show_talent/Dashbord/admin_login.dart';
import 'package:show_talent/Dashbord/admin_signup.dart';
import 'package:show_talent/Dashbord/statistiques_screen.dart';
import 'package:show_talent/theme/admin_theme.dart';
import 'firebase_options.dart';
import 'controller/event_controller.dart';
import 'controller/offre_controller.dart';
import 'controller/user_controller.dart';
import 'controller/video_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  Get.put(UserController());
  Get.put(VideoController());
  Get.put(OffreController());
  Get.put(EventController());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Adfoot Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.buildTheme(),
      locale: const Locale('fr'),
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      initialRoute: '/admin-login',
      getPages: [
        GetPage(name: '/admin-login', page: () => const AdminLoginScreen()),
        GetPage(name: '/admin-dashboard', page: () => AdminDashboardScreen()),
        GetPage(name: '/admin-signup', page: () => const AdminSignupScreen()),
        GetPage(name: '/statistics', page: () => StatisticsScreen()),
      ],
    );
  }
}
