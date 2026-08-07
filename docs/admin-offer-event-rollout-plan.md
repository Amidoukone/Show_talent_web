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

## Lot 2 - Termine (moderation video + mise en relation)

Livre en meme temps que Lot 1 cote code, mais jamais consigne ici -- c'est
l'ecart releve par l'audit de coherence admin/mobile : ces callables sont
reels et deja utilises par le portail admin, sans qu'aucun document ne les
liste.

- Callables admin cote backend partage:
  - `adminSetVideoStatus`
  - `adminRejectVideo`
  - `adminDeleteVideo`
  - `adminSetContactIntakeFollowUp`
  - `adminDeleteContactIntake`
  - `adminDeleteContactIntakeConversation`
- Cote portail admin:
  - meme service callable `AdminContentService`
  - widgets dashboard `VideoReviewWidget`, `VideoReportedWidget`,
    `VideoAddedWidget`, `ContactIntakeManagementWidget`
- Catalogue: les 10 callables de Lot 1 + Lot 2 sont maintenant listes dans
  `lib/utils/admin_callable_action_catalog.dart`, le README, et
  `docs/shared-backend-contract.md` (depot mobile), et verifies
  automatiquement par `npm run contract:mobile`.
