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

    test('buildRecommendedSteps orders email validation before password', () {
      final result = ManagedAccountProvisionResult.fromMap(<String, dynamic>{
        'uid': 'uid-789',
        'email': 'recruteur@example.com',
        'role': 'recruteur',
        'existingUser': false,
        'passwordSetupLink': 'https://reset-link',
        'emailVerificationLink': 'https://verify-link',
      });

      final steps = result.buildRecommendedSteps();

      expect(steps[0], 'Ouvrir d’abord le lien de validation d’e-mail.');
      expect(steps[2], 'Ouvrir ensuite le lien de définition du mot de passe.');
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
      expect(message, contains('Votre compte club Adfoot est prêt.'));
      expect(message, contains('1. Définir votre mot de passe :'));
      expect(message, contains('2. Vous connecter avec :'));
      expect(message, contains('Votre e-mail est déjà validé.'));
      expect(message, isNot(contains('Valider votre e-mail')));
    });

    test('buildWhatsappMessage puts email validation before password', () {
      final result = ManagedAccountProvisionResult.fromMap(<String, dynamic>{
        'uid': 'uid-1000',
        'email': 'agent@example.com',
        'role': 'agent',
        'existingUser': false,
        'passwordSetupLink': 'https://reset-link',
        'emailVerificationLink': 'https://verify-link',
      });

      final message = result.buildWhatsappMessage(recipientName: 'Agent Test');

      expect(message, contains('1. Valider votre e-mail :'));
      expect(message, contains('2. Définir votre mot de passe :'));
      expect(message.indexOf('https://verify-link'),
          lessThan(message.indexOf('https://reset-link')));
    });

    test('buildEmailMessage includes formal instructions and subject', () {
      final result = ManagedAccountProvisionResult.fromMap(<String, dynamic>{
        'uid': 'uid-1001',
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
      expect(message, contains('Votre compte agent Adfoot a été créé.'));
      expect(
        message,
        contains(
          '1. Ouvrez le lien ci-dessous pour valider votre adresse e-mail :',
        ),
      );
      expect(
        message,
        contains('2. Ouvrez ensuite ce lien pour définir votre mot de passe :'),
      );
      expect(message.indexOf('https://verify-link'),
          lessThan(message.indexOf('https://reset-link')));
      expect(message, contains('3. Une fois ces deux étapes terminées'));
      expect(message, contains('L’administration Adfoot'));
    });

    test('buildInviteMessage stays aligned with email format', () {
      final result = ManagedAccountProvisionResult.fromMap(<String, dynamic>{
        'uid': 'uid-1002',
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

    // The backend now e-mails the invitation itself. Telling the admin
    // nothing about that is the failure worth guarding: they would assume
    // the member was contacted, and the member would wait for a message that
    // never left.
    test('a sent invitation is reported as sent', () {
      final result = ManagedAccountProvisionResult.fromMap(<String, dynamic>{
        'uid': 'uid-1003',
        'email': 'joueur@example.com',
        'role': 'joueur',
        'existingUser': false,
        'passwordSetupLink': 'https://reset-link',
        'inviteEmailSent': true,
      });

      expect(result.inviteEmailSent, isTrue);
      expect(
        result.inviteEmailStatusMessage,
        contains('joueur@example.com'),
      );
      // The link survives the send: it is the admin's fallback, always.
      expect(result.hasPasswordSetupLink, isTrue);
    });

    test('a skipped or failed invitation says so, per reason', () {
      Map<String, dynamic> payload(String? reason) => <String, dynamic>{
            'uid': 'uid-1004',
            'email': 'fan@example.com',
            'role': 'fan',
            'existingUser': false,
            'passwordSetupLink': 'https://reset-link',
            'inviteEmailSent': false,
            if (reason != null) 'inviteEmailReason': reason,
          };

      expect(
        ManagedAccountProvisionResult.fromMap(payload('not_configured'))
            .inviteEmailStatusMessage,
        contains('n’est pas configuré'),
      );
      expect(
        ManagedAccountProvisionResult.fromMap(payload('send_failed'))
            .inviteEmailStatusMessage,
        contains('a échoué'),
      );
      expect(
        ManagedAccountProvisionResult.fromMap(payload('invalid_recipient'))
            .inviteEmailStatusMessage,
        contains('refusée'),
      );
      // An older backend returns neither field: default to "not sent", never
      // to a claim that it was.
      final legacy = ManagedAccountProvisionResult.fromMap(payload(null));
      expect(legacy.inviteEmailSent, isFalse);
      expect(legacy.inviteEmailStatusMessage, contains('Aucun e-mail'));
    });
  });
}
