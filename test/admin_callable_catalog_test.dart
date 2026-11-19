// Le catalogue des actions admin, compare au code de ce depot.
//
// `contract:mobile` compare deja ce catalogue au depot mobile : il verifie que
// chaque callable requis y figure. Personne ne verifiait l'inverse, ni ce que
// le catalogue dit du PORTAIL -- et c'est la que trois entrees de la famille
// video avaient derive, en nommant des ecrans qui n'appellent pas l'action.
//
// Un champ de texte libre que rien ne relit redevient faux en quelques mois.
// Ces tests en font une affirmation verifiable.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/utils/admin_callable_action_catalog.dart';

/// Les classes declarees sous les deux dossiers qui portent des surfaces.
Set<String> _declaredClasses() {
  final classes = <String>{};
  final pattern = RegExp(r'^class ([A-Z][A-Za-z0-9_]*)', multiLine: true);

  for (final root in const <String>['lib/dashboard', 'lib/widgets']) {
    for (final entity in Directory(root).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final match in pattern.allMatches(entity.readAsStringSync())) {
        classes.add(match.group(1)!);
      }
    }
  }
  return classes;
}

String _serviceSource(String name) =>
    File('lib/services/$name').readAsStringSync();

void main() {
  group('catalogue des actions admin', () {
    test('chaque surface nommee est une classe qui existe', () {
      // Le defaut reel : `uiSurfaces` melangeait des libelles
      // (« Gestion des utilisateurs ») et des noms de classes, donc aucune
      // verification n'etait possible. Tous sont des noms de classes
      // maintenant, et ce test l'impose.
      final declared = _declaredClasses();
      final unknown = <String>[];

      for (final action in adminCallableActions) {
        for (final surface in action.uiSurfaces) {
          if (!declared.contains(surface)) {
            unknown.add('${action.id} -> $surface');
          }
        }
      }

      expect(
        unknown,
        isEmpty,
        reason:
            'uiSurfaces doit nommer des classes de lib/dashboard ou '
            'lib/widgets, pas des libelles.',
      );
    });

    test('une action raccordee nomme au moins une surface', () {
      // Sans cette regle, `isConnectedInUi: true` pourrait rester vrai apres
      // la suppression de l'ecran qui appelait l'action -- exactement la
      // panne silencieuse que ce catalogue existe pour empecher.
      final orphans = connectedAdminCallableActions
          .where((action) => action.uiSurfaces.isEmpty)
          .map((action) => action.id)
          .toList();

      expect(orphans, isEmpty);
    });

    test('chaque callable raccorde est appele par un service, et un seul', () {
      final contentService = _serviceSource('admin_content_service.dart');
      final managedService = _serviceSource('managed_account_service.dart');

      final missing = <String>[];
      final duplicated = <String>[];

      for (final action in connectedAdminCallableActions) {
        final literal = "'${action.callableName}'";
        final inContent = contentService.contains(literal);
        final inManaged = managedService.contains(literal);

        if (!inContent && !inManaged) missing.add(action.callableName);
        if (inContent && inManaged) duplicated.add(action.callableName);
      }

      expect(
        missing,
        isEmpty,
        reason:
            'une action annoncee raccordee doit etre appelee quelque part : '
            'c’est la difference entre une capacite et une promesse.',
      );
      expect(
        duplicated,
        isEmpty,
        reason:
            'deux services qui appellent le meme callable finissent par '
            'diverger sur la charge utile.',
      );
    });

    test('aucun callable des services n echappe au catalogue', () {
      // La direction inverse, et c'est elle qui a laisse passer la derive :
      // ajouter une methode de service sans entree de catalogue produit une
      // action que `contract:mobile` ne tiendra jamais a son standard.
      final catalogued = adminCallableActions
          .map((action) => action.callableName)
          .toSet();

      final pattern = RegExp(r"_callable\(\s*'([a-zA-Z][A-Za-z0-9]*)'");
      final found = <String>{};
      for (final name in const <String>[
        'admin_content_service.dart',
        'managed_account_service.dart',
      ]) {
        for (final match in pattern.allMatches(_serviceSource(name))) {
          found.add(match.group(1)!);
        }
      }

      expect(
        found,
        isNotEmpty,
        reason:
            'le motif de detection des callables ne doit jamais rien '
            'trouver : ce serait un test vert qui ne verifie rien.',
      );
      expect(found.difference(catalogued), isEmpty);
    });

    test('les identifiants et les callables sont uniques', () {
      final ids = adminCallableActions.map((action) => action.id).toList();
      final callables = adminCallableActions
          .map((action) => action.callableName)
          .toList();

      expect(ids.toSet(), hasLength(ids.length));
      expect(callables.toSet(), hasLength(callables.length));
    });

    test('la famille video nomme les ecrans qui l appellent vraiment', () {
      // Le cas qui a motive ces tests, fixe explicitement parce que les trois
      // ecrans video se ressemblent et que la confusion s'y reinstallera.
      //
      // Verifie dans le code : « Videos a valider » approuve et refuse,
      // « Vidéos ajoutées » et « Vidéos signalées » suppriment, et aucune des
      // deux dernieres n'approuve ni ne rejette.
      Set<String> surfacesOf(String callable) => adminCallableActions
          .firstWhere((action) => action.callableName == callable)
          .uiSurfaces
          .toSet();

      expect(surfacesOf('adminSetVideoStatus'), {'VideoReviewWidget'});
      expect(surfacesOf('adminRejectVideo'), {'VideoReviewWidget'});
      expect(surfacesOf('adminDeleteVideo'), {
        'VideoAddedWidget',
        'VideoReportedWidget',
      });

      final review = File(
        'lib/dashboard/video_review_widget.dart',
      ).readAsStringSync();
      expect(
        review.contains('deleteVideo('),
        isFalse,
        reason:
            'si cet ecran se met a supprimer, le catalogue doit le dire : '
            'un refus notifie le joueur, une suppression non.',
      );
    });
  });
}
