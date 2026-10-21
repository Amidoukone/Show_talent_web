import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la copie francaise suit une seule convention typographique', () {
    // Le portail melangeait 642 apostrophes droites et 107 typographiques,
    // plus 18 « ... » contre 5 « … ». Les deux formes se voient a l'ecran,
    // parfois dans la meme phrase.
    //
    // Deux marqueurs suffisent a verrouiller la convention : une apostrophe
    // droite dans une chaine francaise doit etre echappee ('), et trois
    // points colles a un delimiteur de chaine sont une ellipse mal ecrite.
    // Un spread operator `...identifiant` ne declenche ni l'un ni l'autre.
    final escapedApostrophe = RegExp(r"\\'");
    final asciiEllipsis = RegExp("[.]{3}['\"]");
    final offenders = <String>[];

    for (final root in const <String>[
      'lib/dashboard',
      'lib/widgets',
      'lib/screens',
      'lib/models',
      'lib/utils',
    ]) {
      final directory = Directory(root);
      if (!directory.existsSync()) continue;

      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final content = entity.readAsStringSync();
        if (escapedApostrophe.hasMatch(content)) {
          offenders.add('${entity.path} : apostrophe droite');
        }
        if (asciiEllipsis.hasMatch(content)) {
          offenders.add('${entity.path} : points de suspension');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Employer l’apostrophe ’ et le caractere … dans la copie.',
    );
  });

  test('les ecrans ne posent plus de taille de police en dur', () {
    // L'echelle typographique vit dans lib/theme (AdminTheme + AdminType).
    // Treize tailles distinctes etaient auparavant eparpillees sur
    // soixante-seize TextStyle litteraux : deux textes de meme role
    // n'avaient pas la meme taille d'un ecran a l'autre, et rien dans un
    // fichier pris isolement ne permettait de s'en apercevoir.
    final offenders = <String>[];

    for (final root in const <String>[
      'lib/dashboard',
      'lib/widgets',
      'lib/screens',
    ]) {
      final directory = Directory(root);
      if (!directory.existsSync()) continue;

      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final content = entity.readAsStringSync();
        if (content.contains('fontSize:')) {
          offenders.add(entity.path);
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Utiliser un role de AdminType, ou le textTheme, plutot que de '
          'poser une taille a la main.',
    );
  });

  test('admin source text does not contain common mojibake sequences', () {
    const forbidden = <String>[
      '\u{00C3}',
      '\u{00E2}\u{20AC}\u{2122}',
      '\u{00E2}\u{20AC}\u{0153}',
      '\u{00E2}\u{20AC}',
      '\u{00E2}\u{20AC}\u{00A6}',
      '\u{00E2}\u{201A}\u{00AC}',
      '\u{00F0}\u{0178}',
      '\u{FFFD}',
    ];

    const sourceRoots = <String>['lib', 'scripts'];
    const sourceExtensions = <String>{'.dart', '.mjs', '.ps1'};
    final offenders = <String>[];

    for (final root in sourceRoots) {
      final directory = Directory(root);
      if (!directory.existsSync()) continue;

      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !sourceExtensions.any(entity.path.endsWith)) {
          continue;
        }

        final content = entity.readAsStringSync();
        for (final sequence in forbidden) {
          if (content.contains(sequence)) {
            offenders.add('${entity.path}: $sequence');
          }
        }
      }
    }

    expect(offenders, isEmpty);
  });

  test('admin production UI copy does not expose debug scaffolding', () {
    const forbiddenPhrases = <String>[
      'Mode debug',
      'Mode design',
      'Ouvrir un aperçu local',
      'Thème harmonisé',
      'Actions backend présentes mais UI encore à raccorder',
      'Surfaces UI',
      'createUserWithEmailAndPassword',
      'Firebase Auth est',
      'custom claims',
      'Désactiver Auth',
      'Réactiver Auth',
      'Auth désactivée',
      'statuts Auth',
      'backend partagé',
      'mutation client',
      'côté serveur',
      'contrat mobile',
      'Contrat mobile',
      'Base complete',
      'Auth off',
      'purement front',
      'controllers',
      'mutations de modération',
      'Aucun accès sensible',
      "n’est écrit directement",
    ];

    final offenders = <String>[];
    for (final path in const <String>[
      'lib/dashboard/admin_login.dart',
      'lib/dashboard/admin_dashboard_screen.dart',
      'lib/dashboard/managed_accounts_widget.dart',
      'lib/dashboard/video_review_widget.dart',
      'lib/dashboard/video_added_widget.dart',
      'lib/dashboard/video_reported_widget.dart',
      'lib/dashboard/offer_management_widget.dart',
      'lib/dashboard/event_management_widget.dart',
      'lib/dashboard/contact_intake_management_widget.dart',
      'lib/dashboard/statistiques_screen.dart',
      'lib/dashboard/user_management_widget.dart',
      'lib/utils/admin_access_messages.dart',
      'lib/utils/admin_callable_action_catalog.dart',
    ]) {
      final file = File(path);
      if (!file.existsSync()) continue;

      final content = file.readAsStringSync();
      for (final phrase in forbiddenPhrases) {
        if (content.contains(phrase)) {
          offenders.add('$path: $phrase');
        }
      }
    }

    expect(offenders, isEmpty);
  });
}
