import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/utils/user_contact_projection.dart';
import 'test_support/admin_test_helpers.dart';

void main() {
  test(
    'removed private fields do not leave old email or phone on the screen',
    () {
      final user = buildTestUser(
        uid: 'contact',
        nom: 'Compte',
        email: 'old@example.invalid',
        role: 'joueur',
      );
      applyPrivateContact(user, {
        'email': 'new@example.invalid',
        'phone': '123',
      });
      expect(user.email, 'new@example.invalid');
      expect(user.phone, '123');
      applyPrivateContact(user, {'email': 'new@example.invalid'});
      expect(user.phone, isNull);
      applyPrivateContact(user, null);
      expect(user.email, 'Adresse e-mail inconnue');
      expect(user.phone, isNull);
    },
  );
}
