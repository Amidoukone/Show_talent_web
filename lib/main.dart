import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:show_talent/theme/admin_theme.dart';

import 'config/app_bootstrap.dart';
import 'config/app_routes.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    await AppBootstrap.initialize();
    runApp(const MyApp());
  }, AppBootstrap.reportZoneError);
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
      initialRoute: AppRoutes.adminLogin,
      getPages: AppRoutes.pages,
    );
  }
}
