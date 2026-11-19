import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:show_talent/controller/user_controller.dart';
import 'package:show_talent/models/membership.dart';
import 'package:show_talent/models/user.dart';
import 'package:show_talent/theme/admin_theme.dart';

class TestUserController extends UserController {
  TestUserController({
    List<AppUser> users = const [],
    List<String> claims = const [],
  }) {
    seededUsers.assignAll(users);
    seededClaims.assignAll(claims);
    isLoading.value = false;
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

  int retries = 0;
  @override
  Future<void> retryUsers() async {
    retries++;
    usersLoadError.value = null;
    privateContactLoadError.value = null;
  }

  @override
  Future<List<String>> refreshAdminClaims({
    User? firebaseUser,
    bool forceRefresh = false,
  }) async {
    return seededClaims;
  }

  /// Ce que `users/{uid}/private/contact` porterait, par uid.
  ///
  /// Sans cette graine, tout écran qui lit le document de contact toucherait
  /// Firestore depuis un test.
  final Map<String, Map<String, dynamic>> privateContactByUid =
      <String, Map<String, dynamic>>{};

  /// Les uid pour lesquels la lecture privée a été demandée, dans l'ordre.
  final List<String> privateFieldFetches = <String>[];

  /// Ce que la lecture privée doit lever, pour rejouer une lecture refusée.
  Object? privateFieldsError;

  @override
  Future<AppUser> fetchUserWithPrivateFields(AppUser baseUser) async {
    privateFieldFetches.add(baseUser.uid);
    final error = privateFieldsError;
    if (error != null) {
      throw error;
    }
    final contact = privateContactByUid[baseUser.uid];
    if (contact == null) {
      return baseUser;
    }
    return AppUser.fromMap(baseUser.toMap(), privateContact: contact);
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
  bool profileVerified = false,
  String? profileVerificationStatus,
  DateTime? profileVerificationInvalidatedAt,
  String? position,
  String? team,
  Membership membership = Membership.none,
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
    profileVerified: profileVerified,
    profileVerificationStatus:
        profileVerificationStatus ??
        (profileVerified ? 'verified' : 'unverified'),
    profileVerificationInvalidatedAt: profileVerificationInvalidatedAt,
    profileVerificationInvalidatedBy: profileVerificationInvalidatedAt == null
        ? null
        : uid,
    profileVerificationInvalidationReason:
        profileVerificationInvalidatedAt == null
        ? null
        : 'profile_updated_by_user',
    position: position,
    team: team,
    membership: membership,
    followers: 0,
    followings: 0,
    dateInscription: now,
    dernierLogin: now,
    followersList: const [],
    followingsList: const [],
  );
}

/// Reproduit ce que la coquille d'administration donne à un onglet : une
/// zone de taille bornée. Les écrans de liste y placent une barre d'outils
/// fixe, une liste qui défile et un pied de liste fixe — un
/// `SingleChildScrollView` ici leur donnerait une hauteur infinie, ce que
/// la production ne fait jamais.
Widget buildAdminTestApp(Widget child) {
  return GetMaterialApp(
    theme: AdminTheme.buildTheme(),
    home: Scaffold(
      body: Center(child: SizedBox(width: 1440, height: 2400, child: child)),
    ),
  );
}

Future<void> pumpAdminTestApp(WidgetTester tester, Widget child) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1600, 2600);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(buildAdminTestApp(child));
}

/// Le code source de la coquille d'administration.
const String _shellPath = 'lib/dashboard/admin_dashboard_screen.dart';

/// La position d'un onglet dans `_dashboardItems`, ou -1.
///
/// Lue dans la source parce que la liste est privée, et vérifiée par position
/// parce que c'est la position qui compte : `_widgetOptions()` et les liens
/// profonds de `app_routes.dart` sont indexés dessus, donc un onglet inséré au
/// milieu décale tous les suivants sans que rien n'échoue.
///
/// Assertion de POSITION et non de présence : c'est précisément la différence
/// entre un garde-fou qui voit l'incident et un garde-fou qui reste vert pour
/// toujours.
int dashboardItemIndex(String title) {
  final shell = File(_shellPath).readAsStringSync();
  final start = shell.indexOf('_dashboardItems = [');
  final end = shell.indexOf('];', start);
  if (start < 0 || end < 0) {
    throw StateError('Liste _dashboardItems introuvable dans $_shellPath.');
  }

  return _declaredTitles(shell.substring(start, end)).indexOf(title);
}

/// Le nombre d'onglets déclarés, lu dans la même source.
int get dashboardItemCount {
  final shell = File(_shellPath).readAsStringSync();
  final start = shell.indexOf('_dashboardItems = [');
  final end = shell.indexOf('];', start);
  return _declaredTitles(shell.substring(start, end)).length;
}

/// Les intitulés d'onglets d'un littéral, dans l'ordre déclaré.
///
/// Le motif est ancré en début de ligne, et c'est indispensable : sans l'ancre
/// il tombait aussi sur `subtitle: '...'`, qui contient la sous-chaîne
/// `title: '`, et comptait donc chaque onglet deux fois.
List<String> _declaredTitles(String literal) {
  return RegExp(
    "^ *title: ['\"]([^'\"]+)['\"]",
    multiLine: true,
  ).allMatches(literal).map((match) => match.group(1)!).toList();
}

/// Les index regroupés sous [label] dans le rail de navigation.
///
/// Un onglet ajouté en fin de liste doit rejoindre son métier, sinon il reste
/// seul en bas du rail sans que rien ne le signale.
List<int> dashboardGroupIndices(String label) {
  final shell = File(_shellPath).readAsStringSync();
  final match = RegExp(
    "label: '$label', indices: "
    r"\[([^\]]*)\]",
  ).firstMatch(shell);
  if (match == null) {
    throw StateError('Groupe « $label » introuvable dans $_shellPath.');
  }

  return match
      .group(1)!
      .split(',')
      .map((value) => int.parse(value.trim()))
      .toList();
}

/// La position d'un écran dans `_widgetOptions()`, ou -1.
///
/// L'ordre de `_widgetOptions()` doit suivre celui de `_dashboardItems` :
/// c'est la même position qui sélectionne les deux.
int dashboardScreenIndex(String widgetConstructor) {
  final shell = File(_shellPath).readAsStringSync();
  final start = shell.indexOf('List<Widget> _widgetOptions() {');
  final end = shell.indexOf('];', start);
  if (start < 0 || end < 0) {
    throw StateError('_widgetOptions() introuvable dans $_shellPath.');
  }

  final body = shell.substring(start, end);
  final screens = RegExp(
    r'^\s+(?:const )?([A-Z][A-Za-z]*)\(',
    multiLine: true,
  ).allMatches(body).map((match) => match.group(1)).toList();
  return screens.indexOf(widgetConstructor);
}
