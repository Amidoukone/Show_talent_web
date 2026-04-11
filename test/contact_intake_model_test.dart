import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/models/contact_intake.dart';

void main() {
  group('Contact intake model', () {
    test('parses contact intake payload safely', () {
      final intake = ContactIntake.fromMap(
        <String, dynamic>{
          'requesterUid': 'club-1',
          'targetUid': 'player-1',
          'requesterRole': 'club',
          'targetRole': 'joueur',
          'contextType': 'event',
          'contextTitle': 'Tournoi U19',
          'contactReason': 'trial',
          'introMessage': 'Nous souhaitons organiser une evaluation.',
          'agencyFollowUpStatus': 'reviewing',
          'agencyFollowUpNote': 'A rappeler apres validation terrain.',
          'requesterSnapshot': <String, dynamic>{
            'displayName': 'Academie Horizon',
            'organisation': 'Horizon FC',
          },
          'targetSnapshot': <String, dynamic>{
            'prenom': 'Amadou',
            'nom': 'Diallo',
          },
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 4, 10, 12)),
        },
        fallbackId: 'intake-1',
      );

      expect(intake.id, 'intake-1');
      expect(intake.requesterDisplayName, 'Academie Horizon');
      expect(intake.targetDisplayName, 'Amadou Diallo');
      expect(intake.followUpLabel, 'En revue');
      expect(intake.contextLabel, 'Evenement');
      expect(intake.reasonLabel, 'Essai / Evaluation');
    });

    test('normalizes agency follow-up labels', () {
      expect(
        AgencyFollowUpStatus.label(AgencyFollowUpStatus.inProgress),
        'En accompagnement',
      );
      expect(
        AgencyFollowUpStatus.label('unknown'),
        'Nouveau lead',
      );
    });
  });
}
