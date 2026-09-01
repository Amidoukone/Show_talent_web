import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:show_talent/models/event.dart';
import 'package:show_talent/models/membership.dart';
import 'package:show_talent/models/org_football_profile.dart';
import 'package:show_talent/models/player_football_profile.dart';
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
  bool profileVerified;
  String profileVerificationStatus;
  DateTime? profileVerifiedAt;
  String? profileVerifiedBy;
  DateTime? profileVerificationUpdatedAt;
  String? profileVerificationUpdatedBy;
  String? profileVerificationNote;
  DateTime? profileVerificationInvalidatedAt;
  String? profileVerificationInvalidatedBy;
  String? profileVerificationInvalidationReason;

  /// Droits enregistrés par l'administration.
  ///
  /// Écrit uniquement par le callable `setManagedAccountMembership` : ni le
  /// mobile ni ce portail n'écrivent ce champ directement.
  Membership membership;

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

  /// Les faits footballistiques, tels qu'un recruteur les filtre.
  ///
  /// Lus a plat sur le document, comme cote mobile. Voir
  /// [PlayerFootballProfile].
  PlayerFootballProfile football;

  /// Ce que le club declare.
  ClubFootballProfile club;

  /// Ce que l'agent ou le recruteur declare.
  AgentFootballProfile agent;

  /// Anciens profils en texte libre, remplaces par les trois ci-dessus.
  ///
  /// Conserves pour ne pas perdre le document d'un compte qui en porte encore,
  /// mais plus alimentes ni lus.
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
    this.profileVerified = false,
    this.profileVerificationStatus = 'unverified',
    this.profileVerifiedAt,
    this.profileVerifiedBy,
    this.profileVerificationUpdatedAt,
    this.profileVerificationUpdatedBy,
    this.profileVerificationNote,
    this.profileVerificationInvalidatedAt,
    this.profileVerificationInvalidatedBy,
    this.profileVerificationInvalidationReason,
    this.membership = Membership.none,
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
    this.football = const PlayerFootballProfile(),
    this.club = const ClubFootballProfile(),
    this.agent = const AgentFootballProfile(),
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

  /// [privateContact] merges in users/{uid}/private/contact
  /// (phone/email/authDisabledReason) and [adminNotes] merges in
  /// users/{uid}/private/adminNotes (profileVerificationNote) — both moved
  /// out of the main doc so a non-admin can't read them. Pass them only
  /// when the caller actually fetched those docs (admin review dialog);
  /// omit for list views built from the bulk users snapshot.
  factory AppUser.fromMap(
    Map<String, dynamic> map, {
    Map<String, dynamic>? privateContact,
    Map<String, dynamic>? adminNotes,
  }) {
    final merged = <String, dynamic>{
      ...map,
      ...?privateContact,
      ...?adminNotes,
    };
    return AppUser._fromMap(merged, parseNestedCollections: true);
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
    final profileVerified = map['profileVerified'] == true;

    return AppUser(
      uid: map['uid']?.toString() ?? '',
      nom: map['nom']?.toString() ?? 'Nom inconnu',
      email: map['email']?.toString() ?? 'Adresse e-mail inconnue',
      role: normalizedRole.isEmpty ? 'utilisateur' : normalizedRole,
      photoProfil: map['photoProfil']?.toString() ?? '',
      estActif: _toBool(map['estActif'], true),
      authDisabled: map['authDisabled'] == true,
      emailVerified: _toBool(map['emailVerified'], false),
      createdByAdmin: map['createdByAdmin'] == true,
      followers: _parseInt(map['followers']) ?? 0,
      followings: _parseInt(map['followings']) ?? 0,
      dateInscription: _parseDate(map['dateInscription']),
      dernierLogin: _parseDate(map['dernierLogin']),
      emailVerifiedAt: _parseNullableDate(map['emailVerifiedAt']),
      phone: _normalizeNullableString(map['phone']),
      authDisabledReason: _normalizeNullableString(map['authDisabledReason']),
      profileVerified: profileVerified,
      profileVerificationStatus: _normalizeProfileVerificationStatus(
        map['profileVerificationStatus'],
        verified: profileVerified,
      ),
      profileVerifiedAt: _parseNullableDate(map['profileVerifiedAt']),
      profileVerifiedBy: _normalizeNullableString(map['profileVerifiedBy']),
      profileVerificationUpdatedAt: _parseNullableDate(
        map['profileVerificationUpdatedAt'],
      ),
      profileVerificationUpdatedBy: _normalizeNullableString(
        map['profileVerificationUpdatedBy'],
      ),
      profileVerificationNote: _normalizeNullableString(
        map['profileVerificationNote'],
      ),
      profileVerificationInvalidatedAt: _parseNullableDate(
        map['profileVerificationInvalidatedAt'],
      ),
      profileVerificationInvalidatedBy: _normalizeNullableString(
        map['profileVerificationInvalidatedBy'],
      ),
      profileVerificationInvalidationReason: _normalizeNullableString(
        map['profileVerificationInvalidationReason'],
      ),
      membership: Membership.fromMap(map['membership']),
      birthDate: _parseNullableDate(map['birthDate']),
      country: _normalizeNullableString(map['country']),
      city: _normalizeNullableString(map['city']),
      region: _normalizeNullableString(map['region']),
      languages: _safeList(map['languages']).isEmpty
          ? null
          : _safeList(
              map['languages'],
            ).map((entry) => entry.toString()).toList(),
      openToOpportunities: _toNullableBool(map['openToOpportunities']),
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
        (key, value) => MapEntry(key, value is num ? value.toDouble() : 0),
      ),
      football: PlayerFootballProfile.fromUserMap(map),
      club: ClubFootballProfile.fromUserMap(map),
      agent: AgentFootballProfile.fromUserMap(map),
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
                  (joueur) => AppUser.fromEmbeddedMap(
                    Map<String, dynamic>.from(joueur),
                  ),
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
      followersList: _safeList(
        map['followersList'],
      ).map((entry) => entry.toString()).toList(),
      followingsList: _safeList(
        map['followingsList'],
      ).map((entry) => entry.toString()).toList(),
      profilePublic: _toBool(map['profilePublic'], true),
      allowMessages: _toBool(map['allowMessages'], true),
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
      'profileVerified': profileVerified,
      'profileVerificationStatus': profileVerificationStatus,
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
      'emailVerifiedAt': emailVerifiedAt != null
          ? Timestamp.fromDate(emailVerifiedAt!)
          : null,
      'authDisabledReason': authDisabledReason,
      'profileVerifiedAt': profileVerifiedAt != null
          ? Timestamp.fromDate(profileVerifiedAt!)
          : null,
      'profileVerifiedBy': profileVerifiedBy,
      'profileVerificationUpdatedAt': profileVerificationUpdatedAt != null
          ? Timestamp.fromDate(profileVerificationUpdatedAt!)
          : null,
      'profileVerificationUpdatedBy': profileVerificationUpdatedBy,
      'profileVerificationNote': profileVerificationNote,
      'profileVerificationInvalidatedAt':
          profileVerificationInvalidatedAt != null
          ? Timestamp.fromDate(profileVerificationInvalidatedAt!)
          : null,
      'profileVerificationInvalidatedBy': profileVerificationInvalidatedBy,
      'profileVerificationInvalidationReason':
          profileVerificationInvalidationReason,
      // Volontairement absent de toEmbeddedMap : les droits ne suivent pas un
      // compte recopié dans le document d'un autre. Ici en revanche il faut
      // les garder, sinon la relecture d'un utilisateur enrichi de ses champs
      // privés (fetchUserWithPrivateFields) perdrait son dossier.
      'membership': membership.isRecorded ? membership.toMap() : null,
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
      ...football.toPatch(),
      ...club.toPatch(),
      ...agent.toPatch(),
      'playerProfile': playerProfile,
      'clubProfile': clubProfile,
      'agentProfile': agentProfile,
      'eventOrganizerProfile': eventOrganizerProfile,
      'offrePubliees': offrePubliees?.map((offre) => offre.toMap()).toList(),
      'eventPublies': eventPublies?.map((event) => event.toMap()).toList(),
      'nombreDeRecrutements': nombreDeRecrutements,
      'joueursSuivis': joueursSuivis
          ?.map((joueur) => joueur.toEmbeddedMap())
          .toList(),
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
  bool get isProfileTrusted => profileVerified && isEffectivelyActiveAccount;
  bool get profileVerificationNeedsReview =>
      !profileVerified && profileVerificationStatus == 'pending';

  bool get canBeProfileVerifiedByAdmin {
    return !isAdminPortalOnly &&
        isEffectivelyActiveAccount &&
        isMvpProfileComplete;
  }

  String get profileTrustLabel {
    if (isProfileTrusted) return 'Profil certifié';
    if (profileVerified && !isEffectivelyActiveAccount) {
      return 'Certification suspendue';
    }
    if (!isEffectivelyActiveAccount) return 'Compte à activer';
    if (profileVerificationNeedsReview) return 'À revalider';
    if (isMvpProfileComplete) return 'Prêt à vérifier';
    return 'Profil à compléter';
  }

  String get profileVerificationStatusLabel {
    switch (profileVerificationStatus) {
      case 'verified':
        return 'Vérifié par admin';
      case 'rejected':
        return 'Vérification refusée';
      case 'pending':
        return 'Vérification à refaire';
      case 'unverified':
      default:
        return 'Non vérifié';
    }
  }

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
      // Le profil de base, sans rien de footballistique : le poste est un
      // fait avance depuis la refonte, et l'exiger ici rendrait « Profil
      // complet » inatteignable pour un joueur.
      case 'joueur':
        return nom.isNotEmpty &&
            ((team?.trim().isNotEmpty ?? false) ||
                (clubActuel?.trim().isNotEmpty ?? false));
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
        return football.isNotEmpty;
      case 'club':
        return club.isNotEmpty;
      case 'recruteur':
      case 'agent':
        return agent.isNotEmpty;
      default:
        return false;
    }
  }

  /// Dossier exploitable par un recruteur.
  ///
  /// Miroir de la regle du depot mobile (`AppUser.hasScoutReadyProfile`), et
  /// c'est important qu'elle soit la meme : un administrateur qui voit
  /// « Profil elite » sur une fiche que le mobile annonce « partielle » ne
  /// peut plus arbitrer quoi que ce soit.
  ///
  /// L'age n'y figure pas : `birthDate` vit dans le sous-document prive et ne
  /// parvient pas a tous les lecteurs, donc l'exiger rendrait le verdict
  /// dependant de qui regarde. Il revient sous la forme du `birthYear` public,
  /// derive cote serveur.
  bool get hasScoutReadyProfile {
    if (!isPlayer) return false;

    if (country?.trim().isEmpty ?? true) return false;
    if (football.nationalities.isEmpty) return false;
    if (football.positions.isEmpty) return false;
    if (football.strongFoot == null) return false;
    if (football.heightCm == null) return false;
    if (football.contractStatus == null) return false;
    if (football.currentClubLevel == null) return false;
    if (football.currentSeason == null) return false;

    final hasEvidence =
        (videosPubliees?.isNotEmpty ?? false) ||
        (cvUrl?.trim().isNotEmpty ?? false);
    return hasEvidence;
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
    if (isMvpProfileComplete) return 'Profil complet';
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

  static bool _toBool(dynamic value, bool fallback) {
    if (value is bool) return value;
    return fallback;
  }

  static bool? _toNullableBool(dynamic value) {
    return value is bool ? value : null;
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

  static String _normalizeProfileVerificationStatus(
    dynamic value, {
    required bool verified,
  }) {
    final normalized = value?.toString().trim().toLowerCase();
    const supportedStatuses = {'verified', 'unverified', 'pending', 'rejected'};

    if (normalized != null && supportedStatuses.contains(normalized)) {
      return normalized;
    }

    return verified ? 'verified' : 'unverified';
  }
}
