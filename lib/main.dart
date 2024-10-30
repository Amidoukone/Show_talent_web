import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:show_talent/Dashbord/admin_dashboard_screen.dart';
import 'package:show_talent/Dashbord/admin_login.dart';
import 'package:show_talent/Dashbord/admin_signup.dart';
import 'package:show_talent/Dashbord/statistiques_screen.dart';
import 'firebase_options.dart';
import 'controller/user_controller.dart';
import 'controller/video_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  Get.put(UserController());
  Get.put(VideoController());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Admin Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF214D4F),
        scaffoldBackgroundColor: const Color(0xFFE6EEFA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF214D4F),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      initialRoute: '/admin-login',
      getPages: [
        GetPage(name: '/admin-login', page: () => const AdminLoginScreen()),
        GetPage(name: '/admin-dashboard', page: () => AdminDashboardScreen()),
        GetPage(name: '/admin-signup', page: () => const AdminSignupScreen()),
        GetPage(name: '/statistics', page: () => StatisticsScreen()), // Ajouter la route
      ],
    );
  }
}