// Qui attend un accord de representant legal.
//
// Le consentement parental etait deja enregistrable sur un compte existant :
// `managed_profile_edit_dialog` envoie `guardianConsent` et
// `updateManagedAccountProfile` pose `minorProfileApproved` et
// `minorMediaConsentApproved`. C'est exactement ce qu'il faut quand un club
// declare un mineur avant d'avoir recueilli l'accord.
//
// Ce qui manquait : savoir QUI attend. Un club peut declarer un mineur avant
// l'accord -- le compte existe, la fiche publique non -- donc cet etat est
// normal et transitoire. Normal ne veut pas dire invisible : personne ne
// reclamera cet accord a la place de l'enfant.
import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/dashboard/user_management_widget.dart';
import 'package:show_talent/models/user.dart';
import 'package:show_talent/services/managed_account_service.dart';
import 'package:show_talent/widgets/admin_profile_review.dart';

import 'test_support/admin_test_helpers.dart';

AppUser _minor({
  required String uid,
  required String nom,
  bool isMinorProfile = true,
  bool profileApproved = false,
  bool mediaApproved = false,
}) {
  return AppUser.fromMap(<String, dynamic>{
    'uid': uid,
    'nom': nom,
    'role': 'joueur',
    'emailVerified': true,
    'dateInscription': DateTime(2026, 1, 1),
    'dernierLogin': DateTime(2026, 11, 18),
    'isMinorProfile': isMinorProfile,
    'minorProfileApproved': profileApproved,
    'minorMediaConsentApproved': mediaApproved,
  });
}

ManagedAccountService _inertService() {
  return ManagedAccountService(
    callableExecutor: (name, payload) async => <String, dynamic>{},
  );
}

void main() {
  group('etat du compte', () {
    test('une fiche mineure sans accord attend', () {
      final waiting = _minor(uid: 'm1', nom: 'Mineur sans accord');

      expect(waiting.isMinorProfile, isTrue);
      expect(waiting.minorProfileApproved, isFalse);
      expect(waiting.awaitsGuardianConsent, isTrue);
    });

    test('une fiche mineure approuvee n attend plus', () {
      final approved = _minor(
        uid: 'm2',
        nom: 'Mineur approuvé',
        profileApproved: true,
      );

      expect(approved.awaitsGuardianConsent, isFalse);
    });

    test('un compte majeur n attend jamais d accord parental', () {
      final adult = _minor(uid: 'a1', nom: 'Majeur', isMinorProfile: false);

      expect(adult.awaitsGuardianConsent, isFalse);
    });

    test('les deux autorisations sont distinctes', () {
      // Un representant peut accepter que la fiche existe sans accepter qu'on
      // y publie des videos de l'enfant. Les confondre reviendrait a publier
      // un media sur un accord qui ne le couvre pas.
      final profileOnly = _minor(
        uid: 'm3',
        nom: 'Fiche seule',
        profileApproved: true,
      );

      expect(profileOnly.minorProfileApproved, isTrue);
      expect(profileOnly.minorMediaConsentApproved, isFalse);
      expect(profileOnly.awaitsGuardianConsent, isFalse);
    });

    test('les deux drapeaux survivent a la relecture d un compte enrichi', () {
      final full = _minor(
        uid: 'm4',
        nom: 'Accord complet',
        profileApproved: true,
        mediaApproved: true,
      );

      final roundTripped = AppUser.fromMap(full.toMap());

      expect(roundTripped.minorProfileApproved, isTrue);
      expect(roundTripped.minorMediaConsentApproved, isTrue);
    });
  });

  group('visibilite dans la liste', () {
    testWidgets('un compteur dit combien de fiches attendent', (tester) async {
      final controller = TestUserController(
        users: [
          _minor(uid: 'm1', nom: 'Mineur un'),
          _minor(uid: 'm2', nom: 'Mineur deux'),
          _minor(uid: 'm3', nom: 'Mineur approuvé', profileApproved: true),
          buildTestUser(
            uid: 'a1',
            nom: 'Compte majeur',
            email: 'a1@exemple.test',
            role: 'joueur',
          ),
        ],
      );

      await pumpAdminTestApp(
        tester,
        UserManagementWidget(
          selectedRole: 'Tous',
          userController: controller,
          managedAccountService: _inertService(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('accord parental attendu'), findsOneWidget);
      expect(find.text('Mineur un'), findsOneWidget);
      expect(find.text('Compte majeur'), findsOneWidget);
    });

    testWidgets('le compteur restreint la liste a ceux qui attendent', (
      tester,
    ) async {
      final controller = TestUserController(
        users: [
          _minor(uid: 'm1', nom: 'Mineur un'),
          _minor(uid: 'm3', nom: 'Mineur approuvé', profileApproved: true),
          buildTestUser(
            uid: 'a1',
            nom: 'Compte majeur',
            email: 'a1@exemple.test',
            role: 'joueur',
          ),
        ],
      );

      await pumpAdminTestApp(
        tester,
        UserManagementWidget(
          selectedRole: 'Tous',
          userController: controller,
          managedAccountService: _inertService(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('accord parental attendu'));
      await tester.pumpAndSettle();

      expect(find.text('Mineur un'), findsOneWidget);
      expect(find.text('Mineur approuvé'), findsNothing);
      expect(find.text('Compte majeur'), findsNothing);
    });
  });

  group('fiche de revue', () {
    testWidgets('elle dit ce qui bloque, et ou l enregistrer', (tester) async {
      await pumpAdminTestApp(
        tester,
        ProfileReviewContent(
          user: _minor(uid: 'm1', nom: 'Mineur un'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ACCORD DU REPRÉSENTANT LÉGAL'), findsOneWidget);
      expect(
        find.textContaining('refuse de publier une fiche mineure'),
        findsOneWidget,
      );
      expect(find.textContaining('Gérer le profil'), findsOneWidget);
    });

    testWidgets('elle distingue une fiche publiable d un media autorise', (
      tester,
    ) async {
      await pumpAdminTestApp(
        tester,
        ProfileReviewContent(
          user: _minor(uid: 'm2', nom: 'Fiche seule', profileApproved: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('les médias ne le sont pas'), findsOneWidget);
      expect(
        find.textContaining('refuse de publier une fiche mineure'),
        findsNothing,
      );
    });

    testWidgets('un compte majeur ne porte pas cette section', (tester) async {
      await pumpAdminTestApp(
        tester,
        ProfileReviewContent(
          user: buildTestUser(
            uid: 'a1',
            nom: 'Compte majeur',
            email: 'a1@exemple.test',
            role: 'joueur',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ACCORD DU REPRÉSENTANT LÉGAL'), findsNothing);
    });
  });
}
