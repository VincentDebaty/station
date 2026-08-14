"use strict";
// ------------------------------------------------------------------
// Couche RÉSEAU de la carte — un seul réseau européen, à niveau de détail
// variable (LOD), du continent jusqu'à la desserte locale.
//
// Deux sortes de nœuds, tous à leur VRAIE position géographique :
//   • les gares JOUABLES (catalogue) — pastille numérotée, cliquable ;
//   • les POINTS DE PASSAGE (data/places.js) — jamais dessinés. Ils n'existent
//     que comme géométrie : c'est par eux que le tracé d'une ligne épouse la
//     voie au lieu de tendre une corde. La carte ne montre que le réseau
//     jouable ; une ville qu'on ne peut pas prendre en main n'y a pas sa place
//     (tools/AUTHORING-STATIONS.md §0).
// Les arêtes viennent de js/network.js, donc des fiches elles-mêmes.
//
// Principe de rendu, celui des cartes en ligne :
//   - les ARÊTES vivent dans le SVG, en unités de projection. Zoomer ne les
//     recalcule pas : le navigateur les transforme, et `non-scaling-stroke`
//     garde l'épaisseur du trait constante à l'écran.
//   - les NŒUDS et les LIBELLÉS vivent dans l'overlay HTML. Ils sont créés UNE
//     fois puis seulement repositionnés (`transform`) — jamais recréés pendant
//     un geste, sinon le pincement saccade.
//   - chaque nœud porte une échelle d'apparition. Sous ce seuil il n'existe pas
//     à l'écran ; au-dessus, son libellé s'affiche s'il trouve la place.
//
// Les seuils sont en PIXELS PAR UNITÉ de projection (2000 unités = tour du
// monde). Repères mesurés sur un écran de 1400 px : monde ≈ 0,7 · Europe ≈ 5 ·
// France ≈ 19 · Belgique ≈ 60.
// ------------------------------------------------------------------

const MAPNET = {
  built: false, gEdges: null, layer: null,
  nodes: [], edges: [], measured: false, detail: null
};

// Les 46 gares jouables ne SATURENT pas une vue d'Europe tant qu'elles y sont
// dessinées comme des points — ce sont les libellés qui encombrent, pas les
// nœuds. On les montre donc presque toutes très tôt, et on échelonne surtout
// les NOMS et les villes secondaires.
const LOD = {
  hub: 1.8,        // grands nœuds : dès qu'on distingue l'Europe
  city: 3.2,       // les autres gares jouables
  hubLabel: 2.6,   // leur nom
  cityLabel: 7,    // le nom des autres
  HUBS: 14         // combien de gares comptent comme « grands nœuds »
};

// Écart minimal entre deux points à l'écran : 1 cm (l'unité CSS vaut toujours
// 96/2,54 px, indépendamment de la densité de l'écran). En deçà, le point le
// moins relié s'efface — c'est ce qui empêche un pays dense de se réduire à une
// tache quand on le regarde de loin.
const MIN_SEP = 96 / 2.54;

// Diamètre de la pastille par difficulté (1 → 5), en pixels à pleine échelle,
// et le facteur appliqué à chaque palier de zoom. Ces valeurs vivent ICI et
// seules : le CSS les reçoit en variables (--d, --k), et le modèle de collision
// s'en sert tel quel. Deux barèmes séparés finiraient par diverger.
const DOT_D = [0, 13, 16, 19, 23, 27];
const DETAIL_K = { far: 0.56, mid: 0.8, near: 1 };
// L'étoile du service PARFAIT, posée DANS la pastille. Même silhouette que le
// « Parfait » de la fiche ; en SVG et non en glyphe ★, pour qu'elle reste nette
// de 13 à 27 px sans dépendre d'une police. `currentColor` = la couleur de
// texte de la pastille, soit le fond sombre de la carte : creusée dans l'or.
const STAR_SVG = '<svg class="pf" viewBox="0 0 100 100" aria-hidden="true">' +
  '<polygon fill="currentColor" points="50,2 61,36 98,36 68,58 79,92 50,71 21,92 32,58 2,36 39,36"/></svg>';

// Apparence des pastilles selon l'échelle. Une gare n'a pas à s'afficher de la
// même façon vue d'Europe et vue de sa région : de loin un point menu, de près
// la pastille pleine et son nom. Trois habillages pour un seul élément — c'est
// le CSS qui bascule, via #map-net[data-detail].
function detailForScale(s) {
  if (s < 8) return "far";
  if (s < 17) return "mid";
  return "near";
}

function nameOfNode(id) {
  const c = (typeof cardOf === "function") ? cardOf(id) : null;
  return c ? (c.city || c.name) : id;
}

// ------------------------------------------------------------------
// LA LIGNE D'ARGENT SOUS UNE GARE — et le droit de se taire.
// ------------------------------------------------------------------
// Trois choses peuvent s'écrire là, et une seule à la fois :
//
//   • UN PRIX — mais seulement si l'argent est bien le dernier obstacle.
//     Payable tout de suite, c'est une offre (étiquette d'or vif) ; trop cher,
//     c'est un objectif (étiquette éteinte). Dans les deux cas la promesse est
//     tenue : réunis la somme et la gare s'ouvre.
//   • DEUX ÉTOILES — la gare ne s'achète pas avec de l'argent mais avec du
//     métier : il faut ★★ sur une voisine déjà tenue. Écrire un prix ici serait
//     mentir, l'effacer sans rien dire laisserait la gare inexpliquée.
//   • RIEN — le réseau ne tourne pas : une gare acquise attend son premier
//     service, et tant qu'elle attend plus rien ne se vend nulle part
//     (js/catalog.js). Douze prix barrés pour une seule cause commune seraient
//     douze fois le même bruit ; on les retire tous, et la gare qui respire
//     reste alors le SEUL repère monnayé de la carte. Elle dit d'elle-même où
//     aller.
//
// Et pour une gare acquise : ce qu'elle peut encore verser, en chiffre nu.
function capMoney(buyable, price, block, left) {
  if (!buyable)
    return left ? '<div class="pr earn">' + creditsHTML(left, true) + "</div>" : "";
  if (!block || block.kind === "argent")
    return '<div class="pr">' + creditsHTML(price) + "</div>";
  if (block.kind === "maitrise")
    return '<div class="pr need">★★</div>';
  return "";  // kind === "service"
}

// ------------------------------------------------------------------
// Construction — une fois, puis à chaque changement de progression.
// ------------------------------------------------------------------
function mapnetBuild() {
  if (typeof CATALOG === "undefined" || !CATALOG.length || !MAP.svg) return;
  const prog = (typeof getProgress === "function") ? getProgress() : {};

  // Calques : les arêtes SOUS les formes de pays ? Non — au-dessus, sinon la
  // terre les masque. Elles restent néanmoins sous l'overlay des pastilles.
  if (!MAPNET.gEdges) {
    MAPNET.gEdges = document.createElementNS(SVGNS, "g");
    MAPNET.gEdges.setAttribute("class", "lyr-net");
    MAP.svg.appendChild(MAPNET.gEdges);
  }
  if (!MAPNET.layer) {
    // Calque HTML de la carte, posé sur le SVG. Créé une fois : ses pastilles
    // ne sont jamais recréées pendant un geste, seulement repositionnées.
    MAPNET.layer = document.createElement("div");
    MAPNET.layer.id = "map-net";
    MAP.host.appendChild(MAPNET.layer);
  }
  MAPNET.gEdges.innerHTML = ""; MAPNET.layer.innerHTML = "";
  MAPNET.nodes = []; MAPNET.edges = []; MAPNET.measured = false;

  // --- Rang des gares : le DEGRÉ dans le réseau. Un carrefour se voit de loin,
  // une gare de bout de ligne se mérite. C'est la hiérarchie que dessine le
  // réseau lui-même, pas une liste écrite à la main.
  const ids = CATALOG.map(c => c.id);
  // Une gare OUVERTE et JAMAIS JOUÉE respire, toujours : c'est une invitation,
  // et c'est la seule chose que le joueur cherche sur la carte. Sans quoi elle
  // ne se distingue d'une gare déjà décrochée que par l'absence d'étoiles — une
  // information en creux, qui ne se voit pas.
  // Au premier lancement, cela revient à faire respirer toutes les portes
  // d'entrée : elles sont équivalentes, en désigner une seule serait mentir.
  const byDeg = ids.slice().sort((a, b) => netLinks(b).to.length - netLinks(a).to.length);
  const rankScale = {}, labelScale = {};
  byDeg.forEach((id, i) => {
    const hub = i < LOD.HUBS;
    rankScale[id] = hub ? LOD.hub : LOD.city;
    labelScale[id] = hub ? LOD.hubLabel : LOD.cityLabel;
  });
  const uOf = {};   // id/clé → position en unités de projection
  const byId = {};

  // --- Gares jouables.
  for (const slug in GEO.countries) {
    const country = GEO.countries[slug];
    // Numérotation : l'ordre de jeu DANS le pays (1 = la plus facile).
    const order = Object.keys(country.cities || {})
      .sort((a, b) => catalogIndexOf(a) - catalogIndexOf(b));
    order.forEach((id, i) => {
      const gi = catalogIndexOf(id);
      if (gi < 0) return;
      const card = CATALOG[gi];
      const lonlat = country.cities[id];
      const u = geoProject(lonlat[0], lonlat[1]);
      const rec = prog[id] || {};
      const stars = rec.stars || 0, best = rec.bestDelay;
      const unlocked = (typeof isUnlocked === "function") && isUnlocked(gi);
      // TROIS ÉTATS, JAMAIS DEUX. Avant la monnaie, tout ce qui n'était pas
      // acquis se ressemblait : le joueur ne pouvait pas distinguer ce qui
      // était à portée de bourse de ce qui ne l'était pas, et la carte restait
      // muette sur ce qu'il fallait pour avancer. Désormais une gare achetable
      // porte SON PRIX, en or ; une gare hors réseau reste sourde et sans prix.
      const buyable = !unlocked && typeof isBuyable === "function" && isBuyable(id);
      const price = buyable ? stationPrice(id) : 0;
      // CE QUI S'OPPOSE À L'ACHAT, LU UNE SEULE FOIS. La carte affichait un prix
      // sous toute gare de la frontière, y compris celles qu'aucune somme
      // n'ouvre aujourd'hui : on lisait douze offres, on en cliquait une, et on
      // tombait sur deux boutons éteints et une règle jamais annoncée. Un prix
      // est une PROMESSE ; il n'a le droit de s'afficher que si l'argent est
      // bien la seule chose qui manque.
      const block = buyable && typeof buyBlock === "function" ? buyBlock(id) : null;
      // « Prête » : achetable, payable, et rien d'autre ne s'y oppose (une gare
      // en souffrance, un palier pas atteint). C'est le seul état où le geste
      // est possible tout de suite — donc le seul qui a le droit de respirer.
      // (Exactement canBuy(), mais sans recalculer le blocage qu'on tient déjà.)
      const ready = buyable && !block;
      // CE QU'UNE GARE ACQUISE PEUT ENCORE RAPPORTER. Sans ce chiffre, la carte
      // ne répondait qu'à une moitié de la question : elle disait où dépenser,
      // jamais où gagner. Le joueur à court de crédits n'avait aucun moyen de
      // choisir sa gare à rejouer autrement qu'au souvenir.
      //
      // LE PROCHAIN PALIER, ET LUI SEUL. La carte comptait ce qui restait
      // jusqu'au plein tarif : une gare déjà à ★★★ n'affichait donc plus rien,
      // alors qu'il lui reste le sans-faute — le plus gros palier de tous.
      // Un total lointain ne se décide pas ; un pas suivant, si. Et c'est
      // exactement ce que la fiche montre en face, ligne par ligne.
      // Zéro = palmarès complet : on n'écrit alors RIEN. Un « +0 » sous chaque
      // gare finie serait du bruit, et son absence dit mieux ce qu'elle veut
      // dire — il n'y a plus rien à y chercher.
      const left = unlocked && typeof stationNextAmount === "function"
        ? stationNextAmount(id) : 0;
      // QUI RESPIRE : UNE SEULE CHOSE, ET C'EST UN SERVICE À ASSURER.
      // Une gare acquise qui n'a pas encore tourné — celle-là même qui bloque
      // tout achat tant qu'elle n'a pas servi (js/catalog.js). Rien d'autre.
      //
      // Les gares achetables ont pulsé un temps, elles aussi : à dix pastilles
      // qui battent, plus rien ne bat. Elles gardent leur étiquette de prix en
      // or vif, qui dit déjà « à portée » sans réclamer l'attention.
      const todo = unlocked && (typeof stationInService !== "function" || !stationInService(id));
      const isPulsing = todo;
      // Ce qui se joue MAINTENANT ne se cache derrière personne — qu'il s'agisse
      // d'un service à assurer ou d'une gare à ouvrir. La priorité d'affichage
      // et la pulsation sont deux choses distinctes : l'une décide qui reste
      // visible quand deux points se serrent, l'autre réclame le regard.
      const actionable = todo || ready;

      // La pastille ne porte plus son rang de jeu : sa TAILLE dit la difficulté
      // (petite en 1, grosse en 5). On lit d'un coup d'œil où sont les morceaux,
      // sans avoir à décoder une numérotation propre à chaque pays.
      const diff = Math.max(1, Math.min(5, card.difficulty || 1));
      // LE RÉSULTAT EST DANS LA PASTILLE, PAS À CÔTÉ. Chaque gare portait ses
      // étoiles et son record sous son nom : à treize gares belges à l'écran,
      // cela faisait trente cartouches de trois lignes, et la carte ne se lisait
      // plus. LA PASTILLE SE REMPLIT à la place : le point part creux, gagne un
      // cran de teal par étoile décrochée, et l'ÉTOILE se creuse dedans au
      // service parfait. Creux = tout reste à faire, plein = c'est gagné, et
      // l'étoile est le dernier cran d'un même mouvement plutôt qu'un ornement à
      // part. Le tout dans un point qu'on dessinait déjà, sans une ligne de
      // texte de plus.
      // Deux chemins ont été essayés avant : une échelle de COULEURS par étoiles
      // (ambre, puis teal → fuchsia) — lisible mais jamais belle, et elle sortait
      // de la palette ; puis le RECORD EN CHIFFRES dans la pastille — précis,
      // mais un nombre sans unité et sans sens de lecture se lit à l'envers (23
      // paraît meilleur que 1). Le remplissage n'a ni l'un ni l'autre défaut :
      // plus il y en a, mieux c'est, et ça se voit sans rien savoir.
      // La couleur ne dit donc RIEN du résultat : teal jouable, gris fermé.
      const perfect = best === 0;
      const el = document.createElement("div");
      el.className = "map-chip city-chip" + (unlocked ? "" : " locked") +
        (buyable ? " buyable" : "") + (ready ? " ready" : "") +
        (stars ? " s" + stars : "") + (perfect ? " perfect" : "") +
        (isPulsing ? " entry" : "");
      el.style.setProperty("--d", DOT_D[diff] + "px");
      el.innerHTML =
        // Pastille VIDE tant qu'aucune étoile n'est décrochée — jamais jouée ou
        // jouée sans rien ramener, c'est le même creux, et il se lit comme une
        // case à remplir. Un cadenas sur les gares fermées répétait le gris et
        // écrasait les petites gares, dont la pastille ne fait que 13 px en
        // difficulté 1.
        '<span class="dot">' +
          (perfect ? STAR_SVG : stars ? '<span class="fill"></span>' : "") + "</span>" +
        // UN CHIFFRE SOUS LE NOM, en or, et le SIGNE dit son sens : « 50 », ce
        // qu'il faut sortir pour ouvrir la gare ; « +120 », ce qu'elle peut
        // encore rapporter. Même monnaie, même couleur, deux directions — et la
        // pastille tranche déjà l'une de l'autre (cerne doré contre point teal).
        '<div class="cap"><div class="nm">' + (card.city || card.name) + "</div>" +
          capMoney(buyable, price, block, left) + "</div>";
      // Ce qu'on ne peut pas dire en trois caractères se dit au survol.
      if (block && block.kind === "maitrise")
        el.title = "Demande ★★ sur " + block.from.map(nameOfNode).join(" ou ");
      el.addEventListener("click", ev => { ev.stopPropagation(); openStationModal(gi); });
      MAPNET.layer.appendChild(el);

      const node = {
        key: id, kind: "station", u, el, cap: el.querySelector(".cap"),
        // minScale : la gare à jouer maintenant apparaît dès le premier zoom.
        // rank : le DEGRÉ, et lui seul. Sinon, vue d'Europe, la Belgique se
        // réduirait à Tournai (la prochaine à jouer) au lieu de Bruxelles.
        // Une porte d'entrée ne se cache jamais, et elle PRIME sur les
        // carrefours dans la règle du centimètre : au premier lancement, une
        // gare jouable vaut mieux qu'un hub verrouillé. Rang normal (le degré)
        // dès la première étoile décrochée.
        // Une gare à portée de bourse ne se cache jamais non plus : c'est
        // exactement ce que le joueur est venu chercher sur la carte.
        //
        // LE RÉSEAU ACQUIS PRIME SUR TOUT LE RESTE dans la règle du centimètre.
        // Une gare qu'on possède est ce qui explique la carte : c'est d'elle
        // que part la frontière d'achat. Effacée au profit d'un carrefour
        // verrouillé plus relié qu'elle, on voyait une gare achetable sans
        // comprendre pourquoi elle l'était — Dinant disparaissait derrière
        // Namur, et Libramont semblait ouverte sans raison.
        minScale: actionable ? 0 : rankScale[id],
        labelScale: actionable ? 0 : labelScale[id],
        // QUATRE RANGS, dans l'ordre où ils comptent pour le joueur : ce qu'il
        // peut faire MAINTENANT, ce qu'il possède, ce qu'il pourra acheter, le
        // reste. Le degré dans le réseau ne départage plus qu'à l'intérieur
        // d'un même rang — d'où la multiplication par la taille du catalogue,
        // qui garantit qu'aucun degré ne franchit une frontière de rang.
        //
        // Écrit d'abord en décalages négatifs, la hiérarchie s'inversait sans
        // qu'on le voie : une gare simplement achetable tombait à −125 et
        // évinçait une gare PAYABLE figée à −1. Aarschot, à 50 crédits et la
        // seule chose à faire sur la carte, disparaissait derrière Louvain à
        // 260 — le joueur en concluait qu'il n'avait rien à jouer.
        rank: (actionable ? 0 : unlocked ? 1 : buyable ? 2 : 3) * CATALOG.length + byDeg.indexOf(id),
        diff, diam: DOT_D[diff],
        capW: 0, capH: 0, capUp: false
      };
      MAPNET.nodes.push(node); uOf[id] = u; byId[id] = node;
    });
  }

  // --- Points de passage : aucun DOM, aucune pastille, aucun libellé. Ils
  // entrent quand même dans le graphe des nœuds parce que la CONTRACTION en a
  // besoin (voir plus bas) : sans nœud, un segment qui passe par eux n'aurait
  // pas de représentant et disparaîtrait au lieu de se contracter.
  const places = netPlaces();
  for (const key in places) {
    const u = geoProject(places[key].lonlat[0], places[key].lonlat[1]);
    const node = { key, kind: "way", u, el: null, cap: null, minScale: 0, rank: Infinity, diam: 0 };
    MAPNET.nodes.push(node); uOf[key] = u; byId[key] = node;
  }

  // --- Arêtes : la liste du réseau (data/lines.js via js/network.js). Chaque
  // segment relie deux points CONSÉCUTIFS d'une ligne réelle — jamais une gare
  // à une destination lointaine. Une arête s'allume quand ses deux extrémités
  // sont des gares décrochées ; un segment vers un lieu suit sa gare.
  const starsOf = id => (prog[id] || {}).stars || 0;
  const state = (ka, kb) => {
    const a = byId[ka], b = byId[kb];
    const sa = a && a.kind === "station" ? (starsOf(ka) > 0 ? 1 : 0) : -1;
    const sb = b && b.kind === "station" ? (starsOf(kb) > 0 ? 1 : 0) : -1;
    if (sa === 1 && sb === 1) return "lit";
    if (sa === 1 || sb === 1) return "half";
    return "";
  };
  for (const [ka, kb] of netEdges()) {
    const a = uOf[ka], b = uOf[kb];
    if (!a || !b) continue;
    const line = document.createElementNS(SVGNS, "line");
    line.setAttribute("class", "map-edge " + state(ka, kb));
    line.setAttribute("x1", a.x.toFixed(1)); line.setAttribute("y1", a.y.toFixed(1));
    line.setAttribute("x2", b.x.toFixed(1)); line.setAttribute("y2", b.y.toFixed(1));
    MAPNET.gEdges.appendChild(line);
    // Le seuil d'apparition d'un segment est celui du plus discret de ses deux
    // bouts : une desserte locale ne doit pas surgir avant son village.
    MAPNET.edges.push({
      el: line, a: byId[ka], b: byId[kb],
      minScale: Math.max((byId[ka] || {}).minScale || 0, (byId[kb] || {}).minScale || 0)
    });
  }

  MAPNET.built = true;
}

// Mesure RÉELLE des cartouches, une fois, après insertion : plus fiable que
// n'importe quelle estimation de largeur de texte (elle nous a déjà trompés).
function mapnetMeasure() {
  if (MAPNET.measured || !MAPNET.nodes.length) return;
  const drawn = MAPNET.nodes.filter(n => n.el);   // les points de passage n'ont pas de DOM
  for (const n of drawn) {
    n.el.style.visibility = "hidden";
    n.el.style.display = "";
    // Le cartouche a pu être MASQUÉ à l'image précédente (collision). Le mesurer
    // dans cet état donne 0 × 0, donc « ne chevauche rien » : le nom se poserait
    // alors n'importe où. On le rend d'abord à tous, puis on mesure.
    n.cap.style.display = "";
  }
  for (const n of drawn) {
    const r = n.cap.getBoundingClientRect();
    n.capW = r.width; n.capH = r.height;
  }
  for (const n of drawn) n.el.style.visibility = "";
  MAPNET.measured = true;
}

// ------------------------------------------------------------------
// Positionnement — appelé à CHAQUE changement de cadrage. Aucun DOM créé ici.
// ------------------------------------------------------------------
function mapnetPosition() {
  if (!MAPNET.built || !MAP.svg) return;
  const cw = MAP.svg.clientWidth, ch = MAP.svg.clientHeight;
  if (!cw || !ch) return;
  const vb = readVB();
  const scale = cw / vb[2]; // pixels par unité de projection (viewBox au rapport écran)

  // L'habillage change de palier → les cartouches changent de taille, donc les
  // mesures mises en cache ne valent plus. On les refait, une fois par palier.
  const detail = detailForScale(scale);
  if (detail !== MAPNET.detail) {
    MAPNET.detail = detail;
    MAPNET.layer.dataset.detail = detail;
    MAPNET.layer.style.setProperty("--k", DETAIL_K[detail]);
    MAPNET.measured = false;
  }
  const k = DETAIL_K[detail];
  for (const n of MAPNET.nodes) n.dotR = n.diam * k / 2;
  mapnetMeasure();

  // --- Nœuds visibles, dans l'ordre d'importance : c'est cet ordre qui décide
  // qui garde son libellé quand deux noms se disputent la même place.
  const M = 60; // marge : on positionne un peu au-delà du cadre (pas de « pop »)
  const vis = [];
  for (const n of MAPNET.nodes) {
    // `shown` doit être remis à faux à CHAQUE écarté, sinon un nœud sorti du
    // cadre garderait l'état de l'image précédente et ses arêtes resteraient.
    // `shown` remis à faux à CHAQUE écarté, sinon un nœud sorti du cadre
    // garderait l'état de l'image précédente. `rep` par défaut = lui-même : une
    // arête vers un point hors cadre doit continuer de sortir de l'écran.
    n.shown = false; n.rep = n;
    if (scale < n.minScale) { if (n.el) n.el.style.display = "none"; n.rep = null; continue; }
    const p = uToScreen(n.u.x, n.u.y);
    if (p.x < -M || p.x > cw + M || p.y < -M || p.y > ch + M) {
      if (n.el) n.el.style.display = "none";
      // Un point de passage hors cadre reste son propre représentant : la ligne
      // qui le traverse doit continuer de sortir de l'écran, pas s'interrompre.
      if (n.kind === "way") { n.sx = p.x; n.sy = p.y; }
      continue;
    }
    if (!n.el) { n.sx = p.x; n.sy = p.y; vis.push(n); continue; }
    n.el.style.display = "";
    // On écrase le transform CSS de .map-chip : il faut donc reprendre son
    // centrage (-50%, -50%) après la translation, sinon le point se pose par
    // son coin haut-gauche.
    n.el.style.transform = "translate(" + p.x.toFixed(1) + "px," + p.y.toFixed(1) + "px) translate(-50%,-50%)";
    n.sx = p.x; n.sy = p.y;
    vis.push(n);
  }
  vis.sort((a, b) => a.rank - b.rank);

  // --- ESPACEMENT MINIMAL entre points, dans l'ordre d'importance. Là où les
  // gares se serrent — la Belgique vue d'Europe — le carrefour reste seul et ses
  // voisines s'effacent ; zoomer les sépare puis les rend une à une. Sans ça,
  // treize gares belges forment une tache là où le réseau devrait se lire.
  // Le tri par rang fait que c'est toujours la PLUS reliée qui survit : à
  // l'échelle de l'Europe, il reste Bruxelles.
  // Les points de passage sont triés en DERNIER (rang infini) : ils n'évincent
  // jamais une gare, ne réservent aucune place, mais se contractent comme les
  // autres. Vue d'Europe, Ciney tombe sur Bruxelles avec Namur et Marloie, et le
  // maillage intérieur devient un point ; zoomé, plus rien ne l'évince et la
  // ligne du Luxembourg reprend le tracé de la vallée.
  const kept = [];
  for (const n of vis) {
    let tooClose = false;
    for (const k of kept) {
      if (Math.hypot(n.sx - k.sx, n.sy - k.sy) < MIN_SEP) { tooClose = true; n.rep = k; break; }
    }
    if (n.kind === "way") { if (!tooClose) n.rep = n; continue; }
    if (tooClose) { n.el.style.display = "none"; n.shown = false; continue; }
    n.shown = true; n.rep = n; kept.push(n);
  }

  // --- Arêtes : CONTRACTÉES sur les points retenus, jamais supprimées. Un point
  // effacé faute de place cède ses lignes à son représentant — le voisin retenu
  // qui l'a évincé. Vue d'Europe, les treize gares belges deviennent Bruxelles,
  // et ce qui les reliait au reste du continent aboutit à Bruxelles au lieu de
  // disparaître. Supprimer ces lignes vidait la carte ; les garder telles quelles
  // laissait un écheveau sur une tache. La contraction fait les deux : moins de
  // points, et le réseau reste entier.
  // Un segment dont les deux bouts se contractent sur le MÊME point devient un
  // point : c'est le maillage interne de la Belgique, et il n'a plus à se voir.
  const drawn = new Set();
  for (const e of MAPNET.edges) {
    const a = e.a && e.a.rep, b = e.b && e.b.rep;
    if (!a || !b || a === b || scale < e.minScale) { e.el.style.display = "none"; continue; }
    // Après contraction, plusieurs segments se superposent exactement : on n'en
    // garde qu'un, sinon un trait éteint se peindrait par-dessus un trait allumé.
    const key = a.key < b.key ? a.key + "|" + b.key : b.key + "|" + a.key;
    if (drawn.has(key)) { e.el.style.display = "none"; continue; }
    drawn.add(key);
    e.el.style.display = "";
    if (e.ra !== a || e.rb !== b) {
      e.ra = a; e.rb = b;
      e.el.setAttribute("x1", a.u.x.toFixed(1)); e.el.setAttribute("y1", a.u.y.toFixed(1));
      e.el.setAttribute("x2", b.u.x.toFixed(1)); e.el.setAttribute("y2", b.u.y.toFixed(1));
    }
  }

  // --- Libellés : placement glouton par ordre d'importance. Un nom qui ne
  // trouve pas de place disparaît — le point, lui, reste. C'est la règle des
  // cartes : jamais deux noms l'un sur l'autre, quitte à en taire un.
  // Les pastilles d'abord : un nom ne se pose jamais sur un point. On note le
  // PROPRIÉTAIRE de chaque pastille — sinon un libellé, collé sous son propre
  // point, se déclarerait en conflit avec lui et disparaîtrait aussitôt.
  // Chaque point a SA taille (la difficulté de la gare) : la boîte qui le
  // protège doit la suivre, sinon un gros nœud se fait écrire dessus.
  const boxes = kept.map(n => ({ x: n.sx, y: n.sy, w: n.dotR * 2 + 4, h: n.dotR * 2 + 4, owner: n }));
  for (const n of kept) {
    if (n.labelScale && scale < n.labelScale) { n.cap.style.display = "none"; continue; }
    const half = n.capH / 2, near = n.dotR + (n.kind === "station" ? 4 : 2);
    let placed = null;
    // Dessous puis dessus, centré puis décalé : neuf essais, on prend le premier
    // qui ne touche rien.
    for (const up of [false, true]) {
      for (const dx of [0, n.capW * 0.42, -n.capW * 0.42]) {
        const box = { x: n.sx + dx, y: n.sy + (up ? -(near + half) : near + half), w: n.capW, h: n.capH };
        if (box.x - box.w / 2 < 2 || box.x + box.w / 2 > cw - 2) continue;
        if (box.y - box.h / 2 < 2 || box.y + box.h / 2 > ch - 2) continue;
        if (boxes.some(b => b.owner !== n &&
                            Math.abs(box.x - b.x) * 2 < box.w + b.w &&
                            Math.abs(box.y - b.y) * 2 < box.h + b.h)) continue;
        placed = { box, up, dx }; break;
      }
      if (placed) break;
    }
    if (!placed) { n.cap.style.display = "none"; continue; }
    n.cap.style.display = "";
    // Exactement le décalage qui vient d'être testé : le cartouche est centré
    // sur le point, on l'en écarte de (dx, dy). Modèle et rendu ne peuvent plus
    // se contredire.
    n.cap.style.transform = "translate(-50%,-50%) translate(" +
      placed.dx.toFixed(1) + "px," + (placed.box.y - n.sy).toFixed(1) + "px)";
    boxes.push(placed.box);
  }
}

// La progression a changé (étoiles, déverrouillage) : reconstruire, puis replacer.
function mapnetRefresh() {
  mapnetBuild();
  mapnetPosition();
}
