import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/utils/account_role_policy.dart';

void main() {
  test('public self-signup roles stay limited to joueur and fan', () {
    expect(publicSelfSignupRoles, equals(const ['joueur', 'fan']));
  });

  test('managed account roles stay admin-provisioned', () {
    expect(
      managedAccountRoles,
      equals(const ['club', 'recruteur', 'agent']),
    );
  });

  test('extractGrantedAdminClaims keeps only enabled admin claims', () {
    final claims = <String, dynamic>{
      'admin': true,
      'platformAdmin': false,
      'superAdmin': true,
      'other': true,
    };

    expect(extractGrantedAdminClaims(claims), equals(['admin', 'superAdmin']));
  });
}
