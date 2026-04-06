import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:show_talent/models/user.dart';

class Event {
  final String id;
  final String titre;
  final String description;
  final DateTime dateDebut;
  final DateTime dateFin;
  final AppUser organisateur;
  final List<AppUser> participants;
  String statut;
  final String lieu;
  final bool estPublic;

  Event({
    required this.id,
    required this.titre,
    required this.description,
    required this.dateDebut,
    required this.dateFin,
    required this.organisateur,
    required this.participants,
    required this.statut,
    required this.lieu,
    required this.estPublic,
  });

  static String normalizeStatus(String rawStatus) {
    final value = rawStatus.trim().toLowerCase();
    switch (value) {
      case 'ouvert':
        return 'ouvert';
      case 'ferme':
      case 'ferm\u00e9':
      case 'ferm\u00c3\u00a9':
      case 'ferm\u00c3\u00a3\u00c2\u00a9':
        return 'ferme';
      case 'archive':
      case 'archiv\u00e9':
      case 'archiv\u00c3\u00a9':
      case 'archiv\u00c3\u00a3\u00c2\u00a9':
        return 'archive';
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
      'organisateur': organisateur.toMap(),
      'participants':
          participants.map((participant) => participant.toMap()).toList(),
      'statut': normalizeStatus(statut),
      'lieu': lieu,
      'estPublic': estPublic,
    };
  }

  factory Event.fromMap(
    Map<String, dynamic> map, {
    String? fallbackId,
  }) {
    final rawParticipants = map['participants'];
    final participantsMaps = rawParticipants is List
        ? rawParticipants
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList()
        : const <Map<String, dynamic>>[];

    final rawOrganisateur = map['organisateur'];
    final organisateurMap = rawOrganisateur is Map
        ? Map<String, dynamic>.from(rawOrganisateur)
        : <String, dynamic>{};

    final rawId = map['id']?.toString().trim() ?? '';
    final resolvedId = rawId.isNotEmpty ? rawId : (fallbackId ?? '');

    return Event(
      id: resolvedId,
      titre: map['titre']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      dateDebut: _parseDate(map['dateDebut']),
      dateFin: _parseDate(map['dateFin']),
      organisateur: AppUser.fromMap(organisateurMap),
      participants: participantsMaps.map(AppUser.fromMap).toList(),
      statut: normalizeStatus(map['statut']?.toString() ?? 'ouvert'),
      lieu: map['lieu']?.toString() ?? '',
      estPublic: map['estPublic'] as bool? ?? true,
    );
  }

  factory Event.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Event.fromMap(data, fallbackId: doc.id);
  }
}
