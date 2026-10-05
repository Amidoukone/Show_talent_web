import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/services/managed_account_service.dart';

void main() {
  test('provisionManagedAccount accepts joueur and fan', () async {
    final recordedCalls = <Map<String, dynamic>>[];
    final service = ManagedAccountService(
      callableExecutor: (callableName, payload) async {
        recordedCalls.add({
          'callableName': callableName,
          'payload': payload,
        });
        return <String, dynamic>{
          'uid': 'test-uid',
          'email': payload['email'],
          'role': payload['role'],
          'existingUser': false,
        };
      },
    );

    final joueurResult = await service.provisionManagedAccount(
      email: 'joueur@example.com',
      nom: 'Joueur Test',
      role: 'joueur',
      birthDate: DateTime(2000, 4, 15),
    );
    final fanResult = await service.provisionManagedAccount(
      email: 'fan@example.com',
      nom: 'Fan Test',
      role: 'fan',
    );

    expect(joueurResult.role, 'joueur');
    expect(fanResult.role, 'fan');
    expect(recordedCalls, hasLength(2));
    expect(recordedCalls[0]['callableName'], 'provisionManagedAccount');
    expect(recordedCalls[0]['payload']['role'], 'joueur');
    expect(recordedCalls[0]['payload']['birthDate'], '2000-04-15T00:00:00.000Z');
    expect(recordedCalls[1]['payload']['role'], 'fan');
  });

  test('minor provisioning carries the admin-recorded guardian agreement', () async {
    final recordedCalls = <Map<String, dynamic>>[];
    final service = ManagedAccountService(
      callableExecutor: (callableName, payload) async {
        recordedCalls.add({'callableName': callableName, 'payload': payload});
        return <String, dynamic>{
          'uid': 'minor-1',
          'email': payload['email'],
          'role': payload['role'],
          'existingUser': false,
        };
      },
    );

    await service.provisionManagedAccount(
      email: 'minor@example.com',
      nom: 'Joueur Mineur',
      role: 'joueur',
      birthDate: DateTime(2012, 4, 15),
      guardianConsent: const {
        'guardianName': 'Parent Test',
        'relationship': 'parent',
        'method': 'oral_confirmation',
        'evidenceReference': '',
        'mediaAllowed': false,
        'confirmed': true,
      },
    );

    expect(recordedCalls.single['payload']['guardianConsent']['confirmed'], true);
    expect(recordedCalls.single['payload']['birthDate'], '2012-04-15T00:00:00.000Z');
  });

  test('minor account can be provisioned while guardian agreement is pending', () async {
    final calls = <Map<String, dynamic>>[];
    final service = ManagedAccountService(
      callableExecutor: (callableName, payload) async {
        calls.add({'callableName': callableName, 'payload': payload});
        return <String, dynamic>{'success': true};
      },
    );

    await service.provisionManagedAccount(
      email: 'pending-minor@example.com',
      nom: 'Joueur en attente',
      role: 'joueur',
      birthDate: DateTime(2012, 4, 15),
    );

    expect(calls.single['payload']['guardianConsent'], isNull);
  });

  test('profile verification actions use managed profile callable', () async {
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

    await service.verifyManagedAccountProfile(
      uid: 'player-1',
      note: 'Identité et dossier scout contrôlés',
    );
    await service.unverifyManagedAccountProfile(uid: 'player-1');

    expect(recordedCalls, hasLength(2));
    expect(recordedCalls.first['callableName'], 'updateManagedAccountProfile');
    expect(recordedCalls.first['payload'], {
      'uid': 'player-1',
      'patch': {
        'profileVerified': true,
        'profileVerificationStatus': 'verified',
        'profileVerificationNote': 'Identité et dossier scout contrôlés',
      },
    });
    expect(recordedCalls.last['payload'], {
      'uid': 'player-1',
      'patch': {
        'profileVerified': false,
        'profileVerificationStatus': 'unverified',
      },
    });
  });
}
