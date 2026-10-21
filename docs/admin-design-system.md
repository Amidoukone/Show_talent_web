# Socle visuel du portail admin

Mis en place le 20 octobre 2026, en remplacement de la mise en page
« panneaux de verre » d'origine. Ce document décrit les règles à suivre
pour qu'un écran ajouté plus tard ressemble aux neuf autres.

Rien ici ne touche au contrat partagé avec le dépôt mobile : la refonte est
strictement présentation. Les contrôleurs, services, modèles miroirs et
callables sont inchangés.

## 1. Surfaces

Quatre niveaux pleins, une bordure d'un pixel, **aucune ombre portée**. La
hiérarchie se lit par la valeur du fond, pas par une lueur.

| Rôle | Token | Valeur |
| --- | --- | --- |
| Fond de page | `AdminTheme.background` | `#0E1114` |
| Zone en creux (en-tête de tableau, piste de jauge) | `surfaceSunken` | `#10151B` |
| Carte, panneau, barre d'outils | `surface` | `#141922` |
| Ligne survolée, menu, dialogue, fiche latérale | `surfaceRaised` | `#1A2029` |
| Filet par défaut | `border` | `#232B36` |
| Filet appuyé (élément actif, séparateur fort) | `borderStrong` | `#2E3A45` |

Règle de peinture : une carte qui clippe son contenu (`ClipRRect`) porte sa
bordure en `foregroundDecoration`, sinon l'en-tête en creux la recouvre aux
angles. Voir `AdminTable` et `AdminDetailPanel`.

## 2. Couleur

`AdminTheme.accent` (vert) désigne **une seule chose par écran** : l'action
primaire. Il n'est jamais décoratif.

Les couleurs d'état (`success`, `warning`, `danger`, `cyan`) ne signalent
qu'un état réel. Un compteur à zéro n'a rien à signaler : il reste gris.
Les compteurs de `AdminStatStrip` suivent cette règle — `tone` n'est passé
que lorsque la valeur mérite l'oeil.

## 3. Espacement et tailles

Une seule échelle, `AdminTheme.space1..space8` (4, 8, 12, 16, 20, 24, 32).
Ne pas réintroduire de 10/14/18/22 littéraux.

| Mesure | Token | Valeur |
| --- | --- | --- |
| Hauteur des contrôles de barre d'outils | `controlHeight` | 38 |
| En-tête de tableau | `tableHeaderHeight` | 40 |
| Ligne de tableau | `tableRowHeight` | 52 |
| Ligne de tableau vidéo (vignette) | — | 56, passé en `rowHeight` |
| Fiche latérale | `detailPanelWidth` | 440 |
| Rayons | `radiusSm` / `radiusMd` / `radiusLg` | 8 / 12 / 16 |

Tous les contrôles d'une barre d'outils partagent `controlHeight`, sinon la
barre paraît bancale.

## 4. Typographie

Deux polices, deux rôles : **Space Grotesk** pour les titres, **Public
Sans** pour tout le reste.

**Sept crans, pas un de plus** : 11, 12, 13, 15, 17, 22, 28. Le portail en
comptait treize (10, 10.5, 11.5, 12, 12.5, 13, 13.5, 14, 15, 17, 22, 28,
30), posés en dur sur soixante-seize `TextStyle` littéraux : deux textes de
même rôle n'avaient pas la même taille d'un écran à l'autre.

Chaque cran porte un rôle nommé dans `lib/theme/admin_type.dart` :

| Rôle | Taille | Usage |
| --- | --- | --- |
| `overline` | 11 | intitulé de colonne, titre de bloc, groupe de navigation — en capitales |
| `caption` | 12 | deuxième ligne d'une cellule, légende, aide |
| `label` / `labelStrong` | 12 | pastille d'état, libellé compact |
| `body` / `bodyStrong` | 13 | cellule de tableau, valeur de fiche, identité d'une ligne |
| `prose` | 13 | paragraphe à lire en entier, interligne 1,6 |
| `numeric` | 13 | nombre dans un tableau ou un compteur |
| `brand` | 15 | mot-marque « Adfoot » |
| `metric` | 28 | grand nombre d'un indicateur |

Les titres (15 `titleMedium`, 17 `titleLarge`, 22 `headlineMedium`, 28
`displaySmall`) restent dans `AdminTheme.buildTheme()` : eux doivent nommer
Space Grotesk, et `GoogleFonts` n'est pas constant.

`numeric` et `metric` portent `FontFeature.tabularFigures()`. Sans chiffres
à chasse fixe, une colonne de nombres se décale d'une ligne à l'autre parce
que le « 1 » est plus étroit que le « 8 ».

**Aucune taille en dur hors de `lib/theme/`** : un garde-fou refuse tout
`fontSize:` dans `lib/dashboard`, `lib/widgets` et `lib/screens`.

### Conventions de copie française

- Apostrophe typographique **’**, jamais l'apostrophe droite. Le portail
  mélangeait 642 des unes et 107 des autres, parfois dans la même phrase.
- Points de suspension **…**, jamais trois points.
- Espace insécable dans les guillemets d'un paragraphe susceptible de
  s'enrouler (`« Utilisateurs »`). Inutile sur les libellés
  courts, qui ne se coupent jamais — on s'épargne un caractère invisible
  qui rendrait le code introuvable à la recherche.

Un garde-fou verrouille les deux premières règles via deux marqueurs
fiables : une apostrophe droite dans une chaîne française doit être
échappée, et trois points collés à un délimiteur de chaîne sont une ellipse
mal écrite. Un `...spread` ne déclenche ni l'un ni l'autre.

## 5. Gabarit d'un écran de liste

Les neuf onglets suivent le même ordre, porté par `AdminWorkspace` :

```
[ barre de page : titre de l'onglet            (coquille) ]
[ avis éventuel                                           ]
[ barre d'outils : recherche | filtres | actions          ]
[ bande de compteurs cliquables                           ]
[ tableau (en-tête figé, seules les lignes défilent)      ]
[ pied de liste : 1-25 sur 128 · ‹ › · charger plus       ]
```

Points non négociables :

- **Seule la liste défile.** La barre d'outils et le pied restent en place.
  La coquille donne à chaque onglet une hauteur bornée ; un écran qui se
  place dans un `SingleChildScrollView` casse ce contrat (c'est ce que fait
  volontairement l'onglet Statistiques, qui est une surface de lecture et
  non une liste).
- **Un seul pied de liste.** `AdminListFooter` dit la position dans le jeu
  filtré *et* propose le chargement du lot suivant. Ne pas réempiler une
  barre de pagination et une barre « charger plus », qui se contredisaient.
- **Les compteurs filtrent.** Un compteur qui annonce « 3 accès suspendus »
  sans permettre de les voir oblige à les chercher à la main.
- En disposition compacte (`breakpointCompact`, 1120 px), le tableau cède
  la place à une liste de `AdminDataCard` et la page défile d'un bloc.

## 6. Actions

Modèle appliqué partout (`AdminRowActions`) :

- **Deux ou trois actions fréquentes en clair** sur la ligne, en icônes avec
  infobulle. Avant la refonte, toute action coûtait deux clics parce qu'elle
  vivait dans un `PopupMenuButton`.
- **Le reste sous « … »**, y compris les suppressions : une action
  destructrice ne doit pas être la plus facile à atteindre.
- Une action **temporairement** indisponible reste visible et désactivée
  (ex. « Approuver » pendant l'optimisation d'une vidéo) : l'opérateur voit
  qu'elle existe. Une action **structurellement** impossible est retirée du
  menu (ex. « Gérer les droits » sur un compte du portail) : la proposer
  reviendrait à promettre une opération que les callables refuseraient.
- Les boutons d'action de ligne portent
  `tapTargetSize: MaterialTapTargetSize.shrinkWrap`, sans quoi chacun
  réserve 48 px et la rangée déborde de sa colonne.

## 7. Fiche latérale plutôt que modale

`AdminDetailPanel` affiche un enregistrement à droite de la liste, avec
`‹ ›` pour enchaîner la file sans fermer. La ligne correspondante reste
marquée d'un filet vert dans le tableau.

Elle ne se pose à côté de la liste que si la zone de contenu fait au moins
`bodyMinWidth + detailPanelWidth` : chaque écran passe à `AdminWorkspace`
le même `bodyMinWidth` que celui donné à `AdminTable.minWidth`. En dessous,
la fiche prend toute la zone — une fiche collée à un tableau trop étroit
force la liste à défiler horizontalement et sort la colonne d'actions de
l'écran, exactement ce qu'on voulait éviter. En pratique, la vue à deux
colonnes demande un écran d'environ 1 700 px.

Les boîtes de dialogue restent pour les **décisions** (modifier un profil,
changer un rôle, saisir une note de certification), pas pour la
consultation.

## 8. Navigation

Les neuf onglets sont regroupés en quatre blocs métier (Communauté,
Modération, Activité, Analyse) dans `admin_dashboard_screen.dart`. Les
index pointent toujours vers `_dashboardItems` : l'ordre des onglets et les
liens profonds de `app_routes.dart` sont inchangés, et
`AdminDashboardScreen.tabCount` reste la source unique du nombre d'onglets.

La déconnexion vit dans le pied du rail, avec l'identité de session. Elle
était auparavant un bouton vert plein répété en haut des neuf écrans —
l'élément le plus voyant de la page était celui qu'on veut presser le
moins.

## 9. Vocabulaire

Un concept, un mot. L'unification a d'ailleurs révélé que deux colonnes
disaient la même chose (voir plus bas).

| Concept | Le mot | À ne pas employer |
| --- | --- | --- |
| Signal de confiance affiché publiquement | **certifier**, certification, certifié | vérifier — déjà pris par l'e-mail vérifié, qui est autre chose |
| Connexion bloquée par un administrateur | **suspendre**, accès suspendu | désactiver, bloquer |
| Compte créé ou suivi par l'administration | **compte administré** | compte géré, créé par l'administration |

Les intitulés de colonne ne s'abrègent pas (« Candidats », « Places », et
non « Cand. », « Part. ») : une abréviation suivie d'un point dans un
en-tête fait économiser vingt pixels et coûte une hésitation.

**Deux axes distincts, deux colonnes distinctes.** « Confiance » ne parle
que de certification (`AppUser.profileTrustLabel`), « Statut » ne parle que
d'accès (`AdminAccountStatusChips`). Tant que l'un disait « Vérifié » et
l'autre « Profil certifié », la redondance passait inaperçue ; une fois le
même mot employé des deux côtés, elle sautait aux yeux sur la moitié des
lignes. Si une colonne se met à répéter l'autre, c'est qu'un des deux axes
a débordé sur le voisin.

## 10. Garde-fous

Trois tests verrouillent ces règles par lecture du code source :

- `test/admin_responsive_guardrails_test.dart` — les six écrans de liste
  passent bien par `AdminWorkspace` / `AdminToolbar` / `AdminListFooter`.
- `test/contact_intake_management_guardrails_test.dart` — les actions de
  suivi restent câblées au service partagé.
- `test/admin_text_quality_guardrails_test.dart` — pas de mojibake, pas de
  vocabulaire technique dans la copie visible, aucune taille de police en
  dur, une seule convention typographique.
- `test/private_contact_cache_test.dart` — le portail ne se réabonne pas à
  toute la base privée.

Les mettre à jour volontairement lorsqu'un composant change de nom ; ne pas
les supprimer.
