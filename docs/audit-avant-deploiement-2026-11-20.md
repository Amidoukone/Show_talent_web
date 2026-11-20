# Audit avant déploiement du système Adfoot

La [revue transversale suivante](revue-coherence-transversale-2026-11-20.md) détaille les nouveaux constats après ces corrections, notamment sur les déclarations interrompues, les invitations, les verdicts concurrents et le téléchargement public.

**Mise à jour après correction, le 20 novembre 2026.** Les six constats ci-dessous décrivent le candidat avant intervention. Les scripts associés vérifient désormais le comportement corrigé. Les journaux locaux ont été régénérés.

### Résultat de la passe de correction

| Constat | Changement et preuve locale |
| --- | --- |
| F01 et F02 — consultation et verdict | Le portail affiche le document dans un dialogue. Une fermeture simple laisse le verdict désactivé. La confirmation porte sur la référence consultée et son remplacement impose une nouvelle lecture. Le backend renvoie le statut historique et l’enveloppe attendue par le décodeur Dart. Une approbation réellement enregistrée dans Firestore émulé a été relue comme réussie par le portail. |
| F03 — documents privés | La version web de FlutterFire installée utilise un lien de téléchargement dans son implémentation de `getData`. Le portail appelle directement `getBytes` du SDK JavaScript configuré pour la même application et le même bucket. La limite est de 8 Mio. Chrome a affiché le PDF dans la page et libéré son adresse `blob:` après fermeture. Une nouvelle lecture Storage après retrait des droits a été refusée sur émulateur. |
| F04 — retrait du droit club | Le backend retire le droit et enregistre la décision dans une transaction. Le traitement conserve son curseur et ses compteurs à chaque page de 25 liens. Les reprises manuelle et planifiée utilisent la même décision. Après une interruption à 25 liens sur 27, le renouvellement a été refusé, le scheduler a terminé les deux liens restants et la relance a rendu le total de 27. Le dialogue admin propose la reprise sur un club déjà privé du droit. |
| F05 — corrections du joueur | Le test de l’écran mobile vérifie l’envoi des deux listes vides après suppression du dernier poste et de la dernière nationalité. Le test inter-dépôts relit ensuite les tableaux vides dans le profil après confirmation. |
| F06 — invitation | L’intégration appelle le provisionnement réel sur Firestore émulé, avec Auth et courriel simulés. Elle vérifie le profil actif, l’adresse vérifiée, l’absence de demande de lien de vérification supplémentaire et le résultat de distribution. Le scénario de panne du lien d’activation reste couvert. |

**Contrôles du candidat corrigé.** Les suites Flutter comptent 1 179 réussites côté mobile et 296 côté portail. Les 106 tests Node des Functions, TypeScript et ESLint passent. Les émulateurs valident 182 cas Firestore, 65 cas Storage et 69 régressions applicatives. Le contrôle des 23 callables, les modèles miroirs, la configuration de production, les tests de release admin et la compilation web de production passent. L’analyse Dart du portail se termine avec 54 informations, sans erreur ni avertissement. Le site public conserve la couverture d’activation du lot précédent. Les fichiers livrables figurent dans les deux arbres de travail locaux.

**Portée du contrôle navigateur.** Le lanceur de tests Flutter pour Chrome a expiré au chargement de son iframe. Le test widget de consultation et de remplacement a réussi sur la VM Flutter. Le contrôle navigateur a réussi séparément dans Chrome sur une application compilée montant le véritable composant PDF. Il vérifie la présence du PDF, les octets locaux, la libération de l’adresse et l’absence de nouvel onglet. Depuis le dépôt admin, les commandes sont les suivantes.

```powershell
flutter build web --release --no-pub --no-web-resources-cdn --target scripts/document_preview_browser_fixture.dart --output build/document-preview-smoke
node scripts/audit_document_open_2026_11_20.mjs
```

**Anciens liens et staging.** L’outil [d’inventaire des jetons](../../../MOBILE/Show-Talent/functions/scripts/review-private-document-tokens.cjs) parcourt uniquement les fichiers des accords et les justificatifs contractuels. Depuis le dépôt mobile, `node functions/scripts/review-private-document-tokens.cjs --bucket <nom-du-bucket>` compte les objets concernés. L’option `--apply` demande une modification conditionnée à la version des métadonnées, suivie d’une relecture. Dans la simulation, un objet a été corrigé et un jeton est resté présent sur un autre objet. L’outil a remonté cet échec. Aucun inventaire ni retrait de jetons n’a été lancé sur un bucket distant.

Avant toute décision de production, vérifier sur staging la lecture depuis l’origine réelle du portail avec CORS et App Check, le refus d’une nouvelle lecture après retrait des droits, et l’invalidation d’un ancien lien de test après traitement. Vérifier aussi la reprise réellement planifiée, la livraison d’une invitation et le parcours des versions iOS et Android installées. L’état des habilitations historiques mérite un contrôle de données séparé. Dans la simulation, un enregistrement avec une date future et sans référence d’accord est encore lu comme actif par le backend. Le callable actuel exige cette référence à l’octroi. La présence de tels enregistrements en production reste inconnue.

### Constat initial conservé pour traçabilité

État examiné le 20 novembre 2026. **Le candidat ne doit pas encore être déployé en production.** Six défauts restent confirmés dans l’état local : trois de priorité P1 et trois de priorité P2. Les plus importants bloquent l’examen des justificatifs contractuels, rendent son résultat trompeur et contredisent la protection attendue des documents privés.

L’analyse couvre les changements récents du mobile, du backend Firebase partagé, du portail admin et du site public, avec les modifications non commitées déjà présentes. Elle conserve ces modifications et ne corrige pas le code applicatif. Aucun déploiement, commit, push, envoi d’invitation réelle ou changement de données distantes n’a été effectué.

## Périmètre et état du candidat

| Surface | Dépôt et responsabilité | Référence locale examinée |
| --- | --- | --- |
| Mobile Android et iOS | `MOBILE/Show-Talent`, application Flutter | HEAD `672eba0a5c183a9b3a203d130e9ce75c615c5a11` et changements locaux |
| Backend commun | Même dépôt, `functions/src`, règles Firestore et Storage, index | Même HEAD et changements locaux |
| Site public | Même dépôt, `site_pub`, pages d’activation et CGU FR/EN | Même HEAD et changements locaux |
| Portail admin | `WEB/Show_talent_web`, application Flutter web | HEAD `d8fc2863fea1734f8a550ff5d9860c276cd57aed` et neuf fichiers déjà modifiés |

Ces HEAD identifient les dépôts de départ, pas l’intégralité du candidat : des fichiers modifiés et de nouveaux fichiers non suivis font partie de son comportement. Le SHA réellement déployé en production n’a pas été établi. L’audit ne prétend donc pas reconstruire exactement le delta depuis les binaires distribués.

Le candidat mobile déclare `1.1.1+60`. Sa baseline locale indique Android `1.1.0 (58)` et iOS `1.1.0 (59)`. Le contrôle local de version passe ; les téléversements déjà effectués sur les pistes de test doivent encore être comparés avant soumission aux stores.

Les rapports des passes précédentes, présents dans le dépôt mobile, ont servi à retrouver les problèmes déjà traités. Leurs résultats historiques ne sont pas assimilés aux vérifications de cette passe. La nouvelle suite mobile présente notamment un échec alors que le dernier rapport annonçait une suite verte.

## Résultats des vérifications exécutées

| Contrôle | Résultat de cette passe | Portée |
| --- | --- | --- |
| Configuration de production du portail | Réussi | `npm run production:check` |
| Contrat admin et mobile strict | Réussi, 23 callables retrouvés côté backend | Modèles miroirs et présence des fonctions, sans validation complète de leurs réponses |
| Suite Flutter complète du portail | **295 réussites** | Tests unitaires et widgets existants |
| Suite de release du portail | Réussie | `npm run test:release` |
| Analyse Flutter du portail | **0 erreur, 0 warning, 51 informations** | Informations de dépréciation ; commande avec `--no-fatal-infos` |
| Compilation web de production du portail | **Réussie** | Sortie `build/web`, environ 133 secondes de compilation, aucun déploiement |
| Suite Flutter complète du mobile | **1 178 réussites et 1 échec** | Défaut F06 ci-dessous ; journal `audit-mobile-tests-2026-11-20.log` |
| Compilation TypeScript | Réussie | Vérification `--noEmit`, puis compilation réelle préalable aux intégrations |
| ESLint backend | Réussi | `npm --prefix functions run lint` |
| Tests Node backend et activation web | **106 réussites** | Suite configurée dans `functions/package.json` |
| Règles et intégrations Firestore existantes | **182 sur 182** | Véritable émulateur, projet `demo-adfoot` |
| Règles Storage existantes | **65 sur 65** | Véritable émulateur, projet `demo-adfoot` |
| Régressions comportementales existantes | **68 sur 68** | Callables, transactions et traitements concurrents |
| Reproduction dans Chrome | Blocage F01 confirmé | Un onglet créé, document ouvert, retour du helper `false` |
| Reproductions backend supplémentaires | F02 à F05 confirmés | Transactions et Storage réels sur émulateurs ; identité Auth simulée pour la gestion de compte |
| Reproductions Dart du portail | **2 réussites de reproduction** | F02 et blocage de reprise F04 ; ces tests constatent les défauts |
| Version mobile et empreintes des images du site | Réussies | Scripts locaux dédiés |
| Encodage de sources mobile, backend, site et cibles natives | **273 fichiers, aucun signalement** | Périmètre explicite du script d’encodage |
| `git diff --check` | Réussi dans les deux dépôts | Contrôle d’espaces, sans validation métier |

Aucun AAB ou IPA signé n’est construit pendant cet audit.

Les premiers lancements de certains outils ont rencontré des contraintes de poste : ancien Java dans le PATH pour les émulateurs et verrou du SDK Flutter hors du dossier accessible au bac à sable. Les suites de règles ont ensuite été réexécutées avec le JDK d’Android Studio. Ces contraintes locales ne constituent pas des défauts applicatifs.

## Défauts confirmés

P1 signifie correction nécessaire avant l’ouverture du parcours concerné en production. P2 signifie défaut fonctionnel ou de validation à traiter avant de déclarer le candidat prêt. Aucun incident déjà survenu en production n’est déduit de ces reproductions locales.

### F01 P1 L’ouverture du justificatif laisse son examen bloqué

**Sources :** [helper web](../lib/utils/admin_external_link_web.dart#L31), [garde du verdict](../lib/dashboard/contract_proof_review_widget.dart#L147), [enregistrement de l’ouverture](../lib/dashboard/contract_proof_review_widget.dart#L185).

Le helper retourne `window.open(url, '_blank', 'noopener,noreferrer') != null`. Avec ces options et cette cible, Chrome ouvre le document tout en retournant `null`. Le portail traite ce résultat comme un refus du navigateur et n’inscrit jamais la pièce dans `_openedProofs`.

Le contrôle ajouté au verdict exige précisément cette inscription. L’administrateur peut donc lire le contrat dans son nouvel onglet, revenir au portail et rester devant une action désactivée lui demandant de l’ouvrir. Autoriser les fenêtres surgissantes ne corrige pas ce cas, puisque l’onglet a déjà été ouvert.

**Preuve :** le script Chrome crée une page locale, exécute exactement l’appel du helper avec un geste utilisateur simulé, puis vérifie la présence du nouvel onglet. Résultat : `createdPages: 1`, `openedDocumentPresent: true`, `adminHelperReturnValue: false`. La sémantique de retour est également décrite dans la [documentation de Window.open](https://developer.mozilla.org/en-US/docs/Web/API/Window/open#noopener).

**Impact :** le parcours ordinaire d’approbation et de rejet des pièces contractuelles est bloqué. Les accords de club et les autres ouvertures utilisant ce helper peuvent aussi afficher un faux message de blocage ; ils n’ont pas tous la même conséquence sur leur action suivante.

**Correction attendue :** conserver l’isolation de l’onglet, mais découpler la preuve d’ouverture du retour de `window.open` avec `noopener`. Préparer un aperçu ou une ouverture contrôlée, gérer le véritable blocage du navigateur et enregistrer l’identité du fichier réellement présenté. Ajouter un test navigateur du parcours ouvrir puis rendre le verdict, sur Chromium et Safari.

### F02 P1 Un verdict enregistré est interprété comme un échec

**Sources :** [retour backend](../../../MOBILE/Show-Talent/functions/src/contract_proof_actions.ts#L336), [décodage du service](../lib/services/admin_content_service.dart#L51), [modèle de réponse](../lib/models/admin_action_response.dart#L27), [retour à l’opérateur](../lib/dashboard/contract_proof_review_widget.dart#L243).

Après sa transaction, `reviewContractStatusProof` renvoie uniquement `{status: 'approved'}` ou `{status: 'rejected'}`. Le service admin décode toutes ses réponses avec `AdminActionResponse.fromMap`, qui exige `success == true` et attend aussi `code` et `message`.

La mutation réussit donc dans Firestore, tandis que le portail construit une réponse d’échec avec le code `unknown` et un message vide. L’écran annonce ensuite que l’examen est impossible. Le contrôle de contrat reste vert parce qu’il vérifie la présence du callable, pas ce format de réponse.

**Preuve :** invocation du véritable handler sur émulateur avec une pièce existante. La pièce termine en `approved`, la réponse vaut `{status: 'approved'}`, et le décodage Dart réellement utilisé par le portail donne `success: false`. Le problème subsistera après correction de F01 ; les deux défauts sont indépendants.

**Impact :** faux échec d’une action effectivement commise, tentative de répétition possible, incertitude sur le statut publié et perte de confiance dans les décisions administratives.

**Correction attendue :** aligner le backend sur l’enveloppe des actions admin, avec `success`, `code`, `message` et `data`. Garder si nécessaire `status` au niveau historique pour les autres consommateurs. Tester la réponse d’un handler réel avec le décodeur du portail ; un mock qui invente une réponse conforme ne couvre pas ce défaut.

### F03 P1 Les liens de documents privés restent lisibles après retrait des droits

**Sources :** [résolution des justificatifs](../lib/services/admin_document_service.dart#L121), [résolution des accords](../lib/services/admin_document_service.dart#L162), [règle de lecture des contrats](../../../MOBILE/Show-Talent/storage.rules#L330).

Les commentaires du service annoncent une lecture contrôlée à chaque ouverture et une adresse valable pour la session. L’implémentation appelle pourtant `getDownloadURL()`, puis transmet son URL au navigateur. Cette URL contient un jeton de téléchargement durable. Le fait de conserver une référence `gs://` dans Firestore et de redemander l’URL à chaque clic ne retire pas la capacité portée par une URL déjà obtenue.

**Preuve :** sur Storage émulé, un administrateur obtient le lien d’une pièce. Une nouvelle session du même UID sans claim admin reçoit ensuite `storage/unauthorized` pour la lecture SDK. Une requête HTTP sans aucune authentification vers l’ancienne URL reçoit encore **200** et les octets du document. Le jeton lui-même n’est pas inclus dans les preuves conservées.

La documentation Firebase décrit ces liens comme durables et révocables, utilisables pour partager le fichier : [référence StorageReference](https://firebase.google.com/docs/reference/android/com/google/firebase/storage/StorageReference#getDownloadUrl()). La reproduction confirme ici l’écart avec la garantie attendue par ce service.

**Impact :** après obtention du lien, sa réutilisation et sa transmission ne dépendent plus du claim admin de son porteur. Les pièces contractuelles et les accords signés sont concernés par les deux méthodes de résolution. Cela ne prouve pas une fuite passée ; cela confirme que la révocation des droits ne suffit pas à fermer les liens déjà remis.

**Correction attendue :** pour ces dossiers, choisir une lecture authentifiée des octets et un aperçu local au navigateur, ou un endpoint qui vérifie les droits à chaque demande. Définir aussi le traitement des jetons déjà créés. Une URL temporaire peut borner la durée d’exposition, mais ne reproduit pas une vérification des droits à chaque lecture. Le critère de recette doit porter sur une nouvelle requête après retrait d’accès, sans prétendre retirer les octets déjà téléchargés.

### F04 P2 Une révocation interrompue ne peut plus être relancée depuis son dialogue

**Sources :** [retrait du droit puis cascade](../../../MOBILE/Show-Talent/functions/src/admin_account_actions.ts#L1938), [cascade](../../../MOBILE/Show-Talent/functions/src/club_links.ts#L778), [validation du dialogue](../lib/widgets/club_enrollment_dialog.dart#L264).

Le backend supprime d’abord `clubEnrollment`, puis parcourt les rattachements pour annuler les déclarations non confirmées et signaler les affiliations à réexaminer. Une panne entre ces étapes laisse bien le club sans droit, mais la cascade incomplète n’a pas de demande durable de reprise. Aucun consommateur de reprise de cette cascade n’a été trouvé.

Le callable peut être explicitement réexécuté. Le dialogue, lui, n’autorise « Retirer » que lorsque `_current.granted` est vrai. Après le premier retrait, il considère qu’il n’y a plus rien à retirer et désactive la commande nécessaire à la reprise.

**Preuve :** une panne est injectée au début du scan. Le callable échoue, le droit est absent et une déclaration reste en `declared`. Le second appel direct du même callable termine la cascade. Un test widget séparé monte le dialogue avec le profil révoqué et constate le bouton désactivé. Aucun nouveau profil ou accord n’est nécessaire pour reprendre côté backend.

**Impact :** déclarations bloquées pour les joueurs, affiliations non signalées pour réexamen et dossier apparemment retiré côté admin. La coupure du droit fonctionne ; c’est la finalisation de la décision qui reste incomplète.

**Correction attendue :** enregistrer une opération de cascade avec état, progression, erreurs et reprise idempotente. Le portail doit afficher une finalisation en attente et proposer de la relancer même lorsque le droit est déjà absent. Vérifier une panne après plusieurs rattachements traités, la reprise et les renouvellements concurrents.

### F05 P2 Vider une correction conserve silencieusement les valeurs du club

**Sources :** [préparation des corrections mobiles](../../../MOBILE/Show-Talent/lib/screens/club_link_confirmation_screen.dart#L83), [filtrage serveur](../../../MOBILE/Show-Talent/functions/src/club_links.ts#L97), [fusion avec la déclaration](../../../MOBILE/Show-Talent/functions/src/club_links.ts#L349).

Le joueur peut retirer toutes les nationalités affichées ou désélectionner tous les postes avant de confirmer son rattachement. Le mobile n’envoie alors pas le champ corrigé, parce qu’il exige une liste non vide. Même un appel direct envoyant `[]` ne suffit pas : `sanitizeDeclaredFacts` supprime ces listes, puis la fusion réintroduit les valeurs déclarées par le club.

**Preuve :** déclaration avec `positionCodes: ['ST']` et `nationalities: ['ML']`, puis confirmation réelle avec deux listes de correction vides. Le callable répond avec succès ; les deux anciennes valeurs restent enregistrées sur la fiche. Le bouton de confirmation mobile n’interdit pas cet état et aucun message ne prévient que l’effacement sera ignoré.

**Impact :** l’écran et les données validées divergent. Le système peut présenter comme accepté par le joueur un fait qu’il vient de retirer. Ce défaut touche l’intégrité du dossier, même si le joueur peut ensuite utiliser d’autres parcours de modification.

**Correction attendue :** distinguer explicitement champ absent, valeur corrigée et effacement. Accepter un effacement autorisé ou désactiver la confirmation avec une raison précise si le champ est obligatoire. Le mobile et le validateur serveur doivent appliquer le même contrat. Tester le retrait de la dernière valeur et la persistance finale, pas seulement la forme du payload.

### F06 P2 La suite mobile échoue sur un garde fou devenu obsolète

**Sources :** [assertion en échec](../../../MOBILE/Show-Talent/test/account_invite_email_guardrails_test.dart#L163), [construction actuelle des liens](../../../MOBILE/Show-Talent/functions/src/managed_accounts.ts#L436).

La suite complète se termine par `+1178 -1`. L’assertion cherche la chaîne exacte `const emailVerificationLink = userRecord.emailVerified ?`, alors que l’implémentation déclare maintenant une variable `let`, puis l’affecte dans le bloc protégé de génération des liens.

Les autres assertions du test sur la vérification de l’adresse et l’activation du profil ont passé avant cet échec. Il s’agit d’un contrôle couplé à l’ancienne écriture du code, et non d’une démonstration que les invitations échouent. La livraison reste néanmoins bloquée par une suite officiellement rouge, et les rapports antérieurs ne décrivent plus son résultat actuel.

**Correction attendue :** remplacer cette recherche de texte par un test de comportement : profil actif et adresse vérifiée au provisionnement, absence de lien de vérification superflu, traitement d’une panne de génération et résultat d’envoi correctement rapporté. Relancer ensuite la suite complète sans ignorer le test.

## Lecture de la structure et des changements déjà protégés

La répartition des responsabilités est cohérente : le dépôt mobile porte le backend commun ; le portail consomme ses callables ; les coordonnées privées et les profils publics ont des espaces distincts ; les rôles métier et les claims admin sont séparés. Les modèles miroirs vérifiés restent synchronisés. Les nouvelles entrées du portail sont raccordées à leurs contrôleurs, services et onglets.

Le principal risque vient des transitions entre ces surfaces. Les tests peuvent valider chaque côté séparément tout en laissant passer un désaccord de réponse ou une différence de comportement du navigateur. F01 et F02 le démontrent malgré les suites et le contrat verts.

| Domaine examiné | Ce que les contrôles locaux établissent | Validation encore nécessaire pour la livraison |
| --- | --- | --- |
| Déclaration par club | Les régressions existantes couvrent le droit courant, la concurrence avec une révocation, l’écriture du profil et du rattachement avant invitation, et les pannes Auth simulées | Invitation réelle, activation sur appareil, corrections vidées F05 et reprise F04 |
| Mineurs | Les régressions couvrent l’interdiction d’approbation parentale par un club, le sujet réel d’une vidéo, les lectures anonymes et les purges de médias déposés par le club | Matrice de consentements sur les clients installés et vérification des objets et liens réellement distribués |
| Vidéos de club | Les scénarios existants couvrent finalisation, optimisation, quota par sujet, consentement, retrait, événement ancien et concurrence entre workers | Upload réel interrompu puis repris, lecture sur Android et iOS, notifications, fichier et lien après retrait |
| Statut contractuel | L’identité du fichier attendu, l’immuabilité et la conservation ont des régressions serveur | Corriger F01 à F03, puis effectuer le parcours complet depuis le portail |
| Suppression de compte | Les régressions couvrent purge, mise en attente de suppression Auth, reprise et protection contre une recréation tardive | Auth réel, exécution du scheduler et confirmation de finalisation |
| Modération des coordonnées | Les tests existants couvrent le nettoyage des textes imbriqués, les événements anciens et le maintien des montants métier | Examiner les signalements sur un jeu staging réaliste et vérifier les erreurs de chargement |
| Messagerie | Lecture du même document `config/messaging`, blocage côté règles et visibilité admin de l’absence de support | Comptes de support réellement actifs, parcours depuis un ancien client et notifications reçues |
| Site et activation | Les 106 tests Node incluent les scénarios d’activation, le délai réseau et la double soumission ; les images locales sont cohérentes | Courriel réel, lien universel sur appareil, contenu effectivement servi et parcours FR/EN |
| CGU et version | Pages locales et script d’activation portent la version 1.3 ; le candidat passe le contrôle de version local | Publier les bons octets avant d’activer l’exigence correspondante ; vérifier les derniers uploads des stores |

Les résultats des régressions montrent les garanties des scénarios exécutés. Ils ne prouvent pas l’absence de toute course possible, de tout objet historique divergent ou de toute erreur sur un appareil réel.

## Ordre de correction et critères de recette

1. Corriger ensemble F01, F02 et F03. Le même parcours doit ouvrir une pièce avec les bons droits, empêcher un verdict sur une pièce remplacée, enregistrer la décision et afficher le résultat réel. Une nouvelle lecture après retrait d’accès doit échouer.
2. Rendre la révocation reprenable et visible, puis corriger le contrat d’effacement des faits. Rejouer les pannes et vérifier la fiche persistée après chaque action.
3. Réparer F06 par un test comportemental et obtenir une suite mobile complète verte. Ajouter des tests de contrat de réponse entre handler réel et décodeur client, ainsi qu’un test navigateur d’ouverture de document.
4. Figer le candidat complet : deux SHA, modifications suivies, nouveaux fichiers ajoutés, version, configurations et empreintes des règles et index. Conserver les preuves avec ce candidat précis.
5. Exécuter une recette staging avec les vraies intégrations avant de décider la mise en production.

La recette doit comprendre les identités suivantes : joueur majeur historique, nouveau joueur déclaré par club, mineur sans accord, mineur avec accord de profil seulement, mineur avec accord média, club habilité, club expiré, club révoqué, utilisateur ordinaire, recruteur vérifié, compte de support et admin.

| Parcours staging | Critère d’acceptation |
| --- | --- |
| Club vers joueur | Création unique, invitation reçue, activation, confirmation ou contestation ; le profil reflète exactement les corrections validées |
| Club vers vidéo du joueur | Upload et reprise après coupure ; consentement sur le média consulté ; approbation admin ; présence sur la bonne fiche ; retrait effectif |
| Justificatif contractuel | Ouverture autorisée ; remplacement concurrent refusé au verdict ; décision réelle affichée ; accès retiré effectivement fermé |
| Retrait du droit club | Panne injectée après un traitement partiel ; état en attente visible ; reprise accessible ; aucun nouveau joueur déclaré après retrait |
| Compte et données privées | Suppression réelle, échec temporaire Auth puis reprise ; aucune restauration par un ancien traitement |
| Messagerie | Support joignable, interdictions attendues et notification reçue ; état indisponible explicitement affiché |
| Anciennes versions | Les builds représentés par Android 58 et iOS 59 continuent leurs lectures et actions autorisées après remplacement du backend ; mêmes essais sur le candidat 60 |
| Web public | Activation issue d’un véritable courriel, paramètres de lien conservés, cas expiré expliqué, téléchargement des applications et langue vérifiés |

## Séquence de déploiement à préparer après correction

L’ordre « backend, mobile, portail » reste la règle de dépendance du projet, avec une phase additive pour les données et règles partagées avec les anciennes versions.

1. Préparer les index et attendre leur disponibilité. Comparer le backend réellement déployé au contrat attendu : fonctions, règles, index, TTL, secrets présents et configuration des schedulers. Les contrôles locaux verts ne répondent pas à cette comparaison.
2. Livrer les capacités serveur compatibles et les règles de transition appropriées. Exécuter les migrations de profils et d’audience avec compteurs, suivi des erreurs et reprise. Ne pas retirer une lecture utilisée par les clients encore installés avant leur migration.
3. Valider le candidat mobile sur les pistes de test et sur appareils, en incluant les versions anciennes retenues. Ouvrir les nouveaux parcours seulement quand leurs dépendances sont prêtes.
4. Livrer le portail compatible après son backend et ses lecteurs mobiles. La résolution de F02 doit rester compatible avec les callables encore consommés par les autres surfaces.
5. Publier les pages publiques et leurs versions de texte ; vérifier les octets servis avant d’activer l’exigence d’acceptation correspondante. Toute modification distante relève de la phase de déploiement, distincte de cet audit.
6. Suivre erreurs de callables, attentes de consentement, échecs d’upload, cascades et suppressions incomplètes. Préparer un retour compatible avec les nouveaux états déjà écrits ; un simple retour à un ancien binaire ne suffit pas toujours.

Les preuves de cette passe sont locales. La parité du backend de production, les secrets opérationnels, l’envoi SMTP, la réception push, les binaires signés et les parcours sur matériel ne sont pas validés ici. Ces points restent des conditions de recette, sans présumer qu’ils sont défectueux.

## Preuves et reproduction

| Livrable local | Usage |
| --- | --- |
| [Script Chrome](../scripts/audit_document_open_2026_11_20.mjs) | Reproduction F01, pages locales sans compte |
| [Script backend](../scripts/audit_backend_contract_2026_11_20.mjs) | Reproductions F02 à F05 ; exige explicitement `demo-adfoot` et les deux émulateurs locaux |
| [Tests Dart de reproduction](../scripts/audit_portal_behaviour_2026_11_20_test.dart) | Décodage de la réponse réellement produite et blocage du dialogue après révocation |
| `build/audit-2026-11-20/browser-document-open.json` | Observation Chrome |
| `build/audit-2026-11-20/backend-contract-reproductions.json` | Mutations observées et réponses, sans lien de téléchargement sensible |
| `audit-backend-reproductions-2026-11-20.log` | Exécution des reproductions serveur |
| `audit-portal-reproductions-2026-11-20.log` | Deux reproductions Dart |
| `audit-mobile-tests-2026-11-20.log` | Suite mobile complète et assertion en échec |
| `audit-rules-tests-2026-11-20.log` | Suites existantes Firestore, Storage et 68 régressions |
| `audit-admin-build-2026-11-20.log` | Compilation web de production |

**Les scripts de reproduction constatent volontairement les défauts. Leur réussite ne constitue pas une autorisation de release.** Ils sont conservés hors de la suite habituelle. Après correction, leurs assertions doivent être converties en exigences du comportement attendu avant intégration aux contrôles permanents.

Pour relancer le backend avec ses dépendances actuelles et ses émulateurs depuis le dossier admin, après compilation des Functions, utiliser une configuration Firebase locale indiquant les règles du dépôt mobile et les ports 8080 et 9199. Une configuration de cette passe est conservée dans `build/audit-2026-11-20/firebase.json` ; ce dossier est ignoré par Git et cette configuration doit être recréée sur une autre machine. La commande de reproduction est :

```powershell
$env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
$env:PATH = $env:JAVA_HOME + '/bin;' + $env:PATH
& ../../MOBILE/Show-Talent/node_modules/.bin/firebase.cmd emulators:exec --config build/audit-2026-11-20/firebase.json --only firestore,storage --project demo-adfoot "node scripts/audit_backend_contract_2026_11_20.mjs"
flutter test --no-pub scripts/audit_portal_behaviour_2026_11_20_test.dart
node scripts/audit_document_open_2026_11_20.mjs
```

Le chemin mobile du script backend peut être redéfini par `ADFOOT_MOBILE_REPO`. Le script Chrome utilise le chemin Chrome Windows de ce poste. Les références vers les sources mobiles supposent les deux dépôts voisins selon la structure actuelle.

## Résultat de la compilation web

`npm run build:web:production` termine avec le code 0 et produit `build/web`. La compilation prend environ 133 secondes. Le contrôle préalable Wasm réussit également ; son message d’information écrit sur stderr apparaît sous forme de `NativeCommandError` dans le journal PowerShell, sans échec de la compilation. Le résultat retenu est le code de sortie et la production effective du bundle.

Ce résultat confirme que le portail compile avec ses paramètres de production. F01 à F03 restent présents dans le bundle compilé ; une compilation réussie ne valide pas le parcours métier. Aucun fichier produit n’a été déployé.
