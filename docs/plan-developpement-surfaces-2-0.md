# Les surfaces manquantes du portail, lots L4 à L7

Document de développement. Rédigé le 19 novembre 2026, après relecture des
vingt-deux commits du dépôt mobile et de l'état réel de ce dépôt-ci.

Le backend d'ADFOOT 2.0 est écrit et testé : un club est habilité contre un
accord signé, il déclare ses joueurs, le joueur relit et confirme, le club
dépose des vidéos sur ses joueurs confirmés, et un statut contractuel ne
s'affiche que sur pièce approuvée. **Rien n'est déployé**, et sept surfaces
manquent ici. Trois d'entre elles ne sont pas du confort : sans elles, un lot
livré reste une porte fermée, et un opérateur rencontre des refus que rien
n'explique.

Ce document donne, pour chaque surface, ce qui existe déjà côté serveur, les
noms de champs exacts, et où elle se branche dans ce dépôt. Les formes ont été
relevées dans le code, pas dans les documents de conception.

## Avant tout : une ligne de règle à ouvrir dans le dépôt mobile

La collection `contact_leak_reports`, créée au lot L7, est fermée aux deux sens
dans `firestore.rules` :

```
match /contact_leak_reports/{docId} {
  allow read, write: if false;
}
```

Les règles ne distinguent pas l'opérateur admin d'un client, donc **ce portail
ne peut pas la lire**. La lecture doit passer à `isAdminOperator()`, comme
`player_club_links` le fait déjà. C'est un changement de dix minutes dans le
dépôt mobile, et il doit voyager avec le déploiement de règles qui précède
celui du portail : sinon la surface 4 ci-dessous est bloquée et il faut un
second déploiement de règles.

## Rappel de l'ordre, qui n'est pas négociable

1. Règles, index et Cloud Functions, depuis le dépôt mobile.
2. Surveiller `migration_state/profile_submission_grandfather_v1` jusqu'à
   `completed: true`. Ce rattrapage date la soumission des comptes existants ;
   tant qu'il n'a pas fini, une partie des fiches est hors annuaire.
3. Build mobile publié et installé, puis mesure des versions actives.
4. **Ce portail, en dernier, toujours.** C'est l'incident que `CLAUDE.md` du
   dépôt mobile raconte.

Déploiement : `npm run deploy:web:production`, qui enchaîne `release:check`, le
build et la mise en ligne. Ne pas déployer un build périmé en sautant cette
chaîne.

## État de ce dépôt avant de commencer

- Branche `feature/habilitation-clubs`, un seul commit, `11deed4`, **poussé sur
  aucune remote**. À pousser avant d'empiler du travail dessus.
- Quatre artefacts générés traînent non validés (`pubspec.lock`, registrants
  macOS et Windows), réécrits par `flutter test`. À committer ou à ignorer
  avant de commencer, sinon le premier vrai commit sera bruité.
- `lib/utils/admin_callable_action_catalog.dart` liste déjà vingt callables,
  dont `setClubEnrollmentRight` et `revokeClubEnrollment`.

**Contrainte sur les onglets.** `_dashboardItems` et `_widgetOptions()` dans
`lib/dashboard/admin_dashboard_screen.dart` sont indexés par position, et
`lib/config/app_routes.dart` résout les liens profonds sur ces index. Un nouvel
onglet **s'ajoute à la fin**, jamais au milieu : une insertion décale les liens
profonds sans que rien n'échoue. Le regroupement `_dashboardGroups` se met à
jour en même temps.

## 1. Examen des pièces de statut contractuel (lot L7)

**Pourquoi d'abord.** C'est le seul lot dont la totalité dépend d'un écran qui
n'existe pas : aucune pièce ne sera jamais examinée, donc aucun statut
contractuel ne sera jamais publié. Et il force la plomberie d'ouverture de
document, dont les surfaces suivantes profiteront.

**Ce que le serveur fait déjà.** Le joueur dépose sa pièce par
`submitContractStatusProof`, qui écrit sur `users/{uid}` :

| Champ de `contractStatusProof` | Écrit par | Contenu |
| --- | --- | --- |
| `status` | dépôt puis examen | `pending`, `approved` ou `rejected` |
| `fileUrl` | dépôt | `gs://<bucket>/identityDocuments/{uid}/contractProofs/contract_<ms>.(pdf\|jpg\|jpeg\|png)` |
| `submittedAt` | dépôt | horodatage serveur |
| `reviewedAt`, `reviewedBy` | examen | horodatage serveur, uid de l'opérateur |
| `reviewNote` | examen | motif, 400 caractères au plus |
| `approvedContractStatus` | examen favorable | `free`, `under_contract`, `on_loan` ou `amateur` |
| `approvedContractEndDate` | examen favorable | exigé quand le statut est `under_contract` ou `on_loan` |

La projection publique ne publie le statut que si la pièce est approuvée **et**
que le statut saisi aujourd'hui est celui que l'examen a couvert, date de fin
comprise. Un joueur qui change de statut après coup perd donc l'affichage, ce
qui est voulu : l'approbation ne sert pas de caution à une déclaration que
personne n'a lue.

**Le callable à brancher.** `reviewContractStatusProof`, déjà déployable,
refuse tout appelant sans claim admin.

```dart
// lib/services/admin_content_service.dart, même forme que setOfferStatus
Future<AdminActionResponse> reviewContractStatusProof({
  required String uid,
  required String status,          // 'approved' | 'rejected'
  String? contractStatus,          // exigé si status == 'approved'
  DateTime? contractEndDate,       // exigé si le statut attend une date
  String? note,                    // 400 caractères au plus
});
```

Le serveur refuse : un verdict autre que ces deux valeurs, une approbation sans
`contractStatus` dans la liste fermée, une approbation d'un statut qui attend
une date sans date résoluble, un motif trop long, et un joueur qui n'a déposé
aucune pièce.

**Ouvrir la pièce.** `storage.rules` autorise la lecture de
`identityDocuments/{uid}/contractProofs/{fileName}` au propriétaire et à
l'administration, et **jamais à un recruteur vérifié**, contrairement à la
photo de passeport qui partage le même dossier. Ce portail n'ouvre aujourd'hui
aucun document : `lib/widgets/admin_profile_review.dart` affiche seulement
« Présent » ou « Absent » pour le CV et le passeport. C'est donc de la
plomberie neuve, à écrire une fois et à réutiliser : lire la référence `gs://`,
la convertir en référence Storage, obtenir une URL de lecture avec le claim
admin, ouvrir dans un onglet.

**Où ça se branche.** Un nouvel onglet en fin de liste, groupe `Modération`, ou
un panneau dans `admin_profile_review.dart` si vous préférez l'attacher à la
fiche. Un onglet vaut mieux : la file se traite en lot, pas profil par profil.
Requête : `users` où `contractStatusProof.status == 'pending'`, triée par
`contractStatusProof.submittedAt`.

**Catalogue.** Ajouter l'entrée, et c'est à ce moment-là que
`reviewContractStatusProof` entre dans la liste requise du contrôle de contrat
du dépôt mobile (`scripts/check-admin-mobile-contract.ps1`) : un callable n'y
entre qu'une fois le portail doté d'une interface qui l'appelle. La même règle
vaudra pour `endClubLink` avec la surface 2.

**Charge : 1,5 à 2 jours**, dont une demi-journée pour l'ouverture de document.

## 2. File des exceptions du rattachement (lot L4)

**Ce qui casse sans elle.** Une contestation gèle l'état public et attend une
décision humaine. Sans écran, elle attend indéfiniment et le joueur n'a aucune
réponse. Même chose pour deux clubs qui déclarent le même joueur, et pour les
rattachements à réexaminer après une révocation d'habilitation.

**La collection.** `player_club_links`, lisible par le joueur concerné, le club
déclarant et l'administration ; **aucune écriture cliente n'est permise**, tout
passe par les callables du dépôt mobile.

| Champ | Contenu |
| --- | --- |
| `id`, `clubUid`, `clubName`, `playerUid` | identité du rattachement |
| `status` | `declared`, `confirmed`, `contested`, `ended` |
| `declaredFacts` | ce que le club a saisi, en quarantaine |
| `confirmedFacts`, `corrections` | ce que le joueur a accepté, et ce qu'il a corrigé |
| `declaredUnderAgreementRef` | référence de l'accord sous lequel la déclaration a été faite |
| `declaredAt`, `confirmedAt`, `contestedAt`, `endedAt` | horodatages |
| `contestReason` | motif écrit par le club ou le joueur |
| `reviewRequired` | posé par la cascade de révocation |

Les index composites nécessaires sont déjà déclarés dans le dépôt mobile :
`clubUid + status + declaredAt`, `playerUid + status`, `status + updatedAt`.

**Les trois files à montrer :** `status == 'contested'` par date ;
`reviewRequired == true` pour les suites de révocation ; et les doublons, soit
deux rattachements ouverts sur le même `playerUid`, qui se détectent en lisant
`playerUid + status` sur les états ouverts.

**L'arbitrage qui existe déjà, et celui qui n'existe pas.** `endClubLink`
accepte un appelant administrateur, reconnu à son claim signé, à côté du joueur
et du club déclarant :

```dart
Future<AdminActionResponse> endClubLink({required String linkId});
```

Il passe le rattachement en `ended`, enregistre `endedBy`, et retire
`currentClubName` et `clubAffiliation` de la fiche du joueur. Les faits
sportifs lui restent : son poste et sa nationalité ne changent pas parce qu'il
a quitté un club. Le callable refuse un rattachement déjà clos.

C'est donc l'issue dont le portail dispose pour trancher une contestation ou un
doublon : clore. **Ce qu'aucun callable ne permet, c'est de confirmer à la
place du joueur**, et c'est volontaire, `confirmClubLink` exigeant
`playerUid == uid`. Un doublon se résout en closant le rattachement de trop,
pas en validant l'autre d'office.

Ne pas inventer d'écriture directe sur la collection : elle est fermée aux
clients, et le portail en est un de ce point de vue.

**Charge : 3 à 4 jours**, les trois files en lecture plus l'action de clôture.

## 3. Vidéos en attente du consentement du joueur (lot L5)

**Ce qui casse sans elle.** `adminSetVideoStatus` refuse désormais d'approuver
une vidéo de club que le joueur n'a pas acceptée. L'opérateur verra un refus
qu'aucun écran n'explique, et conclura à une panne.

Le refus exact, dans `functions/src/admin_content_actions.ts` :

> « Le joueur concerné n'a pas encore accepté la publication de cette vidéo. »

**Les champs, sur le document `videos/{id}`.**

| Champ | Contenu |
| --- | --- |
| `playerUid` | le joueur montré, absent quand l'auteur est le sujet |
| `playerConsentRequired` | `true` sur un dépôt de club |
| `playerConsentDecision` | `accepted` ou `refused` |
| `playerConsentAt` | horodatage de l'acceptation, `null` si refus |
| `playerConsentDecidedAt` | horodatage de la décision, quelle qu'elle soit |

L'approbation est refusée tant que `playerConsentRequired == true` et
`playerConsentAt == null`. Une vidéo que le joueur a déposée lui-même n'est pas
concernée : son consentement est acquis par construction.

**Ce qu'il faut faire ici.** `lib/models/video.dart` de ce dépôt ne porte
aucun de ces champs : les ajouter en lecture. Puis, dans
`video_review_widget.dart`, afficher l'état du consentement et **désactiver
l'approbation** avec sa raison plutôt que de laisser l'opérateur buter sur le
refus serveur. Montrer aussi le joueur montré, qui n'est pas l'auteur.

**Charge : 1 à 2 jours.**

## 4. Signalements de coordonnées (lots L1 et L7)

Le serveur retire les numéros et les adresses des champs libres avant
publication, et consigne ce qu'il a retiré. Personne ne le lit. Deux sources,
deux formes :

**Les profils.** Sur `users/{uid}` : `contactLeakFlagged` (booléen) et
`contactLeakFields` (liste des champs concernés). Le document interne garde la
valeur saisie, donc l'opérateur voit ce que l'utilisateur a voulu publier en
lisant le champ lui-même.

**Les offres et les événements.** Collection `contact_leak_reports`, un document
par document signalé, identifiant `{collection}__{docId}` :

| Champ | Contenu |
| --- | --- |
| `collection` | `offres` ou `events` |
| `docId` | identifiant du document nettoyé |
| `ownerUid` | auteur de l'annonce |
| `fields` | champs concernés, triés, y compris les clés du bloc d'auteur comme `recruteur.email` |
| `originals` | le texte d'origine, c'est-à-dire exactement ce qui a été retiré de la surface publique |
| `flaggedAt` | horodatage |

Un signalement par document et non par écriture : une offre corrigée trois fois
produit une ligne mise à jour, pas trois lignes à trier.

**Prérequis : la ligne de règle en tête de ce document.** Sans elle, la lecture
est refusée au portail.

**Charge : 1 à 1,5 jour.**

## 5. Téléversement de l'accord signé

L'habilitation d'un club porte la référence de l'accord (`agreementRef`), mais
le document lui-même n'a aucun chemin d'arrivée. `storage.rules` prévoit déjà
`clubAgreements/{clubUid}/{fileName}`, en lecture et en écriture
**administration seule** : le club n'y accède pas, volontairement, parce que
c'est un acte signé entre deux parties et non une pièce que son propriétaire
dépose.

À brancher dans `club_enrollment_dialog.dart`, à côté de la saisie de la
référence et du terme. **Charge : 1 jour.**

## 6. État d'habilitation dans la liste des utilisateurs

`user_management_widget.dart` change déjà le libellé de l'action selon
`clubEnrollment.active` (« Habiliter le club » ou « Habilitation du club »),
mais rien n'affiche l'état ni son terme. Repérer un club dont l'habilitation
expire demande d'ouvrir chaque ligne.

Une puce dans `lib/widgets/admin_account_status_chips.dart`, avec le terme :
le modèle miroir `lib/models/club_enrollment.dart` porte déjà `granted`,
`validUntil`, `agreementRef` et sait dire `activeAt` et `expiredAt`. **Charge :
0,5 jour.**

## 7. Comptes de support pour la messagerie en étoile (lot L6)

Le mode médiatisé lit `config/messaging` : `mediatedOnly` (booléen) et
`supportUids` (liste d'identifiants). Le document est lisible par tous les
clients et **écrit par le serveur seul**. Sans compte nommé, activer le mode
ferme toute la messagerie : c'est le bon échec, mais pas un état utilisable.

Deux options : un petit écran qui écrit par un callable à créer dans le dépôt
mobile, ou une procédure console documentée dans le runbook. La seconde suffit
pour un pilote. **Charge : 0,5 jour.**

## Ce qui n'est plus à faire, contrairement au plan du 18 novembre

- **Le consentement du représentant légal est déjà faisable**, et pas seulement
  à la création du compte : `managed_profile_edit_dialog.dart` envoie
  `guardianConsent` et `updateManagedAccountProfile` l'enregistre sur un compte
  existant, en posant `minorProfileApproved` et `minorMediaConsentApproved`.
  C'est exactement ce qu'il faut quand un club déclare un mineur. Il ne reste
  que la pièce justificative et la visibilité de qui attend. **0,5 jour au lieu
  de 2 à 3.**
- L'état d'habilitation dans la liste est plus petit que prévu, le modèle étant
  déjà lu.

## Total et ordre conseillé

Neuf à douze jours. L'ordre : 1, puis 3, puis 2, puis 4 à 7 dans l'ordre que
vous voulez. La surface 1 d'abord parce qu'elle débloque un lot entier et écrit
l'ouverture de document ; la 3 ensuite parce qu'elle évite un faux diagnostic
de panne dès le premier dépôt de club ; la 2 après, parce qu'elle est la plus
longue et qu'elle peut commencer en lecture seule.

## Garde-fous à écrire en même temps que les écrans

Le dépôt mobile a quatre fois livré une capacité serveur que rien n'atteignait,
et ses garde-fous ne l'ont pas vu parce qu'ils vérifiaient la **présence** du
code, pas son **accessibilité** : un test disait
`expect(repository, contains('submitProfileForReview('))` et serait resté vert
pour toujours. À ne pas reproduire ici.

Pour chaque surface, un test qui exerce l'**appelant** :

- l'entrée de catalogue existe et porte `isConnectedInUi: true` ;
- la méthode du service envoie bien le nom du callable et la charge utile
  attendue, `admin_content_service_test.dart` donne la forme ;
- l'écran est monté dans `_widgetOptions()` et son item dans `_dashboardItems`,
  **ajouté en fin de liste** ;
- l'action est désactivée quand le serveur la refuserait, et dit pourquoi :
  c'est la leçon de la surface 3.

Et avant chaque livraison, depuis le dépôt mobile :

```powershell
npm run contract:admin-mobile:check
```

Ce script détecte seul le chemin de ce dépôt. Il doit sortir vert avant et
après.
