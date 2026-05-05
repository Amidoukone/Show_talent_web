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
}
