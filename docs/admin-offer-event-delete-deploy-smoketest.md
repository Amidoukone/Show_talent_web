# Runbook Deploiement Et Smoke Test Admin Offers Events

Date de reference : 6 avril 2026

## Objectif

Ce runbook decrit la sequence exacte pour deployer sans casse la correction de
suppression admin des `Offers` et `Events`, puis la verifier de bout en bout
entre :

- le portail admin Flutter : `C:\Users\Ing.Amidou.KONE\Desktop\MyApp\show_talent - web`
- le projet mobile + backend partage : `C:\Users\Ing.Amidou.KONE\Desktop\ODC_PROJECT\MOBILE\Show-Talent`

## Invariants

Ne pas deployer si un seul de ces points diverge :

- projectId partage : `show-talent-5987d`
- Cloud Functions admin en `europe-west1`
- backend Firebase unique pour admin et mobile
- suppression admin uniquement via :
  - `adminDeleteOffer`
  - `adminDeleteEvent`

## Strategie de deploiement

Ordre impose pour limiter le risque :

1. verifier les deux depots
2. verifier le contrat inter-depots
3. verifier le backend mobile / Functions
4. deployer seulement les callables admin concernes
5. publier le portail admin seulement apres le backend
6. executer le smoke test fonctionnel

Ne pas inverser l ordre `backend -> portail admin`.

## Variables locales conseillees

Dans PowerShell :

```powershell
$AdminRepo = "C:\Users\Ing.Amidou.KONE\Desktop\MyApp\show_talent - web"
$MobileRepo = "C:\Users\Ing.Amidou.KONE\Desktop\ODC_PROJECT\MOBILE\Show-Talent"
```

## Phase 1 - Snapshot avant deploiement

Verifier l etat des deux depots avant toute action :

```powershell
git -C $AdminRepo status --short
git -C $MobileRepo status --short
```

Resultat attendu :

- uniquement les changements voulus pour la correction Offers / Events
- aucun changement surprise non compris

Si un changement inattendu apparait, stopper le deploiement.

## Phase 2 - Verifications obligatoires avant production

### 2.1 Contrat admin/mobile

Depuis le depot mobile :

```powershell
Set-Location $MobileRepo
powershell -ExecutionPolicy Bypass -File .\scripts\check-admin-mobile-contract.ps1 `
  -AdminRepoPath $AdminRepo
```

Resultat attendu :

- `Admin/mobile shared contract check completed.`

### 2.2 Portail admin

Depuis le depot admin :

```powershell
Set-Location $AdminRepo
flutter test test/admin_action_response_test.dart test/event_model_test.dart test/offre_model_test.dart
flutter analyze lib/services/admin_content_service.dart
```

Resultat attendu :

- tests OK
- analyze sans erreur

### 2.3 Backend mobile / Functions

Depuis le depot mobile :

```powershell
Set-Location $MobileRepo
flutter test test/offre_model_test.dart test/offre_release_quality_guardrails_test.dart --reporter expanded
flutter test test/event_model_test.dart test/event_release_quality_guardrails_test.dart --reporter expanded
npm.cmd --prefix functions run lint
npm.cmd --prefix functions run build
powershell -ExecutionPolicy Bypass -File .\scripts\check-functions-env.ps1 -Environment production
```

Resultat attendu :

- tests offres OK
- tests events OK
- lint Functions OK
- build Functions OK
- environment check OK

### 2.4 Gate profond recommande

Si la fenetre de release le permet, lancer aussi :

```powershell
Set-Location $MobileRepo
npm.cmd run offer:quality:release
npm.cmd run event:quality:release
```

Ces gates peuvent etre longs. Ils sont recommandes avant une release sensible.

## Phase 3 - Deploiement backend partage

### 3.1 Commande recommandee

Deployer uniquement les callables touches, de maniere sequentielle :

```powershell
Set-Location $MobileRepo
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-functions-safe.ps1 `
  -Environment production `
  -Functions adminSetOfferStatus,adminDeleteOffer,adminSetEventStatus,adminDeleteEvent `
  -Sequential
```

Pourquoi cette commande :

- elle valide l environnement avant deploy
- elle cible seulement les fonctions corrigees
- elle limite le rayon d impact
- elle deploie en sequence, plus lisible en cas d echec

### 3.2 Resultat attendu

Verifier que le deploy annonce bien le succes pour :

- `functions:adminSetOfferStatus`
- `functions:adminDeleteOffer`
- `functions:adminSetEventStatus`
- `functions:adminDeleteEvent`

Ne pas passer a la phase suivante si une seule fonction echoue.

## Phase 4 - Publication du portail admin

### 4.1 Build local obligatoire

Le depot admin ne contient pas de script de publication web standardise. La
partie certaine et reproductible dans ce repo est donc le build Flutter web :

```powershell
Set-Location $AdminRepo
flutter build web --release
```

Resultat attendu :

- generation de `build\web`

### 4.2 Publication

Publier ensuite le contenu de `build\web` via le mecanisme d hebergement deja en
place pour le portail admin.

Important :

- ne pas improviser un nouvel hebergeur pendant cette release
- si le portail admin est exploite localement uniquement, ne pas publier :
  redemarrer simplement l instance locale avec le code a jour

## Phase 5 - Preparation du smoke test

Utiliser uniquement des donnees de test dediees.

### 5.1 Comptes de test

Prevoir :

- un compte admin valide
- un compte gere de test pouvant publier une offre
- un compte gere de test pouvant publier un event

### 5.2 Contenus de test

Creer avant le smoke test :

- 1 offre de test nommee par exemple :
  - `SMOKE DELETE OFFER 2026-04-06`
- 1 event de test nomme par exemple :
  - `SMOKE DELETE EVENT 2026-04-06`

Recommandation :

- pour l offre, ajouter une piece jointe si le flux le permet
- pour l event, ajouter un flyer si le flux le permet

Noter pour chaque contenu :

- l identifiant Firestore
- l uid du proprietaire
- le chemin Storage si une piece jointe ou un flyer existe

## Phase 6 - Smoke test fonctionnel exact

### 6.1 Connexion admin

Depuis le portail admin mis a jour :

1. se connecter avec un operateur admin valide
2. verifier que le dashboard s ouvre
3. verifier que les sections `Offres` et `Events` chargent sans erreur

Attendu :

- aucune erreur de chargement
- aucune redirection anormale

### 6.2 Smoke offre

1. ouvrir `Gestion des offres`
2. retrouver l offre `SMOKE DELETE OFFER ...`
3. changer son statut vers `Archivee`
4. verifier le message de succes
5. supprimer cette offre
6. confirmer la boite de dialogue
7. verifier le message de succes
8. rafraichir la liste

Attendu cote admin :

- aucun message `internal error`
- l offre disparait de la liste
- aucun blocage UI apres suppression

Verifier ensuite dans Firestore :

- le document `/offres/{offerId}` n existe plus

Verifier ensuite dans `/users/{ownerUid}` si le champ existe :

- `offrePubliees` ne contient plus d entree avec `id == offerId`

Verifier ensuite dans Storage si une piece jointe existait :

- le fichier n existe plus, ou n est plus listable au chemin attendu

Verifier enfin cote mobile :

- l offre n apparait plus dans les listes utilisateur

### 6.3 Smoke event

1. ouvrir `Gestion des evenements`
2. retrouver l event `SMOKE DELETE EVENT ...`
3. changer son statut vers `Archive`
4. verifier le message de succes
5. supprimer cet event
6. confirmer la boite de dialogue
7. verifier le message de succes
8. rafraichir la liste

Attendu cote admin :

- aucun message `internal error`
- l event disparait de la liste
- aucun blocage UI apres suppression

Verifier ensuite dans Firestore :

- le document `/events/{eventId}` n existe plus

Verifier ensuite dans `/users/{ownerUid}` si le champ existe :

- `eventPublies` ne contient plus d entree avec `id == eventId`

Verifier ensuite dans Storage si un flyer existait :

- le fichier n existe plus, ou n est plus listable au chemin attendu

Verifier enfin cote mobile :

- l event n apparait plus dans les listes utilisateur

## Phase 7 - Regression minimale apres smoke test

Ne pas cloturer la release sans ces checks rapides :

1. dans le portail admin, changer le statut d une autre offre non critique
2. dans le portail admin, changer le statut d un autre event non critique
3. ouvrir `Comptes geres`
4. verifier que la liste se charge normalement
5. revenir au dashboard
6. verifier que les cartes Offres / Events s affichent

But :

- confirmer que la correction n a pas casse les autres actions admin

## Phase 8 - Rollback

### 8.1 Si le backend casse mais pas le portail admin

Rollback recommande :

1. redeployer les fonctions depuis le dernier commit stable connu
2. cibler au minimum :
   - `adminSetOfferStatus`
   - `adminDeleteOffer`
   - `adminSetEventStatus`
   - `adminDeleteEvent`
3. faire le redeploiement depuis un worktree ou une branche propre

### 8.2 Si le portail admin casse mais pas le backend

Rollback recommande :

1. republier le dernier build web stable du portail admin
2. ne pas redeployer les Functions si le backend fonctionne

## Critere de sortie

La correction est consideree exploitable si :

- le deploy Functions est complet
- le portail admin utilise le code mis a jour
- suppression offre OK sans `internal error`
- suppression event OK sans `internal error`
- documents Firestore supprimes
- references owner nettoyees si presentes
- assets Storage nettoyes si presents
- les listes mobiles et admin restent coherentes
