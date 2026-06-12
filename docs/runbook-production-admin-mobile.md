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
- refus maintenu cote mobile pour toute creation publique de compte metier

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
