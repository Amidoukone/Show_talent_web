import '../models/player_football_profile.dart';

/// « 2024-25 · Ligue 1 CIV · ASEC Mimosas (Académie) · 28 matchs, 11 buts »
///
/// Le niveau du club y figure parce qu'il change la lecture des chiffres :
/// vingt-huit matchs en académie et vingt-huit en première division ne
/// disent pas la même chose du joueur.
///
/// Fonction autonome plutôt que méthode d'un widget : utilisée à la fois par
/// le dialogue d'édition de profil (retrait d'une saison) et par le panneau
/// de revue de profil (affichage du parcours), qui vivent chacun dans leur
/// propre fichier.
String archivedSeasonLabel(SeasonRecord season) {
  final head = <String>[
    ?season.season,
    ?season.competition,
    if (season.clubName != null)
      season.clubLevel == null
          ? season.clubName!
          : '${season.clubName} (${season.clubLevel!.labelFr})',
  ].join(' · ');

  final figures = <String>[
    if (season.appearances != null) '${season.appearances} matchs',
    if (season.minutes != null) '${season.minutes} min',
    if (season.goals != null) '${season.goals} buts',
    if (season.assists != null) '${season.assists} passes',
  ].join(', ');

  if (head.isEmpty) return figures.isEmpty ? 'Saison archivée' : figures;
  return figures.isEmpty ? head : '$head · $figures';
}
