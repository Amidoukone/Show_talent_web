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

  test('AppUser parses mobile advanced profile fields', () {
    final user = AppUser.fromMap({
      'uid': 'player-1',
      'nom': 'Advanced Player',
      'email': 'player@adfoot.org',
      'role': 'joueur',
      'followers': 0,
      'followings': 0,
      'emailVerified': true,
      'birthDate': Timestamp.fromDate(DateTime.utc(2004, 6, 1)),
      'country': 'CI',
      'city': 'Abidjan',
      'languages': ['fr', 'en'],
      'openToOpportunities': true,
      'position': 'Milieu',
      'team': 'Academy A',
      'cvUrl': 'https://cdn.example/cv.pdf',
      'playerProfile': {
        'physical': {
          'heightCm': 181,
          'strongFoot': 'right',
        },
        'positions': ['CM'],
        'skills': ['vision'],
        'stats': {'minutes': 900},
      },
      'clubProfile': {
        'categories': ['U19']
      },
    });

    expect(user.birthDate, isNotNull);
    expect(user.languages, ['fr', 'en']);
    expect(user.openToOpportunities, isTrue);
    expect(user.primaryLocation, 'Abidjan');
    expect(user.matchesLocation('abi'), isTrue);
    expect(user.hasAdvancedProfile, isTrue);
    expect(user.hasScoutReadyProfile, isTrue);
    expect(user.profileLevelLabel, 'Profil elite');
  });

  test('AppUser separates profile completion from admin verification', () {
    final user = AppUser.fromMap({
      'uid': 'verified-player',
      'nom': 'Verified Player',
      'email': 'verified@adfoot.org',
      'role': 'joueur',
      'followers': 0,
      'followings': 0,
      'emailVerified': true,
      'authDisabled': false,
      'position': 'Attaquant',
      'team': 'Academy A',
      'profileVerified': true,
      'profileVerificationStatus': 'verified',
      'profileVerifiedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 1)),
      'profileVerifiedBy': 'admin-1',
      'profileVerificationNote': 'Profil contrôlé',
      'profileVerificationInvalidatedAt':
          Timestamp.fromDate(DateTime.utc(2026, 6, 5)),
      'profileVerificationInvalidatedBy': 'verified-player',
      'profileVerificationInvalidationReason': 'profile_updated_by_user',
    });

    expect(user.profileLevelLabel, 'Profil complet');
    expect(user.profileVerified, isTrue);
    expect(user.isProfileTrusted, isTrue);
    expect(user.profileTrustLabel, 'Profil certifié');
    expect(user.profileVerificationStatusLabel, 'Vérifié par admin');
    expect(user.profileVerifiedAt?.toUtc(), DateTime.utc(2026, 6, 1));
    expect(user.profileVerifiedBy, 'admin-1');
    expect(user.profileVerificationNote, 'Profil contrôlé');
    expect(
      user.profileVerificationInvalidatedAt?.toUtc(),
      DateTime.utc(2026, 6, 5),
    );
    expect(user.profileVerificationInvalidatedBy, 'verified-player');
    expect(
      user.profileVerificationInvalidationReason,
      'profile_updated_by_user',
    );
    expect(user.toEmbeddedMap()['profileVerified'], isTrue);
    expect(user.toMap()['profileVerifiedBy'], 'admin-1');
  });

  test('AppUser exposes pending profile reverification state', () {
    final user = AppUser.fromMap({
      'uid': 'pending-player',
      'nom': 'Pending Player',
      'email': 'pending@adfoot.org',
      'role': 'joueur',
      'followers': 0,
      'followings': 0,
      'emailVerified': true,
      'authDisabled': false,
      'position': 'Attaquant',
      'team': 'Academy A',
      'profileVerified': false,
      'profileVerificationStatus': 'pending',
      'profileVerificationInvalidatedAt':
          Timestamp.fromDate(DateTime.utc(2026, 6, 5)),
      'profileVerificationInvalidatedBy': 'pending-player',
      'profileVerificationInvalidationReason': 'profile_updated_by_user',
    });

    expect(user.profileVerificationNeedsReview, isTrue);
    expect(user.isProfileTrusted, isFalse);
    expect(user.profileTrustLabel, 'À revalider');
    expect(user.profileVerificationStatusLabel, 'Vérification à refaire');
    expect(
      user.toMap()['profileVerificationInvalidationReason'],
      'profile_updated_by_user',
    );
  });

  test('fromEmbeddedMap avoids recursively parsing nested collections', () {
    final embedded = AppUser.fromEmbeddedMap({
      'uid': 'club-1',
      'nom': 'Club embedded',
      'email': 'club@adfoot.org',
      'role': 'club',
      'followers': 0,
      'followings': 0,
      'offrePubliees': [
        {'id': 'offer-1'},
      ],
    });

    expect(embedded.offrePubliees, isNull);
    expect(embedded.toEmbeddedMap()['role'], 'club');
  });
}
