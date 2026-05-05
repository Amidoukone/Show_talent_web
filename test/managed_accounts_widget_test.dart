import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/dashboard/managed_accounts_widget.dart';
import 'package:show_talent/services/managed_account_service.dart';

import 'test_support/admin_test_helpers.dart';

void main() {
  testWidgets('creation dropdown contains the five admin provisioned roles',
      (tester) async {
    final controller = TestUserController(claims: const ['admin']);
    final service = ManagedAccountService(
      callableExecutor: (callableName, payload) async => <String, dynamic>{
        'uid': 'test-uid',
        'email': payload['email'],
        'role': payload['role'],
        'existingUser': false,
      },
    );

    await pumpAdminTestApp(
      tester,
      ManagedAccountsWidget(
        userController: controller,
        managedAccountService: service,
      ),
    );
    await tester.pumpAndSettle();

    final roleDropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(roleDropdown);
    await tester.tap(roleDropdown);
    await tester.pumpAndSettle();

    for (final role in const ['joueur', 'fan', 'club', 'recruteur', 'agent']) {
      expect(find.text(role), findsWidgets);
    }
  });
}
