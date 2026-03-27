# show_talent

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Admin / Mobile Shared Backend Contract

Le projet mobile public et le projet admin utilisent le meme backend Firebase
partage :

- projectId : `show-talent-5987d`
- Firebase Auth
- Firestore
- Cloud Functions
- Storage : `show-talent-5987d.appspot.com`

Documents de reference associes :

- [docs/prd-runbook-exploitation-inter-depots.md](docs/prd-runbook-exploitation-inter-depots.md)
- [docs/runbook-production-admin-mobile.md](docs/runbook-production-admin-mobile.md)

## Roles

Roles publics autorises en self-signup :

- `joueur`
- `fan`

Roles geres uniquement par l administration :

- `club`
- `recruteur`
- `agent`

Role Firestore des operateurs admin :

- `admin`

Claims admin reconnus :

- `admin`
- `platformAdmin`
- `superAdmin`

Le niveau reel d administration repose sur les custom claims, pas sur le seul
champ Firestore `role`.

## Mobile public

L application mobile publique :

- autorise l inscription uniquement pour `joueur` et `fan`
- refuse la creation client-side de `club`, `recruteur`, `agent`
- refuse la connexion si `/users/{uid}` est absent
- refuse la connexion si `estBloque == true`
- refuse la connexion si `authDisabled == true`
- refuse les comptes reserves au portail admin

## Portail admin

Le portail admin :

- authentifie uniquement des operateurs admin valides
- exige un document `/users/{uid}`
- exige `role == 'admin'`
- exige au moins un claim `admin|platformAdmin|superAdmin`
- refuse `estBloque == true`
- refuse `authDisabled == true`
- ne cree plus d admins cote client
- ne cree plus directement `club`, `recruteur`, `agent` cote client

## Cloud Functions admin

Toutes les operations sensibles passent par les callables backend partagees :

- `provisionManagedAccount`
- `blockManagedAccount`
- `unblockManagedAccount`
- `deleteManagedAccount`
- `changeManagedAccountRole`
- `resendManagedAccountInvite`
- `disableManagedAccountAuth`
- `enableManagedAccountAuth`
- `updateManagedAccountProfile`

Le portail admin doit appeler ces fonctions via :

- `FirebaseFunctions.instanceFor(region: 'europe-west1')`

## Bootstrap admin

Les operateurs admin sont crees uniquement via Admin SDK, depuis le depot
admin, avec :

- `scripts/create_admin_account.mjs`

Le bootstrap doit :

- creer ou mettre a jour Firebase Auth
- poser le custom claim admin
- creer ou mettre a jour `/users/{uid}`

Le document Firestore admin attendu :

- `role: 'admin'`
- `estBloque: false`
- `authDisabled: false`
- `createdByAdmin: false`

## Comptes geres

Les comptes `club`, `recruteur`, `agent` sont provisionnes uniquement via
`provisionManagedAccount`.

Le portail admin recupere :

- `uid`
- `email`
- `role`
- `existingUser`
- `passwordSetupLink`
- `emailVerificationLink`

## Regle de coherence

Le backend Firebase partage est la source d autorite unique pour :

- Auth
- custom claims
- Firestore `/users`
- cycle de vie des comptes geres

## Admin account script

This repository also includes a small Node script to create or update an admin
account in the shared Firebase project.

1. Install the tooling:

```bash
npm install
```

2. Provide Firebase Admin credentials with one of these environment variables:

- `FIREBASE_SERVICE_ACCOUNT_KEY_PATH`
- `GOOGLE_APPLICATION_CREDENTIALS`

3. Run the script with the admin identity you want to provision:

```bash
npm run create-admin -- --email admin@adfoot.com --password "TempPass123!" --name "Admin AD.FOOT" --claim admin
```

The script will:

- create or update the Firebase Auth user
- set an admin custom claim
- create or update `/users/{uid}` in Firestore

Important details:

- The dashboard only accepts the account if `/users/{uid}` exists, `estBloque`
  is `false`, `authDisabled` is `false`, `role` is `admin`, and one of the
  custom claims `admin`, `platformAdmin`, or `superAdmin` is present.
- Re-running the script is safe: it updates the Auth user, normalizes the admin
  claims, and upserts the Firestore profile.
- Keep the Firestore role as `admin` unless you intentionally need another
  stored label. Access control is based on custom claims, not on `role`.
- In this script, `estActif` is derived from the provisioned Auth user
  (`emailVerified`) instead of being documented as an unconditional hardcoded
  `true`.
- Use a temporary password and ask the operator to change it after first login.

Quick PowerShell example:

```powershell
$env:FIREBASE_SERVICE_ACCOUNT_KEY_PATH="C:\secrets\serviceAccount.json"
npm.cmd run create-admin -- --email admin@adfoot.com --password "TempPass123!" --name "Admin AD.FOOT" --claim admin
```

If PowerShell blocks `npm.ps1`, use `npm.cmd` as shown above.

Available options:

- `--email`
- `--password`
- `--name`
- `--claim` with `admin`, `platformAdmin`, or `superAdmin`
- `--role`
- `--projectId`
- `--serviceAccount`
- `--help`
