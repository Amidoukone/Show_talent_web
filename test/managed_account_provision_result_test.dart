import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/models/managed_account_provision_result.dart';

void main() {
  group('ManagedAccountProvisionResult', () {
    test('parses callable envelope payload from data field', () {
      final result = ManagedAccountProvisionResult.fromMap(<String, dynamic>{
        'success': true,
        'code': 'managed_account_created',
        'message': 'ok',
        'data': <String, dynamic>{
          'uid': 'uid-123',
          'email': 'club@example.com',
          'role': 'club',
          'existingUser': false,
          'passwordSetupLink': 'https://reset-link',
          'emailVerificationLink': 'https://verify-link',
        },
      });

      expect(result.uid, 'uid-123');
      expect(result.email, 'club@example.com');
      expect(result.role, 'club');
      expect(result.existingUser, isFalse);
      expect(result.passwordSetupLink, 'https://reset-link');
      expect(result.emailVerificationLink, 'https://verify-link');
    });

    test('keeps backward compatibility with flat payload', () {
      final result = ManagedAccountProvisionResult.fromMap(<String, dynamic>{
        'uid': 'uid-456',
        'email': 'agent@example.com',
        'role': 'agent',
        'existingUser': true,
        'passwordSetupLink': 'https://reset-link',
        'emailVerificationLink': null,
      });

      expect(result.uid, 'uid-456');
      expect(result.email, 'agent@example.com');
      expect(result.role, 'agent');
      expect(result.existingUser, isTrue);
      expect(result.passwordSetupLink, 'https://reset-link');
      expect(result.emailVerificationLink, isNull);
    });

    test('buildRecommendedSteps orders password before email validation', () {
      final result = ManagedAccountProvisionResult.fromMap(<String, dynamic>{
        'uid': 'uid-789',
        'email': 'recruteur@example.com',
        'role': 'recruteur',
        'existingUser': false,
        'passwordSetupLink': 'https://reset-link',
        'emailVerificationLink': 'https://verify-link',
      });

      final steps = result.buildRecommendedSteps();

      expect(
        steps,
        contains('Ouvrir d abord le lien de definition du mot de passe.'),
      );
      expect(
        steps,
        contains('Ouvrir ensuite le lien de validation d e-mail.'),
      );
      expect(steps.last, contains('recruteur@example.com'));
    });

    test('buildWhatsappMessage adapts when email is already verified', () {
      final result = ManagedAccountProvisionResult.fromMap(<String, dynamic>{
        'uid': 'uid-999',
        'email': 'club@example.com',
        'role': 'club',
        'existingUser': true,
        'passwordSetupLink': 'https://reset-link',
        'emailVerificationLink': null,
      });

      final message = result.buildWhatsappMessage(recipientName: 'Club Test');

      expect(message, contains('Bonjour Club Test,'));
      expect(message, contains('Votre compte club Adfoot est pret.'));
      expect(message, contains('1. Definir votre mot de passe :'));
      expect(message, contains('2. Vous connecter avec :'));
      expect(message, contains('Votre e-mail est deja valide.'));
      expect(message, isNot(contains('Valider votre e-mail')));
    });

    test('buildEmailMessage includes formal instructions and subject', () {
      final result = ManagedAccountProvisionResult.fromMap(<String, dynamic>{
        'uid': 'uid-1000',
        'email': 'agent@example.com',
        'role': 'agent',
        'existingUser': false,
        'passwordSetupLink': 'https://reset-link',
        'emailVerificationLink': 'https://verify-link',
      });

      final subject = result.buildEmailSubject();
      final message = result.buildEmailMessage(recipientName: 'Agent Test');

      expect(subject, 'Activation de votre compte agent Adfoot');
      expect(message, contains('Bonjour Agent Test,'));
      expect(message, contains('Votre compte agent Adfoot a ete cree.'));
      expect(
        message,
        contains(
          '1. Ouvrez le lien ci-dessous pour definir votre mot de passe :',
        ),
      );
      expect(
        message,
        contains(
          '2. Apres avoir defini votre mot de passe, ouvrez ce lien pour valider votre adresse e-mail :',
        ),
      );
      expect(message, contains('3. Une fois ces deux etapes terminees'));
      expect(message, contains('L administration Adfoot'));
    });

    test('buildInviteMessage stays aligned with email format', () {
      final result = ManagedAccountProvisionResult.fromMap(<String, dynamic>{
        'uid': 'uid-1001',
        'email': 'club@example.com',
        'role': 'club',
        'existingUser': true,
        'passwordSetupLink': 'https://reset-link',
        'emailVerificationLink': null,
      });

      expect(
        result.buildInviteMessage(recipientName: 'Club Test'),
        result.buildEmailMessage(recipientName: 'Club Test'),
      );
    });
  });
}
