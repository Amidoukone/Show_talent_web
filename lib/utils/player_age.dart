/// L'âge d'un joueur, calculé en un seul endroit.
///
/// Le seuil fait foi côté serveur : `MINIMUM_PLAYER_AGE` dans
/// `functions/src/minor_consent.ts` du dépôt mobile, appliqué par
/// `provisionManagedAccount` et `updateManagedAccountProfile`. Ce fichier en
/// est le miroir, et rien de plus : le portail refuse en amont ce que le
/// serveur refuserait de toute façon, pour qu'un administrateur voie l'erreur
/// avant l'appel plutôt qu'après. Changer la valeur ici seule ne change rien
/// à ce que le backend accepte.
///
/// Pourquoi ce fichier existe. Le calcul vivait en cinq copies dans deux
/// widgets, chacune avec son seuil écrit à la main. Le passage de 12 à 13 ans
/// le 15 octobre 2026 en a manqué une : le sélecteur de date continuait de
/// proposer une date rendant le joueur éligible à 12 ans, que la validation
/// rejetait juste après. Une seule source évite la prochaine occurrence.
library;

/// Âge minimum pour qu'un joueur ait un compte Adfoot.
///
/// Doit rester égal à `MINIMUM_PLAYER_AGE` du backend.
const int kMinimumPlayerAge = 13;

/// Âge à partir duquel un joueur n'est plus mineur, donc n'exige plus
/// l'accord enregistré d'un parent ou tuteur.
const int kAdultAge = 18;

/// L'âge révolu à la date [on], ou aujourd'hui par défaut.
///
/// [on] est injectable pour que les tests n'aient pas à dépendre du jour où
/// ils tournent, ce qui est la raison pour laquelle un calcul d'âge se met à
/// échouer une fois par an sans que personne comprenne pourquoi.
int playerAgeOn(DateTime birthDate, {DateTime? on}) {
  final reference = on ?? DateTime.now();
  var age = reference.year - birthDate.year;
  final beforeBirthdayThisYear = reference.month < birthDate.month ||
      (reference.month == birthDate.month && reference.day < birthDate.day);
  if (beforeBirthdayThisYear) {
    age--;
  }
  return age;
}

/// True quand le joueur est trop jeune pour avoir un compte.
bool isBelowMinimumPlayerAge(DateTime birthDate, {DateTime? on}) =>
    playerAgeOn(birthDate, on: on) < kMinimumPlayerAge;

/// True quand le joueur est mineur, donc soumis à l'accord parental.
bool isMinorPlayer(DateTime birthDate, {DateTime? on}) =>
    playerAgeOn(birthDate, on: on) < kAdultAge;

/// La date de naissance la plus récente qui rende un joueur éligible.
///
/// Sert de `lastDate` aux sélecteurs de date : un administrateur ne doit pas
/// pouvoir choisir une date que la validation refusera une seconde plus tard.
DateTime latestEligibleBirthDate({DateTime? on}) {
  final reference = on ?? DateTime.now();
  return DateTime(
    reference.year - kMinimumPlayerAge,
    reference.month,
    reference.day,
  );
}

/// La date proposée à l'ouverture d'un sélecteur, quand aucune n'est connue.
///
/// Un majeur par défaut : c'est le cas le plus fréquent, et cela évite
/// d'ouvrir le calendrier sur une date que le formulaire refusera.
DateTime defaultBirthDatePickerDate({DateTime? on}) {
  final reference = on ?? DateTime.now();
  return DateTime(reference.year - kAdultAge, 1, 1);
}
