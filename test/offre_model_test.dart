import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/models/offre.dart';

void main() {
  group('Offre model', () {
    test('normalizeStatus handles canonical and legacy values', () {
      expect(Offre.normalizeStatus('ouverte'), 'ouverte');
      expect(Offre.normalizeStatus('Ferm\u00e9e'), 'fermee');
      expect(Offre.normalizeStatus('archiv\u00e9e'), 'archivee');
      expect(Offre.normalizeStatus('brouillon'), 'brouillon');
    });

    test('fromMap parses mixed date formats and fallback id', () {
      final raw = <String, dynamic>{
        'titre': 'Offre test',
        'description': 'Description',
        'dateDebut': Timestamp.fromMillisecondsSinceEpoch(1700000000000),
        'dateFin': '2024-12-31T00:00:00.000Z',
        'recruteur': <String, dynamic>{
          'uid': 'recruteur-1',
          'nom': 'Club A',
          'email': 'club@example.com',
          'role': 'club',
        },
        'candidats': [
          <String, dynamic>{
            'uid': 'joueur-1',
            'nom': 'Joueur A',
            'email': 'joueur@example.com',
            'role': 'joueur',
          },
        ],
        'statut': 'archiv\u00e9e',
      };

      final offre = Offre.fromMap(raw, fallbackId: 'fallback-id');

      expect(offre.id, 'fallback-id');
      expect(offre.titre, 'Offre test');
      expect(offre.candidats.length, 1);
      expect(offre.statut, 'archivee');
      expect(offre.dateDebut.year, 2023);
      expect(offre.dateFin.year, 2024);
    });

    test('toMap writes normalized status', () {
      final offre = Offre.fromMap(
        <String, dynamic>{
          'id': 'offre-1',
          'titre': 'Offre test',
          'description': 'Description',
          'dateDebut': DateTime.utc(2024, 1, 10),
          'dateFin': DateTime.utc(2024, 1, 20),
          'recruteur': <String, dynamic>{
            'uid': 'recruteur-1',
            'nom': 'Club A',
            'email': 'club@example.com',
            'role': 'club',
          },
          'candidats': const <Map<String, dynamic>>[],
          'statut': 'Ferm\u00e9e',
        },
      );

      final map = offre.toMap();
      expect(map['statut'], 'fermee');
    });
  });
}
