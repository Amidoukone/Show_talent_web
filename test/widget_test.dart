import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/utils/account_role_policy.dart';

void main() {
  test('public self signup roles are disabled', () {
    expect(publicSelfSignupRoles, isEmpty);
    expect(isPublicSelfSignupRole('joueur'), isFalse);
    expect(isPublicSelfSignupRole('fan'), isFalse);
  });

  test('admin provisioned roles cover all business accounts', () {
    expect(
      adminProvisionedRoles,
      equals(const ['joueur', 'fan', 'club', 'recruteur', 'agent']),
    );
    expect(isAdminProvisionedRole('joueur'), isTrue);
    expect(isAdminProvisionedRole('fan'), isTrue);
  });

  test('managed account roles stay limited to publisher roles', () {
    expect(
      managedAccountRoles,
      equals(const ['club', 'recruteur', 'agent']),
    );
    expect(isManagedAccountRole('joueur'), isFalse);
    expect(isManagedAccountRole('fan'), isFalse);
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
