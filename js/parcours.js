"use strict";
// ------------------------------------------------------------------
// L'ÉCRAN DU RUBAN — la carte posée sur la gare en cours.
// ------------------------------------------------------------------
// Lot E (25 août 2026), §4 quater du document. L'enchaînement est celui que
// Vincent a décrit : on ouvre le jeu et la caméra est POSÉE SUR LA PROCHAINE
// GARE, mise en évidence, avec ses infos de base ; on appuie sur Continuer ;
// on joue ; le relevé tombe ; la caméra glisse le long du rail jusqu'à la
// gare suivante. Il n'y a jamais rien à choisir.
//
// UN SEUL CHAPITRE À L'ÉCRAN (revu le 25 août 2026, après le premier test).
// La première version montrait tout le ruban et cadrait sur la gare en cours :
// le reste du fil traînait autour, et le chapitre qu'on joue se retrouvait
// petit au milieu d'un continent. On ne dessine donc plus QUE le chapitre en
// cours, cadré pour remplir la scène — et les trois niveaux de caméra ont
// disparu avec lui, faute d'objet.
//
// La projection, elle, reste GLOBALE : passer d'un chapitre à l'autre déplace
// vraiment la caméra vers le nord ou vers l'est, et le voyage se sent. Le CSS
// fait le trajet (.monde, transition) ; un saut dure deux fois plus longtemps.
//
// LE FOND EST UN FOND, LE RUBAN EST LE SUJET. L'ancienne carte coloriait les
// pays par zone : sur un ruban, c'est le FIL qui porte la couleur, et le
// continent redevient ce qu'il doit être — de quoi savoir où l'on est.
// ------------------------------------------------------------------

const CARTE = {
  hote: null, bilan: null, voyage: null, prochaine: null,
  etoiles: null, cam: null, camAvant: null, fete: null, chapitre: null,
  chapitreAvant: null, feteAvant: false, transit: null,
  // LE PANNEAU ET LA CAMÉRA NE REGARDENT PLUS LE MÊME CHAPITRE pendant une fin
  // de chapitre : on lit le bilan de celui qu'on ferme (`chapitre`) pendant que
  // la carte, elle, a déjà rejoint le suivant (`voyageFait`). `minuteries` tient
  // les temps du voyage, pour pouvoir le couper net si le joueur clique avant.
  voyageFait: null, minuteries: null, bilanAvant: null
};
// La caméra met .75 s à traverser (1,5 s pour un saut, css/station.css). On
// laisse le voyage se voir avant d'ouvrir le niveau — sinon il se joue derrière
// l'écran de jeu et personne ne le regarde.
// DUREE_POSE (620 ms) est retirée le 1er septembre 2026 : c'était le temps
// mort entre l'arrivée du convoi et l'ouverture du niveau, et il n'y a plus de
// niveau à ouvrir au bout du voyage — le voyage se joue avant le clic.
const DUREE_VOYAGE = 1150, DUREE_SAUT = 1900;
const sansAnimation = () =>
  !!(window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches);

const RAD = Math.PI / 180;
const CADRE_L = 160, CADRE_H = 100;
const PAYS_HORS_CARTE = new Set(["ISL", "SJM", "FRO", "GRL"]);
const ETIREMENT_X = 1.6;   // l'Europe est plus haute que large : on l'élargit

function nomDe(id) { const c = cardOf(id); return c ? (c.city || c.name) : id; }
function villeDe(id) { const c = cardOf(id); return c ? (c.name || c.city) : id; }
function etoilesDe(id) { return ((getProgress()[id] || {}).stars) || 0; }
// UN SANS-FAUTE : zéro minute de retard, une fois. Le diamant s'empile sur les
// trois étoiles, il ne les remplace pas — mieux jouer ne rapporte jamais moins.
// C'est la seule mesure absolue du jeu : le barème des étoiles suit la
// difficulté de la gare (js/ruban.js, SEUILS), zéro reste zéro partout.
function estSansFaute(id) { return (getProgress()[id] || {}).bestDelay === 0; }
function coordDe(id) {
  if (typeof GEO === "undefined" || !GEO.countries) return null;
  for (const p of Object.values(GEO.countries)) {
    const ll = (p.cities || {})[id];
    if (ll) return ll;
  }
  return null;
}
// Quatre états, et ils s'excluent.
function etatDeGare(id) {
  if (!estEcrite(id)) return "avenir";
  if (estFaite(id)) return "faite";
  if (estPassee(id)) return "payee";
  const i = indexDe(id);
  return i >= 0 && i <= positionCourante() ? "courante" : "fermee";
}

// ------------------------------------------------------------------
// LA PROJECTION — cadrée sur le ruban, pas sur le continent.
// ------------------------------------------------------------------
// Une carte se cadre sur ce qu'elle montre. Le ruban ne traverse pour l'instant
// qu'une bande du continent : la cadrer sur l'Europe entière laisserait le fil
// tassé dans un coin. On prend donc la boîte des gares, élargie de moitié pour
// que le pays autour se voie.
let _proj = null, _projPour = null;
function projection() {
  const ordre = ordreDuRuban();
  if (_proj && _projPour === ordre.length) return _proj;
  let lo0 = Infinity, lo1 = -Infinity, la0 = Infinity, la1 = -Infinity;
  for (const g of ordre) {
    const ll = coordDe(g); if (!ll) continue;
    lo0 = Math.min(lo0, ll[0]); lo1 = Math.max(lo1, ll[0]);
    la0 = Math.min(la0, ll[1]); la1 = Math.max(la1, ll[1]);
  }
  if (!isFinite(lo0)) return null;
  const mx = Math.max(2, (lo1 - lo0) * 0.35), my = Math.max(1.5, (la1 - la0) * 0.30);
  lo0 -= mx; lo1 += mx; la0 -= my; la1 += my;
  const cosm = Math.cos((la0 + la1) / 2 * RAD);
  const s = Math.min((CADRE_L - 12) / Math.max((lo1 - lo0) * cosm * ETIREMENT_X, 1),
                     (CADRE_H - 12) / Math.max(la1 - la0, 1));
  _projPour = ordre.length;
  return (_proj = {
    X: lon => CADRE_L / 2 + (lon - (lo0 + lo1) / 2) * cosm * s * ETIREMENT_X,
    Y: lat => CADRE_H / 2 - (lat - (la0 + la1) / 2) * s,
    s
  });
}
function pos(id) {
  const P = projection(), ll = coordDe(id);
  return P && ll ? { x: P.X(ll[0]), y: P.Y(ll[1]) } : null;
}

// ------------------------------------------------------------------
// LA CAMÉRA. Trois niveaux, trois boîtes à cadrer.
// ------------------------------------------------------------------
function fenetreVisible() {
  const svg = CARTE.hote && CARTE.hote.querySelector(".c-graphe");
  let w = 0, h = 0;
  if (svg) { const r = svg.getBoundingClientRect(); w = r.width; h = r.height; }
  const a = w > 0 && h > 0 ? w / h : CADRE_L / CADRE_H;
  return a >= CADRE_L / CADRE_H ? { w: CADRE_H * a, h: CADRE_H } : { w: CADRE_L, h: CADRE_L / a };
}
// CE QUE LA BARRE DU HAUT MASQUE, en unités du cadre. Les compteurs (grade,
// crédits, diamants, étoiles) flottent au-dessus de la scène : la caméra
// cadrait sur toute la surface du SVG sans le savoir, et la dernière gare d'un
// chapitre vertical — Amsterdam au bout du Benelux — finissait sous eux, son
// nom illisible. On réserve donc la bande, et l'on cadre dans ce qui reste.
function bandeauHaut() {
  const svg = CARTE.hote && CARTE.hote.querySelector(".c-graphe");
  const hud = CARTE.hote && CARTE.hote.querySelector(".c-scene .c-compteurs");
  if (!svg || !hud) return 0;
  const r = svg.getBoundingClientRect();
  const s = Math.min(r.width / CADRE_L, r.height / CADRE_H);   // px par unité (meet)
  if (!(s > 0)) return 0;
  return (hud.getBoundingClientRect().height + 8) / s;
}
// LE PLAFOND DE ZOOM SE MESURE EN PIXELS, PAS EN UNITÉS. Le plafond fixe
// (6) avait été calé sur desktop pour « voir le pays autour » — mais une
// unité du cadre y fait ~41 px, contre ~20 sur un iPhone : au même k, le
// téléphone montre un timbre-poste. Mesuré le 28 août 2026 au simulateur,
// après le correctif du voisinage qui n'avait rien changé : le chapitre
// n'occupait que 36 % de la largeur, borné par kMax bien avant de remplir.
// Le plafond se relève donc jusqu'à garantir un plancher de lisibilité en
// pixels par unité de cadre — 48, relevé de 32 après le second retour (« ça
// reste petit, quitte à ne pas voir toute la ligne ») —
// sans effet sur desktop (déjà au-dessus), et borné par le remplissage.
const PX_PAR_UNITE_MIN = 48;
// LE ZOOM N'EST PLUS BRIDÉ (1er septembre 2026). Le cadrage forçait une boîte
// d'au moins 7 × 5 unités et un zoom d'au plus 6 : « La côte Est » tient dans
// 1,5 × 2,32, donc ses cinq gares occupaient 54 px de large dans une scène de
// 964 — 5,6 % — et Darlington se retrouvait à 24 px de Northallerton avec des
// étiquettes de 132 et 155 px. Aucune règle de placement ne rattrape ça : les
// noms étaient six fois plus larges que l'écart entre les points qu'ils
// nomment. Mesuré sur les 49 chapitres du ruban, le cadrage naturel demande un
// zoom de 10 à 179 : le plafond de 6 les sous-cadrait TOUS. Le seul plafond qui
// reste est un garde-fou contre une boîte dégénérée.
const K_MAX_CHAPITRE = 200;
function plafondZoom(base) {
  const svg = CARTE.hote && CARTE.hote.querySelector(".c-graphe");
  const px = svg ? svg.getBoundingClientRect().width : 0;
  if (!(px > 0)) return base;
  const parUnite = px / fenetreVisible().w;     // px par unité à k = 1
  return Math.max(base, PX_PAR_UNITE_MIN / parUnite);
}
function zoomPour(bw, bh, marge, kMax, inset) {
  const f = fenetreVisible();
  const utile = Math.max(20, f.h - (inset || 0));
  return Math.max(1, Math.min(plafondZoom(kMax), (f.w - 2 * marge) / Math.max(bw, 1), (utile - 2 * marge) / Math.max(bh, 1)));
}
function boite(ids) {
  let x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity;
  for (const g of ids) { const p = pos(g); if (!p) continue;
    x0 = Math.min(x0, p.x); x1 = Math.max(x1, p.x); y0 = Math.min(y0, p.y); y1 = Math.max(y1, p.y); }
  if (!isFinite(x0)) return null;
  return { x: (x0 + x1) / 2, y: (y0 + y1) / 2, w: x1 - x0, h: y1 - y0 };
}
// CE QUE LA CARTE MONTRE — pas forcément ce que le PANNEAU raconte. En fin de
// chapitre, le panneau tient le bilan de celui qu'on ferme (`CARTE.chapitre`)
// pendant que le convoi rejoint le suivant : c'est le NOUVEAU qu'il faut
// dessiner et cadrer, dès le départ du convoi et pas seulement à son arrivée.
// Sinon le train roule vers une gare qui n'est pas tracée — relevé au test :
// « on ne voit pas la gare suivante dans l'animation ». La gare QUITTÉE, elle,
// reste dessinée le temps du transit (voir garesHTML), pour que le convoi ne
// parte pas de nulle part.
// Rail, gares et caméra lisent tous les trois cette fonction — les séparer
// avait donné une carte vide, la caméra posée sur un chapitre que le rail ne
// dessinait pas.
function chapitreVu() {
  return (CARTE.transit && CARTE.transit.chapitre) || CARTE.voyageFait || CARTE.chapitre;
}

// La caméra que la vue courante demande.
// LE CHAPITRE EN COURS, CADRÉ POUR REMPLIR LA SCÈNE. Un seul niveau : c'est
// ce que le premier test réclamait — le chapitre qu'on joue doit occuper
// l'écran, pas flotter au milieu d'un continent.
function cameraVoulue() {
  // PENDANT LE TRANSIT, LA CAMÉRA RECULE. Voir d'où l'on part en même temps que
  // là où l'on va est ce qui fait comprendre qu'on a changé de chapitre ; elle
  // ne se posera sur le nouveau qu'une fois le convoi arrivé.
  // On cadre donc la gare QUITTÉE avec tout le chapitre qu'on rejoint. Cadrer
  // les deux seules gares du trajet ne marche pas : Bruxelles–Malines fait
  // 25 km, le minimum de zoom s'appliquait et le ruban devenait un timbre-poste
  // dans un coin.
  if (CARTE.transit) {
    const ch1 = chapitreVu();
    const bt = boite(ch1 ? [CARTE.transit.de].concat(ch1.gares) : [CARTE.transit.de, CARTE.transit.vers]);
    if (bt) {
      const inset = bandeauHaut();
      // Plus large que la pose sans qu'on ait à le forcer : la boîte contient la
      // gare quittée EN PLUS de tout le chapitre rejoint. Le resserrement final
      // se voit donc tout seul, et il suit le même barème.
      const k = zoomPour(bt.w, bt.h, 15, K_MAX_CHAPITRE, inset);
      return { x: bt.x, y: bt.y - inset / (2 * k), k };
    }
  }
  const ch = chapitreVu();
  // LE VOISINAGE, PAS LE CHAPITRE ENTIER. Cadrer les neuf gares du Roussillon
  // réduisait le tracé à un timbre-poste sur un téléphone — mesuré le 28 août
  // 2026, premier essai au simulateur iPhone : « tout est petit ». On cadre
  // donc la gare courante avec sa précédente et ses trois suivantes : un
  // chapitre court (≤ 5 gares) cadre exactement comme avant, un long retrouve
  // un vrai zoom, et la caméra voyage le long du rail à mesure qu'on avance —
  // ce qui est l'intention d'origine de ce fichier.
  let vues = ch && ch.gares;
  if (ch && ch.gares.length > 4) {
    const i = Math.max(0, ch.gares.indexOf(gareCourante()));
    const d = Math.max(0, Math.min(i - 1, ch.gares.length - 4));
    vues = ch.gares.slice(d, d + 4);
  }
  const b = ch && boite(vues);
  if (!b) return { x: CADRE_L / 2, y: CADRE_H / 2, k: 1 };
  // La marge du haut porte aussi les ÉTIQUETTES : le nom d'une gare est posé
  // au-dessus de son point, donc la dernière gare a besoin d'un peu plus de
  // ciel que de sol.
  const inset = bandeauHaut();
  // ON CADRE LE CHAPITRE, PAS LE PAYS. La borne d'avant protégeait le décor —
  // « voir le pays autour » — au prix de la seule chose qu'on doit pouvoir
  // lire : où l'on est sur le rail, et comment s'appellent ces gares.
  const k = zoomPour(b.w, b.h, 15, K_MAX_CHAPITRE, inset);
  // Le centre descend de la moitié de la bande réservée : le chapitre se pose
  // au milieu de ce qui reste visible, pas au milieu du SVG.
  return { x: b.x, y: b.y - inset / (2 * k), k };
}

// ------------------------------------------------------------------
// LE FOND — les pays, sans frontière et sans couleur.
// ------------------------------------------------------------------
let _fond = null;
function fondHTML() {
  if (_fond !== null) return _fond;
  const P = projection();
  if (!P || typeof WORLDMAP === "undefined" || !WORLDMAP.countries) return (_fond = "");
  const out = [];
  for (const c of WORLDMAP.countries) {
    if (c.cont !== "europe" || PAYS_HORS_CARTE.has(c.iso)) continue;
    const d = [];
    for (const r of c.r || []) {
      if (r.length < 8) continue;
      let s = "";
      for (let i = 0; i + 1 < r.length; i += 2)
        s += (i ? "L" : "M") + P.X(r[i]).toFixed(1) + " " + P.Y(r[i + 1]).toFixed(1);
      d.push(s + "Z");
    }
    if (d.length) out.push('<path class="pays" d="' + d.join(" ") + '"/>');
  }
  return (_fond = '<g class="fond">' + out.join("") + "</g>");
}

// ------------------------------------------------------------------
// LE RUBAN DESSINÉ.
// ------------------------------------------------------------------
function couleurDeZone(zid) {
  const z = typeof zoneById === "function" ? zoneById(zid) : null;
  return (z && z.couleur) || "#2dd4bf";
}
// SEUL LE CHAPITRE EN COURS EST DESSINÉ. Le reste du ruban existe, il est
// simplement hors sujet : on ne joue pas Hambourg quand on est en Ardenne.
function railHTML() {
  const ch = chapitreVu(), P = projection();
  if (!P || !ch || ch.gares.length < 2) return "";
  const g = ch.gares, col = couleurDeZone(ch.zone), segs = [];
  for (let i = 1; i < g.length; i++) {
    const a = pos(g[i - 1]), b = pos(g[i]);
    if (!a || !b) continue;
    const ecrit = estEcrite(g[i - 1]) && estEcrite(g[i]);
    const fait = estFranchie(g[i - 1]) && estFranchie(g[i]);
    // LE RAIL OÙ L'ON VA : le segment qui ABOUTIT à la gare courante. Il reste
    // allumé tant qu'on ne l'a pas parcourue — c'est le chemin qu'on s'apprête
    // à faire, et il ne doit pas s'éteindre une fois l'animation finie.
    // Déduit de la position sur le ruban, et non du relevé : sinon il
    // redeviendrait terne au moindre rechargement de la page.
    // `pathLength=1` rend le tracé indépendant de la longueur réelle, sinon un
    // segment de 200 km se dessinerait dix fois plus vite qu'un autre de 20.
    const avance = ecrit && !fait && g[i] === gareCourante();
    segs.push(`<path class="seg ${!ecrit ? "s-avenir" : fait ? "s-fait" : "s-reste"}${
      avance ? " s-avance" : ""}"${avance ? ' pathLength="1"' : ""}` +
      ` style="--col:${col};--i:${i - 1}" d="M${a.x.toFixed(2)} ${a.y.toFixed(2)}L${b.x.toFixed(2)} ${b.y.toFixed(2)}"/>`);
  }
  // LA LIAISON DE TRANSIT — le chemin d'un chapitre au suivant. Il n'appartient
  // à aucun des deux, d'où le pointillé : ce n'est pas une portion à jouer,
  // c'est ce qu'on traverse entre deux étapes.
  if (CARTE.transit) {
    const a = pos(CARTE.transit.de), b = pos(CARTE.transit.vers);
    if (a && b) segs.push(`<path class="seg s-transit${CARTE.transit.saut ? " s-saut" : ""}"` +
      ` style="--col:${col}" d="M${a.x.toFixed(2)} ${a.y.toFixed(2)}L${b.x.toFixed(2)} ${b.y.toFixed(2)}"/>`);
  }
  return '<g class="rail">' + segs.join("") + "</g>";
}
// LES SYMBOLES SE DESSINENT À TAILLE D'ÉCRAN. Un rayon en unités du monde
// grossit avec le zoom : à ×7, un point de gare faisait une soucoupe et son
// nom disparaissait dessous. On divise donc rayons et décalages par k — les
// traits, eux, le font en CSS (calc(px / var(--k))).
function garesHTML() {
  const k = (CARTE.cam && CARTE.cam.k) || 1;
  const R = n => (n / k).toFixed(2);
  const ch0 = chapitreVu(), gc = CARTE.prochaine;
  const out = [];
  if (!ch0) return '<g class="gares"></g>';
  for (const g of ch0.gares) {
    const p = pos(g); if (!p) continue;
    const etat = etatDeGare(g);
    const ch = ch0;
    const fin = ch.gares[ch.gares.length - 1] === g;   // la grande gare
    const ici = g === gc;
    const st = etoilesDe(g);
    const cl = ["gare", "g-" + etat, fin ? "g-fin" : "", ici ? "g-ici" : "",
                CARTE.bilan && CARTE.bilan.gare === g ? "g-bilan" : ""]
      .filter(Boolean).join(" ");
    const jouable = etat === "faite" || etat === "courante" || etat === "payee";
    const cx = p.x.toFixed(2), cy = p.y.toFixed(2);
    out.push(`<g class="${cl}" style="--col:${couleurDeZone(ch && ch.zone)};--i:${ch0.gares.indexOf(g)}"` +
      (jouable ? ` data-gare="${g}" tabindex="0"` : "") + `>` +
      (ici ? `<circle class="halo" cx="${cx}" cy="${cy}" r="${R(fin ? 5.2 : 4.4)}"/>` : "") +
      `<circle class="cible" cx="${cx}" cy="${cy}" r="${R(5.5)}"/>` +
      `<circle class="pt" cx="${cx}" cy="${cy}" r="${R(fin ? 2.3 : 1.5)}"/>` +
      // LE SCORE VIT DANS L'ÉTIQUETTE, À DROITE DU NOM. Il était posé SOUS le
      // point, donc il percutait le nom de la gare d'à côté — « ★Malines ».
      // Nom et score ne font plus qu'un bloc : ils se centrent ensemble sur le
      // point, et il n'y a plus qu'une chose à ne pas faire se chevaucher.
      // UNE ÉTOILE = UN TSPAN. Elles étaient rendues d'un bloc (« ★★★ ») ; il
      // en faut une par élément pour qu'elles se posent l'une après l'autre
      // quand le service vient de se solder (css, .a-service).
      `<text x="${cx}" y="${(p.y - (fin ? 6 : 4.4) / k).toFixed(2)}">${nomDe(g)}` +
        (estSansFaute(g) ? `<tspan class="et dia" style="--s:0" dx="${(1.4 / k).toFixed(2)}">◆</tspan>`
          : st ? Array.from({ length: st }, (_, n) =>
              `<tspan class="et" style="--s:${n}" dx="${(n ? 0 : 1.4 / k).toFixed(2)}">★</tspan>`).join("")
            : "") +
      `</text>` +
      `</g>`);
  }
  // La gare qu'on QUITTE reste dessinée le temps du transit : sans elle, le
  // train partirait de nulle part.
  if (CARTE.transit) {
    const gq = CARTE.transit.de, pq = pos(gq);
    if (pq && ch0.gares.indexOf(gq) < 0) {
      const chq = chapitreDeGare(gq);
      out.unshift(`<g class="gare g-faite g-fin g-quittee" style="--col:${couleurDeZone(chq && chq.zone)}">` +
        `<circle class="pt" cx="${pq.x.toFixed(2)}" cy="${pq.y.toFixed(2)}" r="${R(2.3)}"/>` +
        `<text x="${pq.x.toFixed(2)}" y="${(pq.y - 6 / k).toFixed(2)}">${nomDe(gq)}</text></g>`);
    }
  }
  return '<g class="gares">' + out.join("") + "</g>";
}

// ------------------------------------------------------------------
// LE CARTOUCHE — la gare en cours, et ce qu'il faut en savoir.
// ------------------------------------------------------------------
// « On voit la carte zoomée sur la gare en question, en évidence, avec les
// infos de base. » Les infos de base d'une gare d'aiguillage, ce sont ses
// QUAIS et ses DIRECTIONS : c'est de là que vient la difficulté (§2.1), et
// c'est ce que le joueur doit anticiper avant de prendre le service.
function pipsHTML(d) {
  const n = Math.max(1, Math.min(5, d || 1));
  return '<span class="dif">' + Array.from({ length: 5 },
    (_, i) => '<span class="b' + (i < n ? " on" : "") + '"></span>').join("") + "</span>";
}
function cartoucheHTML(gareId) {
  const cfg = cardOf(gareId);
  if (!cfg) return "";
  const ch = chapitreDeGare(gareId);
  const rang = rangDansChapitre(gareId), total = ch ? ch.gares.length : 0;
  const d = difficulteDeGare(gareId, cfg);
  const quais = (cfg.platforms || []).length;
  // `portals` est un OBJET { NOM: {side, color, abbr} } — une direction par clé.
  const dirs = Object.keys(cfg.portals || {}).length;
  const st = etoilesDe(gareId), best = (getProgress()[gareId] || {}).bestDelay;
  // LE BARÈME S'AFFICHE. Il suit la difficulté de la gare (js/ruban.js,
  // SEUILS) : caché, il passerait pour un bug — « 9 min m'a valu trois étoiles
  // à Arlon et deux à Bruxelles ».
  const seuils = seuilsDeService(cfg);
  // Une grande gare à pleine difficulté porte l'enveloppe de boss (js/ruban.js) :
  // plus de convois, plus de fret, et une bourrasque en fin de journée.
  const boss = typeof estBoss === "function" && estBoss(gareId, cfg);
  const fin = ch && ch.gares[ch.gares.length - 1] === gareId;
  const drapeau = (cfg.country || "").trim().split(" ")[0];
  // LA PHRASE DE LA GARE. Elle est écrite pour chaque fiche et ne servait à
  // rien depuis que le toast a été désactivé : c'est elle qui rend le panneau
  // agréable à lire plutôt qu'un tableau de bord de chiffres. On lui retire le
  // préfixe « Arlon — », qui répéterait le titre juste au-dessus.
  const phrase = (cfg.tagline || "").replace(/^\s*[^—–-]{2,28}\s*[—–]\s*/, "");
  return `<section class="c-fiche">
    <p class="cf-ou">Gare ${rang} <span>sur ${total}</span>${fin ? ' <span class="cf-terminus">terminus</span>' : ""}</p>
    <h3 class="cf-nom">${villeDe(gareId)}</h3>
    <p class="cf-pays">${drapeau} ${(cfg.country || "").trim().split(" ").slice(1).join(" ")}</p>
    ${phrase ? `<p class="cf-phrase">${phrase}</p>` : ""}
    ${boss ? `<p class="cf-boss"><b>Bourrasque</b>Le trafic se resserre en fin de service.</p>` : ""}
    <dl class="cf-mesures">
      <div><dt>Quais</dt><dd>${quais}</dd></div>
      <div><dt>Directions</dt><dd>${dirs}</dd></div>
      <div class="cf-dif"><dt>Difficulté</dt><dd>${pipsHTML(d)}</dd></div>
      <div><dt>Pour 3 ★</dt><dd class="cf-seuil">${seuils.trois}<span> min</span></dd></div>
    </dl>
    ${st ? `<p class="cf-score"><span class="cf-et">${"★".repeat(st)}</span>${
      estSansFaute(gareId) ? `<span class="cf-dia">◆ sans faute</span>`
        : best != null ? `<span class="cf-rec">record ${best} min</span>` : ""}</p>` : ""}
  </section>`;
}

// ------------------------------------------------------------------
// LA BULLE DU RÉSULTAT — sous la gare qu'on vient de tenir.
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// LES MÉDAILLES QU'ON VIENT DE DÉCROCHER.
// ------------------------------------------------------------------
// Elles étaient calculées depuis le lot D (js/recompense.js, 28 médailles) et
// n'étaient MONTRÉES NULLE PART : `medaillesNouvelles` n'avait aucun appelant.
// Le joueur franchissait des paliers sans jamais l'apprendre.
//
// COMBIEN ON EN MONTRE DÉPEND DE LA PLACE, et la place dit le moment. Le
// relevé est une BULLE posée sur la gare, étroite par nature : deux médailles
// au plus, le reste en un chiffre. La FÊTE de chapitre est un écran de
// célébration — c'est là qu'on en décroche cinq d'un coup, et les taire pour
// tenir une limite serait fêter à moitié. Elle les montre toutes.
//
// On NE TRIE PAS par rareté : le tableau de `js/recompense.js` est groupé par
// FAMILLE (Accumulation, Maîtrise, Exploration, Style), pas par difficulté.
// Prendre « les deux dernières » y montrait « Ponctualité suisse » en taisant
// « Chapitre de diamant » — mesuré sur le premier chapitre joué d'affilée.
// L'ordre du tableau est donc conservé tel quel, et c'est la FÊTE qui répond
// au cas des grosses moissons.
function medaillesHTML(combien) {
  const m = CARTE.medailles;
  if (!m || !m.length) return "";
  const montrees = combien && m.length > combien ? m.slice(0, combien) : m;
  const reste = m.length - montrees.length;
  return `<div class="c-medailles">` + montrees.map(x =>
    `<span class="cm-un"><b>${x.nom}</b><i>${x.dit}</i></span>`).join("") +
    (reste ? `<span class="cm-plus">+${reste}</span>` : "") + `</div>`;
}

function bilanHTML(avecMedailles) {
  const b = CARTE.bilan;
  if (!b) return "";
  if (avecMedailles === undefined) avecMedailles = true;
  const cl = "c-bilan" + (b.perfect ? " parfait" : "") + (b.win ? "" : " rate");
  const etoiles = typeof etoilesHTML === "function" ? etoilesHTML(b.stars, b.prevStars) : "";
  const retard = b.failed
    ? `<div class="cb-retard"><b>${b.d}</b> min — plafond dépassé</div>`
    : b.perfect
    ? `<div class="cb-retard sansfaute"><b>0</b> min — pas une minute</div>`
    : `<div class="cb-retard"><b>${b.d}</b> min de retard</div>`;
  // LE DIAMANT SE MONTRE AU MOMENT OÙ IL SE GAGNE. Il était enregistré depuis
  // toujours (store, bestDelay = 0) et ne s'affichait nulle part : le joueur
  // faisait un sans-faute et le jeu ne lui disait rien.
  const diamant = b.perfect
    ? `<div class="cb-diamant">◆ <span>Diamant</span></div>` : "";
  let rec = "";
  if (b.failed) rec = "";
  else if (!b.win) rec = `<div class="cb-record loin">objectif manqué</div>`;
  else if (b.prevBest == null) rec = `<div class="cb-record neuf">premier service</div>`;
  else if (b.d < b.prevBest) rec = `<div class="cb-record bat">record battu · −${b.prevBest - b.d} min</div>`;
  else if (b.d === b.prevBest) rec = `<div class="cb-record egal">record égalé</div>`;
  else rec = `<div class="cb-record loin">record : ${b.prevBest} min</div>`;
  // CE QU'IL AURAIT FALLU. Le barème varie d'une gare à l'autre : après un
  // service à deux étoiles, dire le seuil vaut mieux que laisser deviner.
  const s = b.seuils;
  const vise = (s && b.win && !b.perfect && b.stars < 3)
    ? `<div class="cb-vise">3 ★ sous ${s.trois} min</div>` : "";
  return `<div class="${cl}" role="status">
    <div class="cb-gare">${villeDe(b.gare)}</div>
    <div class="cb-etoiles">${etoiles}</div>${diamant}${retard}${rec}${vise}${
      avecMedailles ? medaillesHTML(2) : ""}</div>`;
}

const FLECHE = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" ' +
  'stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
  '<path d="M5 12h13M12 6l6 6-6 6"/></svg>';
const BOUCLE = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" ' +
  'stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
  '<path d="M20 11.5A8 8 0 1 1 17.4 6L20 8.5"/><path d="M20 4v5h-5"/></svg>';

// ------------------------------------------------------------------
// LE PIED DU PANNEAU — les boutons, et ils ne bougent jamais de là.
// ------------------------------------------------------------------
// Ils vivaient DANS la carte de relevé, donc dans le corps qui défile : sur un
// écran court, « Jouer » se retrouvait rogné en bas. Le geste du jeu ne doit
// jamais pouvoir sortir de l'écran — il est désormais épinglé au pied, quel
// que soit ce que le corps affiche.
//
// REPRENDRE EN HAUT, AVANCER EN BAS — dans les deux issues. Le bouton qui fait
// avancer le ruban tombe ainsi toujours au même endroit, et le doigt n'a pas à
// chercher selon qu'on a gagné ou perdu.
function piedHTML() {
  const gc = CARTE.prochaine, b = CARTE.bilan, f = CARTE.fete;

  // Fin de chapitre : LE BOUTON NOMME LA GARE, exactement comme entre deux
  // gares du même chapitre. Il annonçait le CHAPITRE suivant (« En route · Le
  // Yorkshire noir ») : on savait où l'on allait en gros, plus où l'on allait
  // vraiment, et le geste changeait de nature au pire moment. Le chapitre garde
  // son annonce, en surtitre, où elle ne coûte pas le nom de la destination.
  if (f) return `<div class="cc-pied">` + (f.suivant && gc
    ? `<p class="cp-chapitre">Chapitre suivant · <b>${f.suivant.nom}</b></p>` +
      `<button class="c-suite c-appel" data-gare="${gc}">` +
      `<span class="ca-texte"><span class="ca-quoi">Jouer</span>` +
      `<span class="ca-ou">${villeDe(gc)}</span></span>${FLECHE}</button>`
    : `<div class="c-avenir">Le ruban s'arrête ici — pour le moment.</div>`) + `</div>`;

  // Échec : réessayer (gratuit, illimité) et payer le passage, côte à côte.
  if (b && !b.win) {
    const prix = prixDePassage(b.gare), solde = soldeCredits(), assez = solde >= prix;
    const manque = prix - solde;
    return `<div class="cc-pied">` +
      (assez ? "" : `<div class="cb-manque">Il te manque ${manque} crédit${manque > 1 ? "s" : ""} — ` +
        `rejoue une gare déjà faite pour les gagner.</div>`) +
      `<button class="c-suite cb-payer" data-payer="${b.gare}"${assez ? "" : " disabled"}>` +
        `Passer · ${prix} cr</button>` +
      `<button class="c-suite c-appel" data-gare="${b.gare}">` +
        `<span class="ca-texte"><span class="ca-quoi">Réessayer</span>` +
        `<span class="ca-ou">${villeDe(b.gare)}</span></span>${BOUCLE}</button></div>`;
  }

  // Réussite : rejouer pour mieux faire, puis avancer.
  if (b) return `<div class="cc-pied">` +
    `<button class="c-suite cb-rejouer" data-gare="${b.gare}">Rejouer${BOUCLE}</button>` +
    (gc ? `<button class="c-suite c-appel" data-gare="${gc}">` +
      `<span class="ca-texte"><span class="ca-quoi">Jouer</span>` +
      `<span class="ca-ou">${villeDe(gc)}</span></span>${FLECHE}</button>` : "") + `</div>`;

  // Au repos : un seul bouton, et il nomme la gare.
  if (gc) return `<div class="cc-pied"><button class="c-suite c-appel" data-gare="${gc}">` +
    `<span class="ca-texte"><span class="ca-quoi">Jouer</span>` +
    `<span class="ca-ou">${villeDe(gc)}</span></span>${FLECHE}</button></div>`;
  return `<div class="cc-pied"><div class="c-avenir">${auBoutDeLEcrit()
    ? "La suite du ruban n'est pas encore écrite."
    : "Le ruban est terminé. Reste à le dorer."}</div></div>`;
}

// ------------------------------------------------------------------
// LA FÊTE DE FIN DE CHAPITRE — et le nom du suivant, annoncé.
// ------------------------------------------------------------------
// C'est ce qui manquait le plus au test de jeu : savoir où l'on va. Le
// chapitre se ferme, son rang s'affiche, et le suivant se nomme.
function feteHTML() {
  const f = CARTE.fete;
  if (!f) return "";
  const ch = f.ch, rang = rangDeChapitre(ch);
  const zone = typeof zoneById === "function" ? zoneById(ch.zone) : null;
  // CE QU'ON A GAGNÉ, pas trois façons de dire « terminé ». La première
  // version écrivait le même fait trois fois — une pastille dans l'en-tête,
  // « chapitre terminé » en titre, « chapitre fait » en rang — et annonçait le
  // chapitre suivant deux fois, dans la carte puis sur le bouton. Il reste ici
  // le relevé du chapitre, et lui seul : le nom est dans l'en-tête, la suite
  // est sur le bouton.
  const n = ch.gares.length;
  const et = ch.gares.reduce((t, g) => t + etoilesDe(g), 0), etMax = n * 3;
  const dia = ch.gares.filter(estSansFaute).length;
  const payees = ch.gares.filter(estPassee).length;
  const parfait = et === etMax && dia === n;
  // CE QUI RESTE À PRENDRE. « Réussir est facile, exceller est le vrai jeu » :
  // un chapitre fini n'est pas un chapitre clos, et le dire ici est le seul
  // endroit où ça compte vraiment.
  // Un diamant vaut trois étoiles : « tous les diamants » implique « toutes les
  // étoiles ». Il n'y a donc que trois états, pas quatre.
  let reste = "";
  if (parfait) reste = `<p class="cf-parfait">Pas une minute de retard, nulle part.</p>`;
  else if (et < etMax) reste = `<p class="cf-reste"><b>${etMax - et}</b> étoile${etMax - et > 1 ? "s" : ""} ` +
    `à prendre ici${payees ? `, dont ${payees} gare${payees > 1 ? "s" : ""} passée${payees > 1 ? "s" : ""}` : ""}.</p>`;
  else reste = `<p class="cf-reste">Toutes les étoiles. Reste les sans-faute : <b>${n - dia}</b>.</p>`;

  return `<div class="c-fete" role="status" style="--col:${couleurDeZone(ch.zone)}">
    <p class="cf-quoi">Chapitre terminé</p>
    <div class="cf-butin">
      <span class="cb-et"><b>${et}</b><span>/ ${etMax} ★</span></span>
      <span class="cb-dia${dia ? " on" : ""}"><b>${dia}</b><span>◆</span></span>
    </div>
    ${rang && rang.id !== "ouverte" ? `<p class="cf-rang r-${rang.id}">${rang.nom}</p>` : ""}
    ${reste}
    ${f.zoneFinie && zone ? `<p class="cf-zone">${zone.nom} — région traversée</p>` : ""}
    ${medaillesHTML()}
  </div>`;
}

// ------------------------------------------------------------------
// LES COMPTEURS.
// ------------------------------------------------------------------
function bourseHTML() {
  if (typeof gradeOf !== "function" || typeof etoilesTotal !== "function") return "";
  const n = etoilesTotal(), g = gradeOf(n);
  const s = typeof getSerie === "function" ? getSerie() : { n: 0 };
  const cr = typeof soldeCredits === "function" ? soldeCredits() : null;
  // ◆ EST LE DIAMANT, PAS LA MONNAIE. Les deux se disputaient le signe dans la
  // barre du haut ; les crédits passent donc en « cr », et le losange revient
  // à ce qu'il désigne depuis le premier jour : un service sans la moindre
  // minute de retard.
  const dia = typeof etatRecompenses === "function" ? etatRecompenses().diamants : 0;
  return `<div class="c-compteurs">` +
    (s.n >= 2 ? `<span class="c-serie" title="${s.n} services d'affilée sous dix minutes">» ${s.n}</span>` : "") +
    `<span class="c-grade" title="${g.nom}"><span class="g-nom">${g.nom}</span>` +
      `<span class="g-jauge"><i style="width:${Math.round(g.part * 100)}%"></i></span></span>` +
    (cr === null ? "" : `<span class="c-credits" title="crédits, pour passer une gare">${cr} cr</span>`) +
    (dia ? `<span class="c-diamants" title="${dia} service${dia > 1 ? "s" : ""} sans faute">◆ ${dia}</span>` : "") +
    `<span class="c-etoiles">★ ${n}</span></div>`;
}

// ------------------------------------------------------------------
// LA VUE, ET LE RENDU.
// ------------------------------------------------------------------
// LE PANNEAU DE GAUCHE — tout ce qui se lit, d'un seul côté.
// Le premier test l'a demandé : les infos de la gare tenaient au milieu, sous
// la carte, et coupaient l'écran en deux. À gauche, la carte prend toute la
// place qui reste — et sur un écran en paysage, c'est beaucoup.
function chapitreHTML() {
  const ch = CARTE.chapitre;
  if (!ch) return "";
  const zone = typeof zoneById === "function" ? zoneById(ch.zone) : null;
  const rang = rangDeChapitre(ch);
  const faits = ch.gares.filter(estFaite).length;
  const chs = chapitresDuRuban();
  // TROIS LIGNES, TROIS NIVEAUX DE LECTURE, et aucune qui puisse casser en
  // orphelin : le compteur d'abord (court, monospace), le nom du chapitre en
  // grand, la région dessous dans sa couleur. La première version mettait tout
  // sur une ligne d'eyebrow, qui se repliait sur « CHAPITRE / 1 SUR 11 ».
  return `<header class="cc-chapitre" style="--col:${couleurDeZone(ch.zone)}">
    <p class="cc-compteur">Chapitre ${ch.rang + 1} <span>/ ${chs.length}</span></p>
    <h2 class="cc-nom">${ch.nom}</h2>
    <p class="cc-zone">${zone ? zone.nom : nomDeCarte()}</p>
    <div class="cc-jauge">
      <span class="cj-piste">${ch.gares.map(g =>
        `<i class="cj-cran${estSansFaute(g) ? " dia" : estFaite(g) ? " fait" : estPassee(g) ? " paye" : ""}${
          g === CARTE.prochaine ? " ici" : ""}"></i>`).join("")}</span>
      ${rang && rang.id !== "ouverte" && !CARTE.fete
        ? `<span class="c-rang r-${rang.id}">${rang.nom}</span>`
        : `<span class="c-avance">${faits}<span class="cj-sur">/</span>${ch.gares.length}</span>`}
    </div>
  </header>`;
}

// ------------------------------------------------------------------
// L'ÉCRAN DES CARTES (lot H) — choisir son territoire, et l'acheter.
// ------------------------------------------------------------------
// IL N'APPARAÎT QU'À PARTIR DE DEUX CARTES. Avec une seule, il n'y a rien à
// choisir : un écran qui ne pose pas de question est un écran de trop, et le
// joueur tombe directement sur son ruban.
function plusieursCartes() { return typeof CARTES !== "undefined" && CARTES.length >= 2; }

// Ce qu'une carte montre d'elle-même AVANT d'être ouverte : sa taille et, si
// on y a déjà joué, où l'on en est. Tout se déduit de sa définition et de la
// progression enregistrée — rien n'est stocké pour l'affichage.
function resumeDeCarte(id) {
  const def = typeof defDeCarte === "function" ? defDeCarte(id) : null;
  const chs = (def && def.chapitres) || [];
  const gares = chs.reduce((n, c) => n + ((c.gares || []).length), 0);
  let stations = {}, passees = [];
  if (typeof getCartesEnregistrees === "function")
    for (const c of getCartesEnregistrees()) if (c.id === id) { stations = c.stations || {}; passees = c.passees || []; }
  let faites = 0, etoiles = 0;
  for (const g of chs.flatMap(c => c.gares || [])) {
    const r = stations[g] || {};
    if ((r.stars || 0) >= 1) faites++;
    etoiles += r.stars || 0;
  }
  return { def, chapitres: chs.length, gares, faites, etoiles, entamee: faites > 0 || passees.length > 0 };
}

function vueCartes() {
  const liste = typeof CARTES !== "undefined" ? CARTES : [];
  const cour = typeof getCarteCourante === "function" ? getCarteCourante() : null;
  const solde = typeof soldeCredits === "function" ? soldeCredits() : 0;
  const tuiles = liste.map(e => {
    const r = resumeDeCarte(e.id);
    const possede = typeof possedeCarte === "function" ? possedeCarte(e.id) : !!e.gratuite;
    const prix = typeof prixDeCarte === "function" ? prixDeCarte(e.id) : 0;
    const manque = prix - solde;
    const courante = e.id === cour;
    // L'AVANCEMENT NE SE MONTRE QUE S'IL EXISTE. Une carte jamais ouverte
    // afficherait « 0 / 71 », ce qui ressemble à un échec plutôt qu'à une
    // invitation.
    const avance = r.entamee
      ? `<span class="ct-avance">${r.faites}<span class="ct-sur">/</span>${r.gares} gares · ★ ${r.etoiles}</span>` : "";
    let action;
    if (courante) action = `<button class="c-suite ct-action" disabled>Carte en cours</button>`;
    else if (possede) action = `<button class="c-suite ct-action" data-carte="${e.id}">` +
      (r.entamee ? "Reprendre" : "Commencer") + `</button>`;
    else if (solde >= prix) action = `<button class="c-suite ct-action" data-acheter="${e.id}">Ouvrir · ${prix} cr</button>`;
    else action = `<div class="cb-manque">Il te manque ${manque} crédit${manque > 1 ? "s" : ""} — ` +
      `gagne des étoiles sur ta carte en cours.</div>` +
      `<button class="c-suite ct-action" disabled>Ouvrir · ${prix} cr</button>`;
    // LA CARTE BANCAIRE EST HORS PROTOTYPE. Le bouton existe pour que la place
    // soit prise et que le geste se voie, mais il ne fait rien : seul l'état
    // « achat » est prévu dans la sauvegarde, pour que le moteur final n'ait
    // pas à migrer le jour où le paiement existera.
    const cb = possede ? "" :
      `<button class="ct-cb" disabled title="Le paiement n'existe pas dans le prototype">Carte bancaire — bientôt</button>`;
    return `<article class="ct-tuile${courante ? " ici" : ""}${possede ? "" : " verrou"}">
      <header class="ct-tete">
        <h3 class="ct-nom">${e.nom || (r.def && r.def.nom) || e.id}</h3>
        ${courante ? `<span class="ct-fanion">ici</span>` : possede ? "" : `<span class="ct-cadenas">verrouillée</span>`}
      </header>
      <p class="ct-sous">${e.sousTitre || ""}</p>
      <p class="ct-taille">${r.chapitres} chapitre${r.chapitres > 1 ? "s" : ""} · ${r.gares} gares</p>
      ${avance}
      <div class="ct-pied">${action}${cb}</div>
    </article>`;
  }).join("");
  return `<div class="cv-entete">
      <button class="cv-retour" data-fermer-cartes><span class="arw">‹</span>Revenir au ruban</button>
      <h2 class="cv-titre">Les cartes</h2>
      <span class="c-credits" title="crédits">${solde} cr</span>
    </div>
    <div class="cv-tuiles">${tuiles}</div>`;
}

// Ouvrir, fermer. La vue est un simple état de l'écran : rien ne se stocke, et
// revenir au ruban ne coûte pas un rechargement.
function ouvrirCartes() { CARTE.vue = "cartes"; renderCarte(); }
function fermerCartes() { CARTE.vue = "ruban"; renderCarte(); }

// CHANGER DE CARTE, C'EST CHANGER DE MONDE. La progression de l'ancienne reste
// intacte — chaque carte a la sienne (js/store.js) — mais tout ce que l'écran
// gardait de la précédente doit tomber : le relevé, la fête, la caméra et le
// chapitre de référence. Sans ça, on arrive sur le nouveau ruban avec le bilan
// de l'ancien affiché à côté.
async function choisirCarte(id) {
  if (typeof possedeCarte === "function" && !possedeCarte(id)) return;
  annulerVoyage();
  if (typeof getCarteCourante === "function" && getCarteCourante() === id) { fermerCartes(); return; }
  if (typeof setCarteCourante === "function") setCarteCourante(id);
  if (typeof loadCarte === "function") await loadCarte(id);
  CARTE.vue = "ruban";
  CARTE.bilan = null; CARTE.fete = null; CARTE.medailles = null; CARTE.voyage = null;
  CARTE.cam = null; CARTE.camAvant = null; CARTE.derive = null;
  CARTE.chapitre = null; CARTE.chapitreAvant = null; CARTE.feteAvant = false;
  CARTE.transit = null; CARTE.voyageFait = null;
  renderCarte();
}
// Acheter : le seul FAIT que l'économie des cartes écrive. Le solde, lui, se
// déduit — et il retombe tout seul du prix de la carte (js/recompense.js).
function acheterCarte(id) {
  const prix = typeof prixDeCarte === "function" ? prixDeCarte(id) : 0;
  if (typeof soldeCredits === "function" && soldeCredits() < prix) return;
  if (typeof acquerirCarte !== "function" || !acquerirCarte(id, "credits")) return;
  renderCarte();
}

function vueRuban() {
  const gc = gareCourante();
  CARTE.prochaine = gc;
  // PENDANT LA FÊTE, ON RESTE SUR LE CHAPITRE QU'ON VIENT DE FINIR — en-tête,
  // jauge pleine, rang, et la carte encore allumée dessus. L'écran passait
  // déjà au suivant pendant qu'on célébrait le précédent : on félicitait le
  // joueur d'un chapitre en lui montrant l'autre. « En route » fait le pas,
  // et c'est là que la caméra voyage.
  CARTE.chapitre = CARTE.fete ? CARTE.fete.ch
    : (chapitreDeGare(gc) || chapitreAt(Math.min(positionCourante(), longueurDuRuban() - 1)));
  const ch = CARTE.chapitre;
  if (!ch) return `<div class="c-cote"><div class="cc-nom">Aucun chapitre n'est encore écrit</div></div>`;

  // Le saut se montre AVANT le chapitre qu'il ouvre : c'est une transition,
  // et elle a le droit d'être lue.
  const saut = ch.saut && ch.gares.indexOf(gc) === 0
    ? `<div class="c-saut"><b>${ch.saut.mode}</b>${ch.saut.texte}</div>` : "";

  return `
    <aside class="c-cote">
      ${plusieursCartes() ? `<button class="cc-carte" data-ouvrir-cartes>` +
        `<span class="ccc-nom">${nomDeCarte()}</span>` +
        `<span class="ccc-quoi">Changer de carte</span></button>` : ""}
      ${chapitreHTML()}
      <div class="cc-corps${CARTE.fete && !CARTE.bilan ? " fete" : ""}">
        ${CARTE.fete
          ? feteHTML() + (CARTE.bilan ? bilanHTML(false) : "")
          : CARTE.bilan ? bilanHTML() : (gc ? cartoucheHTML(gc) : "")}
      </div>
      ${piedHTML()}
    </aside>
    <div class="c-scene">
      ${bourseHTML()}
      ${saut}
      <svg class="c-graphe c-ruban" viewBox="0 0 ${CADRE_L} ${CADRE_H}" preserveAspectRatio="xMidYMid meet">
        <g class="monde">${fondHTML()}${railHTML()}${garesHTML()}</g>
      </svg>
    </div>`;
}

function renderCarte() {
  const hote = document.getElementById("hub-map");
  if (!hote) return;
  CARTE.hote = hote;
  if (CARTE.vue === "cartes") { renderChoixDeCarte(hote); return; }
  hote.className = "carte v-ruban";
  hote.innerHTML = vueRuban();
  CARTE.etoiles = hote.querySelector(".c-etoiles");
  poserCamera();
  // ------------------------------------------------------------------
  // CE QUI VIENT DE CHANGER SE VOIT. Un chapitre se terminait et l'écran
  // passait au suivant sans que rien ne marque le pas : ni sur la carte, ni
  // dans le panneau. Trois marques, et elles ne durent qu'un instant.
  // ------------------------------------------------------------------
  const chId = CARTE.chapitre ? CARTE.chapitre.id : null;
  const nouveauChapitre = chId && CARTE.chapitreAvant && chId !== CARTE.chapitreAvant;
  const feteNeuve = !!CARTE.fete && !CARTE.feteAvant;
  // UN SERVICE VIENT DE SE SOLDER. On ne le joue qu'une fois : le relevé se
  // rend à chaque retour sur l'écran, l'animation, non. On compare l'OBJET et
  // non l'id de la gare — sans quoi REJOUER une gare déjà tenue ne rejouerait
  // pas l'animation, alors que c'est bien un service neuf. js/game.js construit
  // un relevé neuf à chaque fin de service : la référence suffit.
  const b = CARTE.bilan && CARTE.bilan.win ? CARTE.bilan : null;
  const bilanNeuf = !!b && b !== CARTE.bilanAvant;
  CARTE.chapitreAvant = chId; CARTE.feteAvant = !!CARTE.fete; CARTE.bilanAvant = b;
  if (!sansAnimation()) {
    const svg = hote.querySelector(".c-ruban");
    // Le service se solde SUR LA CARTE : les étoiles se posent sur la gare
    // qu'on vient de tenir, puis le rail avance vers la suivante. C'est le
    // seul endroit où le résultat et la destination se rejoignent.
    if (bilanNeuf && svg) svg.classList.add("a-service");
    // Le chapitre se ferme : son rail s'allume d'un bout à l'autre, gare après
    // gare. C'est la marche franchie, et elle se lit sans un mot.
    if (feteNeuve && svg) svg.classList.add("a-fete");
    // Le chapitre suivant arrive : le panneau et le rail entrent ensemble.
    // Jamais pendant une fête : là, c'est le chapitre qu'on VIENT DE FINIR qui
    // s'allume, et une animation d'arrivée par-dessus brouillerait le geste.
    if (nouveauChapitre && !CARTE.fete) {
      hote.querySelector(".cc-chapitre")?.classList.add("a-neuf");
      if (svg) svg.classList.add("a-arrivee");
    }
  }
  // LES GARES SE REDESSINENT AU BON ZOOM. Leur taille dépend de k, et k ne se
  // connaît qu'une fois le SVG mesuré : on refait donc ce seul calque après
  // la caméra. Le fond et le rail, eux, se mettent à l'échelle en CSS.
  const gs = hote.querySelector(".c-ruban .gares");
  if (gs) gs.outerHTML = garesHTML();
  hote.onclick = ev => {
    if (ev.target.closest("[data-ouvrir-cartes]")) { ouvrirCartes(); return; }
    const pay = ev.target.closest("[data-payer]");
    if (pay && !pay.disabled) { passerLaGare(pay.dataset.payer); return; }
    const g = ev.target.closest("[data-gare]");
    if (g && g.dataset.gare) { jouerGare(g.dataset.gare); return; }
  };
  hote.onkeydown = ev => {
    if (ev.key !== "Enter" && ev.key !== " ") return;
    const g = ev.target.closest("[data-gare]");
    if (g && g.dataset.gare) { ev.preventDefault(); jouerGare(g.dataset.gare); }
  };
}
// L'écran des cartes ne dessine ni rail ni caméra : il n'a rien à poser.
function renderChoixDeCarte(hote) {
  hote.className = "carte v-cartes";
  hote.innerHTML = vueCartes();
  hote.onkeydown = null;
  hote.onclick = ev => {
    if (ev.target.closest("[data-fermer-cartes]")) { fermerCartes(); return; }
    const a = ev.target.closest("[data-acheter]");
    if (a && !a.disabled) { acheterCarte(a.dataset.acheter); return; }
    const c = ev.target.closest("[data-carte]");
    if (c && !c.disabled) { choisirCarte(c.dataset.carte); return; }
  };
}
function renderHub() { renderCarte(); }

// ------------------------------------------------------------------
// LE VOYAGE — la caméra glisse le long du rail.
// ------------------------------------------------------------------
// Le relevé désigne une gare par son nom ; la carte la marque d'un halo. Entre
// les deux, le joueur devrait faire lui-même le lien entre un mot et un point.
// La caméra le fait à sa place : le trajet EST la phrase. Un SAUT dure plus
// longtemps — c'est ce qui le distingue d'un rail continu.
// LA CARTE SE DÉPLACE AU DOIGT (28 août 2026, retour du simulateur iPhone :
// « quitte à ne pas voir toute la ligne, qu'on puisse bouger la carte »). Le
// glisser décale le centre de la caméra, en unités du monde ; la dérive
// appartient à la vue en cours et se remet à zéro dès que la caméra change de
// sujet — nouvelle gare, nouveau chapitre — pour que la pose reste la sienne.
function transfoCamera(c) {
  const d = CARTE.derive || { x: 0, y: 0 };
  const x = c.x + d.x, y = c.y + d.y;
  return `translate(${(CADRE_L / 2 - c.k * x).toFixed(2)}px, ${(CADRE_H / 2 - c.k * y).toFixed(2)}px) scale(${c.k.toFixed(3)})`;
}
function brancherDerive() {
  const h = CARTE.hote;
  if (!h || h._deriveOK) return;
  h._deriveOK = true;
  let suivi = null;
  h.addEventListener("pointerdown", e => {
    const svg = e.target.closest ? e.target.closest(".c-graphe") : null;
    if (!svg || CARTE.transit || !CARTE.cam) return;
    const r = svg.getBoundingClientRect();
    const s = Math.min(r.width / CADRE_L, r.height / CADRE_H);
    if (!(s > 0)) return;
    suivi = { x0: e.clientX, y0: e.clientY, d0: { ...(CARTE.derive || { x: 0, y: 0 }) },
              s, svg, actif: false, id: e.pointerId };
  });
  h.addEventListener("pointermove", e => {
    if (!suivi || e.pointerId !== suivi.id) return;
    const dx = e.clientX - suivi.x0, dy = e.clientY - suivi.y0;
    if (!suivi.actif && Math.hypot(dx, dy) < 6) return;   // un tap reste un tap
    suivi.actif = true;
    e.preventDefault();
    const monde = suivi.svg.querySelector(".monde");
    const c = CARTE.cam;
    if (!monde || !c) return;
    CARTE.derive = { x: suivi.d0.x - dx / (suivi.s * c.k),
                     y: suivi.d0.y - dy / (suivi.s * c.k) };
    monde.style.transitionDuration = "0s";
    monde.style.transform = transfoCamera(c);
  });
  const lacher = e => {
    if (!suivi || (e.pointerId !== undefined && e.pointerId !== suivi.id)) return;
    const monde = suivi.svg.querySelector(".monde");
    if (monde && suivi.actif) {
      monde.style.transitionDuration = "";
      CARTE.camAvant = monde.style.transform;   // la prochaine pose repart d'ici
    }
    suivi = null;
  };
  h.addEventListener("pointerup", lacher);
  h.addEventListener("pointercancel", lacher);
}
function poserCamera() {
  const svg = CARTE.hote && CARTE.hote.querySelector(".c-graphe");
  const monde = svg && svg.querySelector(".monde");
  if (!svg || !monde) { CARTE.camAvant = null; return; }
  brancherDerive();
  // La dérive est propre au sujet cadré : elle meurt avec lui.
  const sujet = (chapitreVu() ? chapitreVu().id : "-") + ":" + (gareCourante() || "-");
  if (CARTE.deriveSujet !== sujet) { CARTE.derive = { x: 0, y: 0 }; CARTE.deriveSujet = sujet; }
  const c = cameraVoulue();
  CARTE.cam = c;
  svg.style.setProperty("--k", c.k.toFixed(3));
  const t = transfoCamera(c);
  // Le zoom SE JOUE, il ne se pose pas : le SVG est refait à chaque rendu, donc
  // le monde repart de sa transformation d'avant et reçoit la nouvelle — c'est
  // le CSS qui fait le trajet.
  const lent = !!CARTE.voyageSaut;
  monde.style.transitionDuration = lent ? "1.5s" : "";
  if (CARTE.camAvant && CARTE.camAvant !== t) {
    monde.style.transform = CARTE.camAvant;
    monde.getBoundingClientRect();
  }
  monde.style.transform = t;
  CARTE.camAvant = t;
  CARTE.voyage = null; CARTE.voyageSaut = false;
}

// ------------------------------------------------------------------
// LE TRAIN DE TRANSIT — le trajet d'un chapitre au suivant.
// ------------------------------------------------------------------
// La caméra se déplaçait, mais rien ne PARCOURAIT la distance : on changeait
// de cadrage, pas d'endroit. Un convoi qui quitte la dernière gare d'un
// chapitre et rejoint la première du suivant fait la différence entre « la
// carte a bougé » et « je suis allé quelque part ».
function lancerTrain(duree) {
  const svg = CARTE.hote && CARTE.hote.querySelector(".c-ruban");
  const monde = svg && svg.querySelector(".monde");
  const t = CARTE.transit;
  if (!svg || !monde || !t) return null;
  const a = pos(t.de), b = pos(t.vers);
  if (!a || !b) return null;
  const k = (CARTE.cam && CARTE.cam.k) || 1;
  const ns = "http://www.w3.org/2000/svg";
  const g = document.createElementNS(ns, "g");
  g.setAttribute("class", "c-convoi" + (t.saut ? " par-la-mer" : ""));
  const c = document.createElementNS(ns, "circle");
  c.setAttribute("r", (2.6 / k).toFixed(2));
  const halo = document.createElementNS(ns, "circle");
  halo.setAttribute("class", "cv-halo");
  halo.setAttribute("r", (5 / k).toFixed(2));
  g.appendChild(halo); g.appendChild(c);
  monde.appendChild(g);
  const anim = g.animate(
    [{ transform: `translate(${a.x}px, ${a.y}px)`, opacity: 0 },
     { transform: `translate(${a.x}px, ${a.y}px)`, opacity: 1, offset: 0.12 },
     { transform: `translate(${b.x}px, ${b.y}px)`, opacity: 1, offset: 0.9 },
     { transform: `translate(${b.x}px, ${b.y}px)`, opacity: 0 }],
    { duration: duree, easing: "cubic-bezier(.45,.05,.3,1)", fill: "forwards" });
  anim.onfinish = () => g.remove();
  return anim;
}

// ------------------------------------------------------------------
// LES GESTES.
// ------------------------------------------------------------------
// Un seul geste sur une gare : la jouer. Sur un ruban il n'y a rien à ouvrir —
// une gare est atteinte ou elle ne l'est pas, et elle n'est alors pas cliquable.
function jouerGare(gareId) {
  const i = CATALOG.findIndex(c => c.id === gareId);
  if (i < 0 || !estTenue(gareId)) { renderCarte(); return; }
  // ON QUITTE UNE FÊTE DE CHAPITRE. Le voyage a DÉJÀ eu lieu, pendant qu'on
  // lisait le bilan (voir lancerVoyageDeChapitre) : cliquer ouvre donc le
  // niveau tout de suite, exactement comme entre deux gares du même chapitre.
  // S'il roule encore, on le coupe net — jamais d'attente imposée.
  if (CARTE.fete) {
    annulerVoyage();
    if (CARTE.transit) {
      const suivant = chapitreDeGare(gareId);
      CARTE.transit = null;
      if (suivant && suivant.saut) CARTE.voyageSaut = true;
    }
    CARTE.fete = null;
    CARTE.bilan = null;
    CARTE.medailles = null;
    CARTE.voyageFait = null;
    renderCarte();
  }
  startStation(i);
}

// ------------------------------------------------------------------
// LE VOYAGE DE FIN DE CHAPITRE — joué PENDANT la lecture, plus après le clic.
// ------------------------------------------------------------------
// Mesuré le 1er septembre 2026, retour de test de Vincent : deux gares du même
// chapitre s'enchaînent en 0 ms, un changement de chapitre en 2027 ms — et
// 2760 avec un saut. Trois ruptures d'un coup : l'attente, le panneau qui
// changeait de sujet, et le bouton qui nommait un chapitre au lieu d'une gare.
//
// Le convoi n'était pas le problème : il avait été ajouté exprès, parce que la
// caméra glissait auparavant DERRIÈRE l'écran de jeu et que personne ne le
// voyait. Il était au mauvais moment. Il occupe désormais le temps mort qui
// existait déjà — celui où l'on lit son bilan de chapitre — au lieu d'en créer
// un entre le geste et le jeu. Même spectacle, mieux vu, et zéro attente.
const DELAI_LECTURE = 700;                 // le temps de poser les yeux sur le bilan
function annulerVoyage() {
  for (const m of (CARTE.minuteries || [])) clearTimeout(m);
  CARTE.minuteries = null;
}
// DEUX TEMPS, ET DEUX FONCTIONS. `preparerVoyage` pose les DONNÉES du transit
// sans rendre — parce que la fin de service prépare puis dessine UNE fois
// (js/game.js : deux rendus faisaient clignoter le chapitre suivant avant la
// fête du précédent). `lancerVoyageDeChapitre` ne fait donc que partir les
// minuteries, une fois la carte déjà à l'écran.
function preparerVoyage() {
  annulerVoyage();
  CARTE.transit = null; CARTE.voyageFait = null;
  const f = CARTE.fete, gc = gareCourante();
  if (!f || !gc) return;
  const suivant = chapitreDeGare(gc);
  if (!suivant || suivant === f.ch) return;
  // Mouvement réduit : on se pose sur le nouveau chapitre, sans convoi.
  if (sansAnimation()) { CARTE.voyageFait = suivant; return; }
  CARTE.transit = { de: f.ch.gares[f.ch.gares.length - 1], vers: gc,
                    chapitre: suivant, saut: !!suivant.saut };
}
function lancerVoyageDeChapitre() {
  const t = CARTE.transit;
  if (!t || CARTE.minuteries) return;
  const route = t.saut ? DUREE_SAUT : DUREE_VOYAGE;
  CARTE.minuteries = [
    setTimeout(() => lancerTrain(route), DELAI_LECTURE),
    setTimeout(() => {
      CARTE.transit = null;
      CARTE.voyageFait = t.chapitre;   // la caméra reste sur le chapitre rejoint
      if (t.saut) CARTE.voyageSaut = true;
      renderCarte();
    }, DELAI_LECTURE + route)
  ];
}
// PASSER EN PAYANT (§4 ter). La gare reste à zéro étoile — ni jauge, ni rang,
// ni médaille — et se rejoue quand on veut : la gagner plus tard rend la mise.
function passerLaGare(gareId) {
  const prix = prixDePassage(gareId);
  if (soldeCredits() < prix || !payerPassage(gareId)) return;
  CARTE.bilan = null;
  CARTE.medailles = null;
  finDeGare(gareId);
}

// ------------------------------------------------------------------
// CE QUI SE PASSE QUAND UNE GARE EST FRANCHIE.
// ------------------------------------------------------------------
// Appelé par le relevé de fin (js/game.js) et par le passage payé. Décide s'il
// y a une fête de chapitre à poser, puis fait glisser la caméra.
// PRÉPARE, NE REND PAS. Le relevé de fin appelait ceci APRÈS avoir rendu la
// carte : deux rendus se suivaient, et le premier montrait une fraction de
// seconde le chapitre SUIVANT avant que la fête ne ramène sur celui qu'on
// vient de finir. Un clignotement, et deux animations qui se marchaient
// dessus. On calcule donc l'état d'abord, on rend une seule fois.
function preparerSuite(gareId) {
  const ch = chapitreDeGare(gareId);
  const gc = gareCourante();
  const nouveauCh = chapitreDeGare(gc);
  CARTE.prochaine = gc;
  if (ch && chapitreTermine(ch) && nouveauCh !== ch) {
    const chs = chapitresDuRuban();
    CARTE.fete = {
      ch, suivant: chs[ch.rang + 1] || null,
      zoneFinie: chs.filter(c => c.zone === ch.zone).every(chapitreTermine)
    };
    // LE RELEVÉ DE LA GARE RESTE. Il était effacé par le bilan du chapitre :
    // on perdait de vue les étoiles qu'on venait de décrocher, au seul moment
    // du jeu où deux récompenses tombent ensemble.
    preparerVoyage();               // le cadrage du transit, sans rendre
  } else {
    CARTE.voyageSaut = !!(nouveauCh && nouveauCh !== ch && nouveauCh.saut);
  }
}
function finDeGare(gareId) {
  preparerSuite(gareId);
  renderCarte();
  lancerVoyageDeChapitre();
}
