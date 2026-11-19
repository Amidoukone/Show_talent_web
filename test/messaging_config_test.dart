// L'etat de la messagerie mediatisee, rendu visible avant la bascule.
//
// `config/messaging` est ferme en ecriture a tout client et aucune Cloud
// Function ne l'ecrit : il se modifie par la console, ce qui est delibere --
// refermer un mode qui aurait mal tourne ne doit pas demander de publier un
// build. Ce qui manquait n'etait donc pas une action mais une VUE : activer le
// mode sans nommer de compte de support ferme toute la messagerie de la
// plateforme, et rien nulle part ne l'annoncait.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:show_talent/models/messaging_config.dart';
import 'package:show_talent/widgets/messaging_config_panel.dart';

import 'test_support/admin_test_helpers.dart';

Future<void> _pumpPanel(
  WidgetTester tester, {
  MessagingConfig config = MessagingConfig.absent,
  String error = '',
}) async {
  final controller = TestMessagingConfigController(
    seeded: config,
    error: error,
  );
  addTearDown(controller.onClose);
  addTearDown(Get.reset);

  await pumpAdminTestApp(
    tester,
    SingleChildScrollView(
      child: MessagingConfigPanel(
        controller: controller,
        userController: TestUserController(
          users: [
            buildTestUser(
              uid: 'support-1',
              nom: 'Support Adfoot',
              email: 'support@exemple.test',
              role: 'admin',
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('modele de reglage', () {
    test('un document absent se distingue d un mode desactive', () {
      // Les deux donnent la meme messagerie ouverte, mais pas la meme
      // conclusion : l'un est un reglage pris, l'autre un document jamais cree.
      expect(MessagingConfig.absent.exists, isFalse);
      expect(MessagingConfig.absent.statusLabel, 'Non configurée');

      final configured = MessagingConfig.fromMap(<String, dynamic>{
        'mediatedOnly': false,
      });
      expect(configured.exists, isTrue);
      expect(configured.statusLabel, 'Ouverte');
    });

    test('le mode actif avec des comptes nommes est un etat sain', () {
      final config = MessagingConfig.fromMap(<String, dynamic>{
        'mediatedOnly': true,
        'supportUids': <String>['support-1', 'support-2'],
      });

      expect(config.mediatedOnly, isTrue);
      expect(config.supportUids, ['support-1', 'support-2']);
      expect(config.closesAllMessaging, isFalse);
      expect(config.statusLabel, 'Médiatisée');
    });

    test('le mode actif sans compte ferme toute la messagerie', () {
      // Les regles exigent qu'une conversation ait un compte nomme d'un cote :
      // activer sans nommer personne n'ouvre plus aucune conversation. C'est
      // le bon echec, et ce n'est pas un etat utilisable.
      final config = MessagingConfig.fromMap(<String, dynamic>{
        'mediatedOnly': true,
      });

      expect(config.closesAllMessaging, isTrue);
      expect(config.statusLabel, 'Médiatisée, sans compte de support');
    });

    test('des comptes nommes hors mode mediatise ne ferment rien', () {
      final config = MessagingConfig.fromMap(<String, dynamic>{
        'mediatedOnly': false,
        'supportUids': <String>['support-1'],
      });

      expect(config.closesAllMessaging, isFalse);
      expect(config.statusLabel, 'Ouverte');
    });

    test('une liste bruitee est nettoyee sans lever', () {
      final config = MessagingConfig.fromMap(<String, dynamic>{
        'mediatedOnly': true,
        'supportUids': <Object?>['  support-1  ', '', null, 42],
      });

      expect(config.supportUids, ['support-1', '42']);
    });

    test('une forme inattendue ne fait pas echouer la lecture', () {
      final config = MessagingConfig.fromMap(<String, dynamic>{
        'mediatedOnly': 'oui',
        'supportUids': 'support-1',
      });

      expect(config.exists, isTrue);
      expect(config.mediatedOnly, isFalse);
      expect(config.supportUids, isEmpty);
    });
  });

  group('panneau de lecture', () {
    testWidgets('un mode actif sans compte crie, en rouge', (tester) async {
      await _pumpPanel(
        tester,
        config: MessagingConfig.fromMap(<String, dynamic>{
          'mediatedOnly': true,
        }),
      );

      expect(
        find.text('La messagerie est fermée à tout le monde'),
        findsOneWidget,
      );
      expect(find.text('Médiatisée, sans compte de support'), findsOneWidget);
      expect(find.text('Aucun'), findsOneWidget);
    });

    testWidgets('un compte nomme est affiche avec son identifiant', (
      tester,
    ) async {
      // L'identifiant et pas seulement le nom : c'est lui qui figure dans le
      // document, donc c'est lui qu'un operateur recopie dans la console.
      await _pumpPanel(
        tester,
        config: MessagingConfig.fromMap(<String, dynamic>{
          'mediatedOnly': true,
          'supportUids': <String>['support-1'],
        }),
      );

      expect(find.textContaining('Support Adfoot'), findsOneWidget);
      expect(find.textContaining('support-1'), findsOneWidget);
      expect(
        find.text('La messagerie est fermée à tout le monde'),
        findsNothing,
      );
    });

    testWidgets('un compte hors fenetre reste exploitable', (tester) async {
      await _pumpPanel(
        tester,
        config: MessagingConfig.fromMap(<String, dynamic>{
          'mediatedOnly': true,
          'supportUids': <String>['support-hors-fenetre'],
        }),
      );

      expect(find.textContaining('support-hors-fenetre'), findsOneWidget);
    });

    testWidgets('un document jamais cree le dit', (tester) async {
      await _pumpPanel(tester);

      expect(find.text('Non configurée'), findsOneWidget);
      expect(
        find.textContaining('config/messaging — jamais créé'),
        findsOneWidget,
      );
    });

    testWidgets('le panneau renvoie au runbook plutot qu a un bouton', (
      tester,
    ) async {
      // Lecture seule par construction : il n'y a aucun bouton a proposer, et
      // en inventer un ferait croire que le portail peut basculer le mode.
      await _pumpPanel(tester);

      expect(find.textContaining('runbook de production'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(Switch), findsNothing);
    });
  });

  group('procedure documentee', () {
    test('le runbook porte la procedure console, dans le bon ordre', () {
      // Le plan laissait le choix entre un ecran qui ecrit par un callable a
      // creer, et une procedure console documentee. La seconde a ete retenue :
      // la bascule doit rester possible quand tout va mal, sans build publie.
      final runbook = File(
        'docs/runbook-production-admin-mobile.md',
      ).readAsStringSync();

      expect(runbook, contains('## Messagerie mediatisee'));
      expect(runbook, contains('config/messaging'));
      expect(runbook, contains('mediatedOnly'));
      expect(runbook, contains('supportUids'));

      // L'ordre des ecritures est le point qui compte : nommer les comptes
      // avant d'activer, sinon la messagerie ferme entre les deux ecritures.
      final supportStep = runbook.indexOf('Ecrire `supportUids` **d abord**');
      final activateStep = runbook.indexOf('Passer `mediatedOnly` a `true`');
      expect(supportStep, greaterThan(-1));
      expect(activateStep, greaterThan(supportStep));
    });
  });
}
