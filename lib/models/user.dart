import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:show_talent/models/event.dart';
import 'package:show_talent/models/offre.dart';
import 'package:show_talent/models/video.dart';
import 'package:show_talent/utils/account_role_policy.dart';

class AppUser {
  String uid;
  String nom;
  String email;
  String role;
  String photoProfil;
  bool estActif;
  bool authDisabled;
  bool emailVerified;
  bool createdByAdmin;
  int followers;
  int followings;
  DateTime dateInscription;
  DateTime dernierLogin;
  DateTime? emailVerifiedAt;
  String? phone;
  String? authDisabledReason;

  DateTime? birthDate;
  String? country;
  String? city;
  String? region;
  List<String>? languages;
  bool? openToOpportunities;

  String? bio;
  String? position;
  String? clubActuel;
  int? nombreDeMatchs;
  int? buts;
  int? assistances;
  List<Video>? videosPubliees;
  Map<String, double>? performances;

  Map<String, dynamic>? playerProfile;
  Map<String, dynamic>? clubProfile;
  Map<String, dynamic>? agentProfile;
  Map<String, dynamic>? eventOrganizerProfile;

  String? nomClub;
  String? ligue;
  List<Offre>? offrePubliees;
  List<Event>? eventPublies;

  String? entreprise;
  int? nombreDeRecrutements;

  String? team;
  List<AppUser>? joueursSuivis;
  List<AppUser>? clubsSuivis;
  List<Video>? videosLikees;
  List<String> followersList;
  List<String> followingsList;
  bool profilePublic;
  bool allowMessages;
  String? cvUrl;

  AppUser({
    required this.uid,
    required this.nom,
    required this.email,
    required this.role,
    required this.photoProfil,
    required this.estActif,
    this.authDisabled = false,
    this.emailVerified = false,
    this.createdByAdmin = false,
    required this.followers,
    required this.followings,
    required this.dateInscription,
    required this.dernierLogin,
    this.emailVerifiedAt,
    this.phone,
    this.authDisabledReason,
    this.birthDate,
    this.country,
    this.city,
    this.region,
    this.languages,
    this.openToOpportunities,
    this.bio,
    this.position,
    this.clubActuel,
    this.nombreDeMatchs,
    this.buts,
    this.assistances,
    this.videosPubliees,
    this.performances,
    this.playerProfile,
    this.clubProfile,
    this.agentProfile,
    this.eventOrganizerProfile,
    this.nomClub,
    this.ligue,
    this.offrePubliees,
    this.eventPublies,
    this.entreprise,
    this.nombreDeRecrutements,
    this.team,
    this.joueursSuivis,
    this.clubsSuivis,
    this.videosLikees,
    this.followersList = const [],
    this.followingsList = const [],
    this.profilePublic = true,
    this.allowMessages = true,
    this.cvUrl,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser._fromMap(map, parseNestedCollections: true);
  }

  factory AppUser.fromEmbeddedMap(Map<String, dynamic> map) {
    return AppUser._fromMap(map, parseNestedCollections: false);
  }

  static AppUser _fromMap(
    Map<String, dynamic> map, {
    required bool parseNestedCollections,
  }) {
    final normalizedRole = normalizeUserRole(map['role']?.toString());
    final safeMapPerformances = _safeMap(map['performances']);

    return AppUser(
      uid: map['uid']?.toString() ?? '',
      nom: map['nom']?.toString() ?? 'Nom inconnu',
      email: map['email']?.toString() ?? 'Adresse e-mail inconnue',
      role: normalizedRole.isEmpty ? 'utilisateur' : normalizedRole,
      photoProfil: map['photoProfil']?.toString() ?? '',
      estActif: map['estActif'] as bool? ?? true,
      authDisabled: map['authDisabled'] == true,
      emailVerified: map['emailVerified'] as bool? ?? false,
      createdByAdmin: map['createdByAdmin'] == true,
      followers: _parseInt(map['followers']) ?? 0,
      followings: _parseInt(map['followings']) ?? 0,
      dateInscription: _parseDate(map['dateInscription']),
      dernierLogin: _parseDate(map['dernierLogin']),
      emailVerifiedAt: _parseNullableDate(map['emailVerifiedAt']),
      phone: _normalizeNullableString(map['phone']),
      authDisabledReason: _normalizeNullableString(map['authDisabledReason']),
      birthDate: _parseNullableDate(map['birthDate']),
      country: _normalizeNullableString(map['country']),
      city: _normalizeNullableString(map['city']),
      region: _normalizeNullableString(map['region']),
      languages: _safeList(map['languages']).isEmpty
          ? null
          : _safeList(map['languages'])
              .map((entry) => entry.toString())
              .toList(),
      openToOpportunities: map['openToOpportunities'] as bool?,
      bio: _normalizeNullableString(map['bio']),
      position: _normalizeNullableString(map['position']),
      clubActuel: _normalizeNullableString(map['clubActuel']),
      nombreDeMatchs: _parseInt(map['nombreDeMatchs']),
      buts: _parseInt(map['buts']),
      assistances: _parseInt(map['assistances']),
      videosPubliees: parseNestedCollections
          ? _safeList(map['videosPubliees'])
              .whereType<Map>()
              .map((video) => Video.fromMap(Map<String, dynamic>.from(video)))
              .toList()
          : null,
      performances: safeMapPerformances?.map(
        (key, value) => MapEntry(
          key,
          value is num ? value.toDouble() : 0,
        ),
      ),
      playerProfile: _safeMap(map['playerProfile']),
      clubProfile: _safeMap(map['clubProfile']),
      agentProfile: _safeMap(map['agentProfile']),
      eventOrganizerProfile: _safeMap(map['eventOrganizerProfile']),
      nomClub: _normalizeNullableString(map['nomClub']),
      ligue: _normalizeNullableString(map['ligue']),
      offrePubliees: parseNestedCollections
          ? _safeList(map['offrePubliees'])
              .whereType<Map>()
              .map((offre) => Offre.fromMap(Map<String, dynamic>.from(offre)))
              .toList()
          : null,
      eventPublies: parseNestedCollections
          ? _safeList(map['eventPublies'])
              .whereType<Map>()
              .map((event) => Event.fromMap(Map<String, dynamic>.from(event)))
              .toList()
          : null,
      entreprise: _normalizeNullableString(map['entreprise']),
      nombreDeRecrutements: _parseInt(map['nombreDeRecrutements']),
      team: _normalizeNullableString(map['team']),
      joueursSuivis: parseNestedCollections
          ? _safeList(map['joueursSuivis'])
              .whereType<Map>()
              .map(
                (joueur) =>
                    AppUser.fromEmbeddedMap(Map<String, dynamic>.from(joueur)),
              )
              .toList()
          : null,
      clubsSuivis: parseNestedCollections
          ? _safeList(map['clubsSuivis'])
              .whereType<Map>()
              .map(
                (club) =>
                    AppUser.fromEmbeddedMap(Map<String, dynamic>.from(club)),
              )
              .toList()
          : null,
      videosLikees: parseNestedCollections
          ? _safeList(map['videosLikees'])
              .whereType<Map>()
              .map((video) => Video.fromMap(Map<String, dynamic>.from(video)))
              .toList()
          : null,
      followersList: _safeList(map['followersList'])
          .map((entry) => entry.toString())
          .toList(),
      followingsList: _safeList(map['followingsList'])
          .map((entry) => entry.toString())
          .toList(),
      profilePublic: map['profilePublic'] as bool? ?? true,
      allowMessages: map['allowMessages'] as bool? ?? true,
      cvUrl: _normalizeNullableString(map['cvUrl']),
    );
  }

  Map<String, dynamic> toEmbeddedMap() {
    return {
      'uid': uid,
      'nom': nom,
      'email': email,
      'role': normalizeUserRole(role),
      'photoProfil': photoProfil,
      'estActif': estActif,
      'authDisabled': authDisabled,
      'emailVerified': emailVerified,
      'createdByAdmin': createdByAdmin,
      'phone': phone,
      'nomClub': nomClub,
      'ligue': ligue,
      'entreprise': entreprise,
      'team': team,
      'profilePublic': profilePublic,
      'allowMessages': allowMessages,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      ...toEmbeddedMap(),
      'followers': followers,
      'followings': followings,
      'dateInscription': Timestamp.fromDate(dateInscription),
      'dernierLogin': Timestamp.fromDate(dernierLogin),
      'emailVerifiedAt':
          emailVerifiedAt != null ? Timestamp.fromDate(emailVerifiedAt!) : null,
      'authDisabledReason': authDisabledReason,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'country': country,
      'city': city,
      'region': region,
      'languages': languages,
      'openToOpportunities': openToOpportunities,
      'bio': bio,
      'position': position,
      'clubActuel': clubActuel,
      'nombreDeMatchs': nombreDeMatchs,
      'buts': buts,
      'assistances': assistances,
      'videosPubliees': videosPubliees?.map((video) => video.toMap()).toList(),
      'performances': performances,
      'playerProfile': playerProfile,
      'clubProfile': clubProfile,
      'agentProfile': agentProfile,
      'eventOrganizerProfile': eventOrganizerProfile,
      'offrePubliees': offrePubliees?.map((offre) => offre.toMap()).toList(),
      'eventPublies': eventPublies?.map((event) => event.toMap()).toList(),
      'nombreDeRecrutements': nombreDeRecrutements,
      'joueursSuivis':
          joueursSuivis?.map((joueur) => joueur.toEmbeddedMap()).toList(),
      'clubsSuivis': clubsSuivis?.map((club) => club.toEmbeddedMap()).toList(),
      'videosLikees': videosLikees?.map((video) => video.toMap()).toList(),
      'followersList': followersList,
      'followingsList': followingsList,
      'cvUrl': cvUrl,
    };
  }

  int? get age {
    if (birthDate == null) {
      return null;
    }

    final now = DateTime.now();
    var computedAge = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      computedAge--;
    }

    return computedAge;
  }

  bool get isPlayer => role == 'joueur';
  bool get isClub => role == 'club';
  bool get isAgent => role == 'agent';
  bool get isRecruiter => role == 'recruteur' || role == 'agent';
  bool get isCoach => role == 'coach';
  bool get isFan => role == 'fan';

  bool get isEffectivelyActiveAccount => !authDisabled && emailVerified;

  bool get isAdminPortalOnly => isAdminPortalOnlyRole(role);
  bool get hasManagedAccountRole => isManagedAccountRole(role);
  bool get canPublishOpportunities => isOpportunityPublisherRole(role);

  bool get canAppearInMessagingDirectory {
    return uid.trim().isNotEmpty &&
        nom.trim().isNotEmpty &&
        !authDisabled &&
        !isAdminPortalOnlyRole(role);
  }

  String? get primaryLocation {
    for (final value in [city, region, country]) {
      final normalized = value?.trim();
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }

    return null;
  }

  bool matchesLocation(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return true;
    }

    return [city, region, country].any((value) {
      final normalizedValue = value?.trim().toLowerCase() ?? '';
      return normalizedValue.contains(normalizedQuery);
    });
  }

  bool get isMvpProfileComplete {
    switch (role) {
      case 'joueur':
        return nom.isNotEmpty &&
            (position?.isNotEmpty ?? false) &&
            (team?.isNotEmpty ?? false);
      case 'club':
        return nom.isNotEmpty && (ligue?.isNotEmpty ?? false);
      case 'recruteur':
      case 'agent':
        return nom.isNotEmpty && (entreprise?.isNotEmpty ?? false);
      default:
        return nom.isNotEmpty;
    }
  }

  bool get hasAdvancedProfile {
    switch (role) {
      case 'joueur':
        return playerProfile != null && playerProfile!.isNotEmpty;
      case 'club':
        return clubProfile != null && clubProfile!.isNotEmpty;
      case 'recruteur':
      case 'agent':
        return agentProfile != null && agentProfile!.isNotEmpty;
      default:
        return false;
    }
  }

  bool get hasScoutReadyProfile {
    if (!isPlayer || playerProfile == null) {
      return false;
    }

    final profile = playerProfile!;
    final physical = profile['physical'] is Map
        ? Map<String, dynamic>.from(profile['physical'] as Map)
        : <String, dynamic>{};

    final hasPhysical = physical['heightCm'] != null ||
        physical['weightKg'] != null ||
        physical['strongFoot'] != null;
    final positions = profile['positions'];
    final hasPosition = positions is List && positions.isNotEmpty;
    final skills = profile['skills'];
    final hasSkills = skills is List && skills.isNotEmpty;
    final stats = profile['stats'];
    final hasStats = stats is Map && stats.isNotEmpty;
    final hasEvidence = (videosPubliees?.isNotEmpty ?? false) ||
        (cvUrl?.trim().isNotEmpty ?? false);

    return (hasPhysical || hasSkills) && hasPosition && hasStats && hasEvidence;
  }

  bool get shouldShowAdvancedSection {
    return isPlayer || isClub || isRecruiter;
  }

  bool get shouldPromptAdvancedCompletion {
    return isMvpProfileComplete && !hasAdvancedProfile;
  }

  String get profileLevelLabel {
    if (hasScoutReadyProfile) return 'Profil elite';
    if (hasAdvancedProfile) return 'Profil avance';
    if (isMvpProfileComplete) return 'Profil verifie';
    return 'Profil basique';
  }

  static DateTime _parseDate(dynamic value, {DateTime? fallback}) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return fallback ?? DateTime.now();
  }

  static DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static List<dynamic> _safeList(dynamic value) {
    if (value is List) {
      return value;
    }

    return const [];
  }

  static Map<String, dynamic>? _safeMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  static String? _normalizeNullableString(dynamic value) {
    final normalized = value?.toString().trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
