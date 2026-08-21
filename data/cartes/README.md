# Les cartes

Une carte = un fichier JSON autonome, `<id>.json`, listé dans `index.json`.
Schéma et règles de construction : `meta-progression-jeu-aiguillage.md` (§3 et
§8). Chargement : `js/cartes.js` ; lecture : `js/graph.js`.

```
{ id, nom, gratuite, prixCredits?, sousTitre, echelle: { kmMinEntreHubs },
  zones:  [{ id, nom, couleur }],
  hubs:   [{ id, nom, zone, ll: [lon, lat], rang: 1|2, gare?, versions? }],
  lignes: [{ de, vers, type?: "rail"|"mer", gares: [ficheId…], note? }] }
```

- `hub.gare` est le **nom** de la fiche du catalogue (`name` ou `city`), pas
  son id : c'est `buildGraphe` qui fait la correspondance. Un hub sans `gare`
  n'est pas encore jouable.
- `ligne.gares` est **ordonnée de `de` vers `vers`**, dans l'ordre du rail ; la
  ligne se parcourt dans les deux sens. Vide = ligne pas encore écrite.
- `ll` sert au tracé et au calcul des écartements ; ce n'est pas une position
  d'affichage, le plan de métro s'autorise à déplacer les nœuds.
- `rang` : 1 = hub continental (4 à 6 sorties), 2 = hub régional (3 sorties).
- `versions` : une par sortie, `{ vers, gare, nom }` — quand les versions d'un
  hub sont des gares réelles distinctes (Londres, Paris). Sinon les PROFILS de
  js/graph.js s'appliquent.

## L'Europe — ce qui a décidé de la liste des hubs

Trois mesures, faites avant d'écrire une ligne :

1. **Un hub est un croisement.** La difficulté d'une gare n'est pas un réglage
   libre : elle EST la taille de son croisement (sur 145 gares, une difficulté
   1 a 3,9 directions et 4,6 quais en moyenne, une difficulté 5 en a 6,4 et
   9,8). On ne « promeut » donc pas une petite gare — on choisit les grandes.
2. **Il faut de la place entre deux hubs.** Une ligne de quatre à neuf gares
   suppose 250 à 400 km. En dessous de 110 km il n'y a plus de quoi y glisser
   une gare : le hub est redondant. Seize l'étaient (Malmö à 28 km de
   Copenhague, Cardiff à 41 de Bristol) et ont été retirées. Deux exceptions
   assumées : Lille (94 km de Bruxelles, carrefour Eurostar/TGV) et Stuttgart
   (107 km de Strasbourg, avec une frontière entre les deux).
3. **Les zones doivent s'équilibrer.** La première version allait de 6 hubs
   pour l'Italie à 13 pour la France. On a COMBLÉ plutôt que rogné ; l'écart est
   tombé de 2,2 à 1,86 pour 1.

Les lignes `mer` sont les traversées sans alternative ferroviaire, et qui sont
pourtant la façon dont on voyage vraiment : Helsinki–Tallinn, Dublin–Holyhead,
Durrës–Bari, le tunnel sous la Manche. Les taire laisserait des hubs orphelins.

Les lignes ont été remplies par `node tools/corridors-propose.mjs --js` à graine
fixe, sous deux contraintes : **rester sur la même ligne réelle** (Bruxelles–
Luxembourg passe par Namur, pas par le Hainaut) et **la sinuosité avant la
longueur** (plafond 1,5 × le vol d'oiseau, sinon Montpellier–Toulouse passait
par Paris). Une gare n'appartient qu'à une ligne.
