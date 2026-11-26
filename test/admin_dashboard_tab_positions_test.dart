// Position des neuf premiers onglets du tableau de bord.
//
// `_dashboardItems`, `_widgetOptions()` et `_dashboardGroups`
// (admin_dashboard_screen.dart) sont trois listes synchronisees a la main,
// indexees par position : `_widgetOptions()` et les liens profonds de
// `app_routes.dart` se fient a cette position, pas a un identifiant stable.
// Un onglet insere au milieu decale tous les suivants sans qu'aucune erreur
// de compilation ni d'execution ne le signale.
//
// Les trois onglets les plus recents (Statuts contractuels, Rattachements,
// Coordonnees retirees) portent deja ce garde-fou, a cote de leurs tests de
// fonctionnalite respectifs. Il manquait pour les neuf premiers, apparus
// avant cette convention : un reordonnancement limite a ces neuf-la (par
// exemple inverser Utilisateurs et Comptes administres) ne deplace aucun des
// trois index proteges, et passait donc inapercu. Ce fichier referme cet
// angle mort, un onglet a la fois -- toujours une assertion de POSITION, pas
// seulement de presence, et toujours sans assertion sur le nombre total :
// un onglet ajoute plus tard, apres le dernier protege, reste legitime.
import 'package:flutter_test/flutter_test.dart';

import 'test_support/admin_test_helpers.dart';

void main() {
  group('position des onglets', () {
    test('Utilisateurs', () {
      expect(dashboardItemIndex('Utilisateurs'), 0);
      expect(dashboardScreenIndex('UserManagementWidget'), 0);
      expect(dashboardGroupIndices('Communauté'), contains(0));
    });

    test('Comptes administrés', () {
      expect(dashboardItemIndex('Comptes administrés'), 1);
      expect(dashboardScreenIndex('ManagedAccountsWidget'), 1);
      expect(dashboardGroupIndices('Communauté'), contains(1));
    });

    test('Vidéos à valider', () {
      expect(dashboardItemIndex('Vidéos à valider'), 2);
      expect(dashboardScreenIndex('VideoReviewWidget'), 2);
      expect(dashboardGroupIndices('Modération'), contains(2));
    });

    test('Vidéos ajoutées', () {
      expect(dashboardItemIndex('Vidéos ajoutées'), 3);
      expect(dashboardScreenIndex('VideoAddedWidget'), 3);
      expect(dashboardGroupIndices('Modération'), contains(3));
    });

    test('Vidéos signalées', () {
      expect(dashboardItemIndex('Vidéos signalées'), 4);
      expect(dashboardScreenIndex('VideoReportedWidget'), 4);
      expect(dashboardGroupIndices('Modération'), contains(4));
    });

    test('Offres', () {
      expect(dashboardItemIndex('Offres'), 5);
      expect(dashboardScreenIndex('OfferManagementWidget'), 5);
      expect(dashboardGroupIndices('Activité'), contains(5));
    });

    test('Événements', () {
      expect(dashboardItemIndex('Événements'), 6);
      expect(dashboardScreenIndex('EventManagementWidget'), 6);
      expect(dashboardGroupIndices('Activité'), contains(6));
    });

    test('Mise en relation', () {
      expect(dashboardItemIndex('Mise en relation'), 7);
      expect(dashboardScreenIndex('ContactIntakeManagementWidget'), 7);
      expect(dashboardGroupIndices('Activité'), contains(7));
    });

    test('Statistiques', () {
      expect(dashboardItemIndex('Statistiques'), 8);
      expect(dashboardScreenIndex('StatisticsOverviewPanel'), 8);
      expect(dashboardGroupIndices('Analyse'), contains(8));
    });
  });
}
