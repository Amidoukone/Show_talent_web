import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:show_talent/controller/user_controller.dart';
import 'package:show_talent/models/user.dart';
import 'package:show_talent/theme/admin_theme.dart';

class TestUserController extends UserController {
  TestUserController({
    List<AppUser> users = const [],
    List<String> claims = const [],
  }) {
    seededUsers.assignAll(users);
    seededClaims.assignAll(claims);
  }

  final RxList<AppUser> seededUsers = <AppUser>[].obs;
  final RxList<String> seededClaims = <String>[].obs;

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  List<AppUser> get userList => seededUsers;

  @override
  List<String> get grantedAdminClaims => seededClaims;

  @override
  bool get hasRequiredAdminClaims => seededClaims.isNotEmpty;

  @override
  void fetchUsers() {}

  @override
  Future<List<String>> refreshAdminClaims({
    User? firebaseUser,
    bool forceRefresh = false,
  }) async {
    return seededClaims;
  }
}

AppUser buildTestUser({
  required String uid,
  required String nom,
  required String email,
  required String role,
  bool createdByAdmin = false,
  bool authDisabled = false,
  bool emailVerified = true,
}) {
  final now = DateTime(2026, 4, 17);
  return AppUser(
    uid: uid,
    nom: nom,
    email: email,
    role: role,
    photoProfil: '',
    estActif: true,
    authDisabled: authDisabled,
    emailVerified: emailVerified,
    createdByAdmin: createdByAdmin,
    followers: 0,
    followings: 0,
    dateInscription: now,
    dernierLogin: now,
    followersList: const [],
    followingsList: const [],
  );
}

Widget buildAdminTestApp(Widget child) {
  return GetMaterialApp(
    theme: AdminTheme.buildTheme(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: SizedBox(
            width: 1440,
            child: child,
          ),
        ),
      ),
    ),
  );
}

Future<void> pumpAdminTestApp(
  WidgetTester tester,
  Widget child,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1600, 2600);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(buildAdminTestApp(child));
}
