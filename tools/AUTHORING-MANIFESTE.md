# Le manifeste d'enregistrement

Format lu par `tools/enregistrer.mjs`. Reconstitué depuis le code de l'outil le
25 août 2026 — il vivait jusque-là dans un scratchpad hors dépôt, invisible aux
sessions qui en avaient besoin.

## Pourquoi

Écrire des gares en parallèle, c'est se disputer cinq fichiers partagés :
`data/stations/index.json`, `js/geo.js`, `data/lines.js`, `data/places.js` et
`data/cartes/europe.json`. Deux sessions qui les éditent en même temps se
volent leurs modifications.

Personne ne les touche donc à la main. Chaque session écrit **ses fiches**
(`data/stations/<pays>/<id>.json`, un fichier bien à elle) et **un manifeste**
qui décrit ce qu'il faut inscrire ailleurs. `enregistrer.mjs` applique les
manifestes, seul, dans l'ordre.

Deux propriétés qui comptent :

- **Tout ou rien.** À la moindre erreur, l'outil imprime la liste et n'écrit
  aucun fichier (code de sortie 1). On ne se retrouve jamais à moitié enregistré.
- **Idempotent.** Une fiche déjà présente dans l'index est passée sans bruit.
  Rejouer un manifeste est sans danger.

L'outil **ne valide rien** du contenu de jeu : c'est le travail de `gen-check`,
`net-check`, `graph-check` et `carte-check`, dont il imprime les commandes à la
fin de son passage.

## Le format

Un manifeste est un fichier JSON. Toutes les clés sont facultatives — on ne met
que ce que la session a réellement produit.

```json
{
  "pays_nouveau": { "slug": "autriche", "name": "Autriche", "flag": "🇦🇹", "iso": "AT" },

  "fiches": [
    { "id": "linz",  "pays": "autriche", "lonlat": [14.2858, 48.2903] },
    { "id": "wels",  "pays": "autriche", "lonlat": [14.0239, 48.1667] }
  ],

  "places": { "amstetten": [14.8722, 48.1225] },
  "places_a_retirer": ["stpoelten"],

  "lines_js": [
    { "id": "at-westbahn", "name": "Vienne – Salzbourg",
      "nodes": ["wien", "stpoelten", "amstetten", "linz", "wels", "salzburg"] }
  ],

  "hub": "linz",

  "ligne": { "de": "wien", "vers": "salzburg" },
  "composition": ["stpoelten", "linz", "wels"]
}
```

### `pays_nouveau`

`{ slug, name, flag, iso }`. Crée le bloc du pays dans `index.json` (libellé
`<flag> <name>`) et dans `js/geo.js` (inséré juste avant le Royaume-Uni,
dernier pays écrit à la main), avec un `cities` vide que les fiches remplissent.
Sans effet si le pays existe déjà. Obligatoire dès qu'une fiche cite un `pays`
inconnu — sinon l'enregistrement échoue sur « pays inconnu ».

### `fiches`

`[{ id, pays, lonlat: [lon, lat] }]`. Pour chacune :

- la fiche `data/stations/<pays>/<id>.json` doit **exister** et porter le même
  `id` — l'outil le vérifie et refuse sinon ;
- l'id entre dans le bloc de son pays dans `index.json`, **à la fin** — la
  position dans l'index est la progression, à revoir à la main si l'ordre
  compte ;
- `lonlat` entre dans `countries.<pays>.cities` de `js/geo.js`. Une fiche sans
  `lonlat` est une erreur ;
- la clé de point de passage correspondante est **retirée** de
  `data/places.js` : une gare devenue jouable cesse d'être un lieu, sans quoi
  `net-check` la signale orpheline. La clé est dérivée de l'id (accents
  supprimés, minuscules, alphanumérique seulement).

L'ordre `lonlat` est **[longitude, latitude]**, comme partout dans `geo.js`.

### `places` et `places_a_retirer`

`places` : `{ clé: [lon, lat] }`, les points de passage nouveaux, ajoutés en
tête de `PLACES`. Une clé déjà définie est laissée telle quelle.
`places_a_retirer` : les clés devenues inutiles, en plus de celles que les
fiches emportent automatiquement.

### `lines_js`

`[{ id, name, nodes: [...] }]` — les lignes **réelles** de `data/lines.js`, qui
servent au tracé du réseau. Au moins deux nœuds. Une ligne de même `id` est
**remplacée** (c'est ainsi qu'on allonge une ligne existante), une nouvelle est
ajoutée à la fin.

### `hub`

L'id d'un hub de `data/cartes/europe.json`. La **première** fiche du manifeste
devient la gare que ce hub fait jouer (`hub.gare` reçoit son `city`, à défaut
son `name`). Le hub doit exister sur la carte.

### `ligne` + `composition`

`ligne: { de, vers }` désigne une ligne de la carte (dans un sens ou l'autre) ;
`composition` est la suite des gares qui la peuplent, **du `de` vers le `vers`**.
L'outil remet la liste dans le sens de la carte si besoin.

Toutes les gares citées doivent déjà être à l'index — ou être enregistrées par
le même passage. Une composition qui cite une gare inconnue fait échouer
l'ensemble.

## Le passage

```sh
node tools/enregistrer.mjs scratch/linz.json          # un manifeste
node tools/enregistrer.mjs scratch/autriche/          # tous ceux d'un dossier, par ordre alphabétique
```

Avant d'enregistrer, chaque fiche se valide seule, sans toucher à l'index :

```sh
node tools/gen-check.mjs --fiche=data/stations/autriche/linz.json
```

Après, l'outil imprime la liste exacte des contrôles à repasser — et ils sont
obligatoires avant commit (voir `AUTHORING-STATIONS.md` §6 pour la règle des
deux balayages).
