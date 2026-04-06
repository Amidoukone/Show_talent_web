# Admin Offer/Event Rollout Plan

Ce plan est execute par lots courts pour limiter le risque de regression.

## Lot 1 - Termine (integration moderation admin)

- Ajout des callables admin cote backend partage:
  - `adminSetOfferStatus`
  - `adminDeleteOffer`
  - `adminSetEventStatus`
  - `adminDeleteEvent`
- Ajout dans le portail admin:
  - service callable `AdminContentService`
  - modele `AdminActionResponse`
  - controleurs `OffreController` et `EventController` en mode stream + moderation callable
  - widgets dashboard `OfferManagementWidget` et `EventManagementWidget`
  - injection des controleurs dans `main.dart`
  - nouvelles sections Offres/Events dans `AdminDashboardScreen`
- Garde-fous:
  - normalisation stricte des statuts
  - parsing tolerant des modeles (fallback id/dates)
  - tests unitaires de regression modeles et reponses callables
