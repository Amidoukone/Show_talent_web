import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/dashboard/user_management_widget.dart';
import 'package:show_talent/services/managed_account_service.dart';

import 'test_support/admin_test_helpers.dart';

void main() {
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

    final actionMenu = find.byType(PopupMenuButton<String>);
    await tester.ensureVisible(actionMenu);
    await tester.tap(actionMenu);
    await tester.pumpAndSettle();

    expect(find.textContaining('Changer le'), findsOneWidget);
    expect(find.text('Renvoyer l’invitation'), findsOneWidget);
  }

  testWidgets('change role dialog proposes the five admin provisioned roles',
      (tester) async {
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

    final actionMenu = find.byType(PopupMenuButton<String>);
    await tester.ensureVisible(actionMenu);
    await tester.tap(actionMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Changer le'));
    await tester.pumpAndSettle();

    final roleDropdown = find.byType(DropdownButtonFormField<String>);
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
  });

  testWidgets('createdByAdmin fan users receive admin role and invite actions',
      (tester) async {
    await expectAdminActionsForRole(tester, 'fan');
  });

  testWidgets('profile verification action calls managed profile backend',
      (tester) async {
    final recordedCalls = <Map<String, dynamic>>[];
    final service = ManagedAccountService(
      callableExecutor: (callableName, payload) async {
        recordedCalls.add({
          'callableName': callableName,
          'payload': payload,
        });
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

    final actionMenu = find.byType(PopupMenuButton<String>);
    await tester.ensureVisible(actionMenu);
    await tester.tap(actionMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Certifier le profil'));
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

  testWidgets('pending profile verification is surfaced for admin review',
      (tester) async {
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

    expect(find.text('À revalider'), findsWidgets);
    expect(find.text('à revalider'), findsOneWidget);

    final actionMenu = find.byType(PopupMenuButton<String>);
    await tester.ensureVisible(actionMenu);
    await tester.tap(actionMenu);
    await tester.pumpAndSettle();

    expect(find.text('Réexaminer le profil'), findsOneWidget);
  });
}
