import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/controller/private_contact_cache.dart';

void main() {
  test('le portail ne réabonne pas toute la base privée', () {
    // Un `collectionGroup('private').snapshots()` sans filtre lit tous les
    // documents privés de *tous* les comptes à chaque ouverture de session,
    // pour n'afficher que la fenêtre chargée. Le coût ne se voit pas en
    // développement, il se voit sur la facture Firebase.
    final controller = File(
      'lib/controller/user_controller.dart',
    ).readAsStringSync();

    expect(controller, isNot(contains("collectionGroup('private')")));
    expect(controller, contains('PrivateContactCache'));
    expect(controller, contains('_loadPrivateContacts'));
  });

  /// Compte les lectures et répond ce que la graine contient.
  ({PrivateContactCache cache, List<String> reads}) buildCache({
    Map<String, Map<String, dynamic>> seed = const {},
    int batchSize = PrivateContactCache.defaultBatchSize,
    Set<String> failing = const {},
  }) {
    final reads = <String>[];
    final cache = PrivateContactCache(
      batchSize: batchSize,
      reader: (uid) async {
        reads.add(uid);
        if (failing.contains(uid)) {
          throw StateError('lecture refusée pour $uid');
        }
        return seed[uid];
      },
    );
    return (cache: cache, reads: reads);
  }

  Future<void> sync(
    PrivateContactCache cache,
    Iterable<String> uids, {
    void Function()? onApplied,
    void Function(Object error)? onError,
  }) {
    return cache.syncWindow(
      uids,
      onApplied: onApplied ?? () {},
      onError: onError ?? (_) {},
    );
  }

  test('seuls les comptes de la fenêtre sont lus', () async {
    final harness = buildCache(
      seed: {
        'a': {'email': 'a@example.invalid'},
        'b': {'email': 'b@example.invalid'},
        'z': {'email': 'z@example.invalid'},
      },
    );

    await sync(harness.cache, ['a', 'b']);

    expect(harness.reads.toSet(), {'a', 'b'});
    expect(harness.cache.contactFor('a'), {'email': 'a@example.invalid'});
    expect(
      harness.cache.contactFor('z'),
      isNull,
      reason: 'un compte hors fenêtre ne doit jamais être lu',
    );
  });

  test('une deuxième émission de la même fenêtre ne relit rien', () async {
    // Le flux users réémet la fenêtre entière dès qu'un seul document
    // change : sans garde, chaque frappe d'un utilisateur relancerait 500
    // lectures facturées.
    final harness = buildCache(
      seed: {
        'a': {'email': 'a@example.invalid'},
      },
    );

    await sync(harness.cache, ['a']);
    await sync(harness.cache, ['a']);
    await sync(harness.cache, ['a']);

    expect(harness.reads, ['a']);
  });

  test('un document absent est mémorisé, pas relu en boucle', () async {
    final harness = buildCache();

    await sync(harness.cache, ['sans-contact']);
    await sync(harness.cache, ['sans-contact']);

    expect(harness.reads, ['sans-contact']);
    expect(harness.cache.contactFor('sans-contact'), isEmpty);
  });

  test('un compte sorti de la fenêtre est oublié', () async {
    // Sinon le cache grossit indéfiniment au fil des « charger plus » et
    // des reconnexions.
    final harness = buildCache(
      seed: {
        'a': {'email': 'a@example.invalid'},
        'b': {'email': 'b@example.invalid'},
      },
    );

    await sync(harness.cache, ['a', 'b']);
    await sync(harness.cache, ['b']);

    expect(harness.cache.contactFor('a'), isNull);
    expect(harness.cache.contactFor('b'), isNotNull);
  });

  test('la fenêtre est lue par vagues, appliquées au fil de l’eau', () async {
    final harness = buildCache(
      batchSize: 2,
      seed: {
        for (final uid in ['a', 'b', 'c', 'd', 'e'])
          uid: {'email': '$uid@example.invalid'},
      },
    );

    var applied = 0;
    await sync(harness.cache, [
      'a',
      'b',
      'c',
      'd',
      'e',
    ], onApplied: () => applied++);

    expect(harness.reads.toSet(), {'a', 'b', 'c', 'd', 'e'});
    expect(
      applied,
      3,
      reason: 'cinq uid par vagues de deux : trois applications',
    );
  });

  test('hasLoaded reste faux tant que rien n’a abouti', () async {
    final harness = buildCache(failing: {'a'});
    expect(harness.cache.hasLoaded, isFalse);

    await sync(harness.cache, ['a']);

    expect(
      harness.cache.hasLoaded,
      isFalse,
      reason:
          'projeter un cache vide effacerait les adresses au lieu de les '
          'compléter',
    );
  });

  test('un échec de lecture est remonté une fois', () async {
    final harness = buildCache(failing: {'a'});
    final errors = <Object>[];

    await sync(harness.cache, ['a'], onError: errors.add);

    expect(errors, hasLength(1));
  });

  test('une vague périmée n’écrit plus rien', () async {
    // Scénario réel : l'opérateur clique « Recharger » (ou se déconnecte)
    // pendant que la fenêtre précédente finit de se lire.
    final harness = buildCache(
      seed: {
        'a': {'email': 'a@example.invalid'},
      },
    );

    final pending = sync(harness.cache, ['a']);
    harness.cache.invalidate();
    await pending;

    expect(harness.cache.contactFor('a'), isNull);
    expect(harness.cache.hasLoaded, isFalse);
  });

  test('une erreur sur une vague périmée ne remonte pas', () async {
    final harness = buildCache(failing: {'a'});
    final errors = <Object>[];

    final pending = sync(harness.cache, ['a'], onError: errors.add);
    harness.cache.invalidate();
    await pending;

    expect(
      errors,
      isEmpty,
      reason:
          'un bandeau d’erreur pour une fenêtre abandonnée inquiéterait '
          'sans raison',
    );
  });

  test('un uid en échec est relu à la synchronisation suivante', () async {
    // Il n'est pas mémorisé, donc il repasse dans « manquants ». C'est ce
    // qui permet au bandeau d'erreur de se refermer tout seul une fois la
    // panne passée, sans que l'opérateur clique « Recharger ».
    final failing = <String>{'a'};
    final reads = <String>[];
    final cache = PrivateContactCache(
      reader: (uid) async {
        reads.add(uid);
        if (failing.contains(uid)) {
          throw StateError('lecture refusée pour $uid');
        }
        return {'email': '$uid@example.invalid'};
      },
    );

    await cache.syncWindow(['a'], onApplied: () {}, onError: (_) {});
    expect(cache.contactFor('a'), isNull);

    failing.clear();
    var applied = 0;
    await cache.syncWindow(['a'], onApplied: () => applied++, onError: (_) {});

    expect(reads, ['a', 'a']);
    expect(cache.contactFor('a'), isNotNull);
    expect(applied, 1, reason: 'la reprise doit signaler son succès');
  });

  test('après invalidation, la fenêtre est relue', () async {
    final harness = buildCache(
      seed: {
        'a': {'email': 'a@example.invalid'},
      },
    );

    await sync(harness.cache, ['a']);
    harness.cache.invalidate();
    await sync(harness.cache, ['a']);

    expect(harness.reads, ['a', 'a']);
    expect(harness.cache.contactFor('a'), isNotNull);
  });
}
