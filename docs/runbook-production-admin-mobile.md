# Runbook Production Admin / Mobile

Date de reference : 25 mars 2026

## Objectif

Ce runbook formalise l exploitation en production de la plateforme partagee
entre :

- l application mobile publique
- le portail admin
- le backend Firebase `show-talent-5987d`

## Invariants de production

Les points suivants ne doivent jamais diverger :

- projectId : `show-talent-5987d`
- Firebase Auth commun
- Firestore commun
- Cloud Functions communes
- Storage commun : `show-talent-5987d.appspot.com`
- region Functions admin : `europe-west1`

## Matrice des comptes

Comptes publics :

- `joueur`
- `fan`

Comptes geres :

- `club`
- `recruteur`
- `agent`

Operateurs admin :

- Firestore `role: 'admin'`
- claim requis : `admin` ou `platformAdmin` ou `superAdmin`

## Regles d acces production

### Mobile public

Le mobile doit refuser :

- tout signup autre que `joueur|fan`
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

- service account JSON valide du projet `show-talent-5987d`
- fichier stocke localement hors Git
- `.credentials/` ignore par Git

Commande de reference :

```powershell
$env:FIREBASE_SERVICE_ACCOUNT_KEY_PATH="C:\chemin\vers\serviceAccount.json"
npm.cmd run create-admin -- --email superadmin@adfoot.com --password "MotDePasseTemporaire123!" --name "Super Admin ADFOOT" --claim superAdmin
```

Resultat attendu :

- utilisateur cree dans Firebase Auth
- claim `superAdmin: true` ou claim demande
- document `/users/{uid}` present

Document coherent attendu :

- `role: 'admin'`
- `authDisabled: false`
- `createdByAdmin: false`

## Provisionnement d un compte gere

Les comptes `club`, `recruteur`, `agent` sont crees uniquement via :

- `provisionManagedAccount`

Procedure :

1. connexion au portail admin avec operateur valide
2. ouverture de Comptes geres
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
- absence de claim admin sur compte gere
- bon fonctionnement des liens mot de passe et verification e-mail
- connexion mobile possible pour `club|recruteur|agent` apres verification e-mail
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
- refus maintenu cote mobile pour creation publique de `club|recruteur|agent`

## Garde-fous production

A maintenir imperativement :

- aucune creation d admin cote client
- aucune creation directe client-side de `club|recruteur|agent`
- aucune cle service account commitee
- rotation immediate de toute cle exposee
- protection contre l auto-blocage, l auto-desactivation ou l auto-suppression
  d un admin
- journalisation minimale des actions sensibles si disponible

## Gestion d incident

En cas d echec de provisioning :

- verifier region `europe-west1`
- verifier claim admin de l operateur
- verifier presence de `/users/{uid}`
- verifier IAM du service account si bootstrap Admin SDK
- verifier collision utilisateur via `existingUser`

En cas de derive inter-depots :

- verifier `projectId`
- verifier configuration FlutterFire
- verifier region Functions
- verifier contrat de roles
- verifier regles Firestore et garde d acces admin/mobile

## Decision d exploitation

La plateforme est exploitable si :

- le backend partage reste l unique source d autorite
- le bootstrap admin est strictement serveur/Admin SDK
- les comptes geres passent uniquement par les callables
- le mobile public reste limite a `joueur|fan`
- le portail admin reste la seule surface legitime pour l administration
