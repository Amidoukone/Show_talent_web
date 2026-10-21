import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/utils/player_age.dart';

/// L'âge d'un joueur décide de deux choses qui ne se rattrapent pas : s'il
/// peut avoir un compte, et s'il faut l'accord d'un parent avant de le rendre
/// visible. Le calcul vivait en cinq copies dans deux widgets, et le passage
/// de 12 à 13 ans en a manqué une. Ces tests tiennent la seule copie qui
/// reste.
void main() {
  // Date fixe : un calcul d'âge testé « aujourd'hui » se met à échouer une
  // fois par an, le jour d'anniversaire de la donnée d'exemple.
  final reference = DateTime(2026, 10, 15);

  group('playerAgeOn compte les anniversaires révolus', () {
    test('anniversaire déjà passé cette année', () {
      expect(playerAgeOn(DateTime(2010, 3, 4), on: reference), 16);
    });

    test('anniversaire pas encore atteint cette année', () {
      expect(playerAgeOn(DateTime(2010, 12, 31), on: reference), 15);
    });

    test('anniversaire le jour même : l’âge est acquis', () {
      expect(playerAgeOn(DateTime(2010, 10, 15), on: reference), 16);
    });

    test('la veille de l’anniversaire, il ne l’est pas', () {
      expect(playerAgeOn(DateTime(2010, 10, 16), on: reference), 15);
    });
  });

  group('le seuil d’éligibilité', () {
    test('le seuil du portail suit celui du backend', () {
      // `MINIMUM_PLAYER_AGE` dans functions/src/minor_consent.ts. Les deux
      // doivent bouger ensemble : changer celui-ci seul ne change rien à ce
      // que le serveur accepte.
      expect(kMinimumPlayerAge, 13);
      expect(kAdultAge, 18);
    });

    test('un joueur de 12 ans est refusé, un de 13 est accepté', () {
      expect(
        isBelowMinimumPlayerAge(DateTime(2014, 1, 1), on: reference),
        isTrue,
      );
      expect(
        isBelowMinimumPlayerAge(DateTime(2013, 1, 1), on: reference),
        isFalse,
      );
    });

    test('le jour exact des 13 ans est accepté', () {
      expect(
        isBelowMinimumPlayerAge(DateTime(2013, 10, 15), on: reference),
        isFalse,
      );
      expect(
        isBelowMinimumPlayerAge(DateTime(2013, 10, 16), on: reference),
        isTrue,
      );
    });
  });

  group('la minorité', () {
    test('17 ans est mineur, 18 ne l’est plus', () {
      expect(isMinorPlayer(DateTime(2009, 1, 1), on: reference), isTrue);
      expect(isMinorPlayer(DateTime(2008, 1, 1), on: reference), isFalse);
    });

    test('le jour exact des 18 ans sort de la minorité', () {
      expect(isMinorPlayer(DateTime(2008, 10, 15), on: reference), isFalse);
      expect(isMinorPlayer(DateTime(2008, 10, 16), on: reference), isTrue);
    });
  });

  group('le sélecteur de date ne propose rien que le formulaire refuse', () {
    // C'est le défaut que ce fichier existe pour empêcher : le `lastDate` du
    // calendrier était resté à 12 ans après le passage à 13, donc un
    // administrateur pouvait choisir une date puis se voir refuser l'envoi.
    test('la dernière date éligible rend le joueur tout juste accepté', () {
      final latest = latestEligibleBirthDate(on: reference);

      expect(playerAgeOn(latest, on: reference), kMinimumPlayerAge);
      expect(isBelowMinimumPlayerAge(latest, on: reference), isFalse);
    });

    test('un jour plus tard serait refusé', () {
      final latest = latestEligibleBirthDate(on: reference);
      final tooYoung = latest.add(const Duration(days: 1));

      expect(isBelowMinimumPlayerAge(tooYoung, on: reference), isTrue);
    });

    test('la date proposée par défaut est acceptable', () {
      final fallback = defaultBirthDatePickerDate(on: reference);

      expect(isBelowMinimumPlayerAge(fallback, on: reference), isFalse);
      expect(isMinorPlayer(fallback, on: reference), isFalse);
    });
  });
}
