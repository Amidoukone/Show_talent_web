// Les signalements de coordonnees, enfin lisibles.
//
// Le serveur retire les numeros et les adresses des champs libres avant
// publication et consigne ce qu'il a retire. Personne ne lisait ces traces :
// la capacite existait et n'atteignait aucune audience. La collection etait
// meme fermee aux deux sens jusqu'au 2026-11-19 -- le defaut que ce lot avait
// justement pour objet de fermer ailleurs.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:show_talent/config/app_environment.dart';
import 'package:show_talent/config/app_routes.dart';
import 'package:show_talent/controller/contact_leak_controller.dart';
import 'package:show_talent/dashboard/contact_leak_reports_widget.dart';
import 'package:show_talent/models/contact_leak_report.dart';
import 'package:show_talent/models/user.dart';

import 'test_support/admin_test_helpers.dart';

class _MockFirestore extends Fake implements FirebaseFirestore {}

/// Un controleur qui n'ouvre aucun flux Firestore.
class _SeededContactLeakController extends ContactLeakController {
  _SeededContactLeakController({
    List<ContactLeakReport> seededReports = const <ContactLeakReport>[],
    List<ContactLeakProfile> seededProfiles = const <ContactLeakProfile>[],
    bool atLimit = false,
  }) : super(firestore: _MockFirestore()) {
    reports.assignAll(seededReports);
    profiles.assignAll(seededProfiles);
    truncated.value = atLimit;
    isLoading.value = false;
  }

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> refreshLeaks() async {}
}

ContactLeakReport _report({
  required String collection,
  required String docId,
  String ownerUid = 'recruteur-1',
  List<String> fields = const <String>['description'],
  Map<String, dynamic>? originals,
  DateTime? flaggedAt,
}) {
  return ContactLeakReport.fromMap(<String, dynamic>{
    'collection': collection,
    'docId': docId,
    'ownerUid': ownerUid,
    'fields': fields,
    'originals':
        originals ??
        <String, dynamic>{'description': 'Appelez le 07 00 00 00 01'},
    'flaggedAt': Timestamp.fromDate(flaggedAt ?? DateTime(2026, 11, 18)),
  }, docIdFallback: '${collection}__$docId');
}

Future<void> _pumpLeaks(
  WidgetTester tester, {
  List<ContactLeakReport> reports = const <ContactLeakReport>[],
  List<ContactLeakProfile> profiles = const <ContactLeakProfile>[],
  bool atLimit = false,
}) async {
  final controller = _SeededContactLeakController(
    seededReports: reports,
    seededProfiles: profiles,
    atLimit: atLimit,
  );
  addTearDown(controller.onClose);
  addTearDown(Get.reset);

  await pumpAdminTestApp(
    tester,
    ContactLeakReportsWidget(
      controller: controller,
      userController: TestUserController(
        users: [
          buildTestUser(
            uid: 'recruteur-1',
            nom: 'Kone Recrutement',
            email: 'recruteur@exemple.test',
            role: 'recruteur',
          ),
        ],
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('modele de signalement', () {
    test('les noms de champs du depot mobile sont lus tels quels', () {
      final report = _report(
        collection: 'offres',
        docId: 'offer-1',
        fields: const <String>['description', 'recruteur.email'],
        originals: const <String, dynamic>{
          'description': 'Joignable au 07 00 00 00 01',
          'recruteur.email': 'contact@exemple.test',
        },
        flaggedAt: DateTime.utc(2026, 11, 18, 9),
      );

      expect(report.id, 'offres__offer-1');
      expect(report.collection, 'offres');
      expect(report.docId, 'offer-1');
      expect(report.ownerUid, 'recruteur-1');
      expect(report.isOffer, isTrue);
      expect(report.isEvent, isFalse);
      expect(report.collectionLabel, 'Offre');
      expect(report.fields, ['description', 'recruteur.email']);
      expect(report.originals['recruteur.email'], 'contact@exemple.test');
      expect(report.flaggedAt!.toUtc(), DateTime.utc(2026, 11, 18, 9));
    });

    test('un evenement est reconnu comme tel', () {
      final report = _report(collection: 'events', docId: 'event-1');

      expect(report.isEvent, isTrue);
      expect(report.collectionLabel, 'Événement');
    });

    test('une collection inconnue s affiche telle quelle', () {
      final report = _report(collection: 'autres', docId: 'x');

      expect(report.collectionLabel, 'autres');
    });

    test('un reliquat de bloc d auteur se distingue d une tentative', () {
      // Un document ecrit avant le demenagement des coordonnees porte encore
      // `recruteur.email` : le nettoyage l'a retire, et son auteur n'a rien
      // tente. Confondre les deux ferait sanctionner quelqu'un pour une
      // migration.
      final legacy = _report(
        collection: 'offres',
        docId: 'o1',
        fields: const <String>['recruteur.email', 'recruteur.phone'],
      );
      final attempt = _report(
        collection: 'offres',
        docId: 'o2',
        fields: const <String>['description', 'recruteur.email'],
      );

      expect(legacy.isLegacyOwnerBlockOnly, isTrue);
      expect(attempt.isLegacyOwnerBlockOnly, isFalse);
    });

    test('un signalement sans champ n est pas un reliquat', () {
      final empty = _report(
        collection: 'offres',
        docId: 'o3',
        fields: const <String>[],
      );

      expect(empty.isLegacyOwnerBlockOnly, isFalse);
    });
  });

  group('profil signale', () {
    test('la valeur saisie du champ signale est relue sur le document', () {
      // Le document interne garde la valeur saisie : c'est elle qui dit ce que
      // l'utilisateur a voulu publier.
      final profile = ContactLeakProfile.fromMap(<String, dynamic>{
        'uid': 'joueur-1',
        'nom': 'Mamadou Diabaté',
        'role': 'joueur',
        'contactLeakFlagged': true,
        'contactLeakFields': <String>['bio', 'city'],
        'bio': 'Contactez-moi au 07 00 00 00 01',
        'city': 'Abidjan 0700000001',
        'ligue': 'Non signalée',
      });

      expect(profile.uid, 'joueur-1');
      expect(profile.fields, ['bio', 'city']);
      expect(profile.currentValues['bio'], 'Contactez-moi au 07 00 00 00 01');
      expect(
        profile.currentValues.containsKey('ligue'),
        isFalse,
        reason: 'seuls les champs signales sont relus',
      );
    });

    test('la liste des champs scannes suit celle du depot mobile', () {
      // Un champ ajoute la-bas et absent ici se signalerait sans que sa
      // valeur soit lisible.
      expect(ContactLeakProfile.scannedFields, hasLength(12));
      expect(ContactLeakProfile.scannedFields, contains('currentClubName'));
      expect(ContactLeakProfile.scannedFields, contains('performances'));
      expect(ContactLeakProfile.scannedFields, contains('region'));
    });

    test('un identifiant absent retombe sur celui du document', () {
      final profile = ContactLeakProfile.fromMap(<String, dynamic>{
        'nom': 'Sans uid',
      }, docIdFallback: 'doc-1');

      expect(profile.uid, 'doc-1');
    });
  });

  group('intitules de champs', () {
    test('les cles du document sont traduites', () {
      expect(describeLeakField('bio'), 'Présentation');
      expect(describeLeakField('team'), 'Équipe');
      expect(describeLeakField('remuneration'), 'Rémunération');
    });

    test('une cle pointee dit qu elle vient du bloc recopie', () {
      final label = describeLeakField('recruteur.email');

      expect(label, contains('Recruteur'));
      expect(label, contains('bloc recopié'));
      expect(label, contains('email'));
    });

    test('une cle inconnue s affiche telle quelle', () {
      expect(describeLeakField('champInedit'), 'champInedit');
    });
  });

  group('le compte porte le signalement', () {
    test('AppUser lit les deux champs, et les conserve a la relecture', () {
      final user = AppUser.fromMap(<String, dynamic>{
        'uid': 'joueur-1',
        'nom': 'Mamadou Diabaté',
        'role': 'joueur',
        'emailVerified': true,
        'dateInscription': DateTime(2026, 1, 1),
        'dernierLogin': DateTime(2026, 11, 18),
        'contactLeakFlagged': true,
        'contactLeakFields': <String>['bio'],
      });

      expect(user.contactLeakFlagged, isTrue);
      expect(user.contactLeakFields, ['bio']);

      // fetchUserWithPrivateFields repasse par toMap() : le drapeau doit
      // survivre, sinon la fiche de revue l'oublie des qu'on l'ouvre.
      final roundTripped = AppUser.fromMap(user.toMap());
      expect(roundTripped.contactLeakFlagged, isTrue);
      expect(roundTripped.contactLeakFields, ['bio']);
    });

    test('un compte sain ne porte aucun signalement', () {
      final user = buildTestUser(
        uid: 'u1',
        nom: 'Compte sain',
        email: 'u1@exemple.test',
        role: 'joueur',
      );

      expect(user.contactLeakFlagged, isFalse);
      expect(user.contactLeakFields, isEmpty);
    });
  });

  group('accessibilite de la surface', () {
    test('l onglet est monte a la position que les liens profonds visent', () {
      expect(dashboardItemIndex('Coordonnées retirées'), 11);
      expect(dashboardScreenIndex('ContactLeakReportsWidget'), 11);
      expect(dashboardGroupIndices('Modération'), contains(11));

      // Les onglets precedents n'ont pas bouge.
      expect(dashboardItemIndex('Statuts contractuels'), 9);
      expect(dashboardItemIndex('Rattachements'), 10);
    });

    test('le lien profond resout vers le dernier onglet', () {
      for (final slug in const <String>[
        'contact-leaks',
        'coordonnees-retirees',
      ]) {
        expect(
          AppRoutes.resolveDashboardInitialIndex(
            environment: AppEnvironment.local,
            uri: Uri.parse('http://localhost:8080/#/admin-dashboard?tab=$slug'),
          ),
          11,
        );
      }
    });

    test('le controleur est enregistre par la liaison du tableau de bord', () {
      expect(
        File('lib/config/app_page_bindings.dart').readAsStringSync(),
        contains('ContactLeakController'),
      );
    });
  });

  group('ecran des signalements', () {
    testWidgets('une offre nettoyee montre son auteur et ses champs', (
      tester,
    ) async {
      await _pumpLeaks(
        tester,
        reports: [
          _report(
            collection: 'offres',
            docId: 'offer-1',
            fields: const <String>['description', 'remuneration'],
          ),
        ],
      );

      expect(find.text('Kone Recrutement'), findsOneWidget);
      expect(find.text('Offre'), findsWidgets);
      expect(find.textContaining('Description'), findsOneWidget);
      expect(find.textContaining('Rémunération'), findsOneWidget);
    });

    testWidgets('la fiche montre le texte retire en entier', (tester) async {
      // C'est la seule audience qu'un signalement ait : le texte n'a jamais
      // ete publie, et il est montre ici parce qu'il n'est lisible nulle part
      // ailleurs.
      await _pumpLeaks(
        tester,
        reports: [
          _report(
            collection: 'offres',
            docId: 'offer-1',
            originals: const <String, dynamic>{
              'description': 'Appelez le 07 00 00 00 01 pour un essai',
            },
          ),
        ],
      );

      await tester.tap(find.text('Kone Recrutement'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Appelez le 07 00 00 00 01'), findsOneWidget);
      expect(find.text('CE QUI A ÉTÉ RETIRÉ'), findsOneWidget);
    });

    testWidgets('un profil signale se distingue d une annonce', (tester) async {
      await _pumpLeaks(
        tester,
        profiles: [
          const ContactLeakProfile(
            uid: 'joueur-1',
            nom: 'Mamadou Diabaté',
            role: 'joueur',
            fields: <String>['bio'],
            currentValues: <String, dynamic>{'bio': 'Au 07 00 00 00 01'},
          ),
        ],
      );

      expect(find.text('Profil'), findsWidgets);
      expect(find.text('profils'), findsOneWidget);
    });

    testWidgets('le filtre d origine separe les trois sources', (tester) async {
      await _pumpLeaks(
        tester,
        reports: [
          _report(collection: 'offres', docId: 'o1'),
          _report(collection: 'events', docId: 'e1'),
        ],
        profiles: [
          const ContactLeakProfile(
            uid: 'joueur-1',
            nom: 'Mamadou Diabaté',
            role: 'joueur',
            fields: <String>['bio'],
          ),
        ],
      );

      expect(find.text('offres'), findsOneWidget);
      expect(find.text('événements'), findsOneWidget);
      expect(find.text('profils'), findsOneWidget);

      // Restreindre aux profils ne doit laisser que celui-la.
      await tester.tap(find.text('profils'));
      await tester.pumpAndSettle();

      expect(find.text('Mamadou Diabaté'), findsOneWidget);
      expect(find.text('Kone Recrutement'), findsNothing);
    });

    testWidgets('une liste plafonnee le dit avant de conclure', (tester) async {
      await _pumpLeaks(
        tester,
        reports: [_report(collection: 'offres', docId: 'o1')],
        atLimit: true,
      );

      expect(find.text('Liste plafonnée'), findsOneWidget);
    });

    testWidgets('aucun signalement est un bon etat, pas une erreur', (
      tester,
    ) async {
      await _pumpLeaks(tester);

      expect(find.text('Aucun signalement'), findsOneWidget);
    });
  });
}
