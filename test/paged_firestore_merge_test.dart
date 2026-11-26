// La fusion page-temps-reel + pages-par-curseur, partagee par
// OffreController et ClubLinkController.
//
// Avant cette classe, exactement la meme boucle (deux tables par id, triees,
// fusionnees) vivait recopiee dans chacun des deux controleurs. Ces tests
// portent directement sur la mecanique partagee : un bug corrige ici est
// corrige dans les deux a la fois, et ne peut plus diverger silencieusement
// entre les deux copies.
//
// Le curseur est un entier de test, pas un DocumentSnapshot : la classe est
// generique sur le type du curseur precisement pour pouvoir la tester sans
// construire un vrai document Firestore (DocumentSnapshot/
// QueryDocumentSnapshot sont des classes scellees qu'aucun bouchon de test
// ne peut implementer hors du paquet qui les declare).
import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/controller/paged_firestore_merge.dart';

void main() {
  late PagedFirestoreMerge<int, int> merge;

  setUp(() {
    // Identite = la valeur elle-meme, tri croissant : assez pour observer
    // la fusion sans que la forme d'un vrai modele n'ajoute du bruit.
    merge = PagedFirestoreMerge<int, int>(
      idOf: (value) => value.toString(),
      compare: (a, b) => a.compareTo(b),
    );
  });

  test('la premiere page seule se rend triee', () {
    final result = merge.applyFirstPage([3, 1, 2], 1);
    expect(result, [1, 2, 3]);
  });

  test('curseur pose seulement si un curseur non nul est fourni', () {
    expect(merge.cursor, isNull);
    merge.applyFirstPage([1], 1);
    expect(merge.cursor, 1);
  });

  test('un lot sans curseur (page vide) ne deplace pas le curseur', () {
    merge.applyFirstPage([1], 1);
    merge.appendPage(<int>[], null);
    expect(merge.cursor, 1);
  });

  test('page supplementaire et premiere page se fusionnent, triees', () {
    merge.applyFirstPage([5, 1], 1);
    final result = merge.appendPage([3, 2], 2);
    expect(result, [1, 2, 3, 5]);
    expect(merge.cursor, 2);
  });

  test(
    'un meme identifiant present dans les deux pages ne compte qu une fois, '
    'et la premiere page l emporte',
    () {
      // La page temps reel est la plus fraiche : si un document a bouge
      // entre deux "charger plus", sa version a jour doit gagner.
      final tagged = PagedFirestoreMerge<_Tagged, int>(
        idOf: (value) => value.id,
        compare: (a, b) => a.id.compareTo(b.id),
      );
      tagged.applyFirstPage([_Tagged('a', 'frais')], 1);
      final result = tagged.appendPage([_Tagged('a', 'perime')], 2);

      expect(result, hasLength(1));
      expect(result.single.tag, 'frais');
    },
  );

  test('removeWhere retire de la fenetre chargee, premiere page et extra', () {
    merge.applyFirstPage([1, 2], 1);
    merge.appendPage([3, 4], 2);

    final result = merge.removeWhere((id) => id == '2' || id == '3');

    expect(result, [1, 4]);
  });

  test('reset repart de zero : plus de curseur, plus de contenu', () {
    merge.applyFirstPage([1, 2], 1);
    merge.appendPage([3], 2);

    merge.reset();

    expect(merge.cursor, isNull);
    expect(merge.applyFirstPage(<int>[], null), isEmpty);
  });

  test(
    'un nouveau flux (reapplyFirstPage) remplace la premiere page sans '
    'garder les anciennes entrees qui en ont disparu',
    () {
      // La premiere page est un flux temps reel : un document qui en sort
      // (supprime, ou sorti de la fenetre) ne doit pas survivre fantome dans
      // la liste fusionnee.
      merge.applyFirstPage([1, 2, 3], 1);
      final result = merge.applyFirstPage([1, 3], 2);

      expect(result, [1, 3]);
    },
  );
}

class _Tagged {
  const _Tagged(this.id, this.tag);
  final String id;
  final String tag;
}
