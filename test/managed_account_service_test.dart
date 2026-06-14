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
    expect(recordedCalls[1]['payload']['role'], 'fan');
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
