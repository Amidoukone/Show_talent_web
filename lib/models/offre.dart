import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:show_talent/models/user.dart';

class Offre {
  final String id;
  final String titre;
  final String description;
  final DateTime dateDebut;
  final DateTime dateFin;
  final AppUser recruteur;
  final List<AppUser> candidats;
  String statut;

  Offre({
    required this.id,
    required this.titre,
    required this.description,
    required this.dateDebut,
    required this.dateFin,
    required this.recruteur,
    required this.candidats,
    required this.statut,
  });

  static String normalizeStatus(String rawStatus) {
    final value = rawStatus.trim().toLowerCase();
    switch (value) {
      case 'ouverte':
        return 'ouverte';
      case 'fermee':
      case 'ferm\u00e9e':
      case 'ferm\u00c3\u00a9e':
      case 'ferm\u00c3\u00a3\u00c2\u00a9e':
        return 'fermee';
      case 'archivee':
      case 'archiv\u00e9e':
      case 'archiv\u00c3\u00a9e':
      case 'archiv\u00c3\u00a3\u00c2\u00a9e':
        return 'archivee';
      case 'brouillon':
        return 'brouillon';
      default:
        return value;
    }
  }

  static DateTime _parseDate(
    dynamic value, {
    DateTime? fallback,
  }) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return fallback ?? DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titre': titre,
      'description': description,
      'dateDebut': dateDebut,
      'dateFin': dateFin,
      'recruteur': recruteur.toMap(),
      'candidats': candidats.map((joueur) => joueur.toMap()).toList(),
      'statut': normalizeStatus(statut),
    };
  }

  factory Offre.fromMap(
    Map<String, dynamic> map, {
    String? fallbackId,
  }) {
    final rawId = map['id']?.toString().trim() ?? '';
    final resolvedId = rawId.isNotEmpty ? rawId : (fallbackId ?? '');
    final rawRecruteur = map['recruteur'];
    final recruteurMap = rawRecruteur is Map
        ? Map<String, dynamic>.from(rawRecruteur)
        : <String, dynamic>{};
    final rawCandidats = map['candidats'];
    final candidatsMaps = rawCandidats is List
        ? rawCandidats
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList()
        : const <Map<String, dynamic>>[];

    return Offre(
      id: resolvedId,
      titre: map['titre']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      dateDebut: _parseDate(map['dateDebut']),
      dateFin: _parseDate(map['dateFin']),
      recruteur: AppUser.fromMap(recruteurMap),
      candidats: candidatsMaps.map(AppUser.fromMap).toList(),
      statut: normalizeStatus(map['statut']?.toString() ?? 'ouverte'),
    );
  }

  factory Offre.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Offre.fromMap(data, fallbackId: doc.id);
  }
}
