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
      'blockedReason': 'contenu non conforme',
      'blockMode': 'temporary',
      'blockedUntil': '2026-04-22T10:00:00.000Z',
      'authDisabledReason': 'fraude detectee',
    });

    expect(user.nom, 'Test User');
    expect(user.performances?['speed'], 12);
    expect(user.performances?['vision'], 15.5);
    expect(user.performances?['invalid'], 0);
    expect(user.followersList, ['u1', '2', 'true']);
    expect(user.videosPubliees, hasLength(1));
    expect(user.joueursSuivis, hasLength(1));
    expect(user.blockedReason, 'contenu non conforme');
    expect(user.blockMode, 'temporary');
    expect(user.blockedUntil, isNotNull);
    expect(user.hasTemporaryBlock, isFalse);
    expect(user.authDisabledReason, 'fraude detectee');
  });

  test('temporary suspensions are effective only before their end date', () {
    final active = AppUser.fromMap({
      'uid': 'user-1',
      'nom': 'Active suspension',
      'email': 'active@adfoot.org',
      'role': 'joueur',
      'followers': 0,
      'followings': 0,
      'estBloque': true,
      'blockMode': 'temporary',
      'blockedUntil':
          DateTime.now().add(const Duration(days: 3)).toIso8601String(),
    });
    final expired = AppUser.fromMap({
      'uid': 'user-2',
      'nom': 'Expired suspension',
      'email': 'expired@adfoot.org',
      'role': 'joueur',
      'followers': 0,
      'followings': 0,
      'estBloque': true,
      'blockMode': 'temporary',
      'blockedUntil':
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    });

    expect(active.hasTemporaryBlock, isTrue);
    expect(active.hasActiveAppBlock, isTrue);
    expect(expired.hasTemporaryBlock, isTrue);
    expect(expired.hasExpiredTemporaryBlock, isTrue);
    expect(expired.hasActiveAppBlock, isFalse);
  });
}
