import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/models/user.dart';

void main() {
  test('AppUser.fromMap remains resilient with mixed Firestore payloads', () {
    final user = AppUser.fromMap({
      'nom': 'Test User',
      'email': 'test@adfoot.org',
      'role': 'joueur',
      'followers': 4,
      'followings': 2,
      'dateInscription': Timestamp.fromDate(DateTime(2026, 4, 1)),
      'dernierLogin': '2026-04-07T10:00:00.000Z',
      'performances': {
        'speed': 12,
        'vision': 15.5,
        'invalid': 'n/a',
      },
      'followersList': ['u1', 2, true],
      'followingsList': ['u3'],
      'videosPubliees': const [
        {
          'id': 'video-1',
          'videoUrl': 'https://cdn.example/video.mp4',
          'uid': 'user-1',
        },
      ],
      'joueursSuivis': const [
        {
          'uid': 'nested-1',
          'nom': 'Nested User',
          'email': 'nested@adfoot.org',
          'role': 'fan',
          'followers': 0,
          'followings': 0,
        },
      ],
      'authDisabledReason': 'fraude detectee',
    });

    expect(user.nom, 'Test User');
    expect(user.performances?['speed'], 12);
    expect(user.performances?['vision'], 15.5);
    expect(user.performances?['invalid'], 0);
    expect(user.followersList, ['u1', '2', 'true']);
    expect(user.videosPubliees, hasLength(1));
    expect(user.joueursSuivis, hasLength(1));
    expect(user.authDisabledReason, 'fraude detectee');
  });

  test('isEffectivelyActiveAccount depends on authDisabled and emailVerified',
      () {
    final active = AppUser.fromMap({
      'uid': 'user-1',
      'nom': 'Active account',
      'email': 'active@adfoot.org',
      'role': 'joueur',
      'followers': 0,
      'followings': 0,
      'emailVerified': true,
      'authDisabled': false,
    });
    final disabled = AppUser.fromMap({
      'uid': 'user-2',
      'nom': 'Disabled account',
      'email': 'disabled@adfoot.org',
      'role': 'joueur',
      'followers': 0,
      'followings': 0,
      'emailVerified': true,
      'authDisabled': true,
    });
    final unverified = AppUser.fromMap({
      'uid': 'user-3',
      'nom': 'Unverified account',
      'email': 'unverified@adfoot.org',
      'role': 'joueur',
      'followers': 0,
      'followings': 0,
      'emailVerified': false,
      'authDisabled': false,
    });

    expect(active.isEffectivelyActiveAccount, isTrue);
    expect(disabled.isEffectivelyActiveAccount, isFalse);
    expect(unverified.isEffectivelyActiveAccount, isFalse);
  });
}
