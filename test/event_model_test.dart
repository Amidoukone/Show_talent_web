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
  });
}
