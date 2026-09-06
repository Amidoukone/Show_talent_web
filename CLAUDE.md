# Show_talent_web (portail admin)

## Depot lie

Ce portail admin et l'application mobile Adfoot partagent le meme backend
Firebase. Ce sont deux depots Git separes, mais un seul systeme en
production.

- Ce depot (admin) : `C:\Users\konea\Desktop\ODC_PROJECT\WEB\Show_talent_web`
- Depot mobile : `C:\Users\konea\Desktop\ODC_PROJECT\MOBILE\Show-Talent`
  (repo GitHub `Amidoukone/Show-Talent`)

Les scripts de ce depot detectent automatiquement le chemin mobile ci-dessus
(`scripts/check_mobile_contract.ps1`). Si le chemin change un jour, definir
`ADFOOT_MOBILE_REPO` plutot que modifier le script.

## Avant toute action qui touche le contrat partage

Ne jamais modifier isolement, dans ce depot, l'un de ces elements sans
regarder l'etat correspondant cote mobile :

- la liste des callables admin (`lib/utils/admin_callable_action_catalog.dart`
  ici, `functions/src/index.ts` cote mobile)
- les modeles miroirs : `lib/models/football_vocabulary.dart`,
  `lib/models/player_football_profile.dart`,
  `lib/models/org_football_profile.dart`, `lib/models/offre.dart`,
  `lib/utils/country_codes.dart` -- ce depot en detient une **copie exacte**,
  la source de verite est cote mobile
- les roles/claims admin (`admin`, `platformAdmin`, `superAdmin`) et la
  politique de comptes geres
- tout champ Firestore lu ou ecrit par le portail

Verifier avec :

```powershell
npm.cmd run contract:mobile
```

Ce script echoue fort (exit non nul) si le depot mobile est introuvable ou si
un fichier partage a diverge -- ce n'est pas un simple avertissement.

## Ordre de deploiement -- le lecteur avant l'ecrivain

Regle etablie apres un incident de production (champ `team` vs
`currentClubName` lu differemment selon la version) : voir
`docs/prd-runbook-exploitation-inter-depots.md` et, cote mobile,
`docs/inter-repo-admin-mobile-runbook.md` (section "Ordre de deploiement
entre les deux depots", plus detaillee et plus recente).

Ordre obligatoire :

1. Regles Firestore + Cloud Functions (depot mobile, seul a les deployer)
2. Build mobile publie
3. Portail admin (ce depot)

Deployer ce portail avant le mobile peut casser silencieusement une
correction faite par un administrateur (aucune erreur visible nulle part).

## Docs de reference

Ici :
- `README.md` (section "Admin / Mobile Shared Backend Contract")
- `docs/prd-runbook-exploitation-inter-depots.md`
- `docs/runbook-production-admin-mobile.md`
- `docs/admin-offer-event-rollout-plan.md`

Cote mobile (a lire en cas de doute, generalement plus a jour) :
- `docs/inter-repo-admin-mobile-runbook.md`
- `docs/shared-backend-contract.md`

Note : la version de `prd-runbook-exploitation-inter-depots.md` de ce depot
(25 mars 2026) est moins detaillee que celle du depot mobile (17 avril
2026). En cas de divergence entre les deux, celle du mobile fait foi.

## Secrets

`.credentials/*`, `android/app/google-services.json`,
`config/*.json` (sauf `*.example.json`) sont locaux, jamais dans Git.
Voir `README.md` > "Secrets and Firebase config".
