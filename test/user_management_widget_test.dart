import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/dashboard/user_management_widget.dart';
import 'package:show_talent/services/managed_account_service.dart';

import 'test_support/admin_test_helpers.dart';

void main() {
  testWidgets('loading failures are visible and can be retried', (
    tester,
  ) async {
    final controller = TestUserController();
    controller.usersLoadError.value = 'Connexion indisponible';
    await pumpAdminTestApp(
      tester,
      UserManagementWidget(
        selectedRole: 'Tous',
        userController: controller,
        managedAccountService: ManagedAccountService(
          callableExecutor: (name, payload) async => <String, dynamic>{},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chargement incomplet'), findsOneWidget);
    expect(find.text('Aucun utilisateur trouvé'), findsNothing);
    await tester.ensureVisible(find.text('Réessayer'));
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(controller.retries, 1);
    expect(find.text('Chargement incomplet'), findsNothing);
    controller.privateContactLoadError.value = 'Coordonnées indisponibles';
    await tester.pumpAndSettle();
    expect(find.text('Coordonnées indisponibles'), findsOneWidget);
  });

  testWidgets('live deletion clamps a user page after the list shrinks', (
    tester,
  ) async {
    final controller = TestUserController(
      users: List.generate(
        30,
        (i) => buildTestUser(
          uid: 'page-$i',
          nom: 'Compte $i',
          email: 'test$i@example.invalid',
          role: 'joueur',
        ),
      ),
    );
    await pumpAdminTestApp(
      tester,
      UserManagementWidget(
        selectedRole: 'Tous',
        userController: controller,
        managedAccountService: ManagedAccountService(
          callableExecutor: (name, payload) async => <String, dynamic>{},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final next = find.byIcon(Icons.chevron_right_rounded);
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Compte 25'), findsOneWidget);

    // La liste se vide en direct sous l'opérateur resté en page 2 : la
    // page affichée doit retomber sur la première au lieu de lire au-delà
    // de la fin de liste.
    controller.seededUsers.removeRange(1, 30);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Compte 0'), findsOneWidget);
  });

  ManagedAccountService buildService() {
    return ManagedAccountService(
      callableExecutor: (callableName, payload) async => <String, dynamic>{
        'uid': payload['uid'] ?? 'test-uid',
        'email': 'user@example.com',
        'role': payload['role'] ?? 'joueur',
        'existingUser': false,
      },
    );
  }

  Future<void> expectAdminActionsForRole(
    WidgetTester tester,
    String role,
  ) async {
    final controller = TestUserController(
      users: [
        buildTestUser(
          uid: 'user-$role',
          nom: 'User $role',
          email: '$role@example.com',
          role: role,
          createdByAdmin: true,
        ),
      ],
    );

    await pumpAdminTestApp(
      tester,
      UserManagementWidget(
        selectedRole: 'Tous',
        userController: controller,
        managedAccountService: buildService(),
      ),
    );
    await tester.pumpAndSettle();

    final actionMenu = find.byType(PopupMenuButton<int>);
    await tester.ensureVisible(actionMenu);
    await tester.tap(actionMenu);
    await tester.pumpAndSettle();

    expect(find.textContaining('Changer le'), findsOneWidget);
    expect(find.text('Renvoyer l’invitation'), findsOneWidget);
  }

  testWidgets('change role dialog proposes the five admin provisioned roles', (
    tester,
  ) async {
    final controller = TestUserController(
      users: [
        buildTestUser(
          uid: 'user-1',
          nom: 'User One',
          email: 'user1@example.com',
          role: 'joueur',
          createdByAdmin: true,
        ),
      ],
    );

    await pumpAdminTestApp(
      tester,
      UserManagementWidget(
        selectedRole: 'Tous',
        userController: controller,
        managedAccountService: buildService(),
      ),
    );
    await tester.pumpAndSettle();

    final actionMenu = find.byType(PopupMenuButton<int>);
    await tester.ensureVisible(actionMenu);
    await tester.tap(actionMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Changer le'));
    await tester.pumpAndSettle();

    // Deux menus déroulants de rôle coexistent désormais : le filtre de la
    // barre d'outils et celui de la boîte de dialogue. Le second est le
    // dernier monté.
    final roleDropdown = find.byType(DropdownButtonFormField<String>).last;
    await tester.ensureVisible(roleDropdown);
    await tester.tap(roleDropdown);
    await tester.pumpAndSettle();

    for (final role in const ['joueur', 'fan', 'club', 'recruteur', 'agent']) {
      expect(find.text(role), findsWidgets);
    }
  });

  testWidgets(
    'createdByAdmin joueur users receive admin role and invite actions',
    (tester) async {
      await expectAdminActionsForRole(tester, 'joueur');
    },
  );

  testWidgets(
    'createdByAdmin fan users receive admin role and invite actions',
    (tester) async {
      await expectAdminActionsForRole(tester, 'fan');
    },
  );

  testWidgets('profile verification action calls managed profile backend', (
    tester,
  ) async {
    final recordedCalls = <Map<String, dynamic>>[];
    final service = ManagedAccountService(
      callableExecutor: (callableName, payload) async {
        recordedCalls.add({'callableName': callableName, 'payload': payload});
        return <String, dynamic>{'success': true};
      },
    );
    final controller = TestUserController(
      users: [
        buildTestUser(
          uid: 'player-1',
          nom: 'Player One',
          email: 'player@example.com',
          role: 'joueur',
          createdByAdmin: true,
          position: 'Milieu',
          team: 'Academy A',
        ),
      ],
    );

    await pumpAdminTestApp(
      tester,
      UserManagementWidget(
        selectedRole: 'Tous',
        userController: controller,
        managedAccountService: service,
      ),
    );
    await tester.pumpAndSettle();

    final certify = find.byTooltip('Certifier le profil');
    await tester.ensureVisible(certify);
    await tester.tap(certify);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'Identité et dossier profil contrôlés',
    );
    await tester.tap(find.text('Certifier').last);
    await tester.pumpAndSettle();

    expect(recordedCalls, hasLength(1));
    expect(recordedCalls.single['callableName'], 'updateManagedAccountProfile');
    expect(recordedCalls.single['payload'], {
      'uid': 'player-1',
      'patch': {
        'profileVerified': true,
        'profileVerificationStatus': 'verified',
        'profileVerificationNote': 'Identité et dossier profil contrôlés',
      },
    });
  });

  testWidgets('pending profile verification is surfaced for admin review', (
    tester,
  ) async {
    final controller = TestUserController(
      users: [
        buildTestUser(
          uid: 'player-pending',
          nom: 'Player Pending',
          email: 'pending@example.com',
          role: 'joueur',
          createdByAdmin: true,
          position: 'Milieu',
          team: 'Academy A',
          profileVerificationStatus: 'pending',
          profileVerificationInvalidatedAt: DateTime.utc(2026, 6, 5),
        ),
      ],
    );

    await pumpAdminTestApp(
      tester,
      UserManagementWidget(
        selectedRole: 'Tous',
        userController: controller,
        managedAccountService: buildService(),
      ),
    );
    await tester.pumpAndSettle();

    // Le statut "à revalider" de la ligne et le libellé de la tuile de
    // statistiques partagent maintenant la même casse (voir
    // AdminAccountStatusChips) : un seul statut par compte plutôt que deux
    // graphies différentes de la même information.
    expect(find.text('À revalider'), findsWidgets);

    // L'action de réexamen est posée sur la ligne, pas enfouie dans un
    // menu : son libellé est celui de son infobulle.
    expect(find.byTooltip('Réexaminer le profil'), findsOneWidget);
  });
}
