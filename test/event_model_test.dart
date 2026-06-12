import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/models/event.dart';

void main() {
  group('Event model', () {
    test('normalizeStatus handles canonical and legacy values', () {
      expect(Event.normalizeStatus('ouvert'), 'ouvert');
      expect(Event.normalizeStatus('ferm\u00e9'), 'ferme');
      expect(Event.normalizeStatus('archiv\u00e9'), 'archive');
      expect(Event.normalizeStatus('brouillon'), 'brouillon');
    });

    test('fromMap parses mixed date formats and fallback id', () {
      final raw = <String, dynamic>{
        'titre': 'Event test',
        'description': 'Description',
        'dateDebut': Timestamp.fromMillisecondsSinceEpoch(1710000000000),
        'dateFin': '2025-02-03T00:00:00.000Z',
        'organisateur': <String, dynamic>{
          'uid': 'org-1',
          'nom': 'Organisateur A',
          'email': 'org@example.com',
          'role': 'club',
        },
        'participants': [
          <String, dynamic>{
            'uid': 'joueur-1',
            'nom': 'Joueur A',
            'email': 'joueur@example.com',
            'role': 'joueur',
          },
        ],
        'statut': 'archiv\u00e9',
        'lieu': 'Paris',
      };

      final event = Event.fromMap(raw, fallbackId: 'event-fallback');

      expect(event.id, 'event-fallback');
      expect(event.statut, 'archive');
      expect(event.participants.length, 1);
      expect(event.estPublic, true);
      expect(event.dateDebut.year, 2024);
      expect(event.dateFin.year, 2025);
    });

    test('toMap writes normalized status', () {
      final event = Event.fromMap(
        <String, dynamic>{
          'id': 'event-1',
          'titre': 'Event test',
          'description': 'Description',
          'dateDebut': DateTime.utc(2024, 3, 1),
          'dateFin': DateTime.utc(2024, 3, 2),
          'organisateur': <String, dynamic>{
            'uid': 'org-1',
            'nom': 'Organisateur A',
            'email': 'org@example.com',
            'role': 'club',
          },
          'participants': const <Map<String, dynamic>>[],
          'statut': 'ferm\u00e9',
          'lieu': 'Abidjan',
          'estPublic': false,
        },
      );

      final map = event.toMap();
      expect(map['statut'], 'ferme');
      expect(map['estPublic'], false);
    });

    test('fromMap accepts mobile enriched fields and aliases', () {
      final event = Event.fromMap(
        <String, dynamic>{
          'title': 'Tournoi regional',
          'body': 'Detection ouverte aux academies.',
          'startDate': '2026-07-10T08:00:00.000Z',
          'endDate': '2026-07-10T18:00:00.000Z',
          'ownerUid': 'club-2',
          'ownerName': 'Club Horizon',
          'ownerRole': 'club',
          'status': 'archived',
          'location': 'Yamoussoukro',
          'isPublic': false,
          'capacity': 64,
          'tags': ['u19', 'detection', ''],
          'streamingUrl': 'https://stream.example/live',
          'flyerUrl': 'https://cdn.example/flyer.jpg',
          'views': 42,
          'archivedAt': Timestamp.fromDate(DateTime.utc(2026, 7, 11)),
        },
        fallbackId: 'event-alias',
      );

      expect(event.id, 'event-alias');
      expect(event.titre, 'Tournoi regional');
      expect(event.description, contains('Detection'));
      expect(event.organisateur.uid, 'club-2');
      expect(event.organisateur.nom, 'Club Horizon');
      expect(event.statut, 'archive');
      expect(event.lieu, 'Yamoussoukro');
      expect(event.estPublic, isFalse);
      expect(event.capaciteMax, 64);
      expect(event.tags, ['u19', 'detection']);
      expect(event.streamingUrl, 'https://stream.example/live');
      expect(event.flyerUrl, 'https://cdn.example/flyer.jpg');
      expect(event.views, 42);
      expect(event.archivedAt, isNotNull);
      expect(event.isOpenForRegistration, isFalse);
    });
  });
}
