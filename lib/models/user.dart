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
  String? country;
  String? city;
  String? region;

  String? bio;
  String? position;
  String? clubActuel;
  int? nombreDeMatchs;
  int? buts;
  int? assistances;
  List<Video>? videosPubliees;
  Map<String, double>? performances;

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
    this.country,
    this.city,
    this.region,
    this.bio,
    this.position,
    this.clubActuel,
    this.nombreDeMatchs,
    this.buts,
    this.assistances,
    this.videosPubliees,
    this.performances,
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
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }

      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) {
        return null;
      }

      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is String) {
        return DateTime.tryParse(value);
      }

      return null;
    }

    List<dynamic> safeList(dynamic value) {
      if (value is List) {
        return value;
      }

      return const [];
    }

    Map<String, dynamic>? safeMap(dynamic value) {
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }

      return null;
    }

    final normalizedRole = normalizeUserRole(map['role']?.toString());

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
      followers: (map['followers'] as num?)?.toInt() ?? 0,
      followings: (map['followings'] as num?)?.toInt() ?? 0,
      dateInscription: parseDate(map['dateInscription']),
      dernierLogin: parseDate(map['dernierLogin']),
      emailVerifiedAt: parseNullableDate(map['emailVerifiedAt']),
      phone: map['phone']?.toString(),
      authDisabledReason: map['authDisabledReason']?.toString(),
      country: map['country']?.toString(),
      city: map['city']?.toString(),
      region: map['region']?.toString(),
      bio: map['bio']?.toString(),
      position: map['position']?.toString(),
      clubActuel: map['clubActuel']?.toString(),
      nombreDeMatchs: (map['nombreDeMatchs'] as num?)?.toInt(),
      buts: (map['buts'] as num?)?.toInt(),
      assistances: (map['assistances'] as num?)?.toInt(),
      videosPubliees: safeList(map['videosPubliees'])
          .whereType<Map>()
          .map((video) => Video.fromMap(Map<String, dynamic>.from(video)))
          .toList(),
      performances: safeMap(map['performances'])?.map(
            (key, value) => MapEntry(
              key,
              value is num ? value.toDouble() : 0,
            ),
          ) ??
          {},
      nomClub: map['nomClub']?.toString(),
      ligue: map['ligue']?.toString(),
      offrePubliees: safeList(map['offrePubliees'])
          .whereType<Map>()
          .map((offre) => Offre.fromMap(Map<String, dynamic>.from(offre)))
          .toList(),
      eventPublies: safeList(map['eventPublies'])
          .whereType<Map>()
          .map((event) => Event.fromMap(Map<String, dynamic>.from(event)))
          .toList(),
      entreprise: map['entreprise']?.toString(),
      nombreDeRecrutements: (map['nombreDeRecrutements'] as num?)?.toInt(),
      team: map['team']?.toString(),
      joueursSuivis: safeList(map['joueursSuivis'])
          .whereType<Map>()
          .map((joueur) => AppUser.fromMap(Map<String, dynamic>.from(joueur)))
          .toList(),
      clubsSuivis: safeList(map['clubsSuivis'])
          .whereType<Map>()
          .map((club) => AppUser.fromMap(Map<String, dynamic>.from(club)))
          .toList(),
      videosLikees: safeList(map['videosLikees'])
          .whereType<Map>()
          .map((video) => Video.fromMap(Map<String, dynamic>.from(video)))
          .toList(),
      followersList: safeList(map['followersList'])
          .map((entry) => entry.toString())
          .toList(),
      followingsList: safeList(map['followingsList'])
          .map((entry) => entry.toString())
          .toList(),
      profilePublic: map['profilePublic'] as bool? ?? true,
      allowMessages: map['allowMessages'] as bool? ?? true,
      cvUrl: map['cvUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
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
      'followers': followers,
      'followings': followings,
      'dateInscription': Timestamp.fromDate(dateInscription),
      'dernierLogin': Timestamp.fromDate(dernierLogin),
      'emailVerifiedAt':
          emailVerifiedAt != null ? Timestamp.fromDate(emailVerifiedAt!) : null,
      'phone': phone,
      'authDisabledReason': authDisabledReason,
      'country': country,
      'city': city,
      'region': region,
      'bio': bio,
      'position': position,
      'clubActuel': clubActuel,
      'nombreDeMatchs': nombreDeMatchs,
      'buts': buts,
      'assistances': assistances,
      'videosPubliees': videosPubliees != null
          ? videosPubliees!.map((video) => video.toMap()).toList()
          : [],
      'performances': performances ?? {},
      'nomClub': nomClub,
      'ligue': ligue,
      'offrePubliees': offrePubliees != null
          ? offrePubliees!.map((offre) => offre.toMap()).toList()
          : [],
      'eventPublies': eventPublies != null
          ? eventPublies!.map((event) => event.toMap()).toList()
          : [],
      'entreprise': entreprise,
      'nombreDeRecrutements': nombreDeRecrutements,
      'team': team,
      'joueursSuivis': joueursSuivis != null
          ? joueursSuivis!.map((joueur) => joueur.toMap()).toList()
          : [],
      'clubsSuivis': clubsSuivis != null
          ? clubsSuivis!.map((club) => club.toMap()).toList()
          : [],
      'videosLikees': videosLikees != null
          ? videosLikees!.map((video) => video.toMap()).toList()
          : [],
      'followersList': followersList,
      'followingsList': followingsList,
      'profilePublic': profilePublic,
      'allowMessages': allowMessages,
      'cvUrl': cvUrl,
    };
  }

  bool get isEffectivelyActiveAccount => !authDisabled && emailVerified;

  bool get isAdminPortalOnly => isAdminPortalOnlyRole(role);
  bool get hasManagedAccountRole => isManagedAccountRole(role);
  bool get canPublishOpportunities => isOpportunityPublisherRole(role);

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
}
