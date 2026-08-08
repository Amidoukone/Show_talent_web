# Runbook Production Admin / Mobile

Date de reference : 25 mars 2026

## Objectif

Ce runbook formalise l exploitation en production de la plateforme partagee
entre :

- l application mobile publique
- le portail admin
- le backend Firebase cible par l environnement actif

## Invariants de production

Les points suivants ne doivent jamais diverger :

- projectId cible expose dans l UI admin et pilote par `APP_ENV` / `FIREBASE_PROJECT_ID`
- Firebase Auth commun
- Firestore commun
- Cloud Functions communes
- Storage commun aligne sur le projet actif
- region Functions admin pilotee par `FIREBASE_FUNCTIONS_REGION`

## Matrice des comptes

Aucune creation publique metier cote mobile.

Comptes provisionnes par l administration :

- `joueur`
- `fan`
- `club`
- `recruteur`
- `agent`

Operateurs admin :

- Firestore `role: 'admin'`
- claim requis : `admin` ou `platformAdmin` ou `superAdmin`

## Regles d acces production

### Mobile public

Le mobile doit refuser :

- toute creation publique de compte metier
- tout compte Auth sans `/users/{uid}`
- tout compte avec `authDisabled == true`
- tout compte reserve au portail admin

### Portail admin

Le portail admin doit refuser l acces si une seule condition echoue :

- utilisateur non connecte dans Auth
- `/users/{uid}` absent
- `role != 'admin'`
- absence de claim `admin|platformAdmin|superAdmin`
- `authDisabled == true`

## Bootstrap d un operateur admin

Le bootstrap se fait uniquement via Admin SDK.

Pre-requis :

- service account JSON valide du projet Firebase cible
- fichier stocke localement hors Git
- `.credentials/` ignore par Git

Commande de reference :

```powershell
$env:FIREBASE_SERVICE_ACCOUNT_KEY_PATH="C:\chemin\vers\serviceAccount.json"
npm.cmd run create-admin -- --email admin@example.com --name "Super Admin ADFOOT" --claim superAdmin
```

Commande guidee recommandee :

```powershell
npm.cmd run create-admin:staging -- -Email admin@example.com -Name "Super Admin ADFOOT" -DryRun
npm.cmd run create-admin:staging -- -Email admin@example.com -Name "Super Admin ADFOOT"
```

Pour la production :

```powershell
npm.cmd run create-admin:production -- -ServiceAccount "C:\chemin\vers\serviceAccount-production.json" -Email admin@example.com -Name "Super Admin ADFOOT"
```

Resultat attendu :

- utilisateur cree dans Firebase Auth
- claim `superAdmin: true` ou claim demande
- document `/users/{uid}` present
- `emailVerified: true` dans Auth et Firestore
- aucune verification d e-mail a envoyer pour un operateur admin

Document coherent attendu :

- `role: 'admin'`
- `authDisabled: false`
- `createdByAdmin: false`

## Provisionnement d un compte

Les comptes `joueur`, `fan`, `club`, `recruteur` et `agent` sont crees
uniquement via :

- `provisionManagedAccount`

Procedure :

1. connexion au portail admin avec operateur valide
2. ouverture de Provisionnement des comptes
3. saisie du profil
4. appel du callable
5. recuperation du payload
6. transmission controlee des liens au titulaire
7. verification Firestore/Auth

Payload attendu :

- `uid`
- `email`
- `role`
- `existingUser`
- `passwordSetupLink`
- `emailVerificationLink`

Regle :

- si `existingUser == true`, traiter le cas comme reprise/collision

## Mutations admin autorisees

Uniquement via backend partage :

- desactivation Auth : `disableManagedAccountAuth`
- reactivation Auth : `enableManagedAccountAuth`
- renvoi invitation : `resendManagedAccountInvite`
- changement de role : `changeManagedAccountRole`
- suppression : `deleteManagedAccount`
- mise a jour profil : `updateManagedAccountProfile`
- changement de statut offre : `adminSetOfferStatus`
- suppression offre : `adminDeleteOffer`
- changement de statut event : `adminSetEventStatus`
- suppression event : `adminDeleteEvent`
- changement de statut video : `adminSetVideoStatus`
- rejet video : `adminRejectVideo`
- suppression video : `adminDeleteVideo`
- suivi agence mise en relation : `adminSetContactIntakeFollowUp`
- suppression mise en relation : `adminDeleteContactIntake`
- suppression conversation liee : `adminDeleteContactIntakeConversation`

Liste complete des 17 callables et regle de synchronisation : voir
`README.md` (section Cloud Functions admin) et
`docs/admin-offer-event-rollout-plan.md`.

## Verifications operationnelles minimales

A valider en smoke test :

Voir la sequence detaillee :

- `docs/admin-offer-event-delete-deploy-smoketest.md`

- login admin reussi avec un operateur valide
- refus d acces sans claim admin
- refus d acces avec `role != 'admin'`
- refus d acces avec `authDisabled == true`
- succes de `provisionManagedAccount`
- presence du compte dans Auth
- presence de `/users/{uid}`
- absence de claim admin sur compte provisionne
- bon fonctionnement des liens mot de passe et verification e-mail
- connexion mobile possible pour `joueur|fan|club|recruteur|agent` apres verification e-mail
- redirection mobile vers verification e-mail tant que `emailVerified == false`
- succes de `disableManagedAccountAuth`
- succes de `enableManagedAccountAuth`
- succes de `resendManagedAccountInvite`
- succes de `changeManagedAccountRole`
- succes de `deleteManagedAccount`
- succes de `adminSetOfferStatus`
- succes de `adminDeleteOffer`
- succes de `adminSetEventStatus`
- succes de `adminDeleteEvent`
- succes de `adminSetVideoStatus`, `adminRejectVideo`, `adminDeleteVideo`
- succes de `adminSetContactIntakeFollowUp`, `adminDeleteContactIntake`,
  `adminDeleteContactIntakeConversation`
- refus maintenu cote mobile pour toute creation publique de compte metier
- refus cote serveur (callables) pour un compte avec `role: 'admin'` en
  Firestore mais sans claim admin -- le champ Firestore seul ne suffit plus,
  voir section suivante

## Controle serveur admin (claims uniquement)

`assertAdminCaller()` (depot mobile, `functions/src/admin_account_support.ts`)
et `isAdminOperator()` (depot mobile, `firestore.rules`) n exigent que le
custom claim admin -- le champ Firestore `role: 'admin'` seul n ouvre plus
aucun acces, cote callables comme cote regles Firestore. Avant tout
deploiement qui touche l un de ces deux fichiers :

1. Executer `node scripts/audit_admin_claims.mjs --service-account <sa.json>`
   (depot mobile) sur l environnement cible et confirmer qu il ne trouve
   aucun ecart.
2. Combler tout ecart trouve via `npm.cmd run create-admin` avant de
   deployer.
3. Deployer d abord sur staging, valider, puis production.

Sans cette verification prealable, un compte avec `role: 'admin'` mais sans
claim (edition manuelle Firestore, erreur de script) perdrait l acces admin
des le deploiement.

## Requete collectionGroup('private') -- piege d index

Le portail admin lit les contacts prives via une requete
`collectionGroup('private')` sans `where()`/`orderBy()`
(`lib/controller/user_controller.dart`, depot admin). Cette requete
fonctionne aujourd hui uniquement parce qu elle n a aucun filtre.
`firestore.indexes.json` (depot mobile) ne contient aucune entree
`COLLECTION_GROUP` pour `private`.

Avant d ajouter le moindre `where()` ou `orderBy()` a cette requete :

1. Ajouter l entree `COLLECTION_GROUP` correspondante dans
   `firestore.indexes.json` (depot mobile).
2. Deployer l index (`firebase deploy --only firestore:indexes`) sur staging
   et attendre qu il soit `READY` avant de deployer le code qui l utilise.
3. Repeter sur production avant tout rollout.

Sans cette sequence, la requete filtree sera rejetee par Firestore en
production des le premier deploiement -- pas a la revue de code.

## Garde-fous production

A maintenir imperativement :

- aucune creation d admin cote client
- aucune creation directe client-side de compte metier
- aucune cle service account commitee
- rotation immediate de toute cle exposee
- protection contre l auto-blocage, l auto-desactivation ou l auto-suppression
  d un admin
- journalisation minimale des actions sensibles si disponible

## Gestion d incident

En cas d echec de provisioning :

- verifier la region Functions active affichee dans le portail admin
- verifier claim admin de l operateur
- verifier presence de `/users/{uid}`
- verifier IAM du service account si bootstrap Admin SDK
- verifier collision utilisateur via `existingUser`

En cas de derive inter-depots :

- verifier l environnement actif, le `projectId` cible et la region Functions
- verifier la configuration `app_environment.dart` / `firebase_bootstrap.dart`
- verifier contrat de roles
- verifier regles Firestore et garde d acces admin/mobile

## Decision d exploitation

La plateforme est exploitable si :

- le backend partage reste l unique source d autorite
- le bootstrap admin est strictement serveur/Admin SDK
- tous les comptes metier passent uniquement par les callables admin
- le mobile public n ouvre aucun parcours de creation metier
- le portail admin reste la seule surface legitime pour l administration
